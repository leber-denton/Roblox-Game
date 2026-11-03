--[[
	ProgressService: everything that rewards coming back and collecting.
	  - Daily login streak (GameData.DailyRewards). Days are UTC days. Missing a day resets the streak.
	  - Daily quests: GameData.QuestsPerDay picked from GameData.QuestPool, the same for everyone each day.
	    Rewards are paid automatically when a quest is completed.
	  - Stats (caught, shinies, wildWins, pvpWins, towerBest) for leaderboards.
	  - Creature Index region rewards (GameData.IndexRegions), paid once each.
	  - Evolution (GameData.Evolutions): checked after every battle, with a client animation.
	Client data: player attributes "Streak" and "Quests" (JSON list).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local GameData = require(ReplicatedStorage.Shared.GameData)
local PlayerData = require(script.Parent.PlayerData)
local BaseManager = require(script.Parent.BaseManager)
local BattleService = require(script.Parent.BattleService)
local SaveService = require(script.Parent.SaveService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local DailyRemote = Remotes:WaitForChild("Daily")
local EvolveRemote = Remotes:WaitForChild("Evolve")

local ProgressService = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

local questById = {}
for _, q in GameData.QuestPool do
	questById[q.id] = q
end

-- The same quests for everyone on a given day
local function questsFor(day: number)
	local pool = table.clone(GameData.QuestPool)
	local rng = Random.new(day * 7919)
	local picked, kinds = {}, {}
	while #picked < GameData.QuestsPerDay and #pool > 0 do
		local q = table.remove(pool, rng:NextInteger(1, #pool))
		-- avoid two quests of the same kind on one day
		if not kinds[q.kind] then
			kinds[q.kind] = true
			table.insert(picked, { id = q.id, progress = 0, done = false })
		end
	end
	return picked
end

local function syncQuests(player: Player)
	local d = PlayerData.get(player)
	if not d then
		return
	end
	local list = {}
	for _, entry in d.daily.quests or {} do
		local q = questById[entry.id]
		if q then
			table.insert(list, { id = q.id, text = q.text, goal = q.goal, progress = math.min(entry.progress, q.goal), done = entry.done, coins = q.coins, xp = q.xp })
		end
	end
	player:SetAttribute("Quests", HttpService:JSONEncode(list))
	player:SetAttribute("QuestDay", d.daily.questDay)
	player:SetAttribute("Streak", d.daily.streak or 0)
	player:SetAttribute("StreakDay", ((math.max(1, d.daily.streak or 1) - 1) % 7) + 1)
end

-- New day: streak reward + fresh quests
local function checkDay(player: Player)
	local d = PlayerData.get(player)
	if not d then
		return
	end
	local daily = d.daily
	local now = today()
	-- new players get their login reward once the tutorial is finished, not on top of it
	local tutorialDone = player:GetAttribute("TutorialStep") == "done"
	if daily.lastLogin ~= now and tutorialDone then
		if daily.lastLogin == now - 1 then
			daily.streak = (daily.streak or 0) + 1
		else
			daily.streak = 1
		end
		daily.lastLogin = now
		local rewards = GameData.DailyRewards
		local coins = rewards[math.min(daily.streak, #rewards)]
		PlayerData.addCoins(player, coins)
		local cycleDay = ((daily.streak - 1) % 7) + 1
		local apex = cycleDay == 7
		if apex then
			PlayerData.addItem(player, "ApexBall", 1)
		end
		DailyRemote:FireClient(player, "streak", { streak = daily.streak, coins = coins, rewards = rewards, cycleDay = cycleDay, apex = apex })
		SaveService.requestSave(player)

	end
	if daily.questDay ~= now then
		daily.questDay = now
		daily.quests = questsFor(now)
	end
	syncQuests(player)
end

function ProgressService.onJoin(player: Player)
	checkDay(player)
	if player:GetAttribute("TutorialStep") ~= "done" then
		local conn
		conn = player:GetAttributeChangedSignal("TutorialStep"):Connect(function()
			if player:GetAttribute("TutorialStep") == "done" then
				conn:Disconnect()
				-- after the "Tutorial complete!" banner
				task.wait(4)
				if player.Parent then
					checkDay(player)
				end
			end
		end)
	end
	-- a save from before index rewards existed may already qualify
	ProgressService.checkIndex(player, BaseManager.getIndex(player), true)
end

-- Count progress toward today's quests. info.types = creature types (for catchType)
function ProgressService.progress(player: Player, kind: string, amount: number?, info)
	local d = PlayerData.get(player)
	if not d or not d.daily.quests then
		return
	end
	local changed = false
	for _, entry in d.daily.quests do
		local q = questById[entry.id]
		if q and not entry.done and q.kind == kind then
			local counts = true
			if kind == "catchType" then
				counts = info and info.types and table.find(info.types, q.type) ~= nil
			end
			if counts then
				entry.progress += amount or 1
				changed = true
				if entry.progress >= q.goal then
					entry.done = true
					PlayerData.addCoins(player, q.coins)
					PlayerData.addXP(player, q.xp)
					task.delay(3, function()
						Notify:FireClient(player, ("Quest complete: %s! +%d coins, +%d XP"):format(q.text, q.coins, q.xp), "success")
					end)
				end
			end
		end
	end
	-- catchType quests also count as a catch, and vice versa, so check both kinds
	if kind == "catch" and info then
		ProgressService.progress(player, "catchType", amount, info)
	end
	if changed then
		syncQuests(player)
	end
end

-- Index region rewards
function ProgressService.checkIndex(player: Player, index, quiet: boolean?)
	local d = PlayerData.get(player)
	if not d then
		return
	end
	for _, region in GameData.IndexRegions do
		if not table.find(d.claimedRegions, region.id) then
			local complete = true
			for _, name in region.creatures do
				if not index[name] then
					complete = false
					break
				end
			end
			if complete then
				table.insert(d.claimedRegions, region.id)
				PlayerData.addCoins(player, region.coins)
				task.delay(quiet and 6 or 4, function()
					Notify:FireClient(player, ("%s Index complete! +%d coins"):format(region.name, region.coins), "success")
				end)
				if region.id == "All" then
					Notify:FireAllClients(("%s completed the entire Creature Index!"):format(player.DisplayName), "announce")
				end
			end
		end
	end
	player:SetAttribute("ClaimedRegions", HttpService:JSONEncode(d.claimedRegions))
end

-- Evolve one creature right now (evolution crystals). Plays the client animation.
function ProgressService.evolveNow(player: Player, record, into: string)
	local before = { name = record.name, shiny = record.shiny, sizeClass = record.sizeClass, level = record.level }
	local oldName = BaseManager.evolve(player, record, into)
	EvolveRemote:FireClient(player, before, { name = record.name, shiny = record.shiny, sizeClass = record.sizeClass, level = record.level })
	Notify:FireAllClients(("%s's %s evolved into %s!"):format(player.DisplayName, oldName, record.name), "info")
	SaveService.requestSave(player)
	return oldName
end

-- Evolve every team member that has reached its evolution level
local evolving = {}
function ProgressService.checkEvolutions(player: Player)
	if evolving[player] then
		return
	end
	evolving[player] = true
	for _, record in table.clone(BaseManager.getTeam(player)) do
		if not player.Parent or BattleService.isInBattle(player) then
			break
		end
		local evo = GameData.Evolutions[record.name]
		if evo and record.level >= evo.level then
			local before = { name = record.name, shiny = record.shiny, sizeClass = record.sizeClass, level = record.level }
			local oldName = BaseManager.evolve(player, record, evo.into)
			EvolveRemote:FireClient(player, before, { name = record.name, shiny = record.shiny, sizeClass = record.sizeClass, level = record.level })
			Notify:FireAllClients(("%s's %s evolved into %s!"):format(player.DisplayName, oldName, record.name), "info")
			SaveService.requestSave(player)
			task.wait(6.5) -- one animation at a time
		end
	end
	evolving[player] = nil
end

local function typesOf(name: string)
	local c = GameData.Creatures[name]
	return c and { c.type, c.type2 } or {}
end

function ProgressService.init()
	BaseManager.hooks.indexed = function(player, index)
		ProgressService.checkIndex(player, index)
	end

	BattleService.onEnded(function(player, b, result)
		if result == "caught" or result == "won" then
			SaveService.requestSave(player)
		end
		if result == "caught" then
			PlayerData.addStat(player, "caught")
			if b.wild.shiny then
				PlayerData.addStat(player, "shinies")
			end
			ProgressService.progress(player, "catch", 1, { types = typesOf(b.wild.name) })
		elseif result == "won" then
			local kind = b.isTrainer and b.trainer.kind
			if not b.isTrainer then
				PlayerData.addStat(player, "wildWins")
				ProgressService.progress(player, "winWild")
			elseif kind == "dungeon" then
				PlayerData.setStatMax(player, "towerBest", b.trainer.floor)
				ProgressService.progress(player, "towerFloor")
			elseif kind == "pvp" then
				PlayerData.addStat(player, "pvpWins")
				ProgressService.progress(player, "pvpWin")
			end
		end
	end)

	BattleService.onReleased(function(player, b)
		-- wait for dungeon lifts / defeat teleports to finish first
		task.wait(4)
		while player.Parent and (player:GetAttribute("Elevating") or BattleService.isInBattle(player)) do
			task.wait(0.5)
		end
		if player.Parent then
			ProgressService.checkEvolutions(player)
		end
	end)

	-- if someone stays online past midnight UTC, give them the new day
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				if PlayerData.get(player) then
					checkDay(player)
				end
			end
		end
	end)
end

return ProgressService
