--[[
	TutorialService: a new player's first steps.
	Steps (player attribute "TutorialStep"):
	  meet_prof      -> talk to Professor Maple at the lab in the hub (his intro speech)
	  choose_starter -> pick Grass, Fire or Water (the client shows the three starters)
	  rival          -> Rival Kai takes the starter strong against yours and battles you (no running)
	  battle_nibbit  -> a private wild Nibbit appears: battle it, weaken it, catch it (no running;
	                    it can't faint, it only uses Squeak, and the catch is guaranteed once you've attacked)
	  heal           -> talk to Nurse Ivy (Juniper appears for the first time: StoryService)
	  Trainer's Guide (learn, don't play; no battles needed):
	  guide_shop     -> talk to Clerk Milo: items, decorations, crates, BUILD and the Coin Jar
	  guide_tower    -> walk up to the Dark Tower portal: how the tower works
	  guide_regions  -> walk to the Guide Post at the Meadow Route: a camera tour of the route trainers,
	                    the gym and the locked regions, then the Professor wraps up
	  done           (guide reward: coins + a free Garden Crate)
	Unfinished guide steps are saved by StoryService and resumed on rejoin.
	Dialogue and the starter picker go through the "Tutorial" RemoteEvent:
	  server -> client: "dialogue", { id, speaker, lines }   |  "pickStarter", { starters }
	  client -> server: "dialogueDone", id                  |  "choose", starterName
	The client reads TutorialStep and the "TutorialTarget" ObjectValue to draw arrows and highlights.
	Tutorial creatures live in workspace.TutorialCreatures and only work for their owner.
	Finished players are saved with TutorialStep = "done".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local WildSpawner = require(script.Parent.WildSpawner)
local BattleService = require(script.Parent.BattleService)
local PlayerData = require(script.Parent.PlayerData)
local BaseManager = require(script.Parent.BaseManager)
local NPC = require(script.Parent.NPC)

local TUTORIAL_COINS = 250
local TUTORIAL_XP = 150
local GUIDE_COINS = 250
local GUIDE_STEPS = { guide_shop = 1, guide_tower = 2, guide_regions = 3 }

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local TutorialRemote = Remotes:WaitForChild("Tutorial")

local lab = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("Lab")
local professor = lab:WaitForChild("Professor")
local rival = lab:WaitForChild("Rival")
local PROF = GameData.ProfessorName
local RIVAL = GameData.RivalName

local TutorialService = {}

local folder = workspace:FindFirstChild("TutorialCreatures")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TutorialCreatures"
	folder.Parent = workspace
end

local models = {} -- [Player] = { Model }

local function setStep(player: Player, step: string, target: Instance?)
	local value = player:FindFirstChild("TutorialTarget")
	if not value then
		value = Instance.new("ObjectValue")
		value.Name = "TutorialTarget"
		value.Parent = player
	end
	value.Value = target
	player:SetAttribute("TutorialStep", step)
end

local function clearModels(player: Player)
	for _, m in models[player] or {} do
		if m.Parent and not m:GetAttribute("InBattle") then
			m:Destroy()
		end
	end
	models[player] = {}
end

-- Spawn a creature only this player can interact with, near the start of the Meadow Route
local function spawnFor(player: Player, name: string, level: number, z: number, tag: string): Model
	local x = math.random(-14, 14)
	local model = WildSpawner.spawnOne(name, level, Vector3.new(x, 1, z), {
		folder = folder, owner = player.UserId, shiny = false, sizeClass = "Normal", roam = 3,
	})
	model:SetAttribute("Tutorial", tag)
	models[player] = models[player] or {}
	table.insert(models[player], model)
	return model
end

local function starterInfo(name: string)
	for _, s in GameData.Starters do
		if s.name == name then
			return s
		end
	end
	return nil
end

local function dialogue(player: Player, id: string, speaker: string, lines)
	TutorialRemote:FireClient(player, "dialogue", { id = id, speaker = speaker, lines = lines })
end

local function profIntro(player: Player)
	-- kept short on purpose: a new player should be holding a creature inside the first 60 seconds
	dialogue(player, "intro", PROF, {
		("Welcome, %s! I'm Professor Maple."):format(player.DisplayName),
		"Every trainer needs a partner. Pick one of these three!",
	})
end

local function pickStarter(player: Player)
	local list = {}
	for _, s in GameData.Starters do
		local info = GameData.Creatures[s.name]
		table.insert(list, { name = s.name, type = info.type, blurb = s.blurb })
	end
	TutorialRemote:FireClient(player, "pickStarter", { starters = list, professor = PROF })
end

-- Which starter line this player has (walks evolutions back to the first stage)
local function playerStarter(player: Player)
	local from = {}
	for base, evo in GameData.Evolutions do
		from[evo.into] = base
	end
	for _, record in BaseManager.getTeam(player) do
		local name = record.name
		while from[name] do
			name = from[name]
		end
		local s = starterInfo(name)
		if s then
			return s
		end
	end
	return starterInfo(player:GetAttribute("StarterName") or "")
end

-- Kai's team grows with your badges: his counter starter (evolved when he's high enough) plus extras
local function rivalTeam(player: Player, s)
	local badges = player:GetAttribute("Badges") or 0
	local level = 6 + badges * 5
	local lead = s.counter
	while GameData.Evolutions[lead] and level >= GameData.Evolutions[lead].level do
		lead = GameData.Evolutions[lead].into
	end
	local team = { { lead, level } }
	local extras = { "Squawkit", "Pebblit", "Zapkit", "Cinderock", "Frostpaw", "Nightfang", "Galewing" }
	for i = 1, math.min(badges, 3) do
		table.insert(team, 1, { extras[math.min(#extras, badges - i + 1)], level - 2 })
	end
	return team
end

local function rivalChallenge(player: Player)
	local s = playerStarter(player)
	if not s then
		NPC.say(rival, "Come back once you've got a partner!", 3)
		return
	end
	dialogue(player, "rival", RIVAL, {
		"Hey! I'm Kai. I'm going to be the greatest trainer ever!",
		("You've got a %s-type partner? Then my %s has the edge!"):format(GameData.Creatures[s.name].type, s.counter),
		"Let's battle! You can forfeit if it gets too tough.",
	})
end

local function startNibbit(player: Player)
	clearModels(player)
	-- at the route entrance, before the normal wild spawns begin, so E can't grab the wrong creature
	local nibbit = spawnFor(player, "Nibbit", 3, 259, "nibbit")
	setStep(player, "battle_nibbit", nibbit)
end

-- Where each Trainer's Guide step points
local function guideTarget(step: string): Instance?
	local hub = workspace.Map.Hub
	if step == "guide_shop" then
		return hub.Shop:FindFirstChild("Clerk")
	elseif step == "guide_tower" then
		return hub:FindFirstChild("DungeonPortal")
	elseif step == "guide_regions" then
		return hub:FindFirstChild("GuidePost")
	end
	return nil
end

function TutorialService.isGuideStep(step: string?): boolean
	return step ~= nil and GUIDE_STEPS[step] ~= nil
end

-- Put a player back on a guide step (rejoining mid-guide)
function TutorialService.resumeGuide(player: Player, step: string)
	if GUIDE_STEPS[step] then
		setStep(player, step, guideTarget(step))
	end
end

local busyGuide = {} -- [Player] = true while a guide lesson is playing

function TutorialService.start(player: Player)
	local step = player:GetAttribute("TutorialStep")
	if step == "done" then
		-- "done" but no creatures (skipped the tutorial, or a save lost its team): that's a dead end,
		-- because wild battles need a partner. Send them back to the Professor for a starter.
		if #BaseManager.getTeam(player) == 0 then
			player:SetAttribute("RecoveryStarter", true)
			setStep(player, "choose_starter", professor)
			Notify:FireClient(player, ("You don't have a partner yet! Talk to %s at the lab."):format(PROF), "info")
		end
		return
	end
	if GUIDE_STEPS[step] then
		setStep(player, step, guideTarget(step))
		return
	end
	clearModels(player)
	if #BaseManager.getTeam(player) > 0 then
		-- already has a partner (shouldn't happen for new players): straight to the wild battle
		startNibbit(player)
		return
	end
	setStep(player, "meet_prof", professor)
	-- don't make new players hunt for the lab: the Professor greets them as soon as they spawn
	task.delay(3, function()
		if player.Parent and player:GetAttribute("TutorialStep") == "meet_prof" and player.Character then
			profIntro(player)
		end
	end)
end

-- Talking to the professor or the rival
local function onProfessor(player: Player)
	local step = player:GetAttribute("TutorialStep")
	if step == "done" and #BaseManager.getTeam(player) == 0 then
		-- safety net: never leave a player without a partner
		player:SetAttribute("RecoveryStarter", true)
		setStep(player, "choose_starter", professor)
		step = "choose_starter"
	end
	if step == "meet_prof" then
		profIntro(player)
	elseif step == "choose_starter" then
		pickStarter(player)
	elseif step == "battle_nibbit" then
		NPC.say(professor, "A wild Nibbit is waiting on the Meadow Route. Weaken it, then catch it!", 4)
	elseif GUIDE_STEPS[step] then
		NPC.say(professor, "Follow the Trainer's Guide at the top of your screen. It won't take long!", 4)
	elseif player:GetAttribute("MetJuniper") and math.random() < 0.5 then
		-- he can't place her...
		NPC.say(professor, "Juniper? My daughter? That name sounds so familiar... but I don't have a daughter. Do I?", 5)
	else
		NPC.say(professor, "How's your journey going? Catch lots of creatures and beat those gym leaders!", 4)
	end
end

-- Optional rival battle (after the tutorial). You can forfeit.
local function startRivalBattle(player: Player)
	local s = playerStarter(player)
	if not s or BattleService.isInBattle(player) then
		return
	end
	local team = rivalTeam(player, s)
	local level = team[#team][2]
	local ok = BattleService.startTrainer(player, {
		name = RIVAL, team = team, kind = "rival",
		intro = ("%s wants to battle!"):format(RIVAL),
		reward = { coins = 20 + level * 4, xp = level * 8 },
	})
	if not ok then
		Notify:FireClient(player, "Your team needs healing before you can battle Kai.", "info")
	end
end

TutorialRemote.OnServerEvent:Connect(function(player: Player, action, arg)
	local step = player:GetAttribute("TutorialStep")
	if action == "dialogueDone" then
		if arg == "intro" and step == "meet_prof" then
			setStep(player, "choose_starter", professor)
			pickStarter(player)
		elseif arg == "rival" and step == "done" then
			startRivalBattle(player)
		elseif arg == "guide_shop" and step == "guide_shop" then
			busyGuide[player] = nil
			setStep(player, "guide_tower", guideTarget("guide_tower"))
		elseif arg == "guide_tower" and step == "guide_tower" then
			busyGuide[player] = nil
			setStep(player, "guide_regions", guideTarget("guide_regions"))
		elseif arg == "guide_end" and step == "guide_regions" then
			busyGuide[player] = nil
			TutorialService.finishGuide(player)
		end
	elseif action == "tourDone" and step == "guide_regions" then
		dialogue(player, "guide_end", PROF, {
			"So that's how the journey works: catch creatures, beat a region's three trainers, then beat its Gym Leader.",
			"Every badge you win opens the next region. The grey ones will light up once you've earned them.",
			"Your daily quests are in the QUESTS menu, and the BUILD menu turns your coins into a better base.",
			"That's everything I can teach you. Now go out there and start your Creature Quest!",
		})
	elseif action == "choose" and step == "choose_starter" then
		local s = typeof(arg) == "string" and starterInfo(arg)
		if not s or #BaseManager.getTeam(player) > 0 then
			return
		end
		BaseManager.addCreature(player, BaseManager.newRecord(s.name, GameData.StarterLevel))
		player:SetAttribute("StarterName", s.name)
		Notify:FireClient(player, ("You received %s! It's waiting at your base."):format(s.name), "success")
		task.wait(1)
		-- a returning player who just needed a partner skips the rest of the tutorial
		if player:GetAttribute("RecoveryStarter") then
			player:SetAttribute("RecoveryStarter", nil)
			dialogue(player, "afterPickRecovery", PROF, {
				("%s! A wonderful choice. Take good care of it."):format(s.name),
				"You already know the ropes, so off you go. Good luck out there!",
			})
			setStep(player, "done", nil)
			return
		end
		dialogue(player, "afterPick", PROF, {
			("%s! Great choice. Now let's catch your first wild creature!"):format(s.name),
		})
		startNibbit(player)
		-- skip the long walk: the Professor brings you straight to the Nibbit at the route entrance
		task.delay(1.5, function()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and player:GetAttribute("TutorialStep") == "battle_nibbit" and not BattleService.isInBattle(player) then
				player.Character:PivotTo(CFrame.lookAt(Vector3.new(0, 5, 232), Vector3.new(0, 5, 260)))
				Notify:FireClient(player, "A wild Nibbit is right in front of you! Walk up and press E to battle it.", "info")
			end
		end)
	end
end)

BattleService.onEnded(function(player: Player, battle, result: string)
	if battle.isTrainer and battle.trainer and battle.trainer.kind == "rival" then
		battle.rivalResult = result
		return
	end
	if not battle.tutorial or player:GetAttribute("TutorialStep") ~= "battle_nibbit" then
		return
	end
	if result == "caught" then
		models[player] = {}
		local nurse = workspace.Map.Hub.HealingCenter:FindFirstChild("Nurse")
		setStep(player, "heal", nurse)
	elseif result == "lost" then
		-- they'll need to heal anyway; send them to the nurse, then back to the Nibbit
		local nurse = workspace.Map.Hub.HealingCenter:FindFirstChild("Nurse")
		player:SetAttribute("TutorialRetry", true)
		setStep(player, "heal", nurse)
	end
	-- "ran": the Nibbit goes back to where it was and stays the target
end)

-- After the rival battle (win or lose): heal up and head out for a wild creature
BattleService.onReleased(function(player: Player, battle)
	if not battle.rivalResult then
		return
	end
	local won = battle.rivalResult == "won"
	-- an optional friendly battle: the professor patches your team up afterwards
	BaseManager.healAll(player)
	NPC.say(rival, won and "What?! I'll train harder. See you around!"
		or "Ha! Told you so. Get stronger, then come find me!", 5)
	Notify:FireClient(player, "Professor Maple healed your team.", "info")
end)

function TutorialService.init()
	NPC.prompt(professor.PrimaryPart, "Talk", PROF, 12).Triggered:Connect(onProfessor)
	NPC.prompt(rival.PrimaryPart, "Talk", RIVAL, 12).Triggered:Connect(function(player)
		if player:GetAttribute("TutorialStep") == "done" and not BattleService.isInBattle(player) then
			rivalChallenge(player)
		else
			NPC.say(rival, "Finish up with the Professor first, then come battle me!", 3)
		end
	end)
end

-- Called by the Healing Center when this player heals
function TutorialService.onHeal(player: Player)
	if player:GetAttribute("TutorialStep") ~= "heal" then
		return
	end
	if player:GetAttribute("TutorialRetry") then
		player:SetAttribute("TutorialRetry", nil)
		startNibbit(player)
		return
	end
	PlayerData.addCoins(player, TUTORIAL_COINS)
	PlayerData.addXP(player, TUTORIAL_XP)
	Notify:FireClient(player, ("Great work! +%d coins and %d trainer XP. Now for the Trainer's Guide."):format(TUTORIAL_COINS, TUTORIAL_XP), "success")
	setStep(player, "guide_shop", guideTarget("guide_shop"))
end

function TutorialService.finishGuide(player: Player)
	setStep(player, "done", nil)
	PlayerData.addCoins(player, GUIDE_COINS)
	local ok, DecorService = pcall(require, script.Parent.DecorService)
	if ok and DecorService.giveBox then
		DecorService.giveBox(player, "CommonCrate")
	end
	Notify:FireClient(player, ("Trainer's Guide complete! +%d coins and a free Garden Crate (open it in BUILD)."):format(GUIDE_COINS), "success")
end

-- Clerk Milo during the guide: explain the shop instead of just opening it. Returns true if handled.
function TutorialService.onShop(player: Player): boolean
	if player:GetAttribute("TutorialStep") ~= "guide_shop" or busyGuide[player] then
		return false
	end
	busyGuide[player] = true
	dialogue(player, "guide_shop", "Clerk Milo", {
		("Welcome in, %s! Let me show you around."):format(player.DisplayName),
		"I sell balls, tonics, battle draughts and held items for coins. Better stock unlocks as you earn gym badges.",
		"You earn coins by winning battles, catching creatures, daily quests and your login streak.",
		"Want a fancier base? Press BUILD. You can buy decorations, open crates, and change your base's theme.",
		"Some decorations even earn coins for you. They fill the Coin Jar by your spawn, even while you're offline!",
		"Next, the Professor wants you to see the Dark Tower. It's the swirling portal in the middle of the hub.",
	})
	return true
end

-- Walking up to the guide's targets starts the lesson
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in Players:GetPlayers() do
			local step = player:GetAttribute("TutorialStep")
			if (step == "guide_tower" or step == "guide_regions") and not busyGuide[player] and not BattleService.isInBattle(player) then
				local target = guideTarget(step)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local pos = target and target:IsA("Model") and target:GetPivot().Position
				if root and pos and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < 16 then
					busyGuide[player] = true
					if step == "guide_tower" then
						dialogue(player, "guide_tower", PROF, {
							"This is the Dark Tower. Step through the portal and you'll face one trainer on every floor.",
							"Each floor is harder than the last, and every tenth floor has a boss. Your best floor is saved.",
							"The rewards are great, so come back whenever your team gets stronger.",
							"One more thing to learn: how to unlock new regions. Follow the arrow to the Guide Post by the Meadow Route.",
						})
				else
						TutorialRemote:FireClient(player, "tour", { id = "regions" })
					end
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	busyGuide[player] = nil
	for _, m in models[player] or {} do
		if m.Parent then
			m:Destroy()
		end
	end
	models[player] = nil
end)

return TutorialService
