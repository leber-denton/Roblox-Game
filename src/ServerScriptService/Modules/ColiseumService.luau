--[[
	ColiseumService: the Battle Coliseum and the Trade Plaza, two themed areas behind portals in the hub.
	  - Portals: hub -> area (the Coliseum needs GameData.Coliseum.badges), exit portals bring you back.
	  - Zones: players inside an area get InColiseum / InPlaza (server-checked every second).
	  - Hold E on another trainer: "Battle" in the Coliseum, "Trade" in the Plaza (SocialService requests).
	  - Arena Master: spend Battle Points (BP) on Coliseum-only items (GameData.Coliseum.shop).
	BP is earned in BattleService (player battles) and kept in PlayerData (stats.bp).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local PlayerData = require(script.Parent.PlayerData)
local BattleService = require(script.Parent.BattleService)
local SocialService = require(script.Parent.SocialService)
local BaseManager = require(script.Parent.BaseManager)
local SaveService = require(script.Parent.SaveService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local ColiseumRemote = Remotes:WaitForChild("Coliseum")
local BuyRemote = Remotes:WaitForChild("ColiseumBuy")

local ColiseumService = {}

local map = workspace:WaitForChild("Map")
local AREAS = {
	coliseum = { folder = "Coliseum", radius = 112, attr = "InColiseum", kind = "battle" },
	plaza = { folder = "TradePlaza", radius = 90, attr = "InPlaza", kind = "trade" },
}

local function prompt(parent: Instance, action: string, object: string, dist: number?)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.3
	p.MaxActivationDistance = dist or 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function centerOf(area): Vector3?
	local f = map:FindFirstChild(area.folder)
	local ground = f and (f:FindFirstChild("ArenaFloor") or f:FindFirstChild("Sand"))
	return ground and ground.Position or nil
end

local function arriveCFrame(area): CFrame?
	local f = map:FindFirstChild(area.folder)
	local arrive = f and f:FindFirstChild("Arrive")
	local c = centerOf(area)
	if not arrive or not c then
		return nil
	end
	local p = arrive.Position + Vector3.new(0, 3, 0)
	return CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z))
end

local function busy(player: Player): boolean
	return BattleService.isInBattle(player) or player:GetAttribute("InDungeon") == true or player:GetAttribute("TutorialStep") ~= "done"
end

local function move(player: Player, cf: CFrame)
	local character = player.Character
	if not character or not character.Parent then
		return
	end
	pcall(player.RequestStreamAroundAsync, player, cf.Position, 4)
	character:PivotTo(cf)
end

local function hubCFrame(portalName: string): CFrame?
	local m = map.Hub:FindFirstChild(portalName)
	if not m or not m.PrimaryPart then
		return nil
	end
	local p = m.PrimaryPart.CFrame * CFrame.new(0, -2.4, -7)
	return CFrame.lookAt(p.Position, p.Position + m.PrimaryPart.CFrame.LookVector)
end

local function setupPortals()
	local cport = map.Hub:FindFirstChild("ColiseumPortal")
	if cport and cport.PrimaryPart then
		prompt(cport.PrimaryPart, "Enter", "Battle Coliseum").Triggered:Connect(function(player)
			if busy(player) then
				return
			end
			local need = GameData.Coliseum.badges
			if (player:GetAttribute("Badges") or 0) < need then
				Notify:FireClient(player, ("The Battle Coliseum opens after your first gym badge. Beat Gym Leader Slate at the end of the Meadow Route!"):format(need), "fail")
				return
			end
			local cf = arriveCFrame(AREAS.coliseum)
			if cf then
				move(player, cf)
				Notify:FireClient(player, "Welcome to the Battle Coliseum! Join the ranked queue, practice with the Arena Master, or watch a match.", "success")
			end
		end)
	end
	local tport = map.Hub:FindFirstChild("TradePortal")
	if tport and tport.PrimaryPart then
		prompt(tport.PrimaryPart, "Enter", "Trade Center").Triggered:Connect(function(player)
			if busy(player) then
				return
			end
			local cf = arriveCFrame(AREAS.plaza)
			if cf then
				move(player, cf)
				Notify:FireClient(player, "Welcome to the Trade Plaza! Meet at a booth, browse the Trade Board, or show a special creature.", "success")
			end
		end)
	end
	for key, area in AREAS do
		local f = map:FindFirstChild(area.folder)
		local exit = f and f:FindFirstChild("ExitPortal")
		if exit then
			exit.CanCollide = false
			prompt(exit, "Return to the hub", key == "coliseum" and "Battle Coliseum" or "Trade Center", 14).Triggered:Connect(function(player)
				if BattleService.isInBattle(player) then
					return
				end
				local cf = hubCFrame(key == "coliseum" and "ColiseumPortal" or "TradePortal")
				if cf then
					move(player, cf)
				end
			end)
		end
	end
end

-- Arena Master: open the BP shop
local function setupShop()
	local f = map:FindFirstChild("Coliseum")
	local npc = f and f:FindFirstChild("ArenaMaster")
	if npc and npc.PrimaryPart then
		prompt(npc.PrimaryPart, "Spend Battle Points", "Arena Master").Triggered:Connect(function(player)
			ColiseumRemote:FireClient(player, "openShop")
		end)
	end
	BuyRemote.OnServerInvoke = function(player, id)
		if typeof(id) ~= "string" then
			return false, "Something went wrong."
		end
		if not player:GetAttribute("InColiseum") then
			return false, "Visit the Arena Master in the Battle Coliseum."
		end
		local entry
		for _, e in GameData.Coliseum.shop do
			if e.id == id then
				entry = e
			end
		end
		local item = entry and GameData.Items[id]
		if not item then
			return false, "That isn't sold here."
		end
		if not PlayerData.spendBP(player, entry.bp) then
			return false, ("You need %d Battle Points (you have %d)."):format(entry.bp, player:GetAttribute("Stat_bp") or 0)
		end
		PlayerData.addItem(player, id, 1)
		SaveService.requestSave(player)
		return true, ("Got %s!"):format(item.name)
	end
end

-- Hold E on another trainer inside an area
local function addTrainerPrompt(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local p = prompt(root, "Battle", player.DisplayName, 10)
	p.Name = "TrainerPrompt"
	p.HoldDuration = 0.6
	p.Enabled = false
	p:SetAttribute("OwnerId", player.UserId)
	p.Triggered:Connect(function(from)
		if from == player then
			return
		end
		local kind = player:GetAttribute("InColiseum") and "battle" or (player:GetAttribute("InPlaza") and "trade") or nil
		if kind then
			SocialService.request(from, player, kind)
		end
	end)
end

local function updateZones()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local p = root and root.Position
		for _, area in AREAS do
			local c = centerOf(area)
			local inside = p ~= nil and c ~= nil and (Vector3.new(p.X, 0, p.Z) - Vector3.new(c.X, 0, c.Z)).Magnitude < area.radius and math.abs(p.Y - c.Y) < 60
			if inside ~= (player:GetAttribute(area.attr) == true) then
				player:SetAttribute(area.attr, inside or nil)
			end
		end
		local tp = root and root:FindFirstChild("TrainerPrompt")
		if tp then
			local inC, inP = player:GetAttribute("InColiseum"), player:GetAttribute("InPlaza")
			tp.Enabled = (inC or inP) and not BattleService.isInBattle(player)
			tp.ActionText = inC and "Challenge to a battle" or "Ask to trade"
		end
	end
end

-- Ranked play uses the existing authoritative PvP battle engine. Practice never changes rank.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local WeeklyEventService = require(script.Parent.WeeklyEventService)
local ratings, queue, ranked, pairCooldown, spectators = {}, {}, {}, {}, {}
local rankBoardLabel, tournamentLabel, screenPart = nil, nil, nil
local tournamentTop, lastRefresh = {}, 0
local function tier(rating)
	if rating >= 1800 then return "Master" elseif rating >= 1600 then return "Diamond" elseif rating >= 1400 then return "Platinum"
	elseif rating >= 1200 then return "Gold" elseif rating >= 1100 then return "Silver" else return "Bronze" end
end
local function recordFor(player)
	if not ratings[player] then ratings[player] = { rating = 1000, wins = 0, losses = 0, weekly = {}, claimed = {}, practiceAt = 0 } end
	return ratings[player]
end
local function syncRank(player)
	local d = recordFor(player)
	player:SetAttribute("ArenaRating", d.rating)
	player:SetAttribute("ArenaTier", tier(d.rating))
	player:SetAttribute("ArenaWins", d.wins)
end
local function finite(n) return typeof(n) == "number" and n == n and math.abs(n) ~= math.huge end
SaveService.register("coliseum", {
	serialize = function(player) return recordFor(player) end,
	load = function(player, saved)
		local d = recordFor(player)
		if typeof(saved) == "table" then
			for _, key in { "rating", "wins", "losses", "practiceAt" } do
				if finite(saved[key]) then d[key] = math.clamp(math.floor(saved[key]), 0, key == "rating" and 4000 or 2000000000) end
			end
			for _, key in { "weekly", "claimed" } do if typeof(saved[key]) == "table" then d[key] = saved[key] end end
		end
		syncRank(player)
	end,
	release = function(player) ratings[player] = nil end,
})
-- Sunday means a full Pacific calendar day, including daylight saving transitions.
local function pacificDate(now)
	local t = os.date("!*t", now - 8 * 3600)
	if WeeklyEventService._pacificDST(t.year, t.month, t.day) then t = os.date("!*t", now - 7 * 3600) end
	return t
end
local function sundayKey(now)
	local t = pacificDate(now)
	-- At noon UTC the Pacific calendar date is unambiguous. Walk backwards to Sunday.
	return math.floor((now - 8 * 3600) / 86400) - (t.wday - 1)
end
local function weeklyStore(week)
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "CQ_SundayBP_v1", tostring(week))
	return ok and store or nil
end
local rankStore
do local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "CQ_ArenaRank_v1"); if ok then rankStore = result end end
local function persistScore(player)
	if player:GetAttribute("SaveStatus") ~= "ok" or player:GetAttribute("NoSave") then return end
	local d = recordFor(player)
	if rankStore then pcall(rankStore.SetAsync, rankStore, tostring(player.UserId), d.rating) end
	local week = sundayKey(os.time())
	local points = d.weekly[tostring(week)]
	local store = points and weeklyStore(week)
	if store then pcall(store.UpdateAsync, store, tostring(player.UserId), function(old) return math.max(tonumber(old) or 0, points) end) end
