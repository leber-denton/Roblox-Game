--!strict
--[[
	ObstacleCourses (client): looks only, nothing here can claim a reward.
	  * one shared loop moves the tagged course parts (CourseMover, CourseSpinner, CourseVanish) from
	    the server clock, so every player sees the same timing
	  * each chest shows full or empty for this player only (server attribute CourseCooldowns)
	  * the chest open effect (lid, coin burst, sound) when the server says a claim paid out
	  * a one-line hint when you walk up to a course's start sign
	Server side: ServerScriptService.ObstacleCourses. Tuning: ReplicatedStorage.Shared.CourseConfig.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local CourseConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CourseConfig"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local HINT_RANGE, HINT_GAP = 18, 90

-- Moving parts ----------------------------------------------------------------------------------
local base: { [BasePart]: CFrame } = {}
local function track(part: Instance)
	if part:IsA("BasePart") then
		base[part] = part.CFrame -- the server never moves them, so this is the built position
	end
end
local function untrack(part: Instance)
	base[part :: BasePart] = nil
end
for _, tag in { "CourseMover", "CourseSpinner", "CourseVanish" } do
	for _, part in CollectionService:GetTagged(tag) do track(part) end
	CollectionService:GetInstanceAddedSignal(tag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
end

local TAU = math.pi * 2
RunService.Heartbeat:Connect(function()
	local t = workspace:GetServerTimeNow()
	for part, cf in base do
		if not part.Parent then
			base[part] = nil
			continue
		end
		local period = part:GetAttribute("MovePeriod")
		if typeof(period) == "number" and period > 0 then
			local axis = (part:GetAttribute("MoveAxis") or Vector3.zAxis) :: Vector3
			local amp = (part:GetAttribute("MoveAmplitude") or 0) :: number
			local phase = TAU * (t / period + ((part:GetAttribute("MovePhase") or 0) :: number))
			part.CFrame = cf + axis * amp * math.sin(phase)
			-- velocity lets a player standing on it ride along
			part.AssemblyLinearVelocity = axis * amp * TAU / period * math.cos(phase)
			continue
		end
		local speed = part:GetAttribute("SpinSpeed")
		if typeof(speed) == "number" then
			part.CFrame = cf * CFrame.Angles(0, (speed * t) % TAU, 0)
			part.AssemblyAngularVelocity = Vector3.new(0, speed, 0)
			continue
		end
		local vperiod = part:GetAttribute("VanishPeriod")
		if typeof(vperiod) == "number" and vperiod > 0 then
			local on = (part:GetAttribute("VanishOn") or 0.65) :: number
			local phase = (t / vperiod + ((part:GetAttribute("VanishPhase") or 0) :: number)) % 1
			local solid = phase < on
			-- flicker for the last part of the solid time as a warning
			part.Transparency = if not solid then 1 elseif phase > on - 0.15 then 0.55 else 0.1
			part.CanCollide = solid
		end
	end
end)

-- Chests ------------------------------------------------------------------------------------------
type Chest = { model: Model, lid: BasePart, closed: CFrame, coins: BasePart, prompt: ProximityPrompt?, busy: boolean }
local chests: { [string]: Chest } = {}

local function addChest(model: Instance)
	if not model:IsA("Model") then return end
	local id = model:GetAttribute("CourseChest")
	local lid = model:FindFirstChild("Lid")
	local coins = model:FindFirstChild("Coins")
	if typeof(id) ~= "string" or not (lid and lid:IsA("BasePart")) or not (coins and coins:IsA("BasePart")) then return end
	local prompt = model:FindFirstChild("ChestPrompt", true)
	chests[id] = {
		model = model, lid = lid, closed = lid.CFrame, coins = coins,
		prompt = prompt and prompt:IsA("ProximityPrompt") and prompt or nil, busy = false,
	}
end

local obstacles = workspace:WaitForChild("Obstacles", 60)
if obstacles then
	for _, d in obstacles:GetDescendants() do addChest(d) end
	-- With streaming, a chest's parts arrive (and leave) separately: re-register whenever one lands.
	local pending: { [Instance]: boolean } = {}
	obstacles.DescendantAdded:Connect(function(d)
		local model = if d:IsA("Model") then d else d:FindFirstAncestorWhichIsA("Model")
		if not model or model:GetAttribute("CourseChest") == nil or pending[model] then return end
		pending[model] = true
		task.delay(0.3, function()
			pending[model] = nil
			local id = model:GetAttribute("CourseChest")
			local existing = typeof(id) == "string" and chests[id]
			if not (existing and existing.busy) then addChest(model) end
		end)
	end)
end

local function cooldowns(): { [string]: number }
	local raw = player:GetAttribute("CourseCooldowns")
	if typeof(raw) ~= "string" then return {} end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and typeof(decoded) == "table" and decoded or {}
end

local function setLid(chest: Chest, angle: number)
	-- hinge on the back edge (+Z of the chest), so the front lifts toward the road
	local hinge = chest.closed * CFrame.new(0, -chest.lid.Size.Y / 2, chest.lid.Size.Z / 2)
	chest.lid.CFrame = hinge * CFrame.Angles(angle, 0, 0) * hinge:Inverse() * chest.closed
end

local function showState(chest: Chest, ready: boolean, left: number)
	chest.coins.Transparency = ready and 0 or 1
	local glow = chest.coins:FindFirstChild("Glow")
	if glow and glow:IsA("PointLight") then glow.Enabled = ready end
	local sparkle = chest.coins:FindFirstChild("Sparkle")
	if sparkle and sparkle:IsA("ParticleEmitter") then sparkle.Enabled = ready end
	if chest.prompt then
		chest.prompt.ObjectText = ready and "Treasure Chest"
			or ("Empty · refills in %d:%02d"):format(left // 60, left % 60)
	end
end

local function refreshChests()
	local cd = cooldowns()
	local t = workspace:GetServerTimeNow()
	for id, chest in chests do
		if chest.busy then continue end
		if not chest.model.Parent then
			chests[id] = nil
			continue
		end
		local ends = cd[id]
		local left = typeof(ends) == "number" and math.ceil(ends - t) or 0
		showState(chest, left <= 0, math.max(left, 0))
	end
end

local function playOpen(id: string)
	local chest = chests[id]
	if not chest then return end
	chest.busy = true
	chest.coins.Transparency = 0
	local start = os.clock()
	while os.clock() - start < 0.45 do
		setLid(chest, math.rad(105) * math.sin((os.clock() - start) / 0.45 * math.pi / 2))
		RunService.RenderStepped:Wait()
	end
	setLid(chest, math.rad(105))
	local burst = chest.coins:FindFirstChild("CoinBurst")
	if burst and burst:IsA("ParticleEmitter") then burst:Emit(45) end
	Sfx.play("levelUp")
	task.wait(2.5)
	start = os.clock()
	while os.clock() - start < 0.4 do
		setLid(chest, math.rad(105) * (1 - (os.clock() - start) / 0.4))
		RunService.RenderStepped:Wait()
	end
	chest.lid.CFrame = chest.closed
	chest.busy = false
	refreshChests()
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
task.spawn(function()
	local event = remotes:WaitForChild("CourseChest", 60)
	if event and event:IsA("RemoteEvent") then
		event.OnClientEvent:Connect(function(id: string)
			task.spawn(playOpen, id)
		end)
	end
end)
player:GetAttributeChangedSignal("CourseCooldowns"):Connect(refreshChests)

-- Start sign hint ----------------------------------------------------------------------------------
local lastHint: { [string]: number } = {}
local function hintNear(root: BasePart)
	if not obstacles or player:GetAttribute("InBattle") or player:GetAttribute("InDialogue") or player:GetAttribute("InCutscene") then return end
	for _, folder in obstacles:GetChildren() do
		local id = folder:GetAttribute("CourseId")
		local start = folder:FindFirstChild("Start")
		local pad = start and start:FindFirstChild("StartPad")
		local course = typeof(id) == "string" and CourseConfig.get(id)
		if course and pad and pad:IsA("BasePart") and (pad.Position - root.Position).Magnitude < HINT_RANGE then
			if os.clock() - (lastHint[course.Id] or -math.huge) > HINT_GAP then
				lastHint[course.Id] = os.clock()
				local toast = player:FindFirstChild("LocalToast")
				if toast and toast:IsA("BindableEvent") then
					toast:Fire(("Parkour Challenge (%s): reach the chest for %d coins. Falling only sends you back here.")
						:format(CourseConfig.tuning(course).Label, course.CoinReward), "info")
				end
			end
		end
	end
end

while true do
	task.wait(0.5)
	refreshChests()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then hintNear(root) end
end
