--[[
	Main: starts the game. Assigns bases, spawns players at their base,
	sets up the Healing Center, and rotates the 10-minute Wild Shift Hot Zone.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage.Shared.GameData)
local Modules = script.Parent:WaitForChild("Modules")
require(Modules.NpcGuard).run() -- snap back any NPC that drifted from its HomePos, before anything reads them
local BaseManager = require(Modules.BaseManager)
local BattleService = require(Modules.BattleService)
local WildSpawner = require(Modules.WildSpawner)
local TutorialService = require(Modules.TutorialService)
local PlayerData = require(Modules.PlayerData)
local DungeonService = require(Modules.DungeonService)
local GymService = require(Modules.GymService)
local SaveService = require(Modules.SaveService)
local ProgressService = require(Modules.ProgressService)
local RareEventService = require(Modules.RareEventService)
local PassService = require(Modules.PassService)
local SocialService = require(Modules.SocialService)
local ColiseumService = require(Modules.ColiseumService)
local LeaderboardService = require(Modules.LeaderboardService)
local RouteTrainerService = require(Modules.RouteTrainerService)
local AdminService = require(Modules.AdminService)
local DecorService = require(Modules.DecorService)
local StoryService = require(Modules.StoryService)
local LeagueService = require(Modules.LeagueService)
local BattleData = require(ReplicatedStorage.Shared.BattleData)
local TweenService = game:GetService("TweenService")

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

-- Name, trainer level and an XP bar floating above every player's head
local function trainerTag(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "TrainerTag"
	bb.Size = UDim2.fromOffset(180, 46)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Adornee = head
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.6)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Parent = bb
	local barBack = Instance.new("Frame")
	barBack.AnchorPoint = Vector2.new(0.5, 0)
	barBack.Position = UDim2.fromScale(0.5, 0.68)
	barBack.Size = UDim2.fromScale(0.8, 0.24)
	barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	barBack.Parent = bb
	local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(1, 0) c1.Parent = barBack
	local stroke = Instance.new("UIStroke") stroke.Thickness = 1.5 stroke.Color = Color3.fromRGB(10, 10, 15) stroke.Parent = barBack
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 170, 255)
	fill.Parent = barBack
	local c2 = Instance.new("UICorner") c2.CornerRadius = UDim.new(1, 0) c2.Parent = fill
	bb.Parent = head

	local function update()
		local level = player:GetAttribute("TrainerLevel") or 1
		local xp = player:GetAttribute("TrainerXP") or 0
		local nextXP = player:GetAttribute("TrainerXPNext") or 100
		local champion = (player:GetAttribute("Stat_leagueWins") or 0) > 0
		local gladiator = player:GetAttribute("Pass_Gladiator") == true -- Coliseum cosmetic pass
		nameLabel.Text = ("%s%s%s  ·  Lv %d"):format(gladiator and "⚔ " or "", champion and "★ " or "", player.DisplayName .. ((player:GetAttribute("ArenaTier") and " · " .. player:GetAttribute("ArenaTier")) or ""), level)
		nameLabel.TextColor3 = gladiator and Color3.fromRGB(255, 120, 90) or (champion and Color3.fromRGB(255, 215, 90) or Color3.new(1, 1, 1))
		TweenService:Create(fill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(xp / nextXP, 0, 1), 1) }):Play()
	end
	local conns = {
		player:GetAttributeChangedSignal("ArenaTier"):Connect(update),
		player:GetAttributeChangedSignal("TrainerXP"):Connect(update),
		player:GetAttributeChangedSignal("TrainerLevel"):Connect(update),
		player:GetAttributeChangedSignal("Stat_leagueWins"):Connect(update),
		player:GetAttributeChangedSignal("Pass_Gladiator"):Connect(update),
	}
	character.Destroying:Connect(function()
		for _, c in conns do
			c:Disconnect()
		end
	end)
	update()
end

