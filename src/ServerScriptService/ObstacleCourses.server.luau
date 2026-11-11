--!strict
--[[
	ObstacleCourses: server side of the optional parkour courses in Workspace.Obstacles
	(built in Edit by ServerStorage.ObstacleCourseBuilder, tuned in ReplicatedStorage.Shared.CourseConfig).

	Everything is server authoritative. The client never sends an amount or a "finished" claim:
	  * a run starts when the server sees the player standing on the course's StartPad
	  * the chest's ProximityPrompt is the only claim; the server checks the run, the minimum run
	    time (CourseConfig.Difficulties.*.MinSeconds), the distance to the chest, the per-chest
	    cooldown and a rate limit before paying coins through PlayerData.addCoins
	  * falling (below the start pad, inside the course footprint) or touching a ResetStrip only
	    moves the player back to that course's start pad. It never hurts, and it only happens
	    during a run, so nobody is ever moved off the road or between routes
	The one-time first-clear bonus and the chest cooldowns are saved through SaveService's "courses"
	section, so a rejoin neither repeats the bonus nor refills a chest early.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local CourseConfig = require(ReplicatedStorage.Shared.CourseConfig)
local GameData = require(ReplicatedStorage.Shared.GameData)
local Modules = script.Parent:WaitForChild("Modules")
local PlayerData = require(Modules.PlayerData)
local SaveService = require(Modules.SaveService)
local BattleService = require(Modules.BattleService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent
-- Server -> client only (chest open effect). No OnServerEvent handler: clients can't claim anything.
local ChestEvent = Remotes:FindFirstChild("CourseChest") :: RemoteEvent?
if not ChestEvent then
	local remote = Instance.new("RemoteEvent")
	remote.Name = "CourseChest"
	remote.Parent = Remotes
	ChestEvent = remote
end
local chestEvent = ChestEvent :: RemoteEvent

local SAVE_VERSION = 1
local PROMPT_GAP = 1 -- seconds between chest attempts per player
local RESET_GAP = 1.5 -- seconds between fall resets
local LEAVE_MARGIN = 24 -- a run ends once the player is this far outside the course footprint
local START_EXEMPT = 10 -- no fall reset within this distance of the start pad (access steps)

type Course = {
	id: string,
	folder: Instance,
	pad: BasePart,
	bounds: BasePart,
	chest: Model?,
	floorY: number,
}
type Run = { id: string, startedAt: number }

local courses: { [string]: Course } = {}
local runs: { [Player]: Run } = {}
local cooldowns: { [Player]: { [string]: number } } = {}
local cleared: { [Player]: { [string]: boolean } } = {}
local lastPrompt: { [Player]: number } = {}
local lastReset: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function cooldownsOf(player: Player): { [string]: number }
	local c = cooldowns[player]
	if not c then
		c = {}
		cooldowns[player] = c
	end
	return c
end

local function clearedOf(player: Player): { [string]: boolean }
	local c = cleared[player]
	if not c then
		c = {}
		cleared[player] = c
	end
	return c
end

-- The client reads this to show each chest as full or empty for this player only.
local function publish(player: Player)
	local list = {}
	local t = now()
	for id, ends in cooldownsOf(player) do
		if ends > t then list[id] = math.floor(ends) end
	end
	player:SetAttribute("CourseCooldowns", HttpService:JSONEncode(list))
end

-- Save section ---------------------------------------------------------------------------------
SaveService.register("courses", {
	serialize = function(player: Player)
		local ids = {}
		for id in clearedOf(player) do table.insert(ids, id) end
		local list = {}
		local t = now()
		for id, ends in cooldownsOf(player) do
			if ends > t then list[id] = ends end
		end
		return { v = SAVE_VERSION, cleared = ids, cooldowns = list }
	end,
	load = function(player: Player, saved: any)
		if typeof(saved) ~= "table" then return end
		local c = clearedOf(player)
		if typeof(saved.cleared) == "table" then
			for _, id in saved.cleared do
				if typeof(id) == "string" and #id <= 40 then c[id] = true end
			end
		end
		local cd = cooldownsOf(player)
		if typeof(saved.cooldowns) == "table" then
			local t = now()
			for id, ends in saved.cooldowns do
				local course = typeof(id) == "string" and CourseConfig.get(id)
				if course and PlayerData.finite(ends) and ends > t then
					-- never trust a cooldown longer than the configured one
					cd[id] = math.min(ends, t + CourseConfig.cooldown(course))
				end
			end
		end
		publish(player)
	end,
	release = function(player: Player)
		cooldowns[player], cleared[player] = nil, nil
	end,
})

-- Course registry -------------------------------------------------------------------------------
local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function inside(part: BasePart, pos: Vector3, margin: number): boolean
	local p = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X + margin and math.abs(p.Z) <= half.Z + margin and math.abs(p.Y) <= half.Y + margin
end

local function backToStart(player: Player, course: Course, why: string)
	local root = rootOf(player)
	if not root or os.clock() - (lastReset[player] or -math.huge) < RESET_GAP then return end
	lastReset[player] = os.clock()
	local character = player.Character :: Model
	character:PivotTo(course.pad.CFrame * CFrame.new(0, course.pad.Size.Y / 2 + 3.2, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	runs[player] = { id = course.id, startedAt = os.clock() }
	Notify:FireClient(player, why, "info")
end

local function fmtTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function onChest(course: Course, player: Player)
	if os.clock() - (lastPrompt[player] or -math.huge) < PROMPT_GAP then return end
	lastPrompt[player] = os.clock()
	local config = CourseConfig.get(course.id)
	local chest = course.chest
	local root = rootOf(player)
	if not config or not chest or not chest.PrimaryPart or not root then return end
	if (root.Position - chest.PrimaryPart.Position).Magnitude > CourseConfig.PromptDistance + 2 then return end
	if BattleService.isInBattle(player) then return end
	local champion = ((player:GetAttribute("Stat_leagueWins") or 0) :: number) > 0
	if not GameData.canEnter(config.Lane, (player:GetAttribute("Badges") or 0) :: number, champion) then
		Notify:FireClient(player, "Earn this route's badges before opening its chest.", "fail")
		return
	end
	local ends = cooldownsOf(player)[course.id] or 0
	if now() < ends then
		Notify:FireClient(player, ("This chest is empty. It refills in %s."):format(fmtTime(ends - now())), "fail")
		return
	end
	local run = runs[player]
	local tuning = CourseConfig.tuning(config)
	if not run or run.id ~= course.id or os.clock() - run.startedAt > CourseConfig.RunTimeout then
		Notify:FireClient(player, "Start at the Parkour Challenge sign to earn this chest.", "fail")
		return
	end
	if os.clock() - run.startedAt < tuning.MinSeconds then
		-- faster than the course can be run: treat it as a skip, not a clear
		Notify:FireClient(player, "Run the course from the start to earn this chest.", "fail")
		runs[player] = nil
		return
	end
	-- Pay out.
	runs[player] = nil
	local doubled = GameData.hasBoost(player, "DoubleCoins") and 2 or 1
	PlayerData.addCoins(player, config.CoinReward)
	local total = config.CoinReward * doubled
	local text = ("Parkour cleared! +%d coins"):format(total)
	local done = clearedOf(player)
	if not done[course.id] then
		done[course.id] = true
		local bonus = CourseConfig.firstClearBonus(config)
		PlayerData.addCoins(player, bonus)
		total += bonus * doubled
		text ..= (" · First clear bonus +%d!"):format(bonus * doubled)
	end
	cooldownsOf(player)[course.id] = now() + CourseConfig.cooldown(config)
	publish(player)
	SaveService.requestSave(player)
	Notify:FireClient(player, text, "success")
	chestEvent:FireClient(player, course.id, total)
end

local wiredChests: { [Instance]: boolean } = {}
local function register(folder: Instance)
	local id = folder:GetAttribute("CourseId")
	if typeof(id) ~= "string" then return end
	local start = folder:FindFirstChild("Start")
	local pad = start and start:FindFirstChild("StartPad")
	local bounds = folder:FindFirstChild("CourseBounds")
	if not (pad and pad:IsA("BasePart") and bounds and bounds:IsA("BasePart")) then
		warn("ObstacleCourses: course", folder:GetFullName(), "is missing its StartPad or CourseBounds")
		return
	end
	if not CourseConfig.get(id) then
		warn("ObstacleCourses: no CourseConfig entry for", id)
		return
	end
	local chest = folder:FindFirstChild("Chest") :: Model?
	local floorY = folder:GetAttribute("FloorY")
	local course: Course = {
		id = id, folder = folder, pad = pad, bounds = bounds, chest = chest,
		floorY = typeof(floorY) == "number" and floorY or pad.Position.Y + pad.Size.Y / 2,
	}
	courses[id] = course
	local prompt = chest and chest:FindFirstChild("ChestPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") and not wiredChests[prompt] then
		wiredChests[prompt] = true
		prompt.Triggered:Connect(function(player)
			local current = courses[id]
			if current then onChest(current, player) end
		end)
	end
end

local function onHazard(part: Instance)
	if not part:IsA("BasePart") then return end
	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local id = part:GetAttribute("CourseId")
		local run = player and runs[player]
		local course = typeof(id) == "string" and courses[id]
		if player and run and course and run.id == id then
			backToStart(player, course, "Ouch, the glowing strip! Back to the start.")
		end
	end)
end

local obstacles = workspace:WaitForChild("Obstacles", 30)
if obstacles then
	for _, folder in obstacles:GetChildren() do register(folder) end
	obstacles.ChildAdded:Connect(function(folder)
		task.wait(1) -- let the folder's parts arrive
		register(folder)
	end)
end
for _, part in CollectionService:GetTagged("CourseHazard") do onHazard(part) end
CollectionService:GetInstanceAddedSignal("CourseHazard"):Connect(onHazard)

-- One shared loop: starts runs on the pads, resets falls, ends runs that wander off.
task.spawn(function()
	while true do
		task.wait(0.2)
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if not root then continue end
			local pos = root.Position
			for id, course in courses do
				local pad = course.pad
				local local_ = pad.CFrame:PointToObjectSpace(pos)
				if math.abs(local_.X) <= pad.Size.X / 2 + 0.5 and math.abs(local_.Z) <= pad.Size.Z / 2 + 0.5 and local_.Y > 0 and local_.Y < 6 then
					-- standing on the pad: the run (and its minimum time) starts when they step off
					runs[player] = { id = id, startedAt = os.clock() }
				end
			end
			local run = runs[player]
			local course = run and courses[run.id]
			if run and not course then
				runs[player] = nil
			elseif run and course then
				if os.clock() - run.startedAt > CourseConfig.RunTimeout or not inside(course.bounds, pos, LEAVE_MARGIN) then
					runs[player] = nil
				elseif inside(course.bounds, pos, 0) and pos.Y < course.floorY + 2.4 then
					local flat = Vector3.new(pos.X - course.pad.Position.X, 0, pos.Z - course.pad.Position.Z)
					if flat.Magnitude > START_EXEMPT then
						backToStart(player, course, "You fell! Back to the start of the course.")
					end
				end
			end
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	publish(player)
end)
for _, player in Players:GetPlayers() do publish(player) end

Players.PlayerRemoving:Connect(function(player)
	runs[player], lastPrompt[player], lastReset[player] = nil, nil, nil
	-- saved tables are freed by the save section's release hook (after the leave-save); this
	-- fallback covers players whose save never loaded
	task.delay(60, function()
		if not player.Parent then cooldowns[player], cleared[player] = nil, nil end
	end)
end)