end
local function rowsFrom(store, limit)
	if not store then return nil end
	local ok, pages = pcall(store.GetSortedAsync, store, false, limit)
	if not ok then return nil end
	local rows = {}
	for _, entry in pages:GetCurrentPage() do
		local id = tonumber(entry.key)
		local player = id and Players:GetPlayerByUserId(id)
		local name = player and player.DisplayName
		if not name and id then local worked, value = pcall(Players.GetNameFromUserIdAsync, Players, id); if worked then name = value end end
		table.insert(rows, { id = id, name = name or "Trainer", value = entry.value })
	end
	return rows
end
local function claimLastSunday(player)
	local previous = sundayKey(os.time()) - 7
	local d, token = recordFor(player), tostring(previous)
	if d.claimed[token] then return end
	local rows = rowsFrom(weeklyStore(previous), 3)
	if not rows then return end
	for place, row in rows do
		if row.id == player.UserId then
			if player:GetAttribute("SaveStatus") ~= "ok" or player:GetAttribute("NoSave") then return end
			d.claimed[token] = true
			local reward = ({150, 100, 50})[place]
			PlayerData.addBP(player, reward)
			SaveService.requestSave(player)
			Notify:FireClient(player, ("Sunday BP Tournament: you placed #%d and earned %d BP!"):format(place, reward), "success")
		end
	end
