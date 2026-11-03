--[[
	RareEventService: every GameData.RareEvent.everySeconds a boosted creature (higher shiny chance,
	picked from a rare pool) appears in a random open lane for lastsSeconds. Everyone is told, and a
	big beacon marks it. First player to reach it gets the battle.
	ReplicatedStorage attributes for the HUD: RareEventNext (server time of the next one),
	RareEventEnds (while one is live), RareEventName.
	RareEventService.trigger() starts one immediately (handy for testing).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local WildSpawner = require(script.Parent.WildSpawner)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local RareEventService = {}
local Config = GameData.RareEvent
local rng = Random.new()

local folder = workspace:FindFirstChild("RareEventCreatures")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "RareEventCreatures"
	folder.Parent = workspace
end

local live -- current event model

local function beacon(model: Model)
	local root = model.PrimaryPart
	local bb = Instance.new("BillboardGui")
	bb.Name = "RareBeacon"
	bb.Size = UDim2.fromOffset(220, 60)
	bb.StudsOffset = Vector3.new(0, 9, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 1500
	bb.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(40, 25, 0)
	label.Text = "★ RARE SPAWN ★"
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.4, 0)
	c.Parent = label
	label.Parent = bb
	bb.Parent = root
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(255, 210, 80)
	h.FillTransparency = 0.7
	h.OutlineColor = Color3.fromRGB(255, 240, 160)
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 90)
	light.Range = 18
	light.Brightness = 2
	light.Parent = root
end

local function openLanes()
	local list = {}
	for _, lane in workspace.Map.Lanes:GetChildren() do
		if lane:IsA("BasePart") and lane:GetAttribute("Unlocked") then
			table.insert(list, lane)
		end
	end
	return list
end

local function despawn()
	if live and live.Parent and not live:GetAttribute("InBattle") then
		live:Destroy()
	end
	live = nil
	ReplicatedStorage:SetAttribute("RareEventEnds", nil)
	ReplicatedStorage:SetAttribute("RareEventName", nil)
end

local queued = {} -- paid summons waiting for the current rare creature to leave (buyers, in order)
local paidHandler -- fn(player) called when a paid summon actually appears (PassService clears it from the save)

function RareEventService.setPaidHandler(fn)
	paidHandler = fn
end

local function finished()
	despawn()
	-- buyers who left keep their summon in their save and get it in their next server
	while #queued > 0 and not queued[1].Parent do
		table.remove(queued, 1)
	end
	if #queued > 0 then
		local buyer = table.remove(queued, 1)
		task.delay(3, function()
			if buyer.Parent then
				RareEventService.trigger({ paidBy = buyer })
			else
				finished()
			end
		end)
	end
end

-- The rarest spawn of a region (lowest weight, first listed) a little above its usual levels
local function rarestOf(laneName: string)
	local cfg = GameData.Lanes[laneName]
	if not cfg then
		return nil
	end
	local best
	for _, s in cfg.spawns do
		if not best or s.weight < best.weight then
			best = s
		end
	end
	return best and { best.name, cfg.maxLevel + 2 }
end

-- Paid summons are fixed, never random: the buyer's furthest region they can enter, its rarest
-- creature, Huge, never shiny. (Free hourly / weekly-storm spawns keep their surprise.)
local function paidPick(player: Player?)
	local badges = player and (player:GetAttribute("Badges") or 0) or 0
	local champion = player and (player:GetAttribute("Stat_leagueWins") or 0) > 0
	local open = {}
	for _, lane in openLanes() do
		open[lane.Name] = lane
	end
	local chosen
	for _, r in GameData.Regions do
		if open[r.lane] and GameData.canEnter(r.lane, badges, champion) then
			chosen = r.lane
		end
	end
	chosen = chosen or (open.Lane1 and "Lane1")
	if not chosen then
		return nil
	end
	return open[chosen], rarestOf(chosen)
end

function RareEventService.trigger(opts)
	opts = opts or {}
	despawn()
	local lanes = openLanes()
	if #lanes == 0 then
		return false
	end
	local lane = lanes[rng:NextInteger(1, #lanes)]
	local pick = Config.pool[rng:NextInteger(1, #Config.pool)]
	local paidLane, paidSpecies
	if opts.paidBy then
		paidLane, paidSpecies = paidPick(opts.paidBy)
		lane = paidLane or lane
	end
	-- outside the Meadow Route: that region's rarest spawns, a little above its usual levels
	local laneConfig = GameData.Lanes[lane.Name]
	if lane.Name ~= "Lane1" and laneConfig then
		local rarest = {}
		local lowest = math.huge
		for _, s in laneConfig.spawns do
			lowest = math.min(lowest, s.weight)
		end
		for _, s in laneConfig.spawns do
			if s.weight <= math.max(lowest, 10) and not table.find(rarest, s.name) then
				table.insert(rarest, s.name)
			end
		end
		pick = { rarest[rng:NextInteger(1, #rarest)], laneConfig.maxLevel + 2 }
	end
	if opts.paidBy and paidSpecies then
		pick = paidSpecies
	end
	local shiny = not opts.paidBy and rng:NextNumber() < Config.shinyChance
	local halfX = lane.Size.X / 2 - 12
	local z = lane.Position.Z - lane.Size.Z / 2 + 40 + rng:NextNumber() * (lane.Size.Z - 120)
	local pos = Vector3.new(lane.Position.X + rng:NextNumber(-halfX, halfX), lane.Position.Y + lane.Size.Y / 2, z)
	local sizes = { "Large", "Huge" }
	local model = WildSpawner.spawnOne(pick[1], pick[2], pos, {
		folder = folder, shiny = shiny, sizeClass = opts.paidBy and "Huge" or sizes[rng:NextInteger(1, 2)], roam = 4,
	})
	model:SetAttribute("RareEvent", true)
	beacon(model)
	live = model
	if opts.paidBy and paidHandler then
		task.spawn(paidHandler, opts.paidBy)
	end
	local ends = workspace:GetServerTimeNow() + Config.lastsSeconds
	ReplicatedStorage:SetAttribute("RareEventEnds", ends)
	ReplicatedStorage:SetAttribute("RareEventName", (shiny and "Shiny " or "") .. pick[1])
	Notify:FireAllClients(("A RARE %s%s (Lv %d) appeared! Look for the gold beacon. %d minutes left!"):format(
		shiny and "SHINY " or "", pick[1], pick[2], math.floor(Config.lastsSeconds / 60)), "announce")

	local thisOne = model
	task.delay(Config.lastsSeconds, function()
		if live == thisOne then
			if thisOne.Parent and not thisOne:GetAttribute("InBattle") and not thisOne:GetAttribute("Caught") then
				Notify:FireAllClients("The rare creature wandered away...", "info")
			end
			finished()
		end
	end)
	-- clear the HUD timer early once it's caught or beaten
	task.spawn(function()
		while live == thisOne and thisOne.Parent and not thisOne:GetAttribute("Caught") do
			task.wait(1)
		end
		if live == thisOne then
			finished()
		end
	end)
	return true
end

-- Summon Rare Spawn (developer product). If one is already out, the summon waits its turn.
-- resumed = true for a summon bought earlier that was never delivered (saved in the player's data)
function RareEventService.summon(player: Player, resumed: boolean?): boolean
	if #openLanes() == 0 then
		return false -- nowhere to put it: Roblox keeps the receipt and retries later
	end
	Notify:FireAllClients((resumed and "%s's saved RARE SPAWN is coming for everyone!" or "%s summoned a RARE SPAWN for everyone!"):format(player.DisplayName), "announce")
	if live and live.Parent then
		table.insert(queued, player)
		Notify:FireClient(player, "A rare creature is already out. Yours appears as soon as it's gone!", "info")
		return true
	end
	return RareEventService.trigger({ paidBy = player })
end

function RareEventService.isLive(): boolean
	return live ~= nil and live.Parent ~= nil
end

function RareEventService.init()
	task.spawn(function()
		while true do
			ReplicatedStorage:SetAttribute("RareEventNext", workspace:GetServerTimeNow() + Config.everySeconds)
			task.wait(Config.everySeconds)
			RareEventService.trigger()
		end
	end)
end

return RareEventService
