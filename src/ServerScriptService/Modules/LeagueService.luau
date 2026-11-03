--[[
	LeagueService: the Elite Four and Champion of each region, in the hall at the end of that region's arm.
	  - Region 1 (GameData.League, Map.League): needs 8 badges. Beating it = Champion (stat leagueWins),
	    which opens the Region 2 arm.
	  - Region 2 (GameData.League2, Map.League2): needs 16 badges. Everything is Lv 100 with stars.
	    Beating it = Grand Champion (stat league2Wins).
	  - Challenge them in order: Elite 1, 2, 3, 4, then the Champion. Progress is the player attribute
	    "LeagueStage" / "League2Stage" (1-5) and only lasts for this run.
	  - No Healing Center during a run: healing, losing or running away sends you back to Elite 1.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local BattleService = require(script.Parent.BattleService)
local BaseManager = require(script.Parent.BaseManager)
local PlayerData = require(script.Parent.PlayerData)
local NPC = require(script.Parent.NPC)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local LeagueService = {}

local LEAGUES = {
	{ id = 1, data = GameData.League, folder = "League", stageAttr = "LeagueStage", stat = "leagueWins", title = "CHAMPION" },
	{ id = 2, data = GameData.League2, folder = "League2", stageAttr = "League2Stage", stat = "league2Wins", title = "GRAND CHAMPION" },
}
for _, L in LEAGUES do
	L.order = {}
	for _, m in L.data.members do
		table.insert(L.order, m)
	end
	table.insert(L.order, L.data.champion)
end

local busy = {}

local function stage(player: Player, L): number
	return player:GetAttribute(L.stageAttr) or 1
end

local function wins(player: Player, L): number
	local d = PlayerData.get(player)
	return d and (d.stats[L.stat] or 0) or 0
end

local function isChampion(player: Player): boolean
	return wins(player, LEAGUES[1]) > 0
end
LeagueService.isChampion = isChampion

local function reset(player: Player, why: string?)
	local any = false
	for _, L in LEAGUES do
		if stage(player, L) > 1 then
			player:SetAttribute(L.stageAttr, 1)
			any = true
		end
	end
	if any and why then
		Notify:FireClient(player, why, "fail")
	end
end
LeagueService.reset = reset

-- the final form of the starter that beats the player's starter
local function rivalAce(player: Player): string?
	local from = {}
	for base, evo in GameData.Evolutions do
		from[evo.into] = base
	end
	for _, record in BaseManager.getTeam(player) do
		local name = record.name
		while from[name] do
			name = from[name]
		end
		for _, s in GameData.Starters do
			if s.name == name then
				local ace = s.counter
				while GameData.Evolutions[ace] do
					ace = GameData.Evolutions[ace].into
				end
				return ace
			end
		end
	end
	return nil
end

local function teamFor(player: Player, L, i: number)
	local def = L.order[i]
	local team = table.clone(def.team)
	if def == L.data.champion then
		local ace = rivalAce(player)
		if ace then
			table.insert(team, { ace, def.starterLevel, def.starterStars })
		end
	end
	return team
end

local function challenge(player: Player, L, i: number, model: Model)
	local def = L.order[i]
	if busy[player] or BattleService.isInBattle(player) then
		return
	end
	if (player:GetAttribute("Badges") or 0) < L.data.badges then
		Notify:FireClient(player, ("You need all %d badges to challenge this League."):format(L.data.badges), "fail")
		return
	end
	-- Juniper is a real boss encounter in this run, before each region's Champion.
	local story = require(script.Parent.StoryService)
	if L.id == 1 and wins(player, L) == 0 and not story.hasCompleted(player, "reveal") then
		Notify:FireClient(player, "Finish Juniper's Story at " .. GameData.VictoryRoads.League .. " before your first League run. Open Journey → Story for the next objective.", "info")
		return
	end
	if L.id == 2 and i == #L.order and not story.hasCompleted(player, "final") then
		if not story.requestMilestone(player, "final") then
			Notify:FireClient(player, "Clear the three Havoc bases, then face Juniper before the Summit Champion. Open Journey → Story.", "info")
		end
		return
	end
	local s = stage(player, L)
	if i < s then
		NPC.say(model, "You've already beaten me this run. Keep going!", 3)
		return
	elseif i > s then
		NPC.say(model, ("Not so fast. You have to beat %s first."):format(L.order[s].name), 3)
		return
	end
	busy[player] = true
	local again = wins(player, L) > 0
	NPC.say(model, def.intro, 4)
	task.wait(2)
	if player.Parent then
		BattleService.startTrainer(player, {
			name = def.name, team = teamFor(player, L, i), kind = "league", leagueId = L.id, leagueIndex = i, boss = true,
			intro = ("%s wants to battle!"):format(def.name),
			reward = again and { coins = def.rematchCoins, xp = def.rematchXP } or { coins = def.coins, xp = def.xp },
		})
	end
	busy[player] = nil
end

local function itemList(rewards)
	local parts = {}
	for id, n in rewards do
		local item = GameData.Items[id]
		table.insert(parts, ("%d %s"):format(n, item and item.name or id))
	end
	return table.concat(parts, " and ")
end

local function setup(L)
	local folder = workspace.Map:FindFirstChild(L.folder)
	local members = folder and folder:FindFirstChild("Members")
	if not members then
		warn("LeagueService: missing hall", L.folder)
		return
	end
	for i, def in L.order do
		local model = members:FindFirstChild(def.npc)
		if model and model.PrimaryPart then
			local action = def == L.data.champion and "Challenge the Champion" or ("Challenge (%d/4)"):format(i)
			NPC.prompt(model.PrimaryPart, action, def.name, 14).Triggered:Connect(function(player)
				challenge(player, L, i, model)
			end)
			local tag = model:FindFirstChild("NameTag", true)
			if tag and tag:IsA("BillboardGui") then
				for _, t in tag:GetDescendants() do
					if t:IsA("TextLabel") and L.id == 2 then
						if t.Text:find("Elite") or t.Text:find("Champion") or t.Text:find("Kai") then
							t.Text = def.name
							break
						end
					end
				end
			end
		else
			warn("LeagueService: missing", L.folder, def.npc)
		end
	end
	L.members = members
end

function LeagueService.init()
	for _, L in LEAGUES do
		setup(L)
	end

	BattleService.onEnded(function(player, b, result)
		if not (b.isTrainer and b.trainer.kind == "league") then
			return
		end
		local L = LEAGUES[b.trainer.leagueId or 1]
		local i = b.trainer.leagueIndex
		local def = L.order[i]
		local model = L.members and L.members:FindFirstChild(def.npc)
		if result == "won" then
			if model then
				NPC.say(model, def.win, 5)
			end
			if i < #L.order then
				player:SetAttribute(L.stageAttr, i + 1)
				task.delay(4, function()
					Notify:FireClient(player, ("%s defeated! Next: %s."):format(def.name, L.order[i + 1].name), "success")
				end)
			else
				local first = wins(player, L) == 0
				PlayerData.addStat(player, L.stat, 1)
				player:SetAttribute(L.stageAttr, 1)
				if first then
					for id, n in L.data.champion.firstRewards do
						PlayerData.addItem(player, id, n)
					end
					Notify:FireAllClients(("%s defeated %s and became the new %s!"):format(player.DisplayName, L.data.champion.name, L.title), "announce")
				end
				task.delay(4, function()
					local msg
					if first and L.id == 1 then
						msg = ("You are the Champion! You got %s. Your level cap is now %d. Juniper has one more message before your next journey."):format(itemList(L.data.champion.firstRewards), GameData.ChampionCap)
					elseif first then
						msg = ("You are the Grand Champion! You got %s."):format(itemList(L.data.champion.firstRewards))
					else
						msg = "You defended your title! Rematch any time for more rewards."
					end
					Notify:FireClient(player, msg, "success")
				end)
			end
		elseif result == "lost" or result == "ran" then
			player:SetAttribute(L.stageAttr, 1)
			task.delay(3, function()
				Notify:FireClient(player, ("Your League run is over. Heal up and start again from %s."):format(L.order[1].name), "fail")
			end)
		end
	end)

	-- healing during a run starts it over
	local previous = BaseManager.hooks.healed
	BaseManager.hooks.healed = function(player)
		if previous then
			previous(player)
		end
		reset(player, "You healed your team, so your League run starts over from the first Elite.")
	end

	local function fresh(player)
		for _, L in LEAGUES do
			player:SetAttribute(L.stageAttr, 1)
		end
	end
	Players.PlayerAdded:Connect(fresh)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		fresh(player)
	end
end

return LeagueService