end
local function arenaPart(parent, name, pos, size, color)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.Position, p.Size, p.Color = name, true, pos, size, color
	p.Material, p.Parent = Enum.Material.SmoothPlastic, parent
	return p
end
local function boardLabel(part, title)
	local g = Instance.new("SurfaceGui")
	g.Face, g.SizingMode, g.PixelsPerStud = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 24
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundColor3, text.BackgroundTransparency = UDim2.fromScale(1,1), Color3.fromRGB(22,19,30), 0.1
	text.Font, text.TextColor3, text.TextScaled, text.TextWrapped = Enum.Font.GothamBold, Color3.fromRGB(255,215,120), true, true
	text.Text, text.Parent, g.Parent = title, g, part
	return text
end
local function setupArenaFixtures()
	local arena = map:FindFirstChild("Coliseum")
	local c = centerOf(AREAS.coliseum)
	if not c or arena:FindFirstChild("ArenaActivities") then return end
	local folder = Instance.new("Folder") folder.Name, folder.Parent = "ArenaActivities", arena
	local b = arenaPart(folder, "RankBoard", c + Vector3.new(-54,12,-58), Vector3.new(26,20,1), Color3.fromRGB(110,58,40))
	rankBoardLabel = boardLabel(b, "RANKED LADDER\nBronze → Silver → Gold → Platinum → Diamond → Master")
	local t = arenaPart(folder, "SundayBoard", c + Vector3.new(54,12,-58), Vector3.new(26,20,1), Color3.fromRGB(110,58,40))
	tournamentLabel = boardLabel(t, "SUNDAY BP TOURNAMENT\nRanked wins: 10 points · completed losses: 3\nTop 3: 150 / 100 / 50 BP")
	screenPart = arenaPart(folder, "SpectatorScreen", c + Vector3.new(0,26,-66), Vector3.new(48,25,1), Color3.fromRGB(20,20,30))
	screenPart:SetAttribute("ArenaScreen", true)
	boardLabel(screenPart, "LIVE COLISEUM\nUse WATCH to follow a match\nTake a seat in the stands")
	-- Region banners deliberately use the configured names, including future renames.
	for side, name in { [-1] = GameData.Region1 and GameData.Region1.name or "Soraku", [1] = GameData.Region2 and GameData.Region2.region or "Norven" } do
		local banner = arenaPart(folder, "RegionBanner", c + Vector3.new(side * 83,23,0), Vector3.new(1,20,12), side < 0 and Color3.fromRGB(65,150,100) or Color3.fromRGB(80,130,185))
		local gui = Instance.new("BillboardGui") gui.Size, gui.MaxDistance, gui.Parent = UDim2.fromOffset(180,60), 100, banner
		local l = Instance.new("TextLabel") l.Size, l.Text, l.TextScaled, l.BackgroundTransparency, l.TextColor3, l.Font, l.Parent = UDim2.fromScale(1,1), name, true, 1, Color3.new(1,1,1), Enum.Font.FredokaOne, gui
	end
	for _, x in {-76, 76} do for _, z in {-42, 42} do
		local torch = arenaPart(folder, "Torch", c + Vector3.new(x,8,z), Vector3.new(2,12,2), Color3.fromRGB(75,50,35))
		local flame = Instance.new("Fire") flame.Size, flame.Heat, flame.Parent = 5, 3, torch
		local light = Instance.new("PointLight") light.Color, light.Brightness, light.Range, light.Parent = Color3.fromRGB(255,170,70), 1.2, 18, torch
	end end
