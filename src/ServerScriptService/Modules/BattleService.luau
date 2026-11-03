--[[
	BattleService: turn-based battles. Two kinds:
	  wild    - BattleService.start(player, wildModel): fought in an isolated arena; you can catch.
	  trainer - BattleService.startTrainer(player, def): a trainer's team, one creature after another;
	            no catching; rewards coins + trainer XP. def.place = { center, look } fights in place
	            (the dungeon floors); otherwise it uses an arena.
	The server decides everything; the client sends button presses and plays animations.
	Actions: "fight" (move), "catch", "switch" (creature id), "run", "done" (client finished animating).

	Log entries are { text, fx }. fx types: attack, stat, faint, throw, levelup, sendout, reward.
	fx carry model references so the client animates the right creature even if it changes mid-turn.

	PvP: BattleService.startPvP(p1, p2). Two linked battle objects (one per player) share one arena.
	Each side fights with full-HP copies of its team (nothing faints for real). A turn resolves once both
	players have chosen (or the turn timer runs out). The log is built from player 1's point of view and
	mirrored for player 2. Results reach listeners as trainer battles with trainer.kind = "pvp".

	Listeners:
	  BattleService.onEnded(fn(player, battle, result))     -- result: won, caught, lost, ran, ended
	  BattleService.onReleased(fn(player, battle))          -- after the client finished and the player is back
	  BattleService.hooks.firstCatch(player)               -- very first creature caught
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local BattleData = require(ReplicatedStorage.Shared.BattleData)
local CreatureBuilder = require(ReplicatedStorage.Shared.CreatureBuilder)
local BaseManager = require(script.Parent.BaseManager)
local Wander = require(script.Parent.Wander)
local ArenaManager = require(script.Parent.ArenaManager)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local BattleEvent = Remotes:WaitForChild("BattleEvent")
local BattleAction = Remotes:WaitForChild("BattleAction")

local alliesFolder = workspace:FindFirstChild("BattleAllies")
if not alliesFolder then
	alliesFolder = Instance.new("Folder")
	alliesFolder.Name = "BattleAllies"
	alliesFolder.Parent = workspace
end

local BattleService = {}
BattleService.hooks = {}

local endedListeners, releasedListeners = {}, {}
function BattleService.onEnded(fn)
	table.insert(endedListeners, fn)
end
function BattleService.onReleased(fn)
	table.insert(releasedListeners, fn)
end

local battles = {} -- [Player] = battle in progress
local pending = {} -- [Player] = finished battle waiting for the client to finish animating
local rng = Random.new()
local Economy = GameData.Economy

local function fire(list, ...)
	for _, fn in list do
		task.spawn(fn, ...)
	end
end

local function playbackTime(log): number
	return 2 + #log * 1.4
end

local function info(name: string)
	return GameData.Creatures[name]
end

local function statsOf(c)
	return BattleData.stats(c.name, c.level, c.sizeClass, c.ivs)
end

-- A creature's current moves: taught moves (Skill Discs) override the natural learnset
local function movesFor(c): { string }
	return c.moves or BattleData.movesAt(c.name, c.level)
end
BattleService.movesFor = movesFor

local function say(log, text: string, fx)
	if log then
		table.insert(log, { text = text, fx = fx })
	end
end

local function setTag(model: Model?, enabled: boolean)
	local tag = model and model.PrimaryPart and model.PrimaryPart:FindFirstChild("NameTag")
	if tag then
		tag.Enabled = enabled
	end
end

local function newStages()
	return { atk = 0, def = 0, spd = 0 }
end

-- "Wild " / "Foe " / "" in front of a creature's name (PvP uses markers swapped per player)
local function prefixFor(b, s: string): string
	if b.pvp then
		return s == "ally" and "\u{E000}" or "\u{E001}"
	end
	if s == "ally" then
		return ""
	end
	return b.isTrainer and "Foe " or "Wild "
end

-- Status conditions --------------------------------------------------------------
local STATUS_GAINED = {
	brn = "was burned!", psn = "was poisoned!", par = "is paralyzed! It may be unable to move!",
	slp = "fell asleep!", frz = "was frozen solid!",
}
local STATUS_CURED = {
	brn = "'s burn was healed!", psn = " was cured of its poison!", par = " was cured of paralysis!",
	slp = " woke up!", frz = " thawed out!",
}
BattleService.STATUS_CURED = STATUS_CURED

-- Held berries: eaten automatically (HP below half, or a status condition). side's creature only.
local function heldCheck(b, log, side: string)
	local c = side == "ally" and b.ally or b.wild
	if not c or c.hp <= 0 or not c.held then
		return
	end
	local item = GameData.Items[c.held]
	local h = item and item.held
	if not h or not h.berry then
		return
	end
	local who = prefixFor(b, side) .. c.name
	if h.cureStatus then
		if c.status then
			local s = c.status
			c.status, c.sleepTurns, c.held = nil, nil, nil
			say(log, ("%s ate its %s! %s%s"):format(who, item.name, c.name, STATUS_CURED[s]),
				{ type = "status", side = side, status = nil, model = side == "ally" and b.allyModel or b.model })
		end
		return
	end
	local maxHP = statsOf(c).maxHP
	if c.hp < maxHP * (h.below or 0.5) then
		local before = c.hp
		c.hp = math.min(maxHP, c.hp + (h.healHP or math.max(1, math.floor(maxHP * (h.healFrac or 0)))))
		c.held = nil
		say(log, ("%s ate its %s and restored %d HP!"):format(who, item.name, c.hp - before),
			{ type = "heal", side = side, targetHp = c.hp, targetMax = maxHP })
	end
end

-- Speed after stages and paralysis
local function speedOf(c, stage: number): number
	local spd = statsOf(c).spd * BattleData.stageMult(stage)
	if c.status == "par" then
		spd *= 0.5
	end
	return spd
end

local function xpFrac(c): number?
	if not c.xp then
		return nil
	end
	if c.level >= BattleData.MaxLevel then
		-- at level 100 the bar tracks the next star (full once IV Trained)
		return BattleData.starProgress(c) or 1
	end
	local lo, hi = BattleData.xpForLevel(c.level), BattleData.xpForLevel(c.level + 1)
	return math.clamp((c.xp - lo) / (hi - lo), 0, 1)
end

local function snapshot(c)
	local i = info(c.name)
	return {
		name = c.name,
		level = c.level,
		hp = c.hp,
		maxHP = statsOf(c).maxHP,
		type = i.type,
		type2 = i.type2,
		rarity = i.rarity,
		shiny = c.shiny == true,
		sizeClass = c.sizeClass or "Normal",
		xpFrac = xpFrac(c),
		status = c.status,
		stars = c.stars or 0,
	}
end

local function moveOptions(b)
	local defInfo = info(b.wild.name)
	local list = {}
	for _, moveName in movesFor(b.ally) do
		local move = BattleData.Moves[moveName]
		local status = move.category == "status"
		table.insert(list, {
			name = moveName,
			type = move.type,
			power = move.power,
			status = status,
			mult = status and 1 or BattleData.effectiveness(move.type, defInfo.type, defInfo.type2),
		})
	end
	return list
end

-- PvP teams are copies, so the switch menu lists those instead of the real team
local function copySnapshot(list)
	local out = {}
	for _, c in list do
		local i = info(c.name)
		table.insert(out, {
			id = c.id, name = c.name, level = c.level, hp = c.hp, maxHP = statsOf(c).maxHP,
			type = i.type, type2 = i.type2, shiny = c.shiny, sizeClass = c.sizeClass, status = c.status,
			stars = c.stars or 0,
		})
	end
	return out
end

local function buildState(b)
	local ball = GameData.Balls[GameData.DefaultBall]
	return {
		wild = snapshot(b.wild),
		ally = snapshot(b.ally),
		allyId = b.ally.id,
		moves = moveOptions(b),
		team = b.pvpTeam and copySnapshot(b.pvpTeam) or BaseManager.snapshot(b.player),
		pvp = b.pvp ~= nil,
		waiting = b.waiting == true,
		noRun = b.noRun == true,
		canCatch = (not b.isTrainer) and BaseManager.hasRoom(b.player),
		ballName = ball.name,
		mustSwitch = b.mustSwitch == true,
		tutorialHint = b.tutorial and (b.tutorialAttacked and "catch" or "fight") or nil,
		trainer = b.isTrainer and { name = b.trainer.name, index = b.trainerIndex, count = #b.trainer.team } or nil,
		allyModel = b.allyModel,
		wildModel = b.model,
		allyStages = b.stages and b.stages.ally,
		wildStages = b.stages and b.stages.wild,
		turn = b.turn or 0,
		fieldLook = b.look,
		fieldRight = b.right,
	}
end

local function send(b, kind: string, log, extra)
	BaseManager.refresh(b.player)
	if not b.player.Parent then
		return
	end
	local payload = { log = log or {}, state = buildState(b) }
	-- ObjectValues fill in on the client as soon as the models stream in, even if the event got there first
	local refs = b.player:FindFirstChild("BattleRefs")
	if not refs then
		refs = Instance.new("Folder")
		refs.Name = "BattleRefs"
		for _, n in { "Ally", "Wild" } do
			local v = Instance.new("ObjectValue")
			v.Name = n
			v.Parent = refs
		end
		refs.Parent = b.player
	end
	refs.Ally.Value = payload.state.allyModel
	refs.Wild.Value = payload.state.wildModel
	if extra then
		for k, v in extra do
			payload[k] = v
		end
	end
	BattleEvent:FireClient(b.player, kind, payload)
end

-- Ground height under a spot on the battlefield (fixed for in-place battles like the dungeon)
local function groundAt(b, position: Vector3): number
	if b.fixedGroundY then
		return b.fixedGroundY
	end
	return Wander.groundAt(position) or (position.Y - 3)
end

local function modelOf(b, side: string)
	return side == "ally" and b.allyModel or b.model
end

-- Put the player's active creature on the field next to the player
local function placeAlly(b)
	local old = b.allyModel
	if old then
		table.insert(b.oldModels, old)
	end
	local model = CreatureBuilder.build(b.ally.name, b.ally.level, { shiny = b.ally.shiny, sizeClass = b.ally.sizeClass })
	setTag(model, false)
	-- just in front of the trainer and a little to the left; the opponent stands further off to the right
	local spot = b.origin + b.look * 5 - b.right * 1
	local y = groundAt(b, spot) + model:GetAttribute("GroundOffset")
	local pos = Vector3.new(spot.X, y, spot.Z)
	model:PivotTo(CFrame.lookAt(pos, Vector3.new(b.wildSpot.X, y, b.wildSpot.Z)))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = alliesFolder
	b.allyModel = model
end

-- Build and place a trainer's creature on the opponent's spot
local function placeTrainerCreature(b)
	local model = CreatureBuilder.build(b.wild.name, b.wild.level, {})
	setTag(model, false)
	local y = groundAt(b, b.wildSpot) + model:GetAttribute("GroundOffset")
	local pos = Vector3.new(b.wildSpot.X, y, b.wildSpot.Z)
	model:PivotTo(CFrame.lookAt(pos, Vector3.new(b.origin.X, y, b.origin.Z)))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = alliesFolder
	b.model = model
end

-- Move the player to the battlefield (an arena, or a fixed place like a dungeon floor)
local function setupField(b, character: Model, hrp: BasePart, humanoid: Humanoid, place)
	local center, look
	if place then
		center, look = place.center, place.look
		b.fixedGroundY = place.center.Y
	else
		b.arenaIndex, center = ArenaManager.acquire()
		look = Vector3.new(1, 0, 0)
	end
	local hipHeight = humanoid.HipHeight + hrp.Size.Y / 2
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		hipHeight = 3
	end
	local playerPos = center - look * 12 + Vector3.new(0, hipHeight, 0)
	b.origin = playerPos
	b.look = look
	b.right = look:Cross(Vector3.yAxis)
	b.wildSpot = center + look * 9 + b.right * 7
	hrp.Anchored = true
	character:PivotTo(CFrame.lookAt(playerPos, playerPos + look))
	b.player:SetAttribute("InBattle", true)
	-- the arena is far from the map: make sure it has streamed to the player before the battle starts,
	-- or the client receives the creature models as nil (no battle camera, no HP cards)
	pcall(function()
		b.player:RequestStreamAroundAsync(center, 4)
	end)
end

-- Undo the battle once the client has finished: player back, creatures cleaned up, arena freed
local function release(b)
	if b.released then
		return
	end
	b.released = true
	if pending[b.player] == b then
		pending[b.player] = nil
	end

	for _, m in b.oldModels do
		if m.Parent then
			m:Destroy()
		end
	end
	local model = b.model
	if model and model.Parent and not b.isTrainer then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Default
	end
	if model and model.Parent then
		if b.isTrainer or b.result == "won" or b.result == "caught" then
			model:Destroy()
		else
			-- wild creature goes back to where it was wandering, ready to battle again
			model:PivotTo(CFrame.new(b.home + Vector3.new(0, model:GetAttribute("GroundOffset") or 1, 0)))
			model:SetAttribute("InBattle", false)
			setTag(model, true)
			local prompt = model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = true
			end
			Wander.add(model, b.home, b.roam or 6, b.roam or 6, b.groundY, 5)
		end
	end
	if b.allyModel and b.allyModel.Parent then
		b.allyModel:Destroy()
	end

	local character = b.player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and character == b.character then
		character:PivotTo(b.returnCFrame)
		hrp.Anchored = false
	end
	b.player:SetAttribute("InBattle", false)
	b.player:SetAttribute("BattleKind", nil)
	ArenaManager.release(b.arenaIndex)
	fire(releasedListeners, b.player, b)
end

local function finish(b, result: string, log)
	if battles[b.player] ~= b then
		return
	end
	battles[b.player] = nil
	if b.diedConn then
		b.diedConn:Disconnect()
	end
	b.result = result
	log = log or {}
	if not b.isTrainer and (result == "won" or result == "caught") then
		b.model:SetAttribute("Caught", true)
	end

	send(b, "end", log, { result = result })
	fire(endedListeners, b.player, b, result)

	if result == "ended" or not b.player.Parent then
		release(b)
	else
		pending[b.player] = b
		task.delay(playbackTime(log) + 8, function()
			release(b)
		end)
	end
end

local function damage(b, side: string, moveName: string): (number, number)
	local attacker = side == "ally" and b.ally or b.wild
	local defenderSide = side == "ally" and "wild" or "ally"
	local defender = side == "ally" and b.wild or b.ally
	local move = BattleData.Moves[moveName]
	local defInfo, attInfo = info(defender.name), info(attacker.name)
	local mult = BattleData.effectiveness(move.type, defInfo.type, defInfo.type2)
	if mult == 0 then
		return 0, 0
	end
	local atk = statsOf(attacker).atk * BattleData.stageMult(b.stages[side].atk)
	if attacker.status == "brn" then
		atk *= 0.5 -- a burn halves attack
	end
	local def = statsOf(defender).def * BattleData.stageMult(b.stages[defenderSide].def)
	-- held type charm: +20% to moves of its type
	local heldItem = attacker.held and GameData.Items[attacker.held]
	local charm = heldItem and heldItem.held and heldItem.held.boostType == move.type and heldItem.held.mult or 1
	-- Coliseum held items: Arena Band (all attacks), Expert Crest (super-effective), Guard Plate (defender)
	local ah = heldItem and heldItem.held
	if ah and ah.allBoost then
		charm *= ah.allBoost
	end
	if ah and ah.superBoost and mult > 1 then
		charm *= ah.superBoost
	end
	local defItem = defender.held and GameData.Items[defender.held]
	if defItem and defItem.held and defItem.held.guard then
		charm *= defItem.held.guard
	end
	local stab = (move.type == attInfo.type or move.type == attInfo.type2) and 1.5 or 1
	local base = ((2 * attacker.level / 5 + 2) * move.power * atk / def) / 50 + 2
	return math.max(1, math.floor(base * stab * mult * charm * rng:NextNumber(0.85, 1))), mult
end

-- One move. Returns true if the defender fainted.
local function useMove(b, log, side: string, moveName: string): boolean
	local attacker, defender, defenderSide = b.ally, b.wild, "wild"
	if side == "wild" then
		attacker, defender, defenderSide = b.wild, b.ally, "ally"
	end
	local move = BattleData.Moves[moveName]
	local function prefixOf(s)
		return prefixFor(b, s)
	end
	local text = ("%s%s used %s!"):format(prefixOf(side), attacker.name, moveName)
	local models = { attackerModel = modelOf(b, side), defenderModel = modelOf(b, defenderSide) }

	-- a status berry cures sleep / freeze / paralysis before they can stop the move
	if attacker.status then
		heldCheck(b, log, side)
	end
	-- sleep, freeze and paralysis can stop a creature from moving
	local who = prefixOf(side) .. attacker.name
	if attacker.status == "slp" then
		attacker.sleepTurns = (attacker.sleepTurns or 1) - 1
		if attacker.sleepTurns > 0 then
			say(log, who .. " is fast asleep.", { type = "status", side = side, status = "slp", model = models.attackerModel })
			return false
		end
		attacker.status, attacker.sleepTurns = nil, nil
		say(log, who .. " woke up!", { type = "status", side = side, status = nil, model = models.attackerModel })
	elseif attacker.status == "frz" then
		if rng:NextNumber() < 0.2 or move.type == "Fire" then
			attacker.status = nil
			say(log, who .. " thawed out!", { type = "status", side = side, status = nil, model = models.attackerModel })
		else
			say(log, who .. " is frozen solid!", { type = "status", side = side, status = "frz", model = models.attackerModel })
			return false
		end
	elseif attacker.status == "par" and rng:NextNumber() < 0.25 then
		say(log, who .. " is paralyzed! It can't move!", { type = "status", side = side, status = "par", model = models.attackerModel })
		return false
	end

	if rng:NextNumber() > move.accuracy then
		say(log, text, { type = "attack", side = side, moveType = move.type, moveName = moveName, power = move.power, hit = false, attackerModel = models.attackerModel, defenderModel = models.defenderModel })
		say(log, "It missed!")
		return false
	end

	if move.category == "status" then
		local effect = move.effect
		local targetSide = effect.target == "self" and side or defenderSide
		local target = targetSide == "ally" and b.ally or b.wild
		local stages = b.stages[targetSide]
		say(log, text, { type = "attack", side = side, moveType = move.type, moveName = moveName, power = move.power, hit = true, status = true, attackerModel = models.attackerModel })
		local before = stages[effect.stat]
		stages[effect.stat] = math.clamp(before + effect.stages, -6, 6)
		local statName = BattleData.StatNames[effect.stat]
		local who = prefixOf(targetSide) .. target.name
		if stages[effect.stat] == before then
			say(log, ("%s's %s won't go any %s!"):format(who, statName, effect.stages > 0 and "higher" or "lower"))
		else
			say(log, ("%s's %s %s!"):format(who, statName, effect.stages > 0 and "rose" or "fell"),
				{ type = "stat", side = targetSide, stat = effect.stat, stages = effect.stages, model = modelOf(b, targetSide) })
		end
		return false
	end

	local dmg, mult = damage(b, side, moveName)
	defender.hp = math.max(0, defender.hp - dmg)
	if b.tutorial and defenderSide == "wild" then
		defender.hp = math.max(1, defender.hp) -- tutorial creature can't be knocked out
	end
	say(log, text, {
		type = "attack", side = side, moveType = move.type, moveName = moveName, power = move.power, hit = true, mult = mult, damage = dmg,
		targetHp = defender.hp, targetMax = statsOf(defender).maxHP,
		attackerModel = models.attackerModel, defenderModel = models.defenderModel,
	})
	if mult == 0 then
		say(log, "It had no effect...")
	elseif mult > 1 then
		say(log, "It's super effective!")
	elseif mult < 1 then
		say(log, "It's not very effective...")
	end
	if defender.hp <= 0 then
		say(log, ("%s%s fainted!"):format(prefixOf(defenderSide), defender.name), { type = "faint", side = defenderSide, model = models.defenderModel })
		return true
	end
	-- a Fire move thaws a frozen target
	if defender.status == "frz" and move.type == "Fire" and mult > 0 then
		defender.status = nil
		say(log, prefixOf(defenderSide) .. defender.name .. " thawed out!", { type = "status", side = defenderSide, status = nil, model = models.defenderModel })
	end
	-- chance to cause a status condition (never in the tutorial battle)
	local inflict = move.inflict
	if inflict and mult > 0 and not defender.status and not b.tutorial and rng:NextNumber() < inflict.chance then
		local dInfo = info(defender.name)
		if BattleData.canGetStatus(inflict.status, dInfo.type, dInfo.type2) then
			defender.status = inflict.status
			if inflict.status == "slp" then
				defender.sleepTurns = rng:NextInteger(2, 4) -- asleep for 1 to 3 of its turns
			end
			say(log, ("%s%s %s"):format(prefixOf(defenderSide), defender.name, STATUS_GAINED[inflict.status]),
				{ type = "status", side = defenderSide, status = inflict.status, model = models.defenderModel })
		end
	end
	-- berries kick in after the hit
	heldCheck(b, log, defenderSide)
	return false
end

-- Burn and poison hurt at the end of a turn. Returns true if that creature fainted.
local function residual(b, log, side: string): boolean
	local c = side == "ally" and b.ally or b.wild
	if not c or c.hp <= 0 or (c.status ~= "brn" and c.status ~= "psn") then
		return false
	end
	local maxHP = statsOf(c).maxHP
	local dmg = math.max(1, math.floor(maxHP * (c.status == "brn" and 1 / 16 or 1 / 8)))
	c.hp = math.max(0, c.hp - dmg)
	say(log, ("%s%s is hurt by its %s!"):format(prefixFor(b, side), c.name, c.status == "brn" and "burn" or "poison"),
		{ type = "residual", side = side, status = c.status, damage = dmg, targetHp = c.hp, targetMax = maxHP, model = modelOf(b, side) })
	if c.hp <= 0 then
		say(log, ("%s%s fainted!"):format(prefixFor(b, side), c.name), { type = "faint", side = side, model = modelOf(b, side) })
		return true
	end
	heldCheck(b, log, side)
	return false
end

local function wildTurn(b, log): boolean
	local moves = movesFor(b.wild)
	local choice = moves[rng:NextInteger(1, #moves)]
	if b.tutorial and table.find(moves, "Squeak") then
		choice = "Squeak"
	end
	return useMove(b, log, "wild", choice)
end

-- Add XP to one creature record, levelling it up as needed. Returns levels gained.
local function capFor(player: Player?): (number, boolean)
	if not player then
		return BattleData.MaxLevel, true
	end
	return GameData.levelCap(player:GetAttribute("Badges") or 0, (player:GetAttribute("Stat_leagueWins") or 0) > 0)
end
BattleService.capFor = capFor

local function applyXP(record, amount: number, log, announce: boolean, model, player: Player?)
	local starsBefore = record.stars or 0
	local cap, starsOK = capFor(player)
	local limit = BattleData.maxXP()
	if not (starsOK and cap >= BattleData.MaxLevel) then
		limit = math.min(limit, BattleData.xpForLevel(cap))
	end
	if record.level >= cap and record.xp >= limit then
		return 0
	end
	record.xp = math.min(record.xp + amount, math.max(record.xp, limit))
	local levels = 0
	while record.level < math.min(cap, BattleData.MaxLevel) and record.xp >= BattleData.xpForLevel(record.level + 1) do
		local before = statsOf(record).maxHP
		record.level += 1
		levels += 1
		local after = statsOf(record).maxHP
		record.hp = math.min(after, record.hp + (after - before))
		if announce then
			say(log, ("%s grew to level %d!"):format(record.name, record.level), { type = "levelup", model = model })
		end
		for _, moveName in BattleData.learnedAt(record.name, record.level) do
			if record.moves and not table.find(record.moves, moveName) then
				if #record.moves >= 4 then
					table.remove(record.moves, 1)
				end
				table.insert(record.moves, moveName)
			end
			if announce then
				say(log, ("%s learned %s!"):format(record.name, moveName))
			end
		end
	end
	if announce and levels > 0 and record.level >= cap and not (starsOK and cap >= BattleData.MaxLevel) then
		say(log, ("%s hit the level cap (Lv %d). Your next badge raises it."):format(record.name, cap))
	end
	-- level 100+: stars perfect IVs (Star 3 = IV Trained)
	if record.level >= BattleData.MaxLevel and starsOK then
		local before = statsOf(record).maxHP
		BattleData.applyStars(record)
		if (record.stars or 0) > starsBefore then
			local after = statsOf(record).maxHP
			record.hp = math.min(after, record.hp + math.max(0, after - before))
			record.newStar = record.stars
			if announce then
				if record.stars >= BattleData.MaxStars then
					say(log, ("%s earned its 3rd star and is now IV TRAINED! Every stat is perfected."):format(record.name), { type = "levelup", model = model })
				else
					local stat = BattleData.bestStats(record.name)[record.stars]
					local label = ({ hp = "HP", atk = "Attack", def = "Defense", spd = "Speed" })[stat]
					say(log, ("%s earned Star %d! Its %s is now perfected."):format(record.name, record.stars, label), { type = "levelup", model = model })
				end
			end
		end
	end
	return levels
end

-- Quiet XP from outside battles (base Training Dummy). Returns levels gained.
function BattleService.applyXP(record, amount: number, player: Player?): number
	return applyXP(record, amount, nil, false, nil, player)
end

-- XP for beating the current opponent; the XP Canopy shares some with the rest of the team
local function grantXP(b, log)
	local ally = b.ally
	local gain = math.max(1, math.floor(BattleData.Species[b.wild.name].xpYield * b.wild.level / 7))
	local clover = ally.held and GameData.Items[ally.held]
	if clover and clover.held and clover.held.xpMult then
		gain = math.floor(gain * clover.held.xpMult) -- Growth Clover
	end
	if GameData.hasBoost(b.player, "DoubleXP") then
		gain *= 2 -- 2x XP game pass, timed boost or weekly event
	end
	local before = xpFrac(ally) or 0
	local capNow, starsNow = capFor(b.player)
	local capped = ally.level >= capNow and not (starsNow and capNow >= BattleData.MaxLevel)
		and ally.xp >= BattleData.xpForLevel(capNow)
	local entry = { text = capped and ("%s is at the level cap (Lv %d). Earn your next badge to keep growing!"):format(ally.name, capNow)
		or ("%s gained %d XP!"):format(ally.name, gain) }
	table.insert(log, entry)
	local levels = applyXP(ally, gain, log, true, b.allyModel, b.player)
	entry.fx = { type = "xp", from = before, to = xpFrac(ally) or 0, levels = levels, level = ally.level }
	-- the XP Canopy in your base (upgraded with coins) decides the share; 0 until the first upgrade
	local share = math.floor(gain * (b.player:GetAttribute("CanopyShare") or 0))
	if share > 0 then
		local shared = 0
		for _, record in BaseManager.getTeam(b.player) do
			if record ~= ally then
				applyXP(record, share, nil, false, nil, b.player)
				shared += 1
			end
		end
		if shared > 0 then
			say(log, ("The XP Canopy shared %d XP with your other creatures."):format(share))
		end
	end
end

local function giveReward(b, log, coins: number, xp: number)
	PlayerData.addCoins(b.player, coins)
	PlayerData.addXP(b.player, xp)
	say(log, ("You earned %d coins and %d trainer XP!"):format(coins, xp), { type = "reward" })
end

local function makeCreature(name: string, level: number, stars: number?)
	-- trainer creatures have middling IVs; starred ones (Region 2 League) have their best stats perfected
	local ivs = { hp = 12, atk = 12, def = 12, spd = 12 }
	stars = math.clamp(stars or 0, 0, BattleData.MaxStars)
	if stars > 0 then
		local order = BattleData.bestStats(name)
		for i = 1, (stars >= BattleData.MaxStars and #order or stars) do
			ivs[order[i]] = BattleData.IVMax
		end
	end
	return { name = name, level = level, ivs = ivs, stars = stars > 0 and stars or nil, hp = BattleData.stats(name, level, nil, ivs).maxHP, sizeClass = "Normal", shiny = false }
end

local function allyFainted(b, log)
	if BaseManager.firstHealthy(b.player) then
		b.mustSwitch = true
		say(log, "Choose your next creature!")
		send(b, "update", log)
	else
		say(log, "All your creatures fainted! Heal up at the Healing Center.")
		finish(b, "lost", log)
	end
end

-- The opponent fainted: trainers send their next creature, otherwise the battle is won
local function opponentFainted(b, log)
	grantXP(b, log)
	if b.isTrainer and b.trainerIndex < #b.trainer.team then
		table.insert(b.oldModels, b.model)
		b.trainerIndex += 1
		local entry = b.trainer.team[b.trainerIndex]
		b.wild = makeCreature(entry[1], entry[2], entry[3])
		b.stages.wild = newStages()
		placeTrainerCreature(b)
		say(log, ("%s sent out %s!"):format(b.trainer.name, b.wild.name), { type = "sendout", side = "wild", model = b.model, creature = snapshot(b.wild) })
		return send(b, "update", log)
	end
	if b.isTrainer then
		say(log, ("You defeated %s!"):format(b.trainer.name))
		local r = b.trainer.reward or {}
		giveReward(b, log, math.floor((r.coins or 0) * Economy.trainerCoinMult), r.xp or 0)
	else
		giveReward(b, log, Economy.wildWinCoins + math.floor(b.wild.level * Economy.wildCoinsPerLevel), Economy.wildWinXP * b.wild.level)
	end
	finish(b, "won", log)
end

-- End of a turn: burn/poison damage, then the next prompt (or a faint)
local function afterTurn(b, log)
	if residual(b, log, "wild") then
		return opponentFainted(b, log)
	end
	if residual(b, log, "ally") then
		return allyFainted(b, log)
	end
	send(b, "update", log)
end

local function doFight(b, moveName: string, log)
	if not table.find(movesFor(b.ally), moveName) then
		return send(b, "update", log)
	end
	b.tutorialAttacked = true
	local allySpd = speedOf(b.ally, b.stages.ally.spd)
	local wildSpd = speedOf(b.wild, b.stages.wild.spd)
	if allySpd >= wildSpd or b.tutorial then
		if useMove(b, log, "ally", moveName) then
			return opponentFainted(b, log)
		end
		if wildTurn(b, log) then
			return allyFainted(b, log)
		end
	else
		if wildTurn(b, log) then
			return allyFainted(b, log)
		end
		if useMove(b, log, "ally", moveName) then
			return opponentFainted(b, log)
		end
	end
	afterTurn(b, log)
end

-- Medicine on a creature record. Returns ok, message.
-- heal = HP ("max" = all), revive = fraction of HP for a fainted creature, cure = status key or "all"
function BattleService.applyMedicine(record, item): (boolean, string)
	local maxHP = statsOf(record).maxHP
	local function cures(s)
		return item.cure ~= nil and s ~= nil and (item.cure == "all" or item.cure == s)
	end
	if item.revive then
		if record.hp > 0 then
			return false, ("%s hasn't fainted."):format(record.name)
		end
		record.hp = math.max(1, math.floor(maxHP * item.revive))
		local extra = ""
		if cures(record.status) then
			record.status, record.sleepTurns = nil, nil
			extra = " Its status condition was cleared too."
		end
		return true, ("%s was revived%s!%s"):format(record.name, item.revive >= 1 and " at full HP" or "", extra)
	end
	if not item.heal and not item.cure then
		return false, "That can't be used on a creature."
	end
	if record.hp <= 0 then
		return false, ("%s has fainted. Use a Revival Seed first."):format(record.name)
	end
	local parts = {}
	if item.heal and record.hp < maxHP then
		local before = record.hp
		record.hp = item.heal == "max" and maxHP or math.min(maxHP, record.hp + item.heal)
		table.insert(parts, ("%s recovered %d HP!"):format(record.name, record.hp - before))
	end
	if cures(record.status) then
		table.insert(parts, record.name .. STATUS_CURED[record.status])
		record.status, record.sleepTurns = nil, nil
	end
	if #parts == 0 then
		if item.cure and not item.heal then
			if record.status then
				return false, ("%s won't cure %s's %s."):format(item.name, record.name, GameData.StatusInfo[record.status].name:lower())
			end
			return false, ("%s doesn't have a status condition."):format(record.name)
		end
		return false, ("%s already has full HP."):format(record.name)
	end
	return true, table.concat(parts, " ")
end

-- Using medicine in battle takes your turn
local function doItem(b, arg, log)
	local id = typeof(arg) == "table" and arg.id
	local item = typeof(id) == "string" and GameData.Items[id]
	-- battle draughts: +2 stages on your active creature
	if item and item.boost and not b.pvp then
		local inv = PlayerData.get(b.player).items
		if not inv[id] or inv[id] == 0 then
			say(log, "You don't have any left!")
			return send(b, "update", log)
		end
		local st = b.stages.ally
		local stat = item.boost.stat
		if st[stat] >= 6 then
			say(log, ("%s's %s won't go any higher!"):format(b.ally.name, BattleData.StatNames[stat]))
			return send(b, "update", log)
		end
		PlayerData.takeItem(b.player, id)
		local before = st[stat]
		st[stat] = math.clamp(before + item.boost.stages, -6, 6)
		say(log, ("You used a %s."):format(item.name))
		say(log, ("%s's %s rose sharply!"):format(b.ally.name, BattleData.StatNames[stat]),
			{ type = "stat", side = "ally", stat = stat, stages = st[stat] - before, model = b.allyModel })
		if wildTurn(b, log) then
			return allyFainted(b, log)
		end
		return afterTurn(b, log)
	end
	local record = typeof(arg) == "table" and typeof(arg.target) == "number" and BaseManager.findById(b.player, arg.target)
	if b.pvp or not item or not (item.heal or item.revive or item.cure) or not record then
		return send(b, "update", log)
	end
	local inv = PlayerData.get(b.player).items
	if not inv[id] or inv[id] == 0 then
		say(log, "You don't have any left!")
		return send(b, "update", log)
	end
	local ok, message = BattleService.applyMedicine(record, item)
	if not ok then
		say(log, message)
		return send(b, "update", log)
	end
	PlayerData.takeItem(b.player, id)
	say(log, ("You used a %s."):format(item.name))
	local side = record == b.ally and "ally" or nil
	say(log, message, side and { type = "heal", side = side, targetHp = record.hp, targetMax = statsOf(record).maxHP, status = record.status, statusSet = true } or nil)
	if wildTurn(b, log) then
		return allyFainted(b, log)
	end
	afterTurn(b, log)
end

local function doCatch(b, log, ballId)
	if b.isTrainer then
		say(log, "You can't catch another trainer's creature!")
		return send(b, "update", log)
	end
	if not BaseManager.hasRoom(b.player) then
		say(log, "Your base is full!")
		return send(b, "update", log)
	end
	if typeof(ballId) ~= "string" or not GameData.Balls[ballId] then
		ballId = GameData.DefaultBall
	end
	local ball = GameData.Balls[ballId]
	if not ball.unlimited and not PlayerData.takeItem(b.player, ballId) then
		say(log, ("You're out of %ss!"):format(ball.name))
		return send(b, "update", log)
	end
	local wild = b.wild
	local maxHP = statsOf(wild).maxHP
	local rarityName = info(wild.name).rarity
	local rate = GameData.Rarities[rarityName].catchRate
	local ballMult = GameData.ballMultiplier(ballId, {
		turn = math.max(0, (b.turn or 1) - 1), allyLevel = b.ally.level, wildLevel = wild.level, wildName = wild.name, wildSize = wild.sizeClass,
	})
	-- the free Loop Ball struggles with Rare and Legendary creatures (a reason to buy better balls)
	if ball.rareMult and (rarityName == "Rare" or rarityName == "Legendary") then
		ballMult *= ball.rareMult
	end
	-- a sleeping or frozen creature is much easier to catch; other statuses help a little
	local statusMult = (wild.status == "slp" or wild.status == "frz") and 2 or (wild.status and 1.5 or 1)
	local chance = rate * ballMult * statusMult * (3 * maxHP - 2 * wild.hp) / (3 * maxHP)
	if b.tutorial then
		chance = 1
	end
	local caught = rng:NextNumber() <= chance
	-- always the three-shake moment: a catch clicks after the third shake,
	-- a miss breaks out on shake 1, 2 or 3 (the closer it was, the later it breaks)
	local shakes = caught and 3 or math.clamp(math.floor(chance * 3) + 1, 1, 3)

	say(log, ("You threw a %s!"):format(ball.name), { type = "throw", caught = caught, shakes = shakes, ball = ballId })
	if caught then
		say(log, ("Gotcha! %s%s was caught!"):format(wild.shiny and "Shiny " or "", wild.name))
		local record = BaseManager.newRecord(wild.name, wild.level, wild.hp, wild.shiny, wild.sizeClass, wild.ivs)
		record.status, record.sleepTurns = wild.status, wild.sleepTurns
		BaseManager.addCreature(b.player, record)
		giveReward(b, log, Economy.catchCoins, Economy.catchXP * wild.level)
		-- server-wide rare catch banner: shiny, Rare/Legendary, Huge, or the rare spawn event creature
		local fromEvent = b.model and b.model.Parent and b.model:GetAttribute("RareEvent") == true
		if wild.shiny or rarityName == "Rare" or rarityName == "Legendary" or wild.sizeClass == "Huge" or fromEvent then
			local RareCatch = ReplicatedStorage.Remotes:FindFirstChild("RareCatch")
			if RareCatch then
				RareCatch:FireAllClients({
					player = b.player.DisplayName, userId = b.player.UserId, name = wild.name, level = wild.level,
					rarity = rarityName, shiny = wild.shiny == true, size = wild.sizeClass, event = fromEvent, ball = ball.name,
				})
			else
				Notify:FireAllClients(("%s caught a %s%s!"):format(b.player.DisplayName, wild.shiny and "SHINY " or "", wild.name), "announce")
			end
		end
		return finish(b, "caught", log)
	end
	say(log, "Oh no! It broke free!")
	if wildTurn(b, log) then
		return allyFainted(b, log)
	end
	afterTurn(b, log)
end

local function doSwitch(b, id: number, log)
	local record = BaseManager.findById(b.player, id)
	if not record or record.hp <= 0 or record == b.ally then
		return send(b, "update", log)
	end
	b.ally = record
	b.stages.ally = newStages()
	placeAlly(b)
	say(log, ("Go, %s!"):format(record.name), { type = "sendout", side = "ally", model = b.allyModel, creature = snapshot(record) })
	if b.mustSwitch then
		b.mustSwitch = false
		return send(b, "update", log)
	end
	if wildTurn(b, log) then
		return allyFainted(b, log)
	end
	afterTurn(b, log)
end

-- PvP --------------------------------------------------------------------------
local A_MARK, B_MARK = "\u{E000}", "\u{E001}"
local PvP = GameData.PvP
local lastPvPReward = {} -- ["id1:id2"] = os.clock()

-- The log as player 1 (flip = false) or player 2 (flip = true) should see it
local function viewLog(log, flip: boolean)
	local out = {}
	for _, e in log do
		local text = (flip and e.text2) or e.text or ""
		text = text:gsub(A_MARK, flip and "Foe " or ""):gsub(B_MARK, flip and "" or "Foe ")
		local fx = e.fx
		if fx and flip and fx.side then
			fx = table.clone(fx)
			fx.side = fx.side == "ally" and "wild" or "ally"
		end
		table.insert(out, { text = text, fx = fx })
	end
	return out
end

local function pvpCopy(player: Player)
	local list = {}
	for _, r in BaseManager.getTeam(player) do
		local c = {
			id = r.id, name = r.name, level = r.level, shiny = r.shiny, sizeClass = r.sizeClass,
			moves = r.moves and table.clone(r.moves) or nil, held = r.held,
			ivs = r.ivs and table.clone(r.ivs) or nil, stars = r.stars,
		}
		c.hp = statsOf(c).maxHP
		table.insert(list, c)
	end
	return list
end

local function copyHealthy(b)
	for _, c in b.pvpTeam do
		if c.hp > 0 then
			return c
		end
	end
	return nil
end

-- Keep both points of view pointing at the same creatures, models and stat stages
local function relink(m)
	local b1, b2 = m.sides[1], m.sides[2]
	b1.wild, b2.wild = b2.ally, b1.ally
	b1.model, b2.model = b2.allyModel, b1.allyModel
	b1.stages = { ally = m.stages[1], wild = m.stages[2] }
	b2.stages = { ally = m.stages[2], wild = m.stages[1] }
end

local function sendBoth(m, kind: string, log)
	send(m.sides[1], kind, viewLog(log, false))
	send(m.sides[2], kind, viewLog(log, true))
end

-- Log entry for side i sending out a creature (written from player 1's view, with player 2's text)
local function sendOutEntry(m, i: number, rec)
	local b = m.sides[i]
	local mine = ("Go, %s!"):format(rec.name)
	local theirs = ("%s sent out %s!"):format(b.player.DisplayName, rec.name)
	return {
		text = i == 1 and mine or theirs,
		text2 = i == 2 and mine or theirs,
		fx = { type = "sendout", side = i == 1 and "ally" or "wild", model = b.allyModel, creature = snapshot(rec) },
	}
end

local function pvpSwitch(m, i: number, rec, log)
	local b = m.sides[i]
	b.ally = rec
	m.stages[i] = newStages()
	placeAlly(b)
	relink(m)
	table.insert(log, sendOutEntry(m, i, rec))
end

local pvpStartTurn -- forward declaration

local function pvpEnd(m, winner: number, reason: string, log)
	if m.over then
		return
	end
	m.over = true
	log = log or {}
	local w, l = m.sides[winner], m.sides[3 - winner]
	local views = { [1] = viewLog(log, false), [2] = viewLog(log, true) }
	local wLog, lLog = views[winner], views[3 - winner]
	if reason == "forfeit" then
		table.insert(wLog, { text = ("%s forfeited the battle!"):format(l.player.DisplayName) })
		table.insert(lLog, { text = "You forfeited the battle." })
	elseif reason == "left" then
		table.insert(wLog, { text = ("%s left the battle."):format(l.player.DisplayName) })
	end
	table.insert(wLog, { text = ("You defeated %s!"):format(l.player.DisplayName) })
	table.insert(lLog, { text = ("%s won the battle!"):format(w.player.DisplayName) })

	-- rewards, once per pair of players per cooldown (stops win-trading for coins)
	local ids = { w.player.UserId, l.player.UserId }
	table.sort(ids)
	local pairKey = ids[1] .. ":" .. ids[2]
	if reason ~= "left" and (not lastPvPReward[pairKey] or os.clock() - lastPvPReward[pairKey] > PvP.rewardCooldown) then
		lastPvPReward[pairKey] = os.clock()
		giveReward(w, wLog, PvP.winCoins, PvP.winXP)
		giveReward(l, lLog, PvP.loseCoins, PvP.loseXP)
		-- Coliseum Battle Points (forfeits only reward the winner)
		local C = GameData.Coliseum
		local wBP = PlayerData.addBP(w.player, C.winBP)
		table.insert(wLog, { text = ("You earned %d Battle Points!"):format(wBP), fx = { type = "reward" } })
		if reason ~= "forfeit" then
			local lBP = PlayerData.addBP(l.player, C.loseBP)
			table.insert(lLog, { text = ("You earned %d Battle Points for a good fight."):format(lBP) })
		end
	elseif reason ~= "left" then
		table.insert(wLog, { text = "(No rewards: you battled this player recently.)" })
	end

	for i, b in m.sides do
		b.waiting = false
		b.mustSwitch = false
		if b.player.Parent then
			finish(b, i == winner and "won" or "lost", i == winner and wLog or lLog)
		else
			finish(b, "ended", {})
		end
	end
end

-- After moves: handle fainting, then start the next turn
local function pvpAfter(m, log, fainted)
	for i = 1, 2 do
		if fainted[i] then
			if copyHealthy(m.sides[i]) then
				m.sides[i].mustSwitch = true
			else
				return pvpEnd(m, 3 - i, "ko", log)
			end
		end
	end
	m.needSwitch = m.sides[1].mustSwitch or m.sides[2].mustSwitch
	for _, b in m.sides do
		b.waiting = m.needSwitch and not b.mustSwitch
	end
	sendBoth(m, "update", log)
	pvpStartTurn(m)
end

local function pvpResolve(m)
	local b1 = m.sides[1]
	local choices = m.choices
	m.choices = {}
	local log = {}

	if m.needSwitch then
		-- only the side(s) whose creature fainted pick a replacement; nobody attacks
		for i, b in m.sides do
			if b.mustSwitch and choices[i] then
				b.mustSwitch = false
				pvpSwitch(m, i, choices[i].rec, log)
			end
		end
		m.needSwitch = false
		for _, b in m.sides do
			b.waiting = false
		end
		sendBoth(m, "update", log)
		return pvpStartTurn(m)
	end

	-- switches happen before moves
	for i = 1, 2 do
		if choices[i].kind == "switch" then
			pvpSwitch(m, i, choices[i].rec, log)
		end
	end
	local order = {}
	for i = 1, 2 do
		if choices[i].kind == "fight" then
			local b = m.sides[i]
			local spd = speedOf(b.ally, m.stages[i].spd)
			table.insert(order, { side = i, spd = spd, tie = rng:NextNumber(), move = choices[i].move })
		end
	end
	table.sort(order, function(x, y)
		if x.spd == y.spd then
			return x.tie < y.tie
		end
		return x.spd > y.spd
	end)
	local fainted = {}
	for _, o in order do
		if not fainted[o.side] then
			-- everything runs from player 1's point of view: side 1 = "ally", side 2 = "wild"
			if useMove(b1, log, o.side == 1 and "ally" or "wild", o.move) then
				fainted[3 - o.side] = true
			end
		end
	end
	-- burn / poison at the end of the turn
	for i = 1, 2 do
		if not fainted[i] and residual(b1, log, i == 1 and "ally" or "wild") then
			fainted[i] = true
		end
	end
	pvpAfter(m, log, fainted)
end

-- Store a player's choice; resolve once everyone who needs to has chosen
local function pvpChoose(m, i: number, choice)
	if m.over or m.choices[i] then
		return
	end
	local b = m.sides[i]
	if m.needSwitch and not b.mustSwitch then
		return
	end
	m.choices[i] = choice
	local waitingOn = nil
	for j, other in m.sides do
		local needed = (not m.needSwitch) or other.mustSwitch
		if needed and not m.choices[j] then
			waitingOn = other
		end
	end
	if waitingOn then
		b.waiting = true
		send(b, "update", { { text = ("Waiting for %s..."):format(waitingOn.player.DisplayName) } })
		return
	end
	pvpResolve(m)
end

-- Default choice when the timer runs out
local function autoChoice(b)
	if b.mustSwitch then
		local c = copyHealthy(b)
		return c and { kind = "switch", rec = c }
	end
	return { kind = "fight", move = movesFor(b.ally)[1] }
end

function pvpStartTurn(m)
	m.turnId += 1
	local id = m.turnId
	task.delay(PvP.turnSeconds, function()
		if m.over or m.turnId ~= id then
			return
		end
		for i, b in m.sides do
			if not m.choices[i] and ((not m.needSwitch) or b.mustSwitch) then
				local c = autoChoice(b)
				if c then
					pcall(pvpChoose, m, i, c)
				end
			end
		end
	end)
end

local function pvpAbort(m)
	if m.over then
		return
	end
	m.over = true
	for _, b in m.sides do
		finish(b, "ended", { { text = "The battle ended unexpectedly." } })
	end
end

local function pvpAction(b, action: string, arg)
	local m = b.pvp
	if m.over then
		return
	end
	if action == "run" then
		return pvpEnd(m, 3 - b.side, "forfeit")
	end
	local choice
	if action == "fight" and typeof(arg) == "string" and not b.mustSwitch and table.find(movesFor(b.ally), arg) then
		choice = { kind = "fight", move = arg }
	elseif action == "switch" and typeof(arg) == "number" then
		for _, c in b.pvpTeam do
			if c.id == arg and c.hp > 0 and c ~= b.ally then
				choice = { kind = "switch", rec = c }
			end
		end
	end
	if not choice then
		return send(b, "update", {})
	end
	pvpChoose(m, b.side, choice)
end

-- Start a real-time battle between two players. Returns ok, reason.
function BattleService.startPvP(p1: Player, p2: Player): (boolean, string?)
	local ready1 = { BattleService._ready(p1) }
	local ready2 = { BattleService._ready(p2) }
	if not ready1[1] or not ready2[1] then
		return false, "One of you can't battle right now."
	end
	if #BaseManager.getTeam(p1) == 0 or #BaseManager.getTeam(p2) == 0 then
		return false, "Both players need at least one creature."
	end
	local m = { sides = {}, stages = { newStages(), newStages() }, choices = {}, turnId = 0 }
	local arenaIndex, center = ArenaManager.acquire()
	local look = Vector3.new(1, 0, 0)
	local players = { p1, p2 }
	for i, p in players do
		local other = players[3 - i]
		local team = pvpCopy(p)
		m.sides[i] = {
			player = p,
			character = (i == 1 and ready1 or ready2)[1],
			isTrainer = true,
			trainer = { name = other.DisplayName, kind = "pvp", team = BaseManager.getTeam(other), opponent = other },
			trainerIndex = 1,
			returnCFrame = (i == 1 and ready1 or ready2)[1]:GetPivot(),
			ally = team[1],
			pvpTeam = team,
			pvp = m,
			side = i,
			oldModels = {},
		}
	end
	local b1, b2 = m.sides[1], m.sides[2]
	b1.arenaIndex = arenaIndex
	setupField(b1, ready1[1], ready1[2], ready1[3], { center = center, look = look })
	setupField(b2, ready2[1], ready2[2], ready2[3], { center = center, look = -look })
	local function spot(b)
		return b.origin + b.look * 5 - b.right * 1 -- same spot placeAlly uses
	end
	b1.wildSpot, b2.wildSpot = spot(b2), spot(b1)
	placeAlly(b1)
	placeAlly(b2)
	relink(m)
	for _, b in m.sides do
		battles[b.player] = b
		b.player:SetAttribute("BattleKind", "boss")
		local humanoid = b.character:FindFirstChildOfClass("Humanoid")
		b.diedConn = humanoid.Died:Connect(function()
			pvpEnd(m, 3 - b.side, "left")
		end)
	end

	local log = {
		{ text = ("Battle against %s!"):format(p2.DisplayName), text2 = ("Battle against %s!"):format(p1.DisplayName) },
		sendOutEntry(m, 2, b2.ally),
		sendOutEntry(m, 1, b1.ally),
		{ text = ("You have %d seconds to choose each turn."):format(PvP.turnSeconds) },
	}
	sendBoth(m, "start", log)
	pvpStartTurn(m)
	return true
end

BattleAction.OnServerEvent:Connect(function(player, action, arg)
	if action == "done" then
		local p = pending[player]
		if p then
			release(p)
		end
		return
	end
	local b = battles[player]
	if not b or b.busy then
		return
	end
	if b.pvp then
		local m = b.pvp
		local ok, err = pcall(pvpAction, b, action, arg)
		if not ok then
			warn("PvP error:", err)
			pvpAbort(m)
		end
		return
	end
	if b.mustSwitch and action ~= "switch" then
		return
	end
	b.busy = true
	local log = {}
	-- count turns (the Quick Ball only gets its bonus on the first one)
	if action == "fight" or action == "catch" or action == "item" or action == "switch" then
		b.turn = (b.turn or 0) + 1
	end
	local ok, err = pcall(function()
		if action == "fight" and typeof(arg) == "string" then
			doFight(b, arg, log)
		elseif action == "catch" then
			doCatch(b, log, arg)
		elseif action == "item" then
			doItem(b, arg, log)
		elseif action == "switch" and typeof(arg) == "number" then
			doSwitch(b, arg, log)
		elseif action == "run" and b.noRun then
			send(b, "update", { { text = "You can't run from this battle!" } })
		elseif action == "run" then
			finish(b, "ran", { { text = b.isTrainer and "You forfeited the battle." or "You got away safely!" } })
		else
			send(b, "update", log)
		end
	end)
	if not ok then
		warn("Battle error:", err)
		finish(b, "ended", { { text = "The battle ended unexpectedly." } })
	end
	b.busy = false
end)

function BattleService.isInBattle(player: Player): boolean
	return battles[player] ~= nil or pending[player] ~= nil
end

-- Read-only view of a live PvP battle for the Coliseum's watch list. Other battles aren't public.
function BattleService.getPublicBattle(player: Player)
	local b = battles[player]
	if not b or not b.pvp then
		return nil
	end
	local other = b.trainer.opponent
	return {
		player = player.DisplayName,
		opponent = other.DisplayName,
		opponentId = other.UserId,
		ally = snapshot(b.ally),
		wild = snapshot(b.wild),
	}
end

-- Shared checks before any battle. Returns character, hrp, humanoid, lead creature (or nil).
local function ready(player: Player)
	if battles[player] or pending[player] or player:GetAttribute("Trading") then
		return nil
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	if not BaseManager.getBase(player) then
		Notify:FireClient(player, "You need a base before you can battle.", "fail")
		return nil
	end
	return character, hrp, humanoid
end
BattleService._ready = ready

function BattleService.start(player: Player, model: Model)
	if not model.Parent or model:GetAttribute("InBattle") or model:GetAttribute("Caught") then
		return
	end
	local owner = model:GetAttribute("TutorialOwner")
	if owner and owner ~= player.UserId then
		return
	end
	-- regions are gated by badges; the gate is client-side, so check here too
	local lane = model:GetAttribute("Lane")
	if lane and not GameData.canEnter(lane, player:GetAttribute("Badges") or 0, (player:GetAttribute("Stat_leagueWins") or 0) > 0) then
		return
	end
	local character, hrp, humanoid = ready(player)
	if not character then
		return
	end

	local name = model:GetAttribute("CreatureName")
	local level = model:GetAttribute("Level") or 5
	local shiny = model:GetAttribute("Shiny") == true
	local sizeClass = model:GetAttribute("SizeClass") or "Normal"

	-- No partner yet: Professor Maple gives everyone their first creature
	if #BaseManager.getTeam(player) == 0 then
		Notify:FireClient(player, ("You need a partner first! Visit %s at the lab in the hub."):format(GameData.ProfessorName), "fail")
		return
	end

	local lead = BaseManager.firstHealthy(player)
	if not lead then
		Notify:FireClient(player, "All your creatures have fainted! Heal them at the Healing Center.", "fail")
		return
	end

	model:SetAttribute("InBattle", true)
	local prompt = model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	Wander.remove(model)
	setTag(model, false)
	local body = model.PrimaryPart
	local offset = model:GetAttribute("GroundOffset") or 1
	local groundY = body.Position.Y - offset

	local b = {
		player = player,
		character = character,
		model = model,
		home = Vector3.new(body.Position.X, groundY, body.Position.Z),
		groundY = groundY,
		roam = model:GetAttribute("TutorialOwner") and 3 or 6,
		returnCFrame = character:GetPivot(),
		wild = (function()
			local ivs = BattleData.rollIVs(rng)
			return { name = name, level = level, ivs = ivs, hp = BattleData.stats(name, level, sizeClass, ivs).maxHP, shiny = shiny, sizeClass = sizeClass }
		end)(),
		ally = lead,
		stages = { ally = newStages(), wild = newStages() },
		tutorial = model:GetAttribute("Tutorial") == "nibbit",
		noRun = model:GetAttribute("Tutorial") == "nibbit",
		oldModels = {},
	}
	setupField(b, character, hrp, humanoid, nil)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- must reach the client before the battle message
	player:SetAttribute("BattleKind", "wild") -- picks the battle music
	local wildY = groundAt(b, b.wildSpot) + offset
	local wildPos = Vector3.new(b.wildSpot.X, wildY, b.wildSpot.Z)
	model:PivotTo(CFrame.lookAt(wildPos, Vector3.new(b.origin.X, wildY, b.origin.Z)))
	placeAlly(b)

	battles[player] = b
	b.diedConn = humanoid.Died:Connect(function()
		finish(b, "ended", {})
	end)

	local log = {}
	say(log, ("A wild %s%s (Lv %d) appeared!"):format(shiny and "SHINY " or "", name, level))
	say(log, ("Go, %s!"):format(lead.name), { type = "sendout", side = "ally", model = b.allyModel, creature = snapshot(lead) })
	send(b, "start", log)
end

--[[
	def = {
		name = "Gym Leader Slate", team = { { "Pebblit", 9 }, ... },
		reward = { coins = 300, xp = 300 }, intro = "text", kind = "gym"|"dungeon", ...anything else,
		place = { center = Vector3 (ground level), look = Vector3 (unit, toward the opponent) } -- optional
	}
	Returns true if the battle started.
]]
function BattleService.startTrainer(player: Player, def): boolean
	local character, hrp, humanoid = ready(player)
	if not character then
		return false
	end
	local lead = BaseManager.firstHealthy(player)
	if not lead then
		Notify:FireClient(player, "Your creatures need healing before you can battle!", "fail")
		return false
	end

	local first = def.team[1]
	local b = {
		player = player,
		character = character,
		isTrainer = true,
		trainer = def,
		trainerIndex = 1,
		returnCFrame = character:GetPivot(),
		wild = makeCreature(first[1], first[2], first[3]),
		ally = lead,
		stages = { ally = newStages(), wild = newStages() },
		noRun = def.noRun == true,
		oldModels = {},
	}
	setupField(b, character, hrp, humanoid, def.place)
	player:SetAttribute("BattleKind", (def.boss or def.kind == "gym") and "boss" or "trainer")
	placeTrainerCreature(b)
	placeAlly(b)

	battles[player] = b
	b.diedConn = humanoid.Died:Connect(function()
		finish(b, "ended", {})
	end)

	local log = {}
	say(log, def.intro or ("%s wants to battle!"):format(def.name))
	say(log, ("%s sent out %s!"):format(def.name, b.wild.name), { type = "sendout", side = "wild", model = b.model, creature = snapshot(b.wild) })
	say(log, ("Go, %s!"):format(lead.name), { type = "sendout", side = "ally", model = b.allyModel, creature = snapshot(lead) })
	send(b, "start", log)
	return true
end

Players.PlayerRemoving:Connect(function(player)
	local b = battles[player]
	if b and b.pvp then
		pvpEnd(b.pvp, 3 - b.side, "left")
	elseif b then
		finish(b, "ended", {})
	end
	local p = pending[player]
	if p then
		release(p)
	end
end)

return BattleService
