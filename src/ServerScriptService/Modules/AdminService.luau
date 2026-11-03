--[[
	AdminService: owner-only test tools (the ADMIN panel, or press F2).
	Who counts as an admin: the game's owner (game.CreatorId), anyone in ADMINS below, and anyone
	playing in Studio. Every command is checked here on the server, so nobody else can use them.

	Admin sessions do NOT save by default (player attribute NoSave), so stress-testing can't wreck
	a real save or the global leaderboards. The panel's "Saving" toggle turns saving back on.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local BattleData = require(ReplicatedStorage.Shared.BattleData)
local BaseManager = require(script.Parent.BaseManager)
local PlayerData = require(script.Parent.PlayerData)
local BattleService = require(script.Parent.BattleService)
local WildSpawner = require(script.Parent.WildSpawner)
local RareEventService = require(script.Parent.RareEventService)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")
local AdminRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Admin")

local AdminService = {}

-- extra admins by UserId (the owner is always an admin)
local ADMINS = {
	[1170990981] = true, -- LilDiesel468 (owner)
}

function AdminService.isAdmin(player: Player): boolean
	if RunService:IsStudio() or ADMINS[player.UserId] then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- the strongest species by total base stats (starters and legendaries included)
local function strongest(count: number)
	local list = {}
	for name, sp in BattleData.Species do
		if GameData.Creatures[name] then
			table.insert(list, { name = name, total = sp.hp + sp.atk + sp.def + sp.spd })
		end
	end
	table.sort(list, function(a, b)
		return a.total > b.total
	end)
	local out = {}
	for i = 1, math.min(count, #list) do
		table.insert(out, list[i].name)
	end
	return out
end

local function give(player: Player, name: string, level: number, shiny: boolean?, size: string?)
	local record = BaseManager.newRecord(name, level, nil, shiny, size or "Normal")
	local ok = BaseManager.addCreature(player, record, { force = true })
	return ok
end

-- region entrances and other places to jump to
local function spots()
	local list = {}
	for _, r in GameData.Regions do
		local lane = workspace.Map.Lanes:FindFirstChild(r.lane)
		if lane then
			table.insert(list, { name = r.name, pos = Vector3.new(lane.Position.X, 6, lane.Position.Z - lane.Size.Z / 2 + 12) })
			local gym = workspace.Map:FindFirstChild(GameData.GymLeaders[r.gym].model)
			if gym and gym:FindFirstChild("Door") then
				table.insert(list, { name = r.name .. " gym", pos = gym.Door.Position + Vector3.new(0, 1, -16) })
			end
		end
	end
	table.insert(list, { name = "Hub", pos = Vector3.new(0, 4, -100) })
	table.insert(list, { name = GameData.VictoryRoads.League, pos = Vector3.new(0, 5, 4440) })
	table.insert(list, { name = "Creature League", pos = Vector3.new(0, 5, 4590) })
	table.insert(list, { name = GameData.VictoryRoads.League2, pos = Vector3.new(460, 5, 4486) })
	table.insert(list, { name = "Summit Town", pos = Vector3.new(460, 5, 250) })
	table.insert(list, { name = "Region 2 League", pos = Vector3.new(460, 5, 4637) })
	return list
end

local commands = {}

function commands.opTeam(player)
	local names = strongest(6)
	for _, n in names do
		give(player, n, 100, true, "Huge")
	end
	return true, "Added a Lv 100 shiny Huge team: " .. table.concat(names, ", ")
end

function commands.give(player, args)
	local name = typeof(args.name) == "string" and args.name or ""
	-- case-insensitive match
	local found
	for n in GameData.Creatures do
		if n:lower() == name:lower() then
			found = n
		end
	end
	if not found then
		return false, ("No creature called '%s'."):format(name)
	end
	local level = math.clamp(math.floor(tonumber(args.level) or 50), 1, 100)
	local size = table.find({ "Tiny", "Small", "Normal", "Large", "Huge" }, args.size) and args.size or "Normal"
	give(player, found, level, args.shiny == true, size)
	return true, ("Added %s%s Lv %d (%s)."):format(args.shiny and "Shiny " or "", found, level, size)
end

function commands.maxTeam(player)
	for _, r in BaseManager.getTeam(player) do
		r.level = 100
		r.xp = math.max(r.xp or 0, BattleData.xpForLevel(100))
		BattleData.applyStars(r)
		r.hp = BattleData.stats(r.name, 100, r.sizeClass, r.ivs).maxHP
	end
	BaseManager.refresh(player)
	return true, "Your whole team is now Lv 100 with Star 1 (they'll evolve after your next battle)."
end

function commands.bp(player)
	local d = PlayerData.get(player)
	if d then
		d.stats.bp = (d.stats.bp or 0) + 1000
		PlayerData.sync(player)
	end
	return true, "+1000 Battle Points."
end

-- push every Lv 100 creature to its next star
function commands.addStar(player)
	local n = 0
	for _, r in BaseManager.getTeam(player) do
		if r.level >= 100 and (r.stars or 0) < BattleData.MaxStars then
			r.xp = BattleData.xpForLevel(100) + BattleData.StarXP[(r.stars or 0) + 1]
			BattleData.applyStars(r)
			r.hp = BattleData.stats(r.name, r.level, r.sizeClass, r.ivs).maxHP
			n += 1
		end
	end
	BaseManager.refresh(player)
	return true, ("%d creature(s) earned a star. Lv 100 creatures only."):format(n)
end

-- every creature down to 1 HP (to test fainting / the Healing Center warp)
function commands.weakTeam(player)
	for _, r in BaseManager.getTeam(player) do
		r.hp = 1
	end
	BaseManager.refresh(player)
	return true, "Your whole team is at 1 HP."
end

function commands.heal(player)
	BaseManager.healAll(player)
	return true, "Team healed."
end

function commands.coins(player)
	PlayerData.addCoins(player, 1000000)
	return true, "+1,000,000 coins."
end

function commands.items(player)
	for id, ball in GameData.Balls do
		if not ball.unlimited then
			PlayerData.addItem(player, id, 99)
		end
	end
	for id in GameData.Items do
		PlayerData.addItem(player, id, 99)
	end
	return true, "99 of every ball, potion, revive and Skill Disc."
end

function commands.badges(player)
	for _, leader in GameData.GymLeaders do
		if not leader.region and not PlayerData.hasBadge(player, leader.badge) then
			PlayerData.addBadge(player, leader.badge)
		end
	end
	return true, "All 8 badges. Every region is open."
end

function commands.capacity(player)
	player:SetAttribute("TeamCapacity", 60)
	return true, "Team capacity raised to 60 for this session."
end

function commands.finishTutorial(player)
	-- skipping with no creatures would leave you stuck: hand out the first starter
	if #BaseManager.getTeam(player) == 0 then
		local first = GameData.Starters[1]
		give(player, first.name, GameData.StarterLevel)
		player:SetAttribute("StarterName", first.name)
	end
	player:SetAttribute("TutorialStep", "done")
	local f = workspace:FindFirstChild("TutorialCreatures")
	if f then
		for _, m in f:GetChildren() do
			if m:GetAttribute("TutorialOwner") == player.UserId then
				m:Destroy()
			end
		end
	end
	return true, "Tutorial skipped."
end

-- start over as a brand-new player (team emptied, tutorial from the very first step). Saving stays off.
function commands.newPlayer(player)
	if BattleService.isInBattle(player) then
		return false, "Finish your battle first."
	end
	local ids = {}
	for _, r in BaseManager.getTeam(player) do
		table.insert(ids, r.id)
	end
	for _, id in ids do
		BaseManager.removeCreature(player, id)
	end
	local f = workspace:FindFirstChild("TutorialCreatures")
	if f then
		for _, m in f:GetChildren() do
			if m:GetAttribute("TutorialOwner") == player.UserId then
				m:Destroy()
			end
		end
	end
	-- wipe progress too, so a test run matches a real first session
	local d = PlayerData.get(player)
	if d then
		d.coins, d.xp, d.level = 0, 0, 1
		d.items = { LoopBall = -1 }
		d.badges = {}
		d.beatenTrainers = {}
		d.claimedRegions = {}
		for k in d.stats do
			d.stats[k] = 0
		end
		PlayerData.sync(player)
	end
	player:SetAttribute("LeagueStage", 1)
	player:SetAttribute("StarterName", nil)
	player:SetAttribute("TutorialStep", nil)
	require(script.Parent.TutorialService).start(player)
	local spawn = BaseManager.spawnCFrame(player)
	if spawn and player.Character then
		player.Character:PivotTo(spawn)
	end
	return true, "You're a new player again: team, coins, badges and items cleared, tutorial restarted. (Saving is off.)"
end

function commands.resetTrainers(player)
	local d = PlayerData.get(player)
	if d then
		d.beatenTrainers = {}
	end
	return true, "Every route trainer will battle you again."
end

function commands.beatTrainers(player)
	for _, t in GameData.RouteTrainers do
		PlayerData.markTrainerBeaten(player, t.id)
	end
	return true, "All route trainers marked as beaten."
end

function commands.towerTop(player)
	player:SetAttribute("DungeonFloor", #GameData.Dungeon.floors)
	return true, "Dark Tower progress set to the top floor."
end

function commands.rare(player)
	RareEventService.trigger()
	return true, "Rare spawn started."
end

-- start the weekly Rare Storm right now (10 minutes) to test it
function commands.storm(player)
	require(script.Parent.WeeklyEventService).startNow(10)
	return true, "Rare Storm started for 10 minutes."
end

-- stress test: lots of wild creatures right around you
function commands.swarm(player, args)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, "No character."
	end
	local count = math.clamp(math.floor(tonumber(args.count) or 50), 1, 200)
	local names = {}
	for n in GameData.Creatures do
		table.insert(names, n)
	end
	local rng = Random.new()
	for i = 1, count do
		local a = rng:NextNumber() * math.pi * 2
		local r = 8 + rng:NextNumber() * 30
		local pos = hrp.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		pcall(WildSpawner.spawnOne, names[rng:NextInteger(1, #names)], rng:NextInteger(5, 60), pos, { roam = 6 })
		if i % 20 == 0 then
			task.wait()
		end
	end
	return true, ("Spawned %d wild creatures around you."):format(count)
end

function commands.clearWild(player)
	WildSpawner.clear()
	return true, "Cleared distant wild creatures; nearby creatures and battles were protected. Empty spots refill automatically."
end

function commands.teleport(player, args)
	local char = player.Character
	if not char or BattleService.isInBattle(player) then
		return false, "Can't teleport right now."
	end
	for _, s in spots() do
		if s.name == args.spot then
			pcall(player.RequestStreamAroundAsync, player, s.pos, 4)
			char:PivotTo(CFrame.new(s.pos))
			return true, "Teleported to " .. s.name .. "."
		end
	end
	return false, "Unknown place."
end

function commands.saving(player, args)
	player:SetAttribute("AdminSave", args.on == true)
	player:SetAttribute("NoSave", args.on ~= true)
	return true, args.on and "Saving ON: admin changes will be saved to your account." or "Saving OFF: nothing from this session will be saved."
end

-- become the Champion instantly (to test Region 2)
function commands.champion(player)
	if (player:GetAttribute("Stat_leagueWins") or 0) < 1 then
		PlayerData.addStat(player, "leagueWins", 1)
	end
	return true, "You're the Champion now. Summit Town and Region 2 are open."
end

-- all 16 badges (Region 1 and Region 2)
function commands.allBadges(player)
	for _, leader in GameData.GymLeaders do
		if not PlayerData.hasBadge(player, leader.badge) then
			PlayerData.addBadge(player, leader.badge)
		end
	end
	return true, "All 16 badges."
end

-- make Juniper drop in right now (pool: nil, "caught", "wonTrainer" or "lost")
function commands.juniper(player, args)
	local StoryService = require(script.Parent.StoryService)
	local ok = StoryService.chat(player, typeof(args) == "table" and args.pool or nil, true)
	return ok, ok and "Juniper is on her way." or "She can't appear right now (finish the tutorial, heal once to meet her, and stay out of battles)."
end

function commands.info(player)
	local list = {}
	for _, s in spots() do
		table.insert(list, s.name)
	end
	local creatures = {}
	for _, n in GameData.IndexOrder do
		table.insert(creatures, n)
	end
	return true, { spots = list, creatures = creatures, saving = player:GetAttribute("AdminSave") == true }
end

function AdminService.init()
	local function mark(player)
		if AdminService.isAdmin(player) then
			player:SetAttribute("IsAdmin", true)
		end
	end
	Players.PlayerAdded:Connect(mark)
	for _, p in Players:GetPlayers() do
		mark(p)
	end
	AdminRemote.OnServerInvoke = function(player, cmd, args)
		if not AdminService.isAdmin(player) then
			return false, "Not allowed."
		end
		local fn = typeof(cmd) == "string" and commands[cmd]
		if not fn then
			return false, "Unknown command."
		end
		-- the first real command switches saving off unless the admin turned it on
		if cmd ~= "info" and cmd ~= "saving" and player:GetAttribute("AdminSave") ~= true then
			player:SetAttribute("NoSave", true)
		end
		local ok, a, b = pcall(fn, player, typeof(args) == "table" and args or {})
		if not ok then
			warn("Admin command failed:", cmd, a)
			return false, "Error: " .. tostring(a)
		end
		return a, b
	end
end

return AdminService