end
local function strongest(player)
	local max = 1
	for _, c in BaseManager.getTeam(player) do max = math.max(max, c.level) end
	return max
end
local function available(player)
	return player.Parent and player:GetAttribute("InColiseum") == true and not busy(player) and not player:GetAttribute("Trading")
		and not player:GetAttribute("InCutscene") and #BaseManager.getTeam(player) > 0
end
local function unqueue(player, message)
	queue[player] = nil
	player:SetAttribute("ArenaQueued", nil)
	if message and player.Parent then Notify:FireClient(player, message, "info") end
end
local function practice(player)
	if not available(player) then return end
	unqueue(player)
	local level = math.clamp(strongest(player), 5, 100)
	local species = level < 20 and { "Pebblit", "Nibbit" } or { "Cragmaul", "Nightfang", "Puddlepup" }
	local team = {}
	for _, name in species do if GameData.Creatures[name] then table.insert(team, { name, level }) end end
	local ok = BattleService.startTrainer(player, { name = "Arena Master", kind = "arenaPractice", team = team,
		reward = { coins = 0, xp = 0 }, intro = "A practice match! Your rank stays safe. Heal your team at any Healing Center.", noRun = false })
	if not ok then Notify:FireClient(player, "Heal your creatures, then try practice again.", "info") end
