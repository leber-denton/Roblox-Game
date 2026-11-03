--[[
	DecorService: base decorations and the coin economy around them (data in ReplicatedStorage.Shared.DecorData).
	  - Shop: permanent items, a daily rotating shop (same 5 items for everyone each UTC day, one buy each)
	  - Crates: bought with coins or earned (first win against each gym leader = Mystic Crate, other trainer
	    wins have a 25% chance of a Garden Crate). Odds are shown in the menu. Duplicates of crate items become
	    shards, and shards buy any crate item outright.
	  - Building: place / move / remove on a half-stud grid inside your base (and the expansion once unlocked).
	  - Base level (decor cap, coin bonus, coin jar size), themes, and functional decor that ticks every minute:
	    coin generators fill the Coin Jar by your spawn, Healing Pads heal, base training gives XP every minute
	    (Training Dummies and type-matching habitats speed it up; GameData.BaseTraining),
	    Display Pedestals show your strongest creature, Trophy Walls show your badges and catches.
	  - Likes: anyone can like another player's base once a day (owner gets coins; Most Liked board in the hub).
	  - Robux: coin bundles (developer products, ProcessReceipt here) and the Premium Decor game pass.
	Saved by SaveService under "decor". Client talks through Remotes.Decor (RemoteFunction) and gets
	the whole state back through Remotes.DecorSync.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local DecorData = require(ReplicatedStorage.Shared.DecorData)
local GameData = require(ReplicatedStorage.Shared.GameData)
local BattleData = require(ReplicatedStorage.Shared.BattleData)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local BaseManager = require(script.Parent.BaseManager)
local PlayerData = require(script.Parent.PlayerData)
local SaveService = require(script.Parent.SaveService)
local BattleService = require(script.Parent.BattleService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local DecorRemote = Remotes:WaitForChild("Decor")
local DecorSync = Remotes:WaitForChild("DecorSync")

local DecorService = {}

local Items = DecorData.Items
local state = {} -- [Player] = saved decor state
local models = {} -- [Player] = { [uid] = Model }
local staticParts = {} -- [base Model] = { BasePart } things decor can't overlap

local MAX_OWNED = 25 -- of any one item
local MAX_RECEIPTS = 60

local function defaults()
	return {
		owned = {}, -- [id] = how many you own (placed ones included)
		placed = {}, -- { uid, id, x, z, r }
		nextUid = 1,
		shards = 0,
		boxes = {}, -- [boxId] = earned crates waiting to be opened
		theme = "Meadow",
		themes = { Meadow = true },
		level = 1,
		bank = 0,
		lastSeen = os.time(),
		dailyDay = 0,
		dailyBought = {},
		likedDay = 0,
		liked = {}, -- userIds liked today
		gymCrates = {}, -- gym keys that already gave their crate
		receipts = {}, -- Robux purchase ids already granted
		bought = {}, -- one-time Robux bundles bought: [key] = true
		layout = 1, -- base layout the placed positions were saved for (see DecorData.LayoutVersion)
		canopy = 1, -- XP Canopy level (DecorData.CanopyTiers)
	}
end

----------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------
local function floorOf(base: Model): BasePart
	return base.Floor
end

local function levelDef(d)
	return DecorData.BaseLevels[math.clamp(d.level, 1, #DecorData.BaseLevels)]
end

local function placedCount(d, id: string): number
	local n = 0
	for _, p in d.placed do
		if p.id == id then
			n += 1
		end
	end
	return n
end

local function countWith(d, key: string): number
	local n = 0
	for _, p in d.placed do
		local item = Items[p.id]
		if item and item[key] then
			n += 1
		end
	end
	return n
end

-- Coins per minute from coin generators, with the base level bonus (habitats train XP instead)
local function incomeRate(player: Player, d): number
	local rate = 0
	for _, p in d.placed do
		local item = Items[p.id]
		if item and item.gen then
			rate += item.gen
		end
	end
	return rate * (1 + levelDef(d).bonus)
end

-- Base training: the share of a level each creature gains per minute
local Training = GameData.BaseTraining
local function trainingRates(player: Player, d)
	local dummies = math.min(countWith(d, "train"), Training.maxDummies)
	local habitats = {}
	for _, p in d.placed do
		local item = Items[p.id]
		if item and item.habitat and #habitats < Training.maxHabitats then
			table.insert(habitats, item.habitat)
		end
	end
	local rates = {}
	for _, record in BaseManager.getTeam(player) do
		local rate = Training.rate + dummies * Training.dummyRate
		local c = GameData.Creatures[record.name]
		for _, types in habitats do
			if c and (table.find(types, c.type) or (c.type2 and table.find(types, c.type2))) then
				rate += Training.habitatRate
			end
		end
		rates[record] = rate
	end
	return rates
end

-- Give `minutes` of base training to the team. Returns how many creatures levelled up.
local function train(player: Player, d, minutes: number): number
	local cap = Training.levelCap(player:GetAttribute("Badges") or 0, (player:GetAttribute("Stat_leagueWins") or 0) > 0)
	local grew = 0
	for record, rate in trainingRates(player, d) do
		local startLevel = record.level
		local left = minutes
		while left > 0 and record.hp > 0 and record.level < cap do
			local step = math.min(left, 10)
			local span = BattleData.xpForLevel(record.level + 1) - BattleData.xpForLevel(record.level)
			local gain = math.max(1, math.floor(span * rate * step))
			-- never train past the cap's XP
			gain = math.min(gain, BattleData.xpForLevel(cap) - record.xp)
			if gain <= 0 then
				break
			end
			BattleService.applyXP(record, gain, player)
			left -= step
		end
		if record.level > startLevel then
			grew += 1
		end
	end
	return grew
end
DecorService.train = train

local function bankCap(player: Player, d): number
	return math.max(50, math.floor(incomeRate(player, d) * levelDef(d).jarMinutes))
end

-- Everything the client needs
local function publicState(player: Player, d)
	local today = DecorData.today()
	if d.dailyDay ~= today then
		d.dailyDay = today
		d.dailyBought = {}
	end
	return {
		owned = d.owned,
		placed = d.placed,
		shards = d.shards,
		boxes = d.boxes,
		theme = d.theme,
		themes = d.themes,
		level = d.level,
		bank = math.floor(d.bank),
		bankCap = bankCap(player, d),
		rate = incomeRate(player, d),
		daily = DecorData.dailyShop(today),
		dailyBought = d.dailyBought,
		dailyEndsAt = (today + 1) * 86400,
		expansion = BaseManager.isExpansionUnlocked(player),
		premium = player:GetAttribute("Pass_PremiumDecor") == true,
		bought = d.bought,
	}
end

local function sync(player: Player)
	local d = state[player]
	if not d then
		return
	end
	player:SetAttribute("BaseBank", math.floor(d.bank))
	player:SetAttribute("BaseBankCap", bankCap(player, d))
	player:SetAttribute("BaseRate", incomeRate(player, d))
	player:SetAttribute("BaseLevel", d.level)
	local tiers = DecorData.CanopyTiers
	d.canopy = math.clamp(math.floor(tonumber(d.canopy) or 1), 1, #tiers)
	player:SetAttribute("CanopyLevel", d.canopy)
	player:SetAttribute("CanopyShare", tiers[d.canopy].share)
	DecorSync:FireClient(player, publicState(player, d))
end
DecorService.sync = sync

----------------------------------------------------------------------------------------------
-- themes
----------------------------------------------------------------------------------------------
local function themeTargets(base: Model)
	local list = {}
	local function add(part, role)
		if part and part:IsA("BasePart") then
			table.insert(list, { part = part, role = role })
		end
	end
	add(base:FindFirstChild("Floor"), "floor")
	local wings = base:FindFirstChild("Wings")
	if wings then
		for _, w in wings:GetChildren() do
			add(w:FindFirstChild("WingFloor"), "wingfloor")
			local wf = w:FindFirstChild("WingFence")
			if wf then
				for _, p in wf:GetDescendants() do
					add(p, p.Name == "Cap" and "cap" or "fence")
				end
			end
		end
	end
	add(base:FindFirstChild("Pen"), "pen")
	add(base:FindFirstChild("Path"), "path")
	for _, c in base:GetChildren() do
		if c.Name == "Lamp" then
			add(c, "lamp")
		end
	end
	local fence = base:FindFirstChild("Fence")
	if fence then
		for _, p in fence:GetDescendants() do
			add(p, p.Name == "Cap" and "cap" or "fence")
		end
	end
	local exp = base:FindFirstChild("Expansion")
	if exp then
		add(exp:FindFirstChild("ExpFloor"), "expfloor")
		add(exp:FindFirstChild("Pen2"), "exppen")
		local ef = exp:FindFirstChild("ExpFence")
		if ef then
			for _, p in ef:GetDescendants() do
				add(p, p.Name == "Cap" and "cap" or "fence")
			end
		end
	end
	return list
end

-- Remember how every themed part looked originally (Meadow = put these back)
local function rememberOriginals(base: Model)
	for _, t in themeTargets(base) do
		local p = t.part
		if p:GetAttribute("OrigColor") == nil then
			p:SetAttribute("OrigColor", p:GetAttribute("OpenColor") or p.Color)
			p:SetAttribute("OrigMat", p.Material.Name)
		end
	end
end

local function applyTheme(base: Model, themeId: string)
	local theme = DecorData.Themes[themeId]
	local expOpen = base:GetAttribute("ExpansionUnlocked") == true
	for _, t in themeTargets(base) do
		local p, role = t.part, t.role
		local color, mat
		if not theme or themeId == "Meadow" then
			color, mat = p:GetAttribute("OrigColor"), Enum.Material[p:GetAttribute("OrigMat") or "SmoothPlastic"]
		elseif role == "floor" or role == "expfloor" or role == "wingfloor" then
			color, mat = theme.floor, Enum.Material[theme.floorMat]
		elseif role == "pen" or role == "exppen" then
			color, mat = theme.floor:Lerp(Color3.new(0, 0, 0), 0.12), Enum.Material[theme.floorMat]
		elseif role == "path" then
			color, mat = theme.path, Enum.Material[theme.pathMat]
		elseif role == "lamp" then
			color, mat = theme.lamp, Enum.Material.Neon
		elseif role == "cap" then
			color, mat = theme.cap, p.Material
		else
			color, mat = theme.fence, p.Material
		end
		if color then
			if role == "expfloor" or role == "exppen" or p:GetAttribute("OpenColor") then
				-- expansion parts are greyed out until unlocked: BaseManager reads OpenColor
				p:SetAttribute("OpenColor", color)
				local isOpen = expOpen
				if role == "wingfloor" then
					isOpen = p:GetAttribute("WingOpen") == true
				end
				if isOpen then
					p.Color = color
				end
			else
				p.Color = color
			end
			p.Material = mat
		end
		for _, light in p:GetChildren() do
			if light:IsA("Light") and role == "lamp" then
				light.Color = color
			end
		end
	end
end

----------------------------------------------------------------------------------------------
-- models in the world
----------------------------------------------------------------------------------------------
local function decorFolder(base: Model): Folder
	local f = base:FindFirstChild("Decor")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Decor"
		f.Parent = base
	end
	return f
end

local function strongest(player: Player)
	local best
	for _, record in BaseManager.getTeam(player) do
		if not best or record.level > best.level or (record.level == best.level and record.shiny and not best.shiny) then
			best = record
		end
	end
	return best
end

-- Put a still copy of your strongest creature on top of a pedestal
local function dressPedestal(player: Player, model: Model)
	local best = strongest(player)
	local key = best and ("%s|%d|%s|%s"):format(best.name, best.level, tostring(best.shiny), tostring(best.sizeClass)) or "none"
	if model:GetAttribute("Showing") == key then
		return
	end
	model:SetAttribute("Showing", key)
	local old = model:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
	local label = model.PrimaryPart:FindFirstChild("PedestalLabel")
	if not best then
		if label then
			label:Destroy()
		end
		return
	end
	local ok, creature = pcall(CreatureBuilder.build, best.name, best.level, { shiny = best.shiny, sizeClass = best.sizeClass })
	if not ok or not creature then
		return
	end
	creature.Name = "Display"
	for _, d in creature:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("BillboardGui") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	local size = creature:GetExtentsSize()
	local scale = math.min(1, 3.2 / math.max(size.X, size.Y, size.Z, 0.1))
	pcall(creature.ScaleTo, creature, scale)
	local top = model.PrimaryPart.Position.Y + 2.4
	local offset = (creature:GetAttribute("GroundOffset") or 0) * scale
	creature:PivotTo(CFrame.new(model.PrimaryPart.Position.X, top + offset, model.PrimaryPart.Position.Z) * (model.PrimaryPart.CFrame - model.PrimaryPart.Position))
	creature.Parent = model
	if not label then
		label = Instance.new("BillboardGui")
		label.Name = "PedestalLabel"
		label.Size = UDim2.fromOffset(170, 34)
		label.StudsOffset = Vector3.new(0, 7.5, 0)
		label.MaxDistance = 60
		label.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 225, 120)
		t.TextStrokeTransparency = 0.3
		t.Parent = label
		label.Parent = model.PrimaryPart
	end
	label.Text.Text = (best.shiny and "★ " or "") .. ("%s  Lv %d"):format(best.name, best.level)
end

-- Trophy Wall: badges, catches, shinies, likes
local function dressTrophy(player: Player, model: Model)
	local screen = model:FindFirstChild("Screen")
	if not screen then
		return
	end
	local gui = screen:FindFirstChild("Trophies")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "Trophies"
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		local layout = Instance.new("UIListLayout")
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = gui
		for i, name in { "Title", "Badges", "Caught", "Shinies", "Likes" } do
			local t = Instance.new("TextLabel")
			t.Name = name
			t.LayoutOrder = i
			t.BackgroundTransparency = 1
			t.Size = UDim2.new(0.92, 0, 0, i == 1 and 44 or 30)
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextColor3 = i == 1 and Color3.fromRGB(255, 210, 80) or Color3.new(1, 1, 1)
			t.Parent = gui
		end
		gui.Parent = screen
	end
	local badges = player:GetAttribute("Badges") or 0
	local total = 0
	for _ in GameData.GymLeaders do
		total += 1
	end
	gui.Title.Text = player.DisplayName .. "'s Trophies"
	gui.Badges.Text = ("Badges: %d/%d"):format(badges, math.max(total, badges))
	gui.Caught.Text = ("Creatures caught: %d"):format(player:GetAttribute("Stat_caught") or 0)
	gui.Shinies.Text = ("Shinies: %d"):format(player:GetAttribute("Stat_shinies") or 0)
	gui.Likes.Text = ("Base likes: %d"):format(player:GetAttribute("Stat_likes") or 0)
end

local function dress(player: Player, model: Model)
	local item = Items[model:GetAttribute("DecorId")]
	if item and item.pedestal then
		dressPedestal(player, model)
	elseif item and item.trophy then
		dressTrophy(player, model)
	end
end

local function spawnPlaced(player: Player, p)
	local base = BaseManager.getBase(player)
	if not base then
		return
	end
	local model = DecorData.build(p.id)
	if not model then
		return
	end
	model:SetAttribute("Uid", p.uid)
	model:SetAttribute("R", p.r)
	model:SetAttribute("OwnerId", player.UserId)
	model:PivotTo(DecorData.toWorld(floorOf(base), p.x, p.z, p.r))
	model.Parent = decorFolder(base)
	models[player] = models[player] or {}
	models[player][p.uid] = model
	dress(player, model)
end

local function despawnPlaced(player: Player, uid: number)
	local m = models[player] and models[player][uid]
	if m then
		m:Destroy()
		models[player][uid] = nil
	end
end

local function clearModels(player: Player)
	for _, m in models[player] or {} do
		m:Destroy()
	end
	models[player] = {}
	local base = BaseManager.getBase(player)
	if base and base:FindFirstChild("Decor") then
		base.Decor:ClearAllChildren()
	end
end

----------------------------------------------------------------------------------------------
-- placement rules
----------------------------------------------------------------------------------------------
local EXCLUDE = {
	Floor = true, Path = true, PathEdge = true, Pen = true, SpawnPoint = true, HouseFloor = true,
	ExpFloor = true, Pen2 = true, Pond = true, ExpansionBarrier = true, LockLabel = true, Gate = true,
	SignAnchor = true, Leaves = true, ExpLeaves = true, Roof = true, Chimney = true,
}

local function collectStatic(base: Model)
	local list = {}
	for _, d in base:GetDescendants() do
		if d:IsA("BasePart") and not EXCLUDE[d.Name] and d.Name ~= "WingFloor" and d.Name ~= "WingLock" and not d:GetAttribute("WingSide") then
			local skip = false
			local a = d.Parent
			while a and a ~= base do
				if a.Name == "Creatures" or a.Name == "Decor" then
					skip = true
					break
				end
				a = a.Parent
			end
			if not skip then
				table.insert(list, d)
			end
		end
	end
	staticParts[base] = list
end

local function overlaps(ax, az, afx, afz, bx, bz, bfx, bfz): boolean
	return math.abs(ax - bx) * 2 < afx + bfx - 0.01 and math.abs(az - bz) * 2 < afz + bfz - 0.01
end

-- Can this item go here? ignoreUid: the item being moved
local function canPlace(player: Player, d, id: string, x: number, z: number, r: number, ignoreUid: number?): (boolean, string?)
	local base = BaseManager.getBase(player)
	local item = Items[id]
	if not base or not item then
		return false, "You can't build here."
	end
	local fx, fz = DecorData.footprint(id, r)
	if not DecorData.inBounds(x, z, fx, fz, BaseManager.isExpansionUnlocked(player), d.level) then
		return false, "That's outside your base."
	end
	local floor = floorOf(base)
	-- keep the spawn point clear
	local spawn = base:FindFirstChild("SpawnPoint")
	if spawn then
		local sx, sz = DecorData.toLocal(floor, spawn.Position)
		local c = DecorData.SpawnClear * 2
		if overlaps(x, z, fx, fz, sx, sz, c, c) then
			return false, "Keep your spawn point clear."
		end
	end
	-- other decorations (flat things can sit under solid things)
	for _, p in d.placed do
		if p.uid ~= ignoreUid then
			local other = Items[p.id]
			if other and (other.flat == true) == (item.flat == true) then
				local ofx, ofz = DecorData.footprint(p.id, p.r)
				if overlaps(x, z, fx, fz, p.x, p.z, ofx, ofz) then
					return false, ("That overlaps your %s."):format(other.name)
				end
			end
		end
	end
	-- the base's own buildings, trees, fences and signs
	if not staticParts[base] then
		collectStatic(base)
	end
	local cf = DecorData.toWorld(floor, x, z, 0)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = staticParts[base]
	local hits = workspace:GetPartBoundsInBox(cf + Vector3.new(0, 3.3, 0), Vector3.new(fx - 0.2, 5.2, fz - 0.2), params)
	for _, hit in hits do
		if hit.CanCollide or hit.Transparency < 1 then
			return false, "Something is already there."
		end
	end
	return true
end

----------------------------------------------------------------------------------------------
-- actions
----------------------------------------------------------------------------------------------
local function grant(d, id: string, n: number?)
	d.owned[id] = math.min(MAX_OWNED, (d.owned[id] or 0) + (n or 1))
end

local function rollBox(boxId: string): string
	local box = DecorData.Boxes[boxId]
	local total = 0
	for _, w in box.odds do
		total += w
	end
	local roll = math.random() * total
	local rarity
	for _, name in { "Legendary", "Epic", "Rare", "Common" } do
		local w = box.odds[name]
		if w then
			if roll < w then
				rarity = name
				break
			end
			roll -= w
		end
	end
	local options = {}
	for _, id in box.pool do
		if Items[id].rarity == rarity then
			table.insert(options, id)
		end
	end
	if #options == 0 then
		options = box.pool
	end
	return options[math.random(1, #options)]
end

local actions = {}

function actions.state(player, d)
	return true, nil
end

function actions.buy(player, d, id)
	local item = Items[id]
	if not item or item.sold ~= "shop" then
		return false, "That isn't for sale."
	end
	if (d.owned[id] or 0) >= MAX_OWNED then
		return false, "You have as many as you can hold."
	end
	if not PlayerData.spend(player, item.price) then
		return false, ("You need %d coins (you have %d)."):format(item.price, PlayerData.coins(player))
	end
	grant(d, id)
	return true, ("Bought: %s! Open BUILD to place it."):format(item.name)
end

function actions.buyDaily(player, d, id)
	local item = Items[id]
	if not item or not table.find(DecorData.dailyShop(DecorData.today()), id) then
		return false, "That's not in today's shop."
	end
	if d.dailyBought[id] then
		return false, "You already bought that today. Check back tomorrow!"
	end
	if not PlayerData.spend(player, item.price) then
		return false, ("You need %d coins (you have %d)."):format(item.price, PlayerData.coins(player))
	end
	d.dailyBought[id] = true
	grant(d, id)
	return true, ("Bought: %s!"):format(item.name)
end

function actions.openBox(player, d, boxId)
	local box = DecorData.Boxes[boxId]
	if not box then
		return false, "Unknown crate."
	end
	if (d.boxes[boxId] or 0) > 0 then
		d.boxes[boxId] -= 1
	elseif not PlayerData.spend(player, box.price) then
		return false, ("You need %d coins (you have %d)."):format(box.price, PlayerData.coins(player))
	end
	local id = rollBox(boxId)
	local item = Items[id]
	local result = { id = id, rarity = item.rarity, dup = false, shards = 0 }
	if (d.owned[id] or 0) > 0 then
		result.dup = true
		result.shards = DecorData.Rarities[item.rarity].shards
		d.shards += result.shards
	else
		grant(d, id)
	end
	if item.rarity == "Legendary" then
		Notify:FireAllClients(("%s pulled a Legendary %s!"):format(player.DisplayName, item.name), "announce")
	end
	return true, result
end

function actions.shardBuy(player, d, id)
	local item = Items[id]
	if not item or item.sold ~= "box" then
		return false, "Shards only buy crate items."
	end
	local cost = DecorData.Rarities[item.rarity].shardCost
	if d.shards < cost then
		return false, ("You need %d shards (you have %d)."):format(cost, d.shards)
	end
	d.shards -= cost
	grant(d, id)
	return true, ("Traded shards for: %s!"):format(item.name)
end

local function cleanArgs(x, z, r)
	local finite = PlayerData.finite
	if not finite(x) or not finite(z) or not finite(r) then
		return nil -- also rejects NaN / infinity, which would corrupt the save
	end
	r = math.floor(r / 90 + 0.5) % 4 * 90
	return DecorData.snap(x), DecorData.snap(z), r
end

function actions.place(player, d, id, x, z, r)
	if typeof(id) ~= "string" or not Items[id] then
		return false, "Unknown item."
	end
	x, z, r = cleanArgs(x, z, r)
	if not x then
		return false, "Something went wrong."
	end
	if placedCount(d, id) >= (d.owned[id] or 0) then
		return false, "You don't have another one of those. Buy more in the shop."
	end
	local cap = levelDef(d).cap
	if #d.placed >= cap then
		return false, ("Your base holds %d decorations. Upgrade your base for more room."):format(cap)
	end
	local ok, message = canPlace(player, d, id, x, z, r)
	if not ok then
		return false, message
	end
	local p = { uid = d.nextUid, id = id, x = x, z = z, r = r }
	d.nextUid += 1
	table.insert(d.placed, p)
	spawnPlaced(player, p)
	return true, nil
end

function actions.move(player, d, uid, x, z, r)
	x, z, r = cleanArgs(x, z, r)
	if not x then
		return false, "Something went wrong."
	end
	for _, p in d.placed do
		if p.uid == uid then
			local ok, message = canPlace(player, d, p.id, x, z, r, uid)
			if not ok then
				return false, message
			end
			p.x, p.z, p.r = x, z, r
			despawnPlaced(player, uid)
			spawnPlaced(player, p)
			return true, nil
		end
	end
	return false, "That decoration is gone."
end

function actions.remove(player, d, uid)
	for i, p in d.placed do
		if p.uid == uid then
			table.remove(d.placed, i)
			despawnPlaced(player, uid)
			return true, ("Put away your %s."):format(Items[p.id].name)
		end
	end
	return false, "That decoration is gone."
end

function actions.theme(player, d, themeId)
	local theme = DecorData.Themes[themeId]
	if not theme then
		return false, "Unknown theme."
	end
	if not d.themes[themeId] then
		if theme.premium then
			return false, "That theme comes with the Premium Decor Pack."
		end
		if not PlayerData.spend(player, theme.price) then
			return false, ("You need %d coins (you have %d)."):format(theme.price, PlayerData.coins(player))
		end
		d.themes[themeId] = true
	end
	d.theme = themeId
	local base = BaseManager.getBase(player)
	if base then
		applyTheme(base, themeId)
	end
	return true, ("Your base is now %s!"):format(theme.name)
end

function actions.upgrade(player, d)
	local nextDef = DecorData.BaseLevels[d.level + 1]
	if not nextDef then
		return false, "Your base is already max level."
	end
	if not PlayerData.spend(player, nextDef.cost) then
		return false, ("You need %d coins (you have %d)."):format(nextDef.cost, PlayerData.coins(player))
	end
	d.level += 1
	local base = BaseManager.getBase(player)
	if base then
		BaseManager.setWings(base, d.level)
	end
	local extra = nextDef.wing and (" Your base got wider: a new side wing (%s) is open to build on."):format(nextDef.wing) or ""
	return true, ("Base upgraded to %s! Room for %d decorations, +%d%% coins.%s"):format(nextDef.name, nextDef.cap, nextDef.bonus * 100, extra)
end

function actions.canopy(player, d)
	local tiers = DecorData.CanopyTiers
	local nextTier = tiers[(d.canopy or 1) + 1]
	if not nextTier then
		return false, "Your XP Canopy is already maxed out (50% shared)!"
	end
	if not PlayerData.spend(player, nextTier.cost) then
		return false, ("You need %d coins to upgrade the XP Canopy (you have %d)."):format(nextTier.cost, PlayerData.coins(player))
	end
	d.canopy = (d.canopy or 1) + 1
	return true, ("XP Canopy upgraded! Your other creatures now get %d%% of battle XP."):format(nextTier.share * 100)
end

function actions.collect(player, d)
	local amount = math.floor(d.bank)
	if amount <= 0 then
		return false, "Your Coin Jar is empty. Coin generators and habitats fill it."
	end
	d.bank -= amount
	PlayerData.addCoins(player, amount)
	return true, ("Collected %d coins from your Coin Jar!"):format(amount)
end

local SAVE_ACTIONS = { buy = true, buyDaily = true, openBox = true, shardBuy = true, place = true, move = true, remove = true, theme = true, upgrade = true, collect = true, canopy = true }

----------------------------------------------------------------------------------------------
-- per-minute tick
----------------------------------------------------------------------------------------------
local function tick(player: Player)
	local d = state[player]
	if not d then
		return
	end
	d.lastSeen = os.time()
	-- coin jar
	local cap = bankCap(player, d)
	d.bank = math.min(cap, d.bank + incomeRate(player, d) * DecorData.TickSeconds / 60)
	local team = BaseManager.getTeam(player)
	local busy = BattleService.isInBattle(player)
	-- healing pads
	local pads = math.min(countWith(d, "heal"), DecorData.MaxHealPads)
	local changed = false
	if pads > 0 and not busy then
		for _, record in team do
			local maxHP = BattleData.stats(record.name, record.level, record.sizeClass, record.ivs).maxHP
			if record.hp < maxHP then
				record.hp = math.min(maxHP, record.hp + math.ceil(maxHP * Items.HealPad.heal * pads))
				changed = true
			end
		end
	end
	-- base training: everyone in the base slowly gains XP (dummies and matching habitats speed it up)
	if not busy and #team > 0 then
		train(player, d, DecorData.TickSeconds / 60)
		changed = true
	end
	if changed then
		BaseManager.refresh(player)
	end
	for _, m in models[player] or {} do
		dress(player, m)
	end
	sync(player)
end

----------------------------------------------------------------------------------------------
-- coin jar and like stand on every base
----------------------------------------------------------------------------------------------
local function billboard(parent: Instance, offset: number, color: Color3): TextLabel
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	bb.Size = UDim2.fromOffset(190, 40)
	bb.StudsOffset = Vector3.new(0, offset, 0)
	bb.MaxDistance = 50
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.3
	t.Parent = bb
	bb.Parent = parent
	return t
end

local jarLabels = {} -- [base] = TextLabel
local likeLabels = {} -- [base] = TextLabel

local function ownerOf(base: Model): Player?
	local id = base:GetAttribute("OwnerId")
	return id and id ~= 0 and Players:GetPlayerByUserId(id) or nil
end

local function refreshBaseLabels(base: Model)
	local owner = ownerOf(base)
	if jarLabels[base] then
		jarLabels[base].Text = owner and ("Coin Jar  %d/%d"):format(owner:GetAttribute("BaseBank") or 0, owner:GetAttribute("BaseBankCap") or 0) or "Coin Jar"
	end
	if likeLabels[base] then
		likeLabels[base].Text = owner and ("♥ %d likes"):format(owner:GetAttribute("Stat_likes") or 0) or "♥"
	end
	local stand = base:FindFirstChild("LikeStand")
	local prompt = stand and stand:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = owner ~= nil
		prompt.ObjectText = owner and (owner.DisplayName .. "'s Base") or "Empty Base"
	end
	-- XP Canopy sign + upgrade prompt
	local canopy = base:FindFirstChild("Canopy")
	if canopy then
		local tiers = DecorData.CanopyTiers
		local level = owner and (owner:GetAttribute("CanopyLevel") or 1) or 1
		local nextTier = tiers[level + 1]
		local label = canopy:FindFirstChild("Text", true)
		if label and label:IsA("TextLabel") then
			label.Text = ("XP Canopy Lv %d · %d%% shared"):format(level, tiers[level].share * 100)
		end
		local up = canopy:FindFirstChild("UpgradePrompt", true)
		if up then
			up.Enabled = owner ~= nil and nextTier ~= nil
			up.ObjectText = nextTier and ("Next: %d%% shared"):format(nextTier.share * 100) or "Maxed out"
			up.ActionText = nextTier and ("Upgrade (%d coins)"):format(nextTier.cost) or "Maxed"
		end
	end
end
DecorService.refreshBaseLabels = refreshBaseLabels

local function buildBaseProps(base: Model)
	local floor = floorOf(base)
	local s = DecorData.side(floor)
	local top = floor.Position.Y + floor.Size.Y / 2

	-- Coin Jar next to the spawn
	if not base:FindFirstChild("CoinJar") then
		local jar = Instance.new("Model")
		jar.Name = "CoinJar"
		local pos = Vector3.new(floor.Position.X + 21 * s, top, floor.Position.Z + 7)
		local function part(name, size, offset, color, mat, shape, transp)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.Size = size
			p.CFrame = CFrame.new(pos + offset) * (shape == "Cylinder" and CFrame.Angles(0, 0, math.rad(90)) or CFrame.identity)
			p.Color = color
			p.Material = mat
			if shape then
				p.Shape = Enum.PartType[shape]
			end
			p.Transparency = transp or 0
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = jar
			return p
		end
		local glass = part("Glass", Vector3.new(3.2, 2.4, 2.4), Vector3.new(0, 1.6, 0), Color3.fromRGB(200, 235, 255), Enum.Material.Glass, "Cylinder", 0.45)
		part("Coins", Vector3.new(1.6, 2.1, 2.1), Vector3.new(0, 0.9, 0), Color3.fromRGB(245, 195, 50), Enum.Material.Metal, "Cylinder")
		part("Lid", Vector3.new(0.5, 2.6, 2.6), Vector3.new(0, 3.4, 0), Color3.fromRGB(200, 60, 60), Enum.Material.SmoothPlastic, "Cylinder")
		jar.PrimaryPart = glass
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Collect coins"
		prompt.ObjectText = "Coin Jar"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = glass
		jarLabels[base] = billboard(glass, 3.2, Color3.fromRGB(255, 215, 90))
		jar.Parent = base
		prompt.Triggered:Connect(function(player)
			if base:GetAttribute("OwnerId") ~= player.UserId then
				Notify:FireClient(player, "That's not your Coin Jar.", "fail")
				return
			end
			local d = state[player]
			if not d then
				return
			end
			local ok, message = actions.collect(player, d)
			Notify:FireClient(player, message, ok and "success" or "info")
			if ok then
				sync(player)
				refreshBaseLabels(base)
				SaveService.requestSave(player)
			end
		end)
	end

	-- XP Canopy upgrade pad (the bench under the canopy)
	local canopy = base:FindFirstChild("Canopy")
	local bench = canopy and canopy:FindFirstChild("Bench")
	if bench and not bench:FindFirstChild("UpgradePrompt") then
		local up = Instance.new("ProximityPrompt")
		up.Name = "UpgradePrompt"
		up.HoldDuration = 0.4
		up.MaxActivationDistance = 10
		up.RequiresLineOfSight = false
		up.Parent = bench
		up.Triggered:Connect(function(player)
			if base:GetAttribute("OwnerId") ~= player.UserId then
				Notify:FireClient(player, "You can only upgrade the canopy in your own base.", "fail")
				return
			end
			local d = state[player]
			if not d then
				return
			end
			local ok, message = actions.canopy(player, d)
			Notify:FireClient(player, message, ok and "success" or "fail")
			if ok then
				sync(player)
				refreshBaseLabels(base)
				SaveService.requestSave(player)
			end
		end)
	end

	-- Like stand just inside the gate
	if not base:FindFirstChild("LikeStand") then
		local stand = Instance.new("Part")
		stand.Name = "LikeStand"
		stand.Anchored = true
		stand.Size = Vector3.new(1.4, 3.6, 1.4)
		stand.CFrame = CFrame.new(floor.Position.X + 28 * s, top + 1.8, floor.Position.Z - 7.5)
		stand.Color = Color3.fromRGB(255, 95, 130)
		stand.Material = Enum.Material.SmoothPlastic
		local heart = Instance.new("Part")
		heart.Name = "Heart"
		heart.Shape = Enum.PartType.Ball
		heart.Anchored = true
		heart.CanCollide = false
		heart.Size = Vector3.new(1.8, 1.8, 1.8)
		heart.CFrame = stand.CFrame + Vector3.new(0, 2.6, 0)
		heart.Color = Color3.fromRGB(255, 70, 110)
		heart.Material = Enum.Material.Neon
		heart.Parent = stand
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Like base"
		prompt.ObjectText = "Base"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = stand
		likeLabels[base] = billboard(heart, 2.2, Color3.fromRGB(255, 160, 190))
		stand.Parent = base
		prompt.Triggered:Connect(function(liker)
			local owner = ownerOf(base)
			local d = state[liker]
			if not owner or not d then
				return
			end
			if owner == liker then
				Notify:FireClient(liker, "You can't like your own base. Show it off to friends!", "info")
				return
			end
			local today = DecorData.today()
			if d.likedDay ~= today then
				d.likedDay = today
				d.liked = {}
			end
			if table.find(d.liked, owner.UserId) then
				Notify:FireClient(liker, ("You already liked %s's base today."):format(owner.DisplayName), "info")
				return
			end
			table.insert(d.liked, owner.UserId)
			PlayerData.addStat(owner, "likes")
			PlayerData.addCoins(owner, DecorData.LikeCoins)
			Notify:FireClient(liker, ("You liked %s's base!"):format(owner.DisplayName), "success")
			Notify:FireClient(owner, ("%s liked your base! +%d coins"):format(liker.DisplayName, DecorData.LikeCoins), "success")
			refreshBaseLabels(base)
			SaveService.requestSave(owner)
			SaveService.requestSave(liker)
		end)
	end
	refreshBaseLabels(base)
end

----------------------------------------------------------------------------------------------
-- premium pass and Robux coin bundles
----------------------------------------------------------------------------------------------
local function applyPremium(player: Player)
	local d = state[player]
	if not d or not player:GetAttribute("Pass_PremiumDecor") then
		return
	end
	local gave = false
	for _, id in DecorData.PremiumItems do
		if (d.owned[id] or 0) == 0 then
			grant(d, id)
			gave = true
		end
	end
	for id, theme in DecorData.Themes do
		if theme.premium and not d.themes[id] then
			d.themes[id] = true
			gave = true
		end
	end
	if gave then
		Notify:FireClient(player, "Premium Decor unlocked! Open BUILD to place your new items.", "success")
		sync(player)
		SaveService.requestSave(player)
	end
end

local productById = {}
for _, p in DecorData.CoinProducts do
	if p.id and p.id > 0 then
		productById[p.id] = { coins = p.coins, label = p.label }
	end
end
for _, b in DecorData.Bundles do
	if b.id and b.id > 0 then
		productById[b.id] = { bundle = b, label = b.label }
	end
end

-- Hand over what a product gives. Returns a function that takes it back (if the save fails).
local function giveProduct(player: Player, d, product)
	local undo = {}
	local give = product.bundle and product.bundle.give or { coins = product.coins }
	if give.coins then
		PlayerData.addCoinsRaw(player, give.coins)
		table.insert(undo, function()
			PlayerData.spend(player, give.coins)
		end)
	end
	for id, n in give.items or {} do
		PlayerData.addItem(player, id, n)
		table.insert(undo, function()
			for _ = 1, n do
				PlayerData.takeItem(player, id)
			end
		end)
	end
	for id, n in give.decor or {} do
		local before = d.owned[id]
		d.owned[id] = (d.owned[id] or 0) + n -- paid items ignore the usual cap
		table.insert(undo, function()
			d.owned[id] = before
		end)
	end
	if give.shards then
		d.shards += give.shards
		table.insert(undo, function()
			d.shards -= give.shards
		end)
	end
	local key = product.bundle and product.bundle.once and product.bundle.key
	if key then
		d.bought[key] = true
		table.insert(undo, function()
			d.bought[key] = nil
		end)
	end
	return function()
		for _, f in undo do
			f()
		end
	end
end

-- Other one-time-use products (Instant Heal, Summon Rare Spawn): [productId] = fn(player) -> ok
-- Roblox only allows one ProcessReceipt per game, so other systems register here.
local extraProducts = {}
function DecorService.registerProduct(productId: number, label: string, fn)
	if productId and productId > 0 then
		extraProducts[productId] = { label = label, fn = fn }
	end
end

local function processReceipt(info)
	local product = productById[info.ProductId]
	local extra = not product and extraProducts[info.ProductId]
	if extra then
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local d = player and state[player]
		if not player or not d or not SaveService.isLoaded(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if table.find(d.receipts, info.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		-- record the receipt before handing anything over, so a second call for the same PurchaseId
		-- (Roblox retries, or two servers) can never grant it twice
		table.insert(d.receipts, info.PurchaseId)
		local ran, ok = pcall(extra.fn, player)
		if not ran or not ok then
			if not ran then
				warn(("[Receipt] %s failed for %s: %s"):format(extra.label, player.Name, tostring(ok)))
			end
			local i = table.find(d.receipts, info.PurchaseId)
			if i then
				table.remove(d.receipts, i)
			end
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		while #d.receipts > MAX_RECEIPTS do
			table.remove(d.receipts, 1)
		end
		-- save now (not queued): item packs and boosts are kept, so the receipt must be on disk with them
		SaveService.save(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not product then
		-- not one of ours (another system may handle it later)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local d = player and state[player]
	if not player or not d or not SaveService.isLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(d.receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local undo = giveProduct(player, d, product)
	table.insert(d.receipts, info.PurchaseId)
	while #d.receipts > MAX_RECEIPTS do
		table.remove(d.receipts, 1)
	end
	local saved = SaveService.save(player)
	if not saved and not RunService:IsStudio() then
		-- couldn't record it: undo and let Roblox retry later
		undo()
		table.remove(d.receipts, table.find(d.receipts, info.PurchaseId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	sync(player)
	Notify:FireClient(player, product.coins and ("Thanks! +%d coins."):format(product.coins) or ("Thanks! %s added to your account."):format(product.label), "success")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

----------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------
function DecorService.initPlayer(player: Player)
	state[player] = defaults()
	models[player] = {}
end

local function loadSaved(player: Player, saved)
	local d = state[player]
	if not d or typeof(saved) ~= "table" then
		return
	end
	for k, v in defaults() do
		if typeof(saved[k]) == typeof(v) then
			d[k] = saved[k]
		end
	end
	-- the Garden Pond was merged into the Tide Pool
	if d.owned.Pond then
		d.owned.WaterPool = (d.owned.WaterPool or 0) + d.owned.Pond
		d.owned.Pond = nil
	end
	-- drop anything that no longer exists
	for id in d.owned do
		if not Items[id] then
			d.owned[id] = nil
		end
	end
	local keep = {}
	for _, p in d.placed do
		if typeof(p) == "table" and p.id == "Pond" then
			p.id = "WaterPool"
		end
		if typeof(p) == "table" and Items[p.id] and typeof(p.x) == "number" then
			table.insert(keep, p)
		end
	end
	d.placed = keep
	d.themes.Meadow = true
	if not DecorData.Themes[d.theme] then
		d.theme = "Meadow"
	end
end

local function serialize(player: Player)
	local d = state[player]
	if not d then
		return nil
	end
	d.lastSeen = os.time()
	return d
end

local function release(player: Player)
	local base = BaseManager.getBase(player)
	clearModels(player)
	if base then
		applyTheme(base, "Meadow")
	end
	state[player] = nil
	models[player] = nil
	if base then
		task.defer(refreshBaseLabels, base)
	end
end

-- After SaveService.load: build the saved layout, theme, offline coins
function DecorService.onLoaded(player: Player)
	local d = state[player]
	local base = BaseManager.getBase(player)
	if not d or not base then
		return
	end
	clearModels(player)
	BaseManager.setWings(base, d.level)
	-- saves from before the bases were enlarged: keep each decoration in the same spot on the ground
	if (d.layout or 1) < DecorData.LayoutVersion then
		for _, p in d.placed do
			p.x = DecorData.snap(p.x - DecorData.LayoutShift)
		end
		d.layout = DecorData.LayoutVersion
	end
	-- a saved spot can fail if the base differs (e.g. the expansion isn't open): put it back in storage
	local keep = {}
	for _, p in d.placed do
		local ok = canPlace(player, { placed = keep, level = d.level }, p.id, p.x, p.z, p.r)
		if ok and #keep < levelDef(d).cap then
			table.insert(keep, p)
			spawnPlaced(player, p)
		end
	end
	d.placed = keep
	applyTheme(base, d.theme)
	-- coins earned while away (half rate, up to 8 hours, never past the jar's size)
	local away = math.clamp(os.time() - (d.lastSeen or os.time()), 0, DecorData.OfflineHours * 3600)
	local earned = math.floor(incomeRate(player, d) * away / 60 * DecorData.OfflineRate)
	if earned > 0 then
		local cap = bankCap(player, d)
		local before = d.bank
		d.bank = math.min(cap, d.bank + earned)
		local gained = math.floor(d.bank - before)
		if gained > 0 then
			task.delay(6, function()
				if player.Parent then
					Notify:FireClient(player, ("Your Coin Jar earned %d coins while you were away!"):format(gained), "success")
				end
			end)
		end
	end
	-- base training while away (half speed, same 8 hour limit)
	local trainAway = math.clamp(os.time() - (d.lastSeen or os.time()), 0, Training.offlineHours * 3600)
	local awayMinutes = math.floor(trainAway / 60 * Training.offlineRate)
	if awayMinutes >= 5 then
		local grew = train(player, d, awayMinutes)
		BaseManager.refresh(player)
		if grew > 0 then
			task.delay(8, function()
				if player.Parent then
					Notify:FireClient(player, ("Your creatures kept training while you were away! %d of them levelled up."):format(grew), "success")
				end
			end)
		end
	end
	d.lastSeen = os.time()
	applyPremium(player)
	sync(player)
	refreshBaseLabels(base)
	player:GetAttributeChangedSignal("Pass_PremiumDecor"):Connect(function()
		applyPremium(player)
	end)
	for _, attr in { "BaseBank", "BaseBankCap", "Stat_likes", "CanopyLevel" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			local b = BaseManager.getBase(player)
			if b then
				refreshBaseLabels(b)
			end
		end)
	end
	-- the team changing changes habitat income and the pedestal
	player:GetAttributeChangedSignal("TeamCount"):Connect(function()
		if state[player] then
			sync(player)
		end
	end)
end

-- Give a crate (gym wins, events)
function DecorService.giveBox(player: Player, boxId: string, count: number?)
	local d = state[player]
	if not d or not DecorData.Boxes[boxId] then
		return
	end
	d.boxes[boxId] = (d.boxes[boxId] or 0) + (count or 1)
	sync(player)
	SaveService.requestSave(player)
end

function DecorService.init()
	SaveService.register("decor", { serialize = serialize, load = loadSaved, release = release })

	for _, base in workspace.Map.Bases:GetChildren() do
		rememberOriginals(base)
		decorFolder(base)
		buildBaseProps(base)
		collectStatic(base)
		base:GetAttributeChangedSignal("OwnerId"):Connect(function()
			refreshBaseLabels(base)
		end)
		-- the expansion opening re-colours its floor from OpenColor, which the theme already set
	end

	local last = {}
	DecorRemote.OnServerInvoke = function(player, action, a, b, c, e)
		local d = state[player]
		if not d or typeof(action) ~= "string" or not actions[action] then
			return false, "Something went wrong."
		end
		local now = os.clock()
		if action ~= "state" and last[player] and now - last[player] < 0.12 then
			return false, "Slow down a little!"
		end
		last[player] = now
		if action ~= "state" and BattleService.isInBattle(player) then
			return false, "Finish your battle first."
		end
		local ok, result = actions[action](player, d, a, b, c, e)
		if ok and SAVE_ACTIONS[action] then
			SaveService.requestSave(player)
		end
		sync(player)
		return ok, result, publicState(player, d)
	end
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)

	-- crates from battles
	BattleService.onEnded(function(player, b, result)
		if result ~= "won" or not b.isTrainer or not b.trainer then
			return
		end
		local d = state[player]
		if not d then
			return
		end
		if b.trainer.kind == "gym" and b.trainer.gym then
			if not table.find(d.gymCrates, b.trainer.gym) then
				table.insert(d.gymCrates, b.trainer.gym)
				DecorService.giveBox(player, "RareCrate")
				task.delay(6, function()
					Notify:FireClient(player, "You earned a Mystic Crate! Open it from the BUILD menu.", "success")
				end)
			end
		elseif math.random() < 0.25 then
			DecorService.giveBox(player, "CommonCrate")
			task.delay(4, function()
				Notify:FireClient(player, "Bonus: a Garden Crate! Open it from the BUILD menu.", "success")
			end)
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt

	task.spawn(function()
		while true do
			task.wait(DecorData.TickSeconds)
			for _, player in Players:GetPlayers() do
				task.spawn(tick, player)
			end
		end
	end)
end

return DecorService