local function onCharacter(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart")
	player:SetAttribute("InDungeon", false)
	task.spawn(trainerTag, player, character)
	task.spawn(PassService.onCharacter, player, character)
	task.wait() -- let the default spawn finish first
	local cf = BaseManager.spawnCFrame(player)
	if cf and character.Parent then
		character:PivotTo(cf)
	end
end

local function onPlayerAdded(player: Player)
	if not BaseManager.assign(player) then
		warn("No free base for", player.Name)
	end
	PlayerData.init(player)
	DungeonService.initPlayer(player)
	DecorService.initPlayer(player)
	-- saved progress, game passes, leaderboard stats, daily streak + quests
	SaveService.load(player)
	if not player.Parent then
		return
	end
	PassService.check(player)
	PassService.onLoaded(player) -- paid items owed from an earlier session
	DecorService.onLoaded(player)
	StoryService.onLoaded(player)
	LeaderboardService.onJoin(player)
	ProgressService.onJoin(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	-- start the tutorial (the client plays the intro cinematic first)
	task.delay(2, function()
		if player.Parent then
			TutorialService.start(player)
		end
	end)
end

DecorService.init() -- registers its save section, so before players load
StoryService.init()
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
-- leaving: SaveService saves, then frees the base (SaveService.init)
SaveService.init()
ProgressService.init()
RareEventService.init()
require(Modules.WeeklyEventService).init() -- Saturday "Rare Storm" (GameData.WeeklyEvent)
PassService.init()
SocialService.init()
LeaderboardService.init()

-- NPCs ---------------------------------------------------------------------

-- Speech bubble above an NPC's head
local function npcSay(npc: Model, text: string, seconds: number?)
	local head = npc:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("Speech")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Speech"
	bb.Size = UDim2.fromOffset(280, 72)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.MaxDistance = 45
	bb.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(40, 40, 55)
	label.Text = text
	label.Parent = frame
	bb.Parent = head
	task.delay(seconds or 4, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
end

-- Raise the right arm in a wave, then put it back
local function npcWave(npc: Model)
	local arm = npc:FindFirstChild("Right Arm")
	if not arm then
		return
	end
	local parts = { arm }
	for _, p in npc:GetChildren() do
		if p.Name == "Hand" and (p.Position - arm.Position).Magnitude < 1.5 then
			table.insert(parts, p)
		end
	end
	local shoulder = arm.CFrame * CFrame.new(0, 1, 0)
	local originals = {}
	for _, p in parts do
		originals[p] = p.CFrame
	end
	for _, angle in { 150, 125, 150, 125, 150 } do
		local turn = shoulder * CFrame.Angles(0, 0, math.rad(angle)) * shoulder:Inverse()
		for _, p in parts do
			p.CFrame = turn * originals[p]
		end
		task.wait(0.18)
	end
	for _, p in parts do
		p.CFrame = originals[p]
	end
end

local function addPrompt(npc: Model, action: string, objectText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = npc.PrimaryPart
	return prompt
end

-- Healing Center: talk to Nurse Ivy, she loads your team into the healing machine
do
	local center = workspace.Map.Hub.HealingCenter
	local nurse = center.Nurse
	local machine = center.HealMachine
	local slots = {}
	for i = 1, 6 do
		slots[i] = machine["Slot" .. i]
	end
	local screen = machine.Screen
	local EMPTY, BALL, GLOW = Color3.fromRGB(90, 90, 100), Color3.fromRGB(225, 45, 45), Color3.fromRGB(255, 120, 120)
	local busy = {}
	local machineBusy = false

	addPrompt(nurse, "Heal team", "Nurse Ivy").Triggered:Connect(function(player)
		if busy[player] or BattleService.isInBattle(player) then
			return
		end
		local team = BaseManager.getTeam(player)
		if #team == 0 then
			npcSay(nurse, "Hi there! Come back once you've caught a creature.", 3)
			return
		end
		busy[player] = true
		npcSay(nurse, ("Welcome, %s! Let me take your creatures for a moment."):format(player.DisplayName), 3)
		task.wait(1.2)
		while machineBusy do
			task.wait(0.2)
		end
		machineBusy = true
		-- load a ball per creature, then pulse
		for i = 1, math.min(#team, 6) do
			slots[i].Color = BALL
			task.wait(0.25)
		end
		local screenColor = screen.Color
		for _ = 1, 3 do
			for i = 1, math.min(#team, 6) do
				slots[i].Color = GLOW
				slots[i].Material = Enum.Material.Neon
			end
			screen.Color = Color3.fromRGB(90, 220, 140)
			task.wait(0.3)
			for i = 1, math.min(#team, 6) do
				slots[i].Color = BALL
				slots[i].Material = Enum.Material.SmoothPlastic
			end
			screen.Color = screenColor
			task.wait(0.25)
		end
		BaseManager.healAll(player)
		TutorialService.onHeal(player)
		StoryService.onHeal(player)
		ProgressService.progress(player, "heal")
		for i = 1, 6 do
			slots[i].Color = EMPTY
		end
		machineBusy = false
		npcSay(nurse, "All done! Your creatures are fully healed. Come back anytime!", 3.5)
		Notify:FireClient(player, "Your team is fully healed!", "success")
		npcWave(nurse)
		busy[player] = nil
	end)
end

-- Shop: Clerk Milo opens the shop menu (game passes; better balls come later)
do
	local clerk = workspace.Map.Hub.Shop.Clerk
	local OpenShop = ReplicatedStorage.Remotes:WaitForChild("OpenShop")
	local cooldown = {}
	addPrompt(clerk, "Shop", "Clerk Milo").Triggered:Connect(function(player)
		if cooldown[player] then
			return
		end
		if TutorialService.onShop(player) then
			npcWave(clerk)
			return
		end
		cooldown[player] = true
		OpenShop:FireClient(player)
		npcSay(clerk, "Welcome in! Take a look around.", 3)
		npcWave(clerk)
		task.delay(3, function()
			cooldown[player] = nil
		end)
	end)
end

-- Summit Town (Region 2): its own Nurse Ivy and Clerk Milo --------------------------
local summitHealCFrame -- where you stand in front of Nurse Ivy (LastHealStop = "SummitTown")
do
	local town = workspace.Map:FindFirstChild("SummitTown")
	local nurse2 = town and town:FindFirstChild("HealingCenter") and town.HealingCenter:FindFirstChild("Nurse")
	local clerk2 = town and town:FindFirstChild("Shop") and town.Shop:FindFirstChild("Clerk")
	local busy2 = {}
	if nurse2 and nurse2.PrimaryPart then
		local root = nurse2.PrimaryPart
		local front = root.Position + root.CFrame.LookVector * 6
		summitHealCFrame = CFrame.lookAt(front, Vector3.new(root.Position.X, front.Y, root.Position.Z))
		addPrompt(nurse2, "Heal team", "Nurse Ivy").Triggered:Connect(function(player)
			if busy2[player] or BattleService.isInBattle(player) then
				return
			end
			busy2[player] = true
			local healed = BaseManager.healAll(player)
			ProgressService.progress(player, "heal")
			-- respawn point: wiping out in Region 2 now brings you back here, not to Region 1
			player:SetAttribute("LastHealStop", "SummitTown")
			Notify:FireClient(player, "HEAL now brings you back to Summit Town.", "info")
			npcSay(nurse2, healed > 0 and "All better! Your team is fully healed. Good luck out there!" or "Your team is already in perfect shape!", 3)
			task.delay(2, function()
				busy2[player] = nil
			end)
		end)
	end
	if clerk2 and clerk2.PrimaryPart then
		local OpenShop2 = ReplicatedStorage.Remotes:WaitForChild("OpenShop")
		addPrompt(clerk2, "Shop", "Clerk Milo").Triggered:Connect(function(player)
			OpenShop2:FireClient(player)
			npcSay(clerk2, "Welcome to the Summit branch! Same great prices.", 3)
		end)
	end
end

-- Heal Stops: a free heal kiosk at the start of every region along the road. The last one you used
-- is where the HEAL button takes you, and where you wake up if your whole team faints.
local healStopCFrame -- set below; used by the HEAL button and the wipe-out warp
do
	local folder = workspace.Map:FindFirstChild("HealStops")
	local busy = {}
	local function standAt(stop: Model): CFrame
		local m = stop.PrimaryPart
		local roadX = stop:GetAttribute("RoadX") or 0 -- the centre of the arm this stop sits on
		local toRoad = Vector3.new(-math.sign(m.Position.X - roadX), 0, 0)
		local stand = Vector3.new(m.Position.X + toRoad.X * 6, 4.2, m.Position.Z)
		return CFrame.lookAt(stand, Vector3.new(m.Position.X, 4.2, m.Position.Z))
	end
	healStopCFrame = function(player: Player): CFrame?
		local name = player:GetAttribute("LastHealStop")
		if name == "SummitTown" then
			return summitHealCFrame
		end
		local stop = name and folder and folder:FindFirstChild(name)
		return stop and stop.PrimaryPart and standAt(stop) or nil
	end
	for _, stop in folder and folder:GetChildren() or {} do
		if stop:IsA("Model") and stop.PrimaryPart then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Heal team"
			prompt.ObjectText = stop.Name .. " Heal Stop"
			prompt.HoldDuration = 0.4
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = stop.PrimaryPart
			prompt.Triggered:Connect(function(player)
				if busy[player] or BattleService.isInBattle(player) then
					return
				end
				busy[player] = true
				local healed = BaseManager.healAll(player)
				ProgressService.progress(player, "heal")
				player:SetAttribute("LastHealStop", stop.Name)
				Notify:FireClient(player, (healed > 0 and "Your team is fully healed! " or "Your team is already healthy. ") .. "HEAL now brings you back here.", "success")
				task.delay(2, function()
					busy[player] = nil
				end)
			end)
		end
	end
end

-- Dungeon tower and gym ----------------------------------------------------------
DungeonService.init()
GymService.init()
LeagueService.init()
TutorialService.init()
RouteTrainerService.init()
AdminService.init()
ColiseumService.init() -- Battle Coliseum + Trade Plaza

-- Base expansions: the owner unlocks the area behind their base with coins ----------
do
	local cost = GameData.Economy.expansionCost
	for _, base in workspace.Map.Bases:GetChildren() do
		local exp = base:FindFirstChild("Expansion")
		local board = exp and exp:FindFirstChild("UnlockBoard")
		if board then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = ("Unlock (%d coins)"):format(cost)
			prompt.ObjectText = "Base Expansion"
			prompt.HoldDuration = 0.6
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = board
			prompt.Triggered:Connect(function(player)
				if base:GetAttribute("OwnerId") ~= player.UserId then
					Notify:FireClient(player, "Only this base's owner can unlock its expansion.", "fail")
					return
				end
				if BaseManager.isExpansionUnlocked(player) then
					return
				end
				if not PlayerData.spend(player, cost) then
					Notify:FireClient(player, ("You need %d coins (you have %d)."):format(cost, PlayerData.coins(player)), "fail")
					return
				end
				BaseManager.unlockExpansion(player)
				SaveService.requestSave(player)
				Notify:FireClient(player, "Expansion unlocked! Your base now holds 12 creatures.", "success")
			end)
		end
	end
end

-- Bag: using items (Skill Discs teach a move) --------------------------------------
do
	local Remotes = ReplicatedStorage.Remotes
	Remotes.GetTeam.OnServerInvoke = function(player)
		local list = BaseManager.snapshot(player)
		for _, entry in list do
			local record = BaseManager.findById(player, entry.id)
			entry.moves = record and BattleService.movesFor(record) or {}
		end
		return list
	end
	Remotes.UseItem.OnServerInvoke = function(player, itemId, creatureId)
		if typeof(itemId) ~= "string" or typeof(creatureId) ~= "number" then
			return false, "Something went wrong."
		end
		if BattleService.isInBattle(player) or player:GetAttribute("Trading") then
			return false, "Finish your battle or trade first."
		end
		local record = BaseManager.findById(player, creatureId)
		-- take back a held item
		if itemId == "__takeHeld" then
			if not record or not record.held then
				return false, "It isn't holding anything."
			end
			local held = record.held
			record.held = nil
			PlayerData.addItem(player, held, 1)
			SaveService.requestSave(player)
			return true, ("You took the %s from %s."):format(GameData.Items[held].name, record.name)
		end
		local item = GameData.Items[itemId]
		local function owns()
			local inv = PlayerData.get(player).items
			return inv[itemId] and inv[itemId] > 0
		end
		-- held items: give it to a creature (a held item it already had goes back in the bag)
		if item and record and item.held then
			if record.held == itemId then
				return false, ("%s is already holding a %s."):format(record.name, item.name)
			end
			if not owns() or not PlayerData.takeItem(player, itemId) then
				return false, "You don't have that item."
			end
			local old = record.held
			record.held = itemId
			if old then
				PlayerData.addItem(player, old, 1)
			end
			SaveService.requestSave(player)
			return true, old and ("%s swapped its %s for the %s."):format(record.name, GameData.Items[old].name, item.name)
				or ("%s is now holding the %s."):format(record.name, item.name)
		end
		-- evolution crystals
		if item and record and item.evolve then
			local into = GameData.StoneEvolutions[record.name] and GameData.StoneEvolutions[record.name][itemId]
			if not into then
				return false, ("The %s has no effect on %s."):format(item.name, record.name)
			end
			if not owns() or not PlayerData.takeItem(player, itemId) then
				return false, "You don't have that item."
			end
			local oldName = record.name
			ProgressService.evolveNow(player, record, into)
			return true, ("%s is evolving into %s!"):format(oldName, into)
		end
		if item and item.boost then
			return false, "Battle draughts can only be used during a battle."
		end
		-- medicine (potions, revives, status cures)
		if item and record and (item.heal or item.revive or item.cure) then
			local inv = PlayerData.get(player).items
			if not inv[itemId] or inv[itemId] == 0 then
				return false, "You don't have that item."
			end
			local ok, message = BattleService.applyMedicine(record, item)
			if ok then
				PlayerData.takeItem(player, itemId)
				BaseManager.refresh(player)
				SaveService.requestSave(player)
			end
			return ok, message
		end
		if not item or not item.move or not record then
			return false, "You can't use that here."
		end
		local moves = record.moves or table.clone(BattleData.movesAt(record.name, record.level))
		if table.find(moves, item.move) then
			return false, ("%s already knows %s."):format(record.name, item.move)
		end
		if not PlayerData.takeItem(player, itemId) then
			return false, "You don't have that item."
		end
		local forgot
		if #moves >= 4 then
			forgot = table.remove(moves, 1)
		end
		table.insert(moves, item.move)
		record.moves = moves
		SaveService.requestSave(player)
		return true, forgot and ("%s forgot %s and learned %s!"):format(record.name, forgot, item.move) or ("%s learned %s!"):format(record.name, item.move)
	end
end

-- Shop: buying with coins (Clerk Milo's menu) ---------------------------------------
ReplicatedStorage.Remotes:WaitForChild("BuyItem").OnServerInvoke = function(player, itemId, quantity)
	if typeof(itemId) ~= "string" or not PlayerData.finite(quantity) then
		return false, "Something went wrong."
	end
	quantity = math.clamp(math.floor(quantity), 1, 10)
	local entry
	for _, e in GameData.Shop do
		if e.id == itemId then
			entry = e
		end
	end
	if not entry then
		return false, "That isn't for sale."
	end
	if (player:GetAttribute("Badges") or 0) < entry.badges then
		return false, ("Milo sells that once you have %d badge%s."):format(entry.badges, entry.badges == 1 and "" or "s")
	end
	local cost = entry.price * quantity
	if not PlayerData.spend(player, cost) then
		return false, ("You need %d coins (you have %d)."):format(cost, PlayerData.coins(player))
	end
	PlayerData.addItem(player, itemId, quantity)
	SaveService.requestSave(player)
	local def = GameData.Balls[itemId] or GameData.Items[itemId]
	return true, ("Bought %d %s%s!"):format(quantity, def.name, quantity > 1 and "s" or "")
end

-- Teleport buttons (SHOP / BASE / HEAL) ----------------------------------------
do
	local Teleport = ReplicatedStorage.Remotes:WaitForChild("Teleport")
	local hub = workspace.Map.Hub
	local function standInFront(npcName: string, building: Model): CFrame?
		local npc = building:FindFirstChild(npcName)
		if not npc then
			return nil
		end
		local p = npc.PrimaryPart.Position
		local stand = Vector3.new(p.X, 3.6, p.Z + 9)
		return CFrame.lookAt(stand, Vector3.new(p.X, 3.6, p.Z))
	end
	local last = {}
	-- TRAVEL menu destinations: a spot just inside each region's entrance, facing in
	local function travelCFrame(player: Player, where: string, arg): CFrame?
		local badges = player:GetAttribute("Badges") or 0
		local champion = (player:GetAttribute("Stat_leagueWins") or 0) > 0
		local function facing(pos: Vector3)
			return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
		end
		if where == "hub" then
			return facing(Vector3.new(0, 4, -80))
		elseif where == "town2" then
			-- the only long-range jump left: Champions can hop to Summit Town (Region 2's hub)
			if not champion then
				Notify:FireClient(player, "Summit Town opens once you become the Champion.", "fail")
				return nil
			end
			return facing(GameData.Arms[2].town)
		end
		-- no more route-to-route teleports: Region 1 is one road you walk (rare spawns are a real race)
		return nil
	end
	Teleport.OnServerEvent:Connect(function(player, where, arg)
		if BattleService.isInBattle(player) or player:GetAttribute("Trading") or player:GetAttribute("InCutscene") then
			return
		end
		if typeof(where) ~= "string" then
			return
		end
		if last[player] and os.clock() - last[player] < 1.5 then
			return
		end
		-- brand-new players talk to Professor Maple first
		local step = player:GetAttribute("TutorialStep")
		if step == "meet_prof" or step == "choose_starter" then
			Notify:FireClient(player, ("Talk to %s at the lab first!"):format(GameData.ProfessorName), "info")
			return
		end
		player:SetAttribute("InDungeon", false)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		local cf
		if where == "base" then
			cf = BaseManager.spawnCFrame(player)
		elseif where == "shop" then
			cf = standInFront("Clerk", hub.Shop)
		elseif where == "heal" then
			-- the last Heal Stop you used on the road, or Nurse Ivy in the hub
			cf = (healStopCFrame and healStopCFrame(player)) or standInFront("Nurse", hub.HealingCenter)
		else
			cf = travelCFrame(player, where, arg)
		end
		if cf then
			last[player] = os.clock()
			-- the dungeon is far away: load the destination before moving the player there
			pcall(player.RequestStreamAroundAsync, player, cf.Position, 4)
			if not character.Parent then
				return
			end
			character:PivotTo(cf)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)

	-- whole team fainted: wake up in front of Nurse Ivy at the Healing Center
	BattleService.onReleased(function(player, battle)
		if battle.result ~= "lost" or (battle.trainer and battle.trainer.kind == "pvp") then
			return
		end
		if BaseManager.firstHealthy(player) then
			return -- (a forfeit with healthy creatures left isn't a wipe-out)
		end
		local character = player.Character
		local cf = (healStopCFrame and healStopCFrame(player)) or standInFront("Nurse", hub.HealingCenter)
		if not character or not cf then
			return
		end
		player:SetAttribute("InDungeon", false)
		pcall(player.RequestStreamAroundAsync, player, cf.Position, 4)
		if character.Parent then
			character:PivotTo(cf)
			Notify:FireClient(player, "Your team fainted! You hurried back to your last heal spot. Heal up and try again.", "info")
		end
	end)
end

-- Settings (saved): music on/off -------------------------------------------------------
ReplicatedStorage.Remotes:WaitForChild("Settings").OnServerEvent:Connect(function(player, key, value)
	if key == "musicMuted" and typeof(value) == "boolean" then
		PlayerData.setMusicMuted(player, value)
	end
end)

-- Active routes use the same badge + Champion checks as battles and gates.
-- The lane's "Unlocked" attribute means someone online can enter it.
local rotateHotZone
local function canAnyoneEnter(laneKey: string): boolean
	for _, player in Players:GetPlayers() do
		if GameData.canEnter(laneKey, player:GetAttribute("Badges") or 0, (player:GetAttribute("Stat_leagueWins") or 0) > 0) then
			return true
		end
	end
	return false
end

local function refreshActiveLanes()
	for _, lane in workspace.Map.Lanes:GetChildren() do
		if lane:IsA("BasePart") and GameData.Lanes[lane.Name] then
			local active = canAnyoneEnter(lane.Name)
			if active ~= (lane:GetAttribute("Unlocked") == true) then
				lane:SetAttribute("Unlocked", active)
				if active then
					task.spawn(WildSpawner.spawnLane, lane.Name)
				end
			end
			if not active then
				-- A nearby or battling creature stays until it is safe to remove.
				WildSpawner.clearLane(lane.Name)
			end
		end
	end
	local current = WildSpawner.getHotZone()
	if rotateHotZone and (not current or not canAnyoneEnter(current)) then
		rotateHotZone(false)
	end
end

local function watchProgress(player: Player)
	player:GetAttributeChangedSignal("Badges"):Connect(refreshActiveLanes)
	player:GetAttributeChangedSignal("Stat_leagueWins"):Connect(refreshActiveLanes)
	task.defer(refreshActiveLanes)
end
Players.PlayerAdded:Connect(watchProgress)
for _, player in Players:GetPlayers() do
	watchProgress(player)
end
Players.PlayerRemoving:Connect(function()
	task.defer(refreshActiveLanes)
end)

-- One open region is the Hot Zone. Victory Roads keep their regular pools.
-- The paid Summon Rare and free hourly rare run independently in RareEventService.
local shiftRng = Random.new()
rotateHotZone = function(announce: boolean)
	local candidates = {}
	local previous = WildSpawner.getHotZone()
	for _, region in GameData.Regions do
		local lane = workspace.Map.Lanes:FindFirstChild(region.lane)
		if lane and GameData.Lanes[region.lane] and lane:GetAttribute("Unlocked") and canAnyoneEnter(region.lane) then
			table.insert(candidates, region)
		end
	end
	if #candidates > 1 and previous then
		for index = #candidates, 1, -1 do
			if candidates[index].lane == previous then
				table.remove(candidates, index)
			end
		end
	end
	local region = #candidates > 0 and candidates[shiftRng:NextInteger(1, #candidates)] or nil
	WildSpawner.setHotZone(region and region.lane or nil)
	ReplicatedStorage:SetAttribute("HotZoneLane", region and region.lane or nil)
	ReplicatedStorage:SetAttribute("HotZoneName", region and region.name or nil)
	ReplicatedStorage:SetAttribute("WildShiftEndsAt", region and (workspace:GetServerTimeNow() + GameData.ResetSeconds) or nil)
	ReplicatedStorage:SetAttribute("ResetEndsAt", nil) -- retired map-wipe timer
	if not region then
		return
	end
	WildSpawner.shift()
	for _, lane in workspace.Map.Lanes:GetChildren() do
		if lane:IsA("BasePart") and lane:GetAttribute("Unlocked") and GameData.Lanes[lane.Name] then
			WildSpawner.spawnLane(lane.Name)
		end
	end
	if announce then
		Notify:FireAllClients(("WILD SHIFT! %s is the Hot Zone for 10 minutes: 3x shiny chance and more Large and Huge creatures. Nearby creatures and battles stay safe!"):format(region.name), "announce")
	end
end

-- Empty spots still refill every 15 seconds between shifts.
task.spawn(function()
	while true do
		task.wait(GameData.RefillSeconds)
		refreshActiveLanes()
		for _, lane in workspace.Map.Lanes:GetChildren() do
			if lane:IsA("BasePart") and lane:GetAttribute("Unlocked") then
				WildSpawner.refillLane(lane.Name)
			end
		end
	end
end)

refreshActiveLanes()
while true do
	task.wait(1)
	local endsAt = ReplicatedStorage:GetAttribute("WildShiftEndsAt")
	if endsAt and workspace:GetServerTimeNow() >= endsAt then
		rotateHotZone(true)
	end
end