end
local function publicBattles()
	local list = {}
	if not BattleService.getPublicBattle then return list end
	for _, p in Players:GetPlayers() do
		local state = BattleService.getPublicBattle(p)
		if state and (not state.opponentId or p.UserId < state.opponentId) then
			table.insert(list, { userId = p.UserId, name = p.DisplayName, opponent = state.opponent, state = state })
		end
	end
	return list
end
local function refreshBoards()
	local rankRows = rowsFrom(rankStore, 5)
	if not rankRows then
		rankRows = {}
		for _, p in Players:GetPlayers() do local d = recordFor(p); table.insert(rankRows, {name=p.DisplayName,value=d.rating}) end
		table.sort(rankRows, function(a,b)return a.value>b.value end)
	end
	if rankBoardLabel then
		local lines = { "RANKED LADDER" }
		for i=1, math.min(5,#rankRows) do local r=rankRows[i]; table.insert(lines, ("%d. %s · %s %d"):format(i,r.name,tier(r.value),r.value)) end
		table.insert(lines,"Bronze → Master · Queue to climb")
		rankBoardLabel.Text = table.concat(lines,"\n")
	end
	local now = os.time()
	local current = sundayKey(now)
	local live = pacificDate(now).wday == 1
	local showWeek = live and current or current-7
	tournamentTop = rowsFrom(weeklyStore(showWeek),3) or {}
	if #tournamentTop == 0 then
		for _, p in Players:GetPlayers() do local points=recordFor(p).weekly[tostring(showWeek)] or 0; if points>0 then table.insert(tournamentTop,{id=p.UserId,name=p.DisplayName,value=points}) end end
		table.sort(tournamentTop,function(a,b)return a.value>b.value end)
	end
	if tournamentLabel then
		local lines = { "SUNDAY BP TOURNAMENT", live and "LIVE · Pacific time · Queue ranked!" or "Last Sunday · Returns every Sunday" }
		for i=1,math.min(3,#tournamentTop) do local r=tournamentTop[i];table.insert(lines,("#%d %s · %d points"):format(i,r.name,r.value)) end
		if #tournamentTop==0 then table.insert(lines,"No scores yet") end
		table.insert(lines,"Top 3 earn 150 / 100 / 50 BP")
		tournamentLabel.Text=table.concat(lines,"\n")
	end
end
local function finishRanked(player,b,result)
	local match=ranked[player]
	if not match or match.done or not b.pvp or (result~="won" and result~="lost") then return end
	-- The winner processes both sides once. A disconnect is recorded as a rated loss.
	if result~="won" then return end
	match.done=true
	local winner, loser = player, match.a==player and match.b or match.a
	ranked[match.a],ranked[match.b]=nil,nil
	local w,l=recordFor(winner),recordFor(loser)
	local expected=1/(1+10^((l.rating-w.rating)/400))
	local delta=math.max(8,math.floor(32*(1-expected)+0.5))
	w.rating,l.rating=math.min(4000,w.rating+delta),math.max(0,l.rating-delta)
	w.wins+=1;l.losses+=1
	if pacificDate(os.time()).wday==1 then
		local key=tostring(sundayKey(os.time()))
		w.weekly[key]=(w.weekly[key] or 0)+10
		-- Leaving early earns no tournament points.
		if loser.Parent then l.weekly[key]=(l.weekly[key] or 0)+3 end
	end
	for _,p in {winner,loser} do
		if p.Parent then syncRank(p);SaveService.requestSave(p);task.spawn(persistScore,p) end
	end
	Notify:FireAllClients(("Coliseum cheer! %s wins a ranked match and reaches %s (%d)."):format(winner.DisplayName,tier(w.rating),w.rating),"announce")
	ColiseumRemote:FireAllClients("cheer")
end
local function tickQueue()
	local ordered={}
	for p,joined in queue do
		if not available(p) then unqueue(p) else table.insert(ordered,{p=p,at=joined}) end
	end
	table.sort(ordered,function(a,b)return a.at<b.at end)
	for i=1,#ordered do
		local a=ordered[i].p
		if not queue[a] then continue end
		for j=i+1,#ordered do
			local b=ordered[j].p
			local ids={a.UserId,b.UserId};table.sort(ids);local key=ids[1]..":"..ids[2]
			local wait=os.clock()-math.min(ordered[i].at,ordered[j].at)
			local ratingGap=math.min(600,200+wait*4)
			local levelGap=math.min(30,8+wait/8)
			if queue[b] and math.abs(recordFor(a).rating-recordFor(b).rating)<=ratingGap and math.abs(strongest(a)-strongest(b))<=levelGap
				and (not pairCooldown[key] or os.clock()-pairCooldown[key]>300) then
				unqueue(a);unqueue(b)
				local match={a=a,b=b};ranked[a],ranked[b]=match,match
				local ok,reason=BattleService.startPvP(a,b)
				if not ok then ranked[a],ranked[b]=nil,nil;Notify:FireClient(a,reason or "Match unavailable","info");Notify:FireClient(b,reason or "Match unavailable","info")
				else pairCooldown[key]=os.clock() end
				break
			end
		end
	end
end
local function setupActivities()
	setupArenaFixtures()
	BattleService.onEnded(function(player,b,result)
		if b.trainer and b.trainer.kind=="pvp" then finishRanked(player,b,result) end
		if b.trainer and b.trainer.kind=="arenaPractice" and result=="won" then
			local d=recordFor(player)
			if os.time()-d.practiceAt>=1800 then
				d.practiceAt=os.time();PlayerData.addBP(player,3);SaveService.requestSave(player)
				Notify:FireClient(player,"Practice complete! +3 BP (one practice reward every 30 minutes).","success")
			end
		end
	end)
	ColiseumRemote.OnServerEvent:Connect(function(player,action,arg)
		if action=="leaveQueue" then return unqueue(player,"You left the ranked queue.") end
		if action=="stopWatch" then spectators[player]=nil;ColiseumRemote:FireClient(player,"spectating",nil);return end
		if not available(player) then return end
		if action=="queue" then
			if not SaveService.isLoaded(player) or player:GetAttribute("NoSave") then return Notify:FireClient(player,"Ranked battles require a working save. Practice is always available.","info") end
			queue[player]=queue[player] or os.clock();player:SetAttribute("ArenaQueued",true)
			Notify:FireClient(player,"Ranked queue joined. Matching by creature level and rating; practice is available while the arena is quiet.","info")
		elseif action=="practice" then practice(player)
		elseif action=="watchList" then ColiseumRemote:FireClient(player,"watchList",publicBattles())
		elseif action=="watch" then
			if typeof(arg)~="number" then return end
			local target=Players:GetPlayerByUserId(arg)
			if target and BattleService.getPublicBattle and BattleService.getPublicBattle(target) then unqueue(player);spectators[player]=target end
		end
	end)
	local function onPlayer(player)
		syncRank(player)
		player:GetAttributeChangedSignal("SaveStatus"):Connect(function() if player:GetAttribute("SaveStatus")=="ok" then task.delay(3,claimLastSunday,player) end end)
		if player:GetAttribute("SaveStatus")=="ok" then task.spawn(claimLastSunday,player) end
	end
	Players.PlayerAdded:Connect(onPlayer);for _,p in Players:GetPlayers() do onPlayer(p) end
	Players.PlayerRemoving:Connect(function(p)unqueue(p);spectators[p]=nil;task.spawn(persistScore,p) end)
	task.spawn(function()
		while true do
			task.wait(1);tickQueue()
			local live=publicBattles()
			local featured=live[1] and live[1].state
			for _,p in Players:GetPlayers() do
				if p:GetAttribute("InColiseum") then ColiseumRemote:FireClient(p,"screen",featured) end
			end
			for viewer,target in spectators do
				if not available(viewer) then spectators[viewer]=nil;ColiseumRemote:FireClient(viewer,"spectating",nil)
				else
					local state=BattleService.getPublicBattle and BattleService.getPublicBattle(target)
					if not state then spectators[viewer]=nil end
					ColiseumRemote:FireClient(viewer,"spectating",state)
				end
			end
			if os.clock()-lastRefresh>=120 then lastRefresh=os.clock();task.spawn(refreshBoards) end
		end
	end)
end

function ColiseumService.init()
	setupActivities()
	setupPortals()
	setupShop()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			addTrainerPrompt(player, character)
		end)
		if player.Character then
			task.spawn(addTrainerPrompt, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			updateZones()
		end
	end)
end

return ColiseumService
