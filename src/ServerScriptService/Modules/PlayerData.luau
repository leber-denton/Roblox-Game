--[[
	PlayerData: coins, trainer level/XP, badges and the Bag for each player.
	Everything is mirrored to player attributes so the client can show it:
	  Coins, TrainerLevel, TrainerXP, TrainerXPNext, Badges (count), BadgeList (JSON), Inventory (JSON, -1 = unlimited)
	Also: stats (caught, shinies, wildWins, pvpWins, towerBest) mirrored as attributes Stat_<name>,
	daily (streak + quests, run by DailyService) and claimedRegions (Creature Index rewards).
	Saved by SaveService through PlayerData.serialize / PlayerData.load.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local GameData = require(ReplicatedStorage.Shared.GameData)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local PlayerData = {}

local data = {} -- [Player] = { coins, xp, level, items = {}, badges = {} }

-- a real, finite number (rejects NaN and infinity, which would corrupt a save)
local function finite(n): boolean
	return typeof(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
PlayerData.finite = finite

local function sync(player: Player)
	local d = data[player]
	if not d then
		return
	end
	player:SetAttribute("Coins", d.coins)
	player:SetAttribute("TrainerLevel", d.level)
	player:SetAttribute("TrainerXP", d.xp)
	player:SetAttribute("TrainerXPNext", GameData.trainerXPToNext(d.level))
	player:SetAttribute("Badges", #d.badges)
	player:SetAttribute("BadgeList", HttpService:JSONEncode(d.badges))
	player:SetAttribute("Inventory", HttpService:JSONEncode(d.items))
	for k, v in d.stats do
		player:SetAttribute("Stat_" .. k, v)
	end
	player:SetAttribute("MusicMuted", d.settings.musicMuted == true)
	-- bought timed boosts (saved as the server time they end, so they survive a rejoin)
	if type(d.settings.boosts) == "table" then
		local now = workspace:GetServerTimeNow()
		for key, ends in d.settings.boosts do
			if type(ends) == "number" and ends > now then
				player:SetAttribute("Boost_" .. key, ends)
			else
				d.settings.boosts[key] = nil
			end
		end
	end
	player:SetAttribute("BeatenTrainers", HttpService:JSONEncode(d.beatenTrainers))
end
PlayerData.sync = sync

local function defaults()
	return {
		coins = 0,
		xp = 0,
		level = 1,
		items = { LoopBall = -1 },
		badges = {},
		stats = { caught = 0, shinies = 0, wildWins = 0, pvpWins = 0, towerBest = 0, likes = 0, bp = 0, bpEarned = 0 },
		daily = {},
		claimedRegions = {},
		settings = { musicMuted = false },
		beatenTrainers = {}, -- route trainer ids
	}
end

function PlayerData.init(player: Player)
	data[player] = defaults()
	sync(player)
end

-- Fill in saved values (anything missing keeps its default)
function PlayerData.load(player: Player, saved)
	local d = data[player]
	if not d or typeof(saved) ~= "table" then
		return
	end
	local function num(v, fallback)
		v = tonumber(v)
		return (v and finite(v)) and v or fallback
	end
	d.coins = math.max(0, num(saved.coins, d.coins))
	d.xp = math.max(0, num(saved.xp, d.xp))
	d.level = math.max(1, num(saved.level, d.level))
	if typeof(saved.items) == "table" then
		-- drop broken counts (anything that isn't a whole number)
		local clean = {}
		for id, n in saved.items do
			if typeof(id) == "string" and finite(n) and (n > 0 or n == -1) then
				clean[id] = math.floor(n)
			end
		end
		d.items = clean
		d.items.LoopBall = -1
	end
	if typeof(saved.badges) == "table" then
		d.badges = saved.badges
	end
	if typeof(saved.stats) == "table" then
		for k, v in saved.stats do
			d.stats[k] = num(v, 0)
		end
	end
	if typeof(saved.daily) == "table" then
		d.daily = saved.daily
	end
	if typeof(saved.claimedRegions) == "table" then
		d.claimedRegions = saved.claimedRegions
	end
	if typeof(saved.beatenTrainers) == "table" then
		d.beatenTrainers = saved.beatenTrainers
	end
	if typeof(saved.settings) == "table" then
		d.settings.musicMuted = saved.settings.musicMuted == true
		-- bought timed boosts (end times); before this they were saved but never loaded back
		if typeof(saved.settings.boosts) == "table" then
			d.settings.boosts = {}
			for key, ends in saved.settings.boosts do
				if typeof(key) == "string" and finite(ends) then
					d.settings.boosts[key] = ends
				end
			end
		end
		-- paid items not delivered yet (Instant Heal bought mid-battle, queued Summon Rare)
		if typeof(saved.settings.pending) == "table" then
			d.settings.pending = {}
			for key, v in saved.settings.pending do
				if typeof(key) == "string" and (v == true or (finite(v) and v > 0)) then
					d.settings.pending[key] = (v == true) and true or math.floor(v)
				end
			end
		end
	end
	sync(player)
end

function PlayerData.serialize(player: Player)
	local d = data[player]
	if not d then
		return nil
	end
	return {
		coins = d.coins, xp = d.xp, level = d.level, items = d.items, badges = d.badges,
		stats = d.stats, daily = d.daily, claimedRegions = d.claimedRegions, settings = d.settings, beatenTrainers = d.beatenTrainers,
	}
end

function PlayerData.hasBeatenTrainer(player: Player, id: string): boolean
	local d = data[player]
	return d ~= nil and table.find(d.beatenTrainers, id) ~= nil
end

function PlayerData.markTrainerBeaten(player: Player, id: string)
	local d = data[player]
	if d and not table.find(d.beatenTrainers, id) then
		table.insert(d.beatenTrainers, id)
		player:SetAttribute("BeatenTrainers", HttpService:JSONEncode(d.beatenTrainers))
	end
end

function PlayerData.setMusicMuted(player: Player, muted: boolean)
	local d = data[player]
	if d then
		d.settings.musicMuted = muted == true
		player:SetAttribute("MusicMuted", d.settings.musicMuted)
	end
end

function PlayerData.addStat(player: Player, name: string, amount: number?)
	local d = data[player]
	if not d then
		return
	end
	d.stats[name] = (d.stats[name] or 0) + (amount or 1)
	player:SetAttribute("Stat_" .. name, d.stats[name])
end

function PlayerData.setStatMax(player: Player, name: string, value: number)
	local d = data[player]
	if d and value > (d.stats[name] or 0) then
		d.stats[name] = value
		player:SetAttribute("Stat_" .. name, value)
	end
end

-- Timed boost from a developer product: adds minutes on top of any time already left. Returns the end time.
function PlayerData.addBoost(player: Player, key: string, minutes: number): number?
	local d = data[player]
	if not d or not finite(minutes) or minutes <= 0 then
		return nil
	end
	local now = workspace:GetServerTimeNow()
	d.settings.boosts = type(d.settings.boosts) == "table" and d.settings.boosts or {}
	local current = d.settings.boosts[key]
	local ends = ((type(current) == "number" and current > now) and current or now) + minutes * 60
	d.settings.boosts[key] = ends
	player:SetAttribute("Boost_" .. key, ends)
	return ends
end

-- Paid items owed to the player (saved, so they survive a disconnect or server shutdown).
-- Values: true or a positive count; nil clears it.
function PlayerData.getPending(player: Player, key: string)
	local d = data[player]
	return d and type(d.settings.pending) == "table" and d.settings.pending[key] or nil
end

function PlayerData.setPending(player: Player, key: string, value)
	local d = data[player]
	if not d then
		return
	end
	d.settings.pending = type(d.settings.pending) == "table" and d.settings.pending or {}
	if value == true or (finite(value) and value > 0) then
		d.settings.pending[key] = value
	else
		d.settings.pending[key] = nil
	end
end

function PlayerData.get(player: Player)
	return data[player]
end

-- Coins bought with Robux: never doubled by the 2x Coins pass
function PlayerData.addCoinsRaw(player: Player, amount: number)
	local d = data[player]
	if d and finite(amount) then
		d.coins += amount
		sync(player)
	end
end

function PlayerData.coins(player: Player): number
	return data[player] and data[player].coins or 0
end

function PlayerData.addCoins(player: Player, amount: number)
	local d = data[player]
	if not d or not finite(amount) or amount == 0 then
		return
	end
	if amount > 0 and GameData.hasBoost(player, "DoubleCoins") then
		amount *= 2
	end
	d.coins += amount
	sync(player)
end

-- Returns true if the player could afford it
function PlayerData.spend(player: Player, amount: number): boolean
	local d = data[player]
	if not d or not finite(amount) or amount < 0 or d.coins < amount then
		return false
	end
	d.coins -= amount
	sync(player)
	return true
end

-- Battle Points (Coliseum currency). Only earned by battling players; the 2x BP pass doubles it.
function PlayerData.addBP(player: Player, amount: number): number
	local d = data[player]
	if not d or not finite(amount) or amount <= 0 then
		return 0
	end
	amount = math.floor(amount)
	if GameData.hasBoost(player, "DoubleBP") then
		amount *= 2
	end
	d.stats.bp = (d.stats.bp or 0) + amount
	d.stats.bpEarned = (d.stats.bpEarned or 0) + amount
	sync(player)
	return amount
end

function PlayerData.spendBP(player: Player, amount: number): boolean
	local d = data[player]
	if not d or not finite(amount) or amount < 0 or (d.stats.bp or 0) < amount then
		return false
	end
	d.stats.bp -= amount
	sync(player)
	return true
end

-- Trainer XP. Levels up as many times as needed and announces it.
function PlayerData.addXP(player: Player, amount: number)
	local d = data[player]
	if not d or not finite(amount) or amount <= 0 then
		return
	end
	d.xp += amount
	local leveled = false
	while d.xp >= GameData.trainerXPToNext(d.level) do
		d.xp -= GameData.trainerXPToNext(d.level)
		d.level += 1
		leveled = true
	end
	sync(player)
	if leveled then
		Notify:FireClient(player, ("Trainer level up! You're now level %d."):format(d.level), "success")
	end
end

function PlayerData.addItem(player: Player, id: string, count: number)
	local d = data[player]
	if not d or typeof(id) ~= "string" or not finite(count) then
		return
	end
	count = math.floor(count)
	local current = d.items[id]
	if current == -1 then
		return -- already unlimited
	end
	d.items[id] = (current or 0) + count
	sync(player)
end

-- Use up one of an item. Returns false if they don't have it.
function PlayerData.takeItem(player: Player, id: string): boolean
	local d = data[player]
	local current = d and d.items[id]
	if not current or current == 0 or not finite(current) or (current < 0 and current ~= -1) then
		return false
	end
	if current > 0 then
		d.items[id] = current - 1
		if d.items[id] == 0 then
			d.items[id] = nil
		end
	end
	sync(player)
	return true
end

function PlayerData.hasBadge(player: Player, badge: string): boolean
	local d = data[player]
	return d ~= nil and table.find(d.badges, badge) ~= nil
end

function PlayerData.addBadge(player: Player, badge: string)
	local d = data[player]
	if d and not table.find(d.badges, badge) then
		table.insert(d.badges, badge)
		sync(player)
	end
end

-- Called by SaveService after the player's data has been saved
function PlayerData.remove(player: Player)
	data[player] = nil
end

return PlayerData
