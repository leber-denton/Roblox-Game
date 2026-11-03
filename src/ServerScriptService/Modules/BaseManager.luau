--[[
	BaseManager: hands each player one of the 8 bases and tracks their team.
	Each team member is a record: { id, name, level, xp, hp, model }.
	Teams, the index and the expansion are saved by SaveService (BaseManager.serialize / restore).
	Team capacity = 6, +6 with the expansion, +6 with the Extra Slots pass.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local BattleData = require(ReplicatedStorage.Shared.BattleData)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local Wander = require(script.Parent.Wander)

local BaseManager = {}

local function finite(n)
	if typeof(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return 0
	end
	return n
end

local basesFolder = workspace:WaitForChild("Map"):WaitForChild("Bases")
local playerBase = {} -- [Player] = base Model
local teams = {} -- [Player] = { record }
local nextId = 0

-- Creature Index: every species/size/shiny a player has ever caught (kept even if they release it later).
-- Sent to the client as JSON in the player's "IndexData" attribute.
local HttpService = game:GetService("HttpService")
local indexes = {} -- [Player] = { [name] = { count = n, sizes = { [sizeClass] = n }, shiny = n } }
BaseManager.hooks = {} -- hooks.indexed(player, index) after a new index entry; hooks.healed(player) after healAll

function BaseManager.getIndex(player: Player)
	return indexes[player] or {}
end

local function recordIndex(player: Player, record)
	local index = indexes[player]
	if not index then
		return
	end
	local entry = index[record.name] or { count = 0, sizes = {}, shiny = 0 }
	entry.count += 1
	local size = record.sizeClass or "Normal"
	entry.sizes[size] = (entry.sizes[size] or 0) + 1
	if record.shiny then
		entry.shiny += 1
	end
	index[record.name] = entry
	player:SetAttribute("IndexData", HttpService:JSONEncode(index))
	if BaseManager.hooks.indexed then
		task.spawn(BaseManager.hooks.indexed, player, index)
	end
end

local function sortedBases()
	local list = basesFolder:GetChildren()
	table.sort(list, function(a, b)
		return a:GetAttribute("BaseIndex") < b:GetAttribute("BaseIndex")
	end)
	return list
end

-- the base sign is a two-sided board: write the name on every face
local function setSign(base: Model, text: string)
	for _, d in base.SignAnchor:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "Text" then
			d.Text = text
		end
	end
end

-- Empty bases are walled off; the gate opens when a player claims the base
local function setGateOpen(base: Model, open: boolean)
	local gate = base:FindFirstChild("Gate")
	if gate then
		gate.Transparency = open and 1 or 0.35
		gate.CanCollide = not open
	end
end

-- The expansion behind each base: greyed out and walled off until the owner buys it
local function setExpansionOpen(base: Model, open: boolean)
	local exp = base:FindFirstChild("Expansion")
	if not exp then
		return
	end
	base:SetAttribute("ExpansionUnlocked", open)
	for _, d in exp:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "ExpansionBarrier" then
				d.Transparency = open and 1 or 0.1
				d.CanCollide = not open
			elseif d:GetAttribute("OpenColor") then
				local c = d:GetAttribute("OpenColor")
				if open then
					d.Color = c
				else
					local h, s, v = c:ToHSV()
					d.Color = Color3.fromHSV(h, s * 0.15, v * 0.7)
				end
			end
		end
	end
	local lockLabel = exp:FindFirstChild("LockLabel")
	if lockLabel and lockLabel:FindFirstChild("Label") then
		lockLabel.Label.Enabled = not open
	end
	local board = exp:FindFirstChild("UnlockBoard")
	local prompt = board and board:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = not open
	end
end

-- Side wings (base levels Large / Grand): greyed out with the inner fence up until opened
function BaseManager.setWings(base: Model, level: number)
	local wings = base:FindFirstChild("Wings")
	if not wings then
		return
	end
	local DecorData = require(game.ReplicatedStorage.Shared.DecorData)
	local open = {}
	for _, w in wings:GetChildren() do
		local side = w:GetAttribute("Side")
		local isOpen = (level or 1) >= (DecorData.WingLevels[side] or 99)
		open[side] = isOpen
		local f = w:FindFirstChild("WingFloor")
		if f then
			f:SetAttribute("WingOpen", isOpen)
			local c = f:GetAttribute("OpenColor") or f.Color
			if isOpen then
				f.Color = c
			else
				local h, s, v = c:ToHSV()
				f.Color = Color3.fromHSV(h, s * 0.15, v * 0.7)
			end
		end
		local lock = w:FindFirstChild("WingLock")
		if lock and lock:FindFirstChild("Label") then
			lock.Label.Enabled = not isOpen
		end
	end
	base:SetAttribute("WingLeft", open.left == true)
	base:SetAttribute("WingRight", open.right == true)
	local fence = base:FindFirstChild("Fence")
	if fence then
		for _, p in fence:GetChildren() do
			local side = p:GetAttribute("WingSide")
			if side and p:IsA("BasePart") then
				p.Transparency = open[side] and 1 or 0
				p.CanCollide = not open[side]
			end
		end
	end
end

function BaseManager.isExpansionUnlocked(player: Player): boolean
	local base = playerBase[player]
	return base ~= nil and base:GetAttribute("ExpansionUnlocked") == true
end

-- 6, +6 for the expansion, +6 for the Extra Slots game pass
function BaseManager.recalcCapacity(player: Player)
	local cap = GameData.StartingBaseCapacity
	if BaseManager.isExpansionUnlocked(player) then
		cap += 6
	end
	if player:GetAttribute("Pass_ExtraSlots") then
		cap += 6
	end
	player:SetAttribute("TeamCapacity", cap)
end

-- Opens the expansion and raises the team cap by 6
function BaseManager.unlockExpansion(player: Player): boolean
	local base = playerBase[player]
	if not base or base:GetAttribute("ExpansionUnlocked") then
		return false
	end
	setExpansionOpen(base, true)
	BaseManager.recalcCapacity(player)
	return true
end

local function refreshTag(record)
	local model = record.model
	if not model or not model.Parent or not model.PrimaryPart then
		return
	end
	local tag = model.PrimaryPart:FindFirstChild("NameTag")
	if not tag then
		return
	end
	local maxHP = BattleData.stats(record.name, record.level, record.sizeClass, record.ivs).maxHP
	local stars = record.stars or 0
	local starText = stars > 0 and (" " .. string.rep("⭐", stars)) or ""
	tag.NameLabel.Text = (record.shiny and "★ " or "") .. ("%s  Lv %d"):format(record.name, record.level) .. starText
	if record.hp <= 0 then
		tag.SubLabel.Text = "Fainted"
		tag.SubLabel.TextColor3 = Color3.fromRGB(255, 110, 110)
	elseif stars >= BattleData.MaxStars then
		tag.SubLabel.Text = ("HP %d/%d  ·  IV Trained"):format(record.hp, maxHP)
		tag.SubLabel.TextColor3 = Color3.fromRGB(255, 210, 80)
	elseif stars > 0 then
		local pct = math.floor((BattleData.starProgress(record) or 0) * 100)
		tag.SubLabel.Text = ("HP %d/%d  ·  Star %d: %d%%"):format(record.hp, maxHP, stars + 1, pct)
		tag.SubLabel.TextColor3 = Color3.fromRGB(255, 210, 80)
	else
		local lo, hi = BattleData.xpForLevel(record.level), BattleData.xpForLevel(record.level + 1)
		local pct = math.floor(math.clamp((record.xp - lo) / (hi - lo), 0, 1) * 100)
		tag.SubLabel.Text = ("HP %d/%d  ·  XP %d%%"):format(record.hp, maxHP, pct)
		tag.SubLabel.TextColor3 = Color3.fromRGB(140, 235, 140)
	end
end

function BaseManager.assign(player: Player): Model?
	for _, base in sortedBases() do
		if base:GetAttribute("OwnerId") == 0 then
			base:SetAttribute("OwnerId", player.UserId)
			setSign(base, player.DisplayName .. "'s Base")
			setGateOpen(base, true)
			playerBase[player] = base
			teams[player] = {}
			indexes[player] = {}
			player:SetAttribute("IndexData", "{}")
			player:SetAttribute("BaseIndex", base:GetAttribute("BaseIndex"))
			BaseManager.recalcCapacity(player)
			player:SetAttribute("TeamCount", 0)
			return base
		end
	end
	return nil
end

function BaseManager.release(player: Player)
	local base = playerBase[player]
	if base then
		base.Creatures:ClearAllChildren()
		base:SetAttribute("OwnerId", 0)
		setSign(base, "Empty Base")
		setGateOpen(base, false)
		setExpansionOpen(base, false)
		BaseManager.setWings(base, 1)
	end
	playerBase[player] = nil
	teams[player] = nil
	indexes[player] = nil
end

function BaseManager.getBase(player: Player): Model?
	return playerBase[player]
end

function BaseManager.getTeam(player: Player)
	return teams[player] or {}
end

function BaseManager.hasRoom(player: Player): boolean
	local team = teams[player]
	return team ~= nil and #team < (player:GetAttribute("TeamCapacity") or GameData.StartingBaseCapacity)
end

function BaseManager.findById(player: Player, id: number)
	for _, record in BaseManager.getTeam(player) do
		if record.id == id then
			return record
		end
	end
	return nil
end

function BaseManager.firstHealthy(player: Player)
	for _, record in BaseManager.getTeam(player) do
		if record.hp > 0 then
			return record
		end
	end
	return nil
end

function BaseManager.newRecord(name: string, level: number, hp: number?, shiny: boolean?, sizeClass: string?, ivs)
	nextId += 1
	ivs = BattleData.cleanIVs(ivs)
	local maxHP = BattleData.stats(name, level, sizeClass, ivs).maxHP
	local record = {
		id = nextId,
		name = name,
		level = level,
		xp = BattleData.xpForLevel(level),
		hp = math.clamp(hp or maxHP, 0, maxHP),
		shiny = shiny == true,
		sizeClass = sizeClass or "Normal",
		ivs = ivs,
		stars = 0,
	}
	BattleData.applyStars(record)
	return record
end

-- Build the roaming model for a record inside the owner's base
local function spawnModel(player: Player, record)
	local base = playerBase[player]
	if not base then
		return
	end

	-- creatures roam inside the base's fenced pen
	local floor = base:FindFirstChild("Pen") or base.Floor
	local exp = base:FindFirstChild("Expansion")
	if exp and base:GetAttribute("ExpansionUnlocked") and math.random() < 0.5 then
		floor = exp.Pen2
	end
	local groundY = floor.Position.Y + floor.Size.Y / 2
	local model = CreatureBuilder.build(record.name, record.level, { shiny = record.shiny, sizeClass = record.sizeClass })
	local spot = floor.Position + Vector3.new((math.random() * 2 - 1) * (floor.Size.X / 2 - 3), 0, (math.random() * 2 - 1) * (floor.Size.Z / 2 - 3))
	model:PivotTo(CFrame.new(spot.X, groundY + model:GetAttribute("GroundOffset"), spot.Z))
	model.Parent = base.Creatures
	record.model = model
	refreshTag(record)
	Wander.add(model, floor.Position, floor.Size.X / 2 - 3, floor.Size.Z / 2 - 3, groundY, 4)
end

-- opts.skipIndex: don't count it in the index (restoring a save); opts.force: ignore the team cap
function BaseManager.addCreature(player: Player, record, opts): boolean
	opts = opts or {}
	if not teams[player] or (not opts.force and not BaseManager.hasRoom(player)) then
		return false
	end
	table.insert(teams[player], record)
	player:SetAttribute("TeamCount", #teams[player])
	if not opts.skipIndex then
		recordIndex(player, record)
	end
	spawnModel(player, record)
	return true
end

-- Take a creature out of a player's team (trading). Returns the record.
function BaseManager.removeCreature(player: Player, id: number)
	local team = teams[player]
	if not team then
		return nil
	end
	for i, record in team do
		if record.id == id then
			table.remove(team, i)
			if record.model then
				Wander.remove(record.model)
				record.model:Destroy()
				record.model = nil
			end
			player:SetAttribute("TeamCount", #team)
			return record
		end
	end
	return nil
end

-- Turn a record into its evolution. Keeps the HP fraction; natural moves update to the new species.
function BaseManager.evolve(player: Player, record, into: string)
	local oldName = record.name
	local oldMax = BattleData.stats(oldName, record.level, record.sizeClass, record.ivs).maxHP
	local frac = oldMax > 0 and record.hp / oldMax or 1
	record.name = into
	local newMax = BattleData.stats(into, record.level, record.sizeClass, record.ivs).maxHP
	record.hp = record.hp <= 0 and 0 or math.max(1, math.floor(newMax * frac + 0.5))
	if record.moves then
		-- keep taught moves, add the new species' moves it would know now
		for _, m in BattleData.movesAt(into, record.level) do
			if not table.find(record.moves, m) then
				if #record.moves >= 4 then
					table.remove(record.moves, 1)
				end
				table.insert(record.moves, m)
			end
		end
	end
	if record.model then
		Wander.remove(record.model)
		record.model:Destroy()
		record.model = nil
	end
	spawnModel(player, record)
	recordIndex(player, record)
	return oldName
end

-- Plain data for saving
function BaseManager.serialize(player: Player)
	local list = {}
	for _, r in BaseManager.getTeam(player) do
		table.insert(list, {
			name = r.name, level = r.level, xp = r.xp, hp = r.hp,
			shiny = r.shiny, sizeClass = r.sizeClass, moves = r.moves, status = r.status, held = r.held,
			ivs = r.ivs,
		})
	end
	return { team = list, index = indexes[player] or {}, expansion = BaseManager.isExpansionUnlocked(player) }
end

-- Put a saved team, index and expansion back
function BaseManager.restore(player: Player, saved)
	if typeof(saved) ~= "table" or not playerBase[player] then
		return
	end
	if typeof(saved.index) == "table" then
		indexes[player] = saved.index
		player:SetAttribute("IndexData", HttpService:JSONEncode(saved.index))
	end
	if saved.expansion then
		setExpansionOpen(playerBase[player], true)
	end
	BaseManager.recalcCapacity(player)
	for _, s in saved.team or {} do
		if typeof(s) == "table" and GameData.Creatures[s.name] and BattleData.Species[s.name] then
			local level = math.clamp(math.floor(finite(tonumber(s.level) or 1)), 1, BattleData.MaxLevel)
			local record = BaseManager.newRecord(s.name, level, tonumber(s.hp), s.shiny, s.sizeClass, s.ivs)
			local xp = finite(tonumber(s.xp) or record.xp)
			record.xp = math.clamp(xp, BattleData.xpForLevel(level), level >= BattleData.MaxLevel and BattleData.maxXP() or BattleData.xpForLevel(level + 1))
			BattleData.applyStars(record)
			if typeof(s.moves) == "table" then
				record.moves = s.moves
			end
			if typeof(s.status) == "string" and GameData.StatusInfo[s.status] then
				record.status = s.status
			end
			local held = GameData.RetiredItems[s.held] or s.held -- cut items become their replacement
			if typeof(held) == "string" and GameData.Items[held] and GameData.Items[held].held then
				record.held = held
			end
			BaseManager.addCreature(player, record, { skipIndex = true, force = true })
		end
	end
end

-- Update every base creature's name tag (level / HP / fainted)
function BaseManager.refresh(player: Player)
	for _, record in BaseManager.getTeam(player) do
		refreshTag(record)
	end
end

function BaseManager.healAll(player: Player): number
	local healed = 0
	for _, record in BaseManager.getTeam(player) do
		local maxHP = BattleData.stats(record.name, record.level, record.sizeClass, record.ivs).maxHP
		if record.hp < maxHP or record.status then
			record.hp = maxHP
			record.status = nil
			record.sleepTurns = nil
			healed += 1
		end
	end
	BaseManager.refresh(player)
	if BaseManager.hooks.healed then
		task.spawn(BaseManager.hooks.healed, player)
	end
	return healed
end

-- Plain data about the team, safe to send to the client
function BaseManager.snapshot(player: Player)
	local list = {}
	for _, record in BaseManager.getTeam(player) do
		table.insert(list, {
			id = record.id,
			name = record.name,
			level = record.level,
			hp = record.hp,
			maxHP = BattleData.stats(record.name, record.level, record.sizeClass, record.ivs).maxHP,
			stars = record.stars or 0,
			ivs = record.ivs,
			type = GameData.Creatures[record.name].type,
			type2 = GameData.Creatures[record.name].type2,
			shiny = record.shiny,
			sizeClass = record.sizeClass,
			status = record.status,
			held = record.held,
		})
	end
	return list
end

-- Where a player's character appears: the middle of their base, facing the walkway
function BaseManager.spawnCFrame(player: Player): CFrame?
	local base = playerBase[player]
	if not base then
		return nil
	end
	local spawnPoint = base:FindFirstChild("SpawnPoint") or base.Floor
	local pos = spawnPoint.Position + Vector3.new(0, 3, 0)
	return CFrame.lookAt(pos, Vector3.new(0, pos.Y, pos.Z))
end

return BaseManager
