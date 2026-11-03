--[[
	GymService: one gym leader at the end of every region (GameData.GymLeaders).
	First win: the gym's badge (+sprint speed, opens the next region), its Skill Disc, coins and trainer XP.
	Rematches give smaller rewards. A leader only battles players allowed into their region.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local BattleService = require(script.Parent.BattleService)
local PlayerData = require(script.Parent.PlayerData)
local NPC = require(script.Parent.NPC)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local GymService = {}

local function setup(key: string, leader)
	local gym = workspace.Map:FindFirstChild(leader.model)
	local npc = gym and gym:FindFirstChild(leader.npc)
	if not npc or not npc.PrimaryPart then
		warn("GymService: missing leader", key)
		return
	end
	local busy = {}
	NPC.prompt(npc.PrimaryPart, "Challenge", leader.name, 14).Triggered:Connect(function(player)
		if busy[player] or BattleService.isInBattle(player) then
			return
		end
		local need = GameData.badgesForLane(leader.lane)
		if not GameData.canEnter(leader.lane, player:GetAttribute("Badges") or 0, (player:GetAttribute("Stat_leagueWins") or 0) > 0) then
			Notify:FireClient(player, ("You need %d badges%s to challenge %s."):format(need, leader.region == 2 and " and the Champion title" or "", leader.name), "fail")
			return
		end
		busy[player] = true
		local beaten = PlayerData.hasBadge(player, leader.badge)
		NPC.say(npc, beaten and leader.rematch or leader.intro, 3)
		task.wait(1.5)
		BattleService.startTrainer(player, {
			name = leader.name, team = leader.team, kind = "gym", gym = key,
			intro = ("%s wants to battle!"):format(leader.name),
			reward = beaten and { coins = leader.rematchCoins, xp = leader.rematchXP } or { coins = leader.coins, xp = leader.xp },
		})
		busy[player] = nil
	end)

	BattleService.onEnded(function(player, b, result)
		if not (b.isTrainer and b.trainer.kind == "gym" and b.trainer.gym == key) or result ~= "won" then
			return
		end
		if not PlayerData.hasBadge(player, leader.badge) then
			PlayerData.addBadge(player, leader.badge)
			PlayerData.addItem(player, leader.item, 1)
			local disc = GameData.Items[leader.item] or GameData.Balls[leader.item]
			local count = player:GetAttribute("Badges") or 0
			-- which region did this open?
			local opened
			local champion = (player:GetAttribute("Stat_leagueWins") or 0) > 0
			for _, r in GameData.Regions do
				if r.badges == count and (not r.champion or champion) then
					opened = r.name
				end
			end
			if count == GameData.League.badges and not champion then
				opened = GameData.VictoryRoads.League .. " (the Creature League)"
			end
			task.delay(4, function()
				Notify:FireClient(player, ("You earned the %s and %s! Sprint speed increased."):format(leader.badge, disc and disc.name or leader.item), "success")
				if opened then
					Notify:FireClient(player, ("%s is now open!"):format(opened), "success")
				end
			end)
			Notify:FireAllClients(("%s earned the %s!"):format(player.DisplayName, leader.badge), "announce")
		end
		NPC.say(npc, leader.win, 4)
	end)
end

-- Keep the original gym keys/save badge IDs while moving the actual leaders.
local function placeLeaders()
    local map = workspace.Map
    local brook, tide = map:FindFirstChild("BrookGym"), map:FindFirstChild("TideGym")
    if not brook or not tide then return end
    local coralie, duna = brook:FindFirstChild("Coralie"), tide:FindFirstChild("Duna")
    if coralie and duna then
        local a, b = coralie:GetPivot(), duna:GetPivot()
        coralie.Parent = tide; coralie:PivotTo(b); coralie:SetAttribute("HomePos", b.Position)
        duna.Parent = brook; duna:PivotTo(a); duna:SetAttribute("HomePos", a.Position)
    end
    for _, entry in { { brook, "Coralie", "Duna", "Water", "Ground", "Ripple", "Dune" },
        { tide, "Duna", "Coralie", "Ground", "Water", "Dune", "Ripple" } } do
        if not entry[1]:GetAttribute("LeaderSwapApplied") then
            for _, obj in entry[1]:GetDescendants() do
                if obj:IsA("TextLabel") then
                    obj.Text = obj.Text:gsub(entry[2], entry[3]):gsub(entry[4], entry[5]):gsub(entry[6], entry[7])
                end
            end
            entry[1]:SetAttribute("LeaderSwapApplied", true)
        end
    end
end
GymService.applyWorldChanges = placeLeaders

function GymService.init()
	placeLeaders()
	for key, leader in GameData.GymLeaders do
		setup(key, leader)
	end
end

return GymService
