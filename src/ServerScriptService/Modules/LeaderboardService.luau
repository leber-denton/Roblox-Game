--[[
	LeaderboardService:
	  - leaderstats (the player list): Level, Caught, Tower
	  - three boards in the hub (Map.Hub.Leaderboards): global top 10 for trainer level, creatures caught
	    and highest Dark Tower floor, from OrderedDataStores, refreshed every 5 minutes.
	    If DataStores aren't available (Studio without API access), the boards show this server only.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)

local LeaderboardService = {}

local REFRESH = 300
local boards = {
	{ key = "Level", attr = "TrainerLevel", store = "LB_Level_v1", board = "LevelBoard", fmt = function(v) return "Lv " .. v end },
	{ key = "Caught", attr = "Stat_caught", store = "LB_Caught_v1", board = "CaughtBoard", fmt = function(v) return tostring(v) end },
	{ key = "Tower", attr = "Stat_towerBest", store = "LB_Tower_v1", board = "TowerBoard", fmt = function(v)
		local f = GameData.Dungeon.floors[v]
		return f and ("Floor " .. f.label) or "-"
	end },
	{ key = "Likes", attr = "Stat_likes", store = "LB_Likes_v1", board = "LikesBoard", fmt = function(v) return v .. " ♥" end },
}

for _, b in boards do
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, b.store)
	b.ods = ok and store or nil
end

local names = {}
local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and name or ("Player " .. userId)
	return names[userId]
end

local function setupStats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, b in boards do
		local v = Instance.new("IntValue")
		v.Name = b.key
		v.Value = player:GetAttribute(b.attr) or 0
		v.Parent = ls
		player:GetAttributeChangedSignal(b.attr):Connect(function()
			v.Value = player:GetAttribute(b.attr) or 0
		end)
	end
	ls.Parent = player
end

local function draw(b, rows)
	local model = workspace.Map.Hub.Leaderboards:FindFirstChild(b.board)
	local gui = model and model.Board:FindFirstChild("Display")
	if not gui then
		return
	end
	for i = 1, 10 do
		local row = rows[i]
		local label = gui:FindFirstChild("Row" .. i)
		if label then
			label.Text = row and ("%d.  %s  -  %s"):format(i, row.name, b.fmt(row.value)) or (i == 1 and "No entries yet" or "")
		end
	end
end

-- Save online players' scores, then pull the top 10 for each board
function LeaderboardService.refresh()
	for _, b in boards do
		local rows
		if b.ods then
			for _, p in Players:GetPlayers() do
				local v = p:GetAttribute(b.attr)
				if typeof(v) == "number" and v > 0 and p:GetAttribute("SaveStatus") == "ok" and not p:GetAttribute("NoSave") then
					pcall(b.ods.SetAsync, b.ods, tostring(p.UserId), math.floor(v))
				end
			end
			local ok, pages = pcall(b.ods.GetSortedAsync, b.ods, false, 10)
			if ok then
				rows = {}
				for _, entry in pages:GetCurrentPage() do
					table.insert(rows, { name = nameOf(tonumber(entry.key)), value = entry.value })
				end
			end
		end
		if not rows then
			-- fallback: this server only
			rows = {}
			for _, p in Players:GetPlayers() do
				local v = p:GetAttribute(b.attr) or 0
				if v > 0 then
					table.insert(rows, { name = p.DisplayName, value = v })
				end
			end
			table.sort(rows, function(x, y)
				return x.value > y.value
			end)
		end
		draw(b, rows)
	end
end

function LeaderboardService.onJoin(player: Player)
	setupStats(player)
end

function LeaderboardService.init()
	task.spawn(function()
		task.wait(10)
		while true do
			LeaderboardService.refresh()
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardService
