--[[
	WildSpawner: fills open routes with wild creatures and runs safe Wild Shifts.
	Hot Zone bonuses apply only to regular lane spawns. Tutorial creatures and the
	separate paid/hourly RareEventCreatures folder keep their existing rules.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local Wander = require(script.Parent.Wander)
local BattleService = require(script.Parent.BattleService)

local WildSpawner = {}

local folder = workspace:FindFirstChild("WildCreatures")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WildCreatures"
	folder.Parent = workspace
end

local rng = Random.new()
local hotZoneLane: string? = nil
local filling = {}
local PROTECT_DISTANCE = 60
local HOT_SHINY_MULTIPLIER = 3
local HOT_LARGE_MULTIPLIER = 1.5
local HOT_HUGE_MULTIPLIER = 2

function WildSpawner.setHotZone(laneKey: string?)
	assert(laneKey == nil or GameData.Lanes[laneKey], "Unknown Hot Zone lane")
	hotZoneLane = laneKey
end

function WildSpawner.getHotZone(): string?
	return hotZoneLane
end

local function pickEntry(spawns, depth: number, isHotZone: boolean)
	local pool, total, present = {}, 0, {}
	local lowestWeight = math.huge
	for _, entry in spawns do
		lowestWeight = math.min(lowestWeight, entry.weight)
		if depth >= entry.minDepth and depth <= (entry.maxDepth or 1) then
			table.insert(pool, entry)
			present[entry.name] = true
			total += entry.weight
		end
	end
	-- The route's rarest authored species can appear throughout its Hot Zone,
	-- including near the start. Do not import paid-event species or change levels.
	if isHotZone then
		for _, entry in spawns do
			if entry.weight == lowestWeight and not present[entry.name] then
				table.insert(pool, entry)
				present[entry.name] = true
				total += entry.weight
			end
		end
	end
	local roll = rng:NextNumber() * total
	for _, entry in pool do
		roll -= entry.weight
		if roll <= 0 then
			return entry
		end
	end
	return pool[#pool]
end

-- Calls without a regular lane keep the base odds (e.g. admin spawns).
function WildSpawner.rollVariant(laneKey: string?): (boolean, string)
	local hot = laneKey ~= nil and laneKey == hotZoneLane
	local shiny = rng:NextNumber() < math.min(1, GameData.ShinyChance * (hot and HOT_SHINY_MULTIPLIER or 1))
	local function weight(c)
		if hot and c.name == "Large" then
			return c.weight * HOT_LARGE_MULTIPLIER
		elseif hot and c.name == "Huge" then
			return c.weight * HOT_HUGE_MULTIPLIER
		end
		return c.weight
	end
	local total = 0
	for _, c in GameData.SizeClasses do
		total += weight(c)
	end
	local roll = rng:NextNumber() * total
	for _, c in GameData.SizeClasses do
		roll -= weight(c)
		if roll <= 0 then
			return shiny, c.name
		end
	end
	return shiny, "Normal"
end

-- opts: { shiny, sizeClass, folder, owner (tutorial UserId), roam, lane }
function WildSpawner.spawnOne(name: string, level: number, pos: Vector3, opts): Model
	opts = opts or {}
	local shiny, sizeClass = opts.shiny, opts.sizeClass
	if shiny == nil or sizeClass == nil then
		local regularLane = not opts.owner and (not opts.folder or opts.folder == folder) and opts.lane or nil
		local rolledShiny, rolledSize = WildSpawner.rollVariant(regularLane)
		if shiny == nil then
			shiny = rolledShiny
		end
		sizeClass = sizeClass or rolledSize
	end

	local model = CreatureBuilder.build(name, level, { shiny = shiny, sizeClass = sizeClass })
	model:SetAttribute("Level", level)
	if opts.lane then
		model:SetAttribute("Lane", opts.lane)
	end
	if opts.owner then
		model:SetAttribute("TutorialOwner", opts.owner)
	end
	if opts.hotZone then
		model:SetAttribute("WildShiftBoosted", true)
	end
	local groundY = Wander.groundAt(pos) or pos.Y
	model:PivotTo(CFrame.new(pos.X, groundY + model:GetAttribute("GroundOffset"), pos.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Battle"
	prompt.ObjectText = ((shiny and "Shiny " or "") .. "%s  Lv %d"):format(name, level)
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12 + model.PrimaryPart.Size.X * 0.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		BattleService.start(player, model)
	end)

	model.Parent = opts.folder or folder
	local roam = opts.roam or 6
	Wander.add(model, Vector3.new(pos.X, groundY, pos.Z), roam, roam, groundY, 5)
	return model
end

local function spawnInLane(lane: BasePart, config, laneKey: string)
	local halfX = lane.Size.X / 2 - 10
	local startZ = lane.Position.Z - lane.Size.Z / 2 + 20
	local length = lane.Size.Z - 60 -- keep clear of the gym at the end
	local y = lane.Position.Y + lane.Size.Y / 2
	local depth = rng:NextNumber()
	local pos = Vector3.new(lane.Position.X + rng:NextNumber(-halfX, halfX), y, startZ + depth * length)
	local hot = laneKey == hotZoneLane
	local entry = pickEntry(config.spawns, depth, hot)
	if not entry then
		return
	end
	local level = entry.level
		or math.clamp(config.minLevel + math.floor(depth * (config.maxLevel - config.minLevel + 1)), config.minLevel, config.maxLevel)
	WildSpawner.spawnOne(entry.name, level, pos, { lane = laneKey, hotZone = hot })
end

local function laneParts(laneKey: string)
	local lane = workspace.Map.Lanes:FindFirstChild(laneKey)
	local config = GameData.Lanes[laneKey]
	if not lane or not config or not lane:GetAttribute("Unlocked") then
		return nil
	end
	return lane, config
end

-- Count free creatures, including those protected because a player is nearby.
function WildSpawner.countLane(laneKey: string): number
	local n = 0
	for _, model in folder:GetChildren() do
		if model:GetAttribute("Lane") == laneKey and not model:GetAttribute("Caught") and not model:GetAttribute("InBattle") then
			n += 1
		end
	end
	return n
end

local function fillLane(laneKey: string, maxNew: number)
	if filling[laneKey] then
		return
	end
	local lane, config = laneParts(laneKey)
	if not lane then
		return
	end
	filling[laneKey] = true
	local ok, err = pcall(function()
		for _ = 1, maxNew do
			if not lane:GetAttribute("Unlocked") or WildSpawner.countLane(laneKey) >= GameData.WildPerLane then
				break
			end
			spawnInLane(lane, config, laneKey)
		end
	end)
	filling[laneKey] = nil
	if not ok then
		error(err)
	end
end

-- Fill only vacant slots. Kept creatures never cause an extra full batch.
function WildSpawner.spawnLane(laneKey: string)
	fillLane(laneKey, GameData.WildPerLane)
end

function WildSpawner.refillLane(laneKey: string)
	fillLane(laneKey, 1)
end

-- Check live positions at deletion time; wandering can move a creature away
-- from its original spawn. InBattle is set before BattleService yields.
function WildSpawner.canReplace(model: Model): boolean
	if model.Parent ~= folder or not model:IsA("Model")
		or model:GetAttribute("InBattle") or model:GetAttribute("Caught")
		or model:GetAttribute("TutorialOwner") or model:GetAttribute("RareEvent") then
		return false
	end
	local position = model:GetPivot().Position
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude <= PROTECT_DISTANCE then
			return false
		end
	end
	return true
end

function WildSpawner.clearLane(laneKey: string)
	for _, model in folder:GetChildren() do
		if model:GetAttribute("Lane") == laneKey and WildSpawner.canReplace(model) then
			model:Destroy()
		end
	end
end

function WildSpawner.shift(): number
	local removed = 0
	for _, model in folder:GetChildren() do
		if WildSpawner.canReplace(model) then
			model:Destroy()
			removed += 1
		end
	end
	return removed
end

-- Existing admin callers also get the same nearby/battle safeguards.
function WildSpawner.clear()
	return WildSpawner.shift()
end

return WildSpawner
