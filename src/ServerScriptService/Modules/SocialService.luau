--[[
	SocialService: trade and PvP requests between players, and running trades.
	Everything goes through the "Social" RemoteEvent.

	Client -> server:
	  "request", targetUserId, "trade" | "battle"
	  "respond", requestId, accepted
	  "offer", { creature ids }      (trade: what you're putting up; resets both Ready flags)
	  "ready", boolean               (trade: lock in your offer)
	  "accept"                       (trade: final accept, only once both are ready)
	  "cancel"                       (trade: close it)
	Server -> client:
	  "incoming", { id, from, kind }
	  "trade", state   (open/refresh the trade window)
	  "tradeClosed", text

	Trade rules: up to GameData.TradeMax creatures each, you must keep at least one,
	the other base needs room, and nobody can be in a battle when it goes through.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local BaseManager = require(script.Parent.BaseManager)
local BattleService = require(script.Parent.BattleService)
local SaveService = require(script.Parent.SaveService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Social = Remotes:WaitForChild("Social")
local Notify = Remotes:WaitForChild("Notify")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local SocialService = {}

local requests = {} -- [id] = { from, to, kind, expires }
local nextRequest = 0
local trades = {} -- [Player] = trade (shared by both players)
local lastRequest = {} -- [Player] = os.clock() (spam guard)
local history, guides = {}, {}
local listings, displays = {}, {}
local boardChanged = nil
local displaySlots = {}

local function syncHistory(player)
	player:SetAttribute("TradeHistory", HttpService:JSONEncode(history[player] or {}))
end
SaveService.register("social", {
	serialize = function(player) return { history = history[player] or {}, guideSeen = guides[player] == true } end,
	load = function(player, data)
		history[player] = {}
		if typeof(data) == "table" then
			guides[player] = data.guideSeen == true
			if typeof(data.history) == "table" then
				for i = 1, math.min(20, #data.history) do
					local row = data.history[i]
					if typeof(row) == "table" and typeof(row.at) == "number" and typeof(row.partnerId) == "number" then
						table.insert(history[player], row)
					end
				end
			end
		end
		syncHistory(player)
	end,
	release = function(player) history[player], guides[player] = nil, nil end,
})

local function closeEnough(a, b)
	local ar = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
	local br = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
	return ar and br and (ar.Position - br.Position).Magnitude <= 35
end

local function tradeLocation(a, b)
	return a:GetAttribute("InPlaza") == true and b:GetAttribute("InPlaza") == true and closeEnough(a, b)
end

local function canPersist(player)
	return SaveService.isLoaded(player) and not player:GetAttribute("NoSave")
end

local function description(r)
	return { id = r.id, name = r.name, level = r.level, shiny = r.shiny == true, sizeClass = r.sizeClass or "Normal",
		held = r.held, stars = r.stars or 0, ivs = r.ivs, moves = r.moves }
end

local function remember(player, partner, sent, received)
	local function summary(list)
		local result = {}
		for _, r in list do table.insert(result, description(r)) end
		return result
	end
	history[player] = history[player] or {}
	table.insert(history[player], 1, { at = os.time(), partner = partner.DisplayName, partnerId = partner.UserId,
		sent = summary(sent), received = summary(received) })
	while #history[player] > 20 do table.remove(history[player]) end
	syncHistory(player)
end

local function busyReason(player: Player): string?
	if BattleService.isInBattle(player) then
		return "is in a battle"
	elseif player:GetAttribute("InDungeon") then
		return "is in the Dark Tower"
	elseif player:GetAttribute("TutorialStep") ~= "done" then
		return "is still in the tutorial"
	elseif trades[player] then
		return "is already trading"
	end
	return nil
end

local function otherOf(t, player: Player): Player
	return t.a == player and t.b or t.a
end

-- What each player sees in the trade window
local function stateFor(t, player: Player)
	local other = otherOf(t, player)
	local function offered(p)
		local list = {}
		for _, id in t.offers[p] do
			local r = BaseManager.findById(p, id)
			if r then
				table.insert(list, description(r))
			end
		end
		return list
	end
	return {
		partner = other.DisplayName,
		myTeam = BaseManager.snapshot(player),
		myOffer = offered(player),
		theirOffer = offered(other),
		myReady = t.ready[player] == true,
		theirReady = t.ready[other] == true,
		myAccepted = t.accepted[player] == true,
		theirAccepted = t.accepted[other] == true,
		max = GameData.TradeMax,
		version = t.version,
		countdown = t.deadline and math.max(0, math.ceil(t.deadline - workspace:GetServerTimeNow())) or nil,
	}
end

local function push(t)
	Social:FireClient(t.a, "trade", stateFor(t, t.a))
	Social:FireClient(t.b, "trade", stateFor(t, t.b))
end

local function closeTrade(t, text: string)
	t.closed = true
	t.version += 1
	if trades[t.a] == t then
		trades[t.a] = nil
	end
	if trades[t.b] == t then
		trades[t.b] = nil
	end
	for _, p in { t.a, t.b } do
		if p.Parent then
			p:SetAttribute("Trading", nil)
			Social:FireClient(p, "tradeClosed", text)
		end
	end
end

local function openTrade(a: Player, b: Player)
	local t = { a = a, b = b, offers = { [a] = {}, [b] = {} }, ready = {}, accepted = {}, version = 1 }
	trades[a], trades[b] = t, t
	a:SetAttribute("Trading", true)
	b:SetAttribute("Trading", true)
	push(t)
end

-- Checks, then swap the creatures
local function execute(t)
	if t.closed or t.executing or trades[t.a] ~= t or trades[t.b] ~= t then return end
	local a, b = t.a, t.b
	if not tradeLocation(a, b) then return closeTrade(t, "Trade cancelled: stay close together inside the Trade Center.") end
	if not canPersist(a) or not canPersist(b) then return closeTrade(t, "Trading needs a working save for both players. Please rejoin.") end
	t.executing = true
	for _, p in { a, b } do
		if not p.Parent then
			return closeTrade(t, "The other player left.")
		end
		if BattleService.isInBattle(p) then
			return closeTrade(t, "Trade cancelled: someone entered a battle.")
		end
	end
	local give = { [a] = {}, [b] = {} }
	for _, p in { a, b } do
		for _, id in t.offers[p] do
			local r = BaseManager.findById(p, id)
			if not r then
				return closeTrade(t, "Trade cancelled: a creature is no longer available.")
			end
			table.insert(give[p], r)
		end
	end
	if #give[a] == 0 and #give[b] == 0 then
		return closeTrade(t, "Nothing was offered.")
	end
	for _, p in { a, b } do
		local other = otherOf(t, p)
		local after = #BaseManager.getTeam(p) - #give[p] + #give[other]
		if #BaseManager.getTeam(p) - #give[p] < 1 then
			return closeTrade(t, ("Trade cancelled: %s has to keep at least one creature."):format(p.DisplayName))
		end
		if after > (p:GetAttribute("TeamCapacity") or GameData.StartingBaseCapacity) then
			return closeTrade(t, ("Trade cancelled: %s's base doesn't have room."):format(p.DisplayName))
		end
	end
	-- take everything out first, then hand it over
	local moved = { [a] = {}, [b] = {} }
	for _, p in { a, b } do
		for _, r in give[p] do
			local removed = BaseManager.removeCreature(p, r.id)
			if removed then
				table.insert(moved[p], removed)
			end
		end
	end
	for _, p in { a, b } do
		local other = otherOf(t, p)
		for _, r in moved[p] do
			BaseManager.addCreature(other, r, { force = true })
		end
	end
	local function names(list)
		local n = {}
		for _, r in list do
			table.insert(n, (r.shiny and "Shiny " or "") .. r.name)
		end
		return #n > 0 and table.concat(n, ", ") or "nothing"
	end
	remember(a, b, moved[a], moved[b])
	remember(b, a, moved[b], moved[a])
	listings[a], listings[b] = nil, nil
	if boardChanged then boardChanged() end
	closeTrade(t, "Trade complete! See your Bag for the receipt.")
	-- Save both immediately. These are separate player saves; do not claim cross-key crash atomicity.
	task.spawn(function()
		if not SaveService.save(a) then Notify:FireClient(a, "Your trade is complete, but saving is retrying. Please stay in this server.", "info"); SaveService.requestSave(a) end
	end)
	task.spawn(function()
		if not SaveService.save(b) then Notify:FireClient(b, "Your trade is complete, but saving is retrying. Please stay in this server.", "info"); SaveService.requestSave(b) end
	end)
	Notify:FireClient(a, ("Trade complete! You got %s."):format(names(moved[b])), "success")
	Notify:FireClient(b, ("Trade complete! You got %s."):format(names(moved[a])), "success")
end

local function onRequest(player: Player, targetId, kind)
	if typeof(targetId) ~= "number" or targetId ~= targetId or targetId % 1 ~= 0 or math.abs(targetId) == math.huge or (kind ~= "trade" and kind ~= "battle") then
		return
	end
	if lastRequest[player] and os.clock() - lastRequest[player] < 3 then
		return Notify:FireClient(player, "Wait a moment before sending another request.", "fail")
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == player then
		return
	end
	local mine = busyReason(player)
	if mine then
		return Notify:FireClient(player, "You can't do that right now.", "fail")
	end
	local theirs = busyReason(target)
	if theirs then
		return Notify:FireClient(player, ("%s %s."):format(target.DisplayName, theirs), "fail")
	end
	if kind == "trade" then
		if not tradeLocation(player, target) then
			return Notify:FireClient(player, "Stand near your trading partner inside the Trade Center.", "fail")
		end
		if not canPersist(player) or not canPersist(target) then
			return Notify:FireClient(player, "Both players need a working save before trading. Please rejoin.", "fail")
		end
	end
	-- player battles happen in the Battle Coliseum, once both have their first gym badge
	if kind == "battle" then
		local need = GameData.Coliseum.badges
		if (player:GetAttribute("Badges") or 0) < need then
			return Notify:FireClient(player, ("Earn %d gym badge to battle other players."):format(need), "fail")
		end
		if (target:GetAttribute("Badges") or 0) < need then
			return Notify:FireClient(player, ("%s needs a gym badge before they can battle players."):format(target.DisplayName), "fail")
		end
		if not player:GetAttribute("InColiseum") or not target:GetAttribute("InColiseum") then
			return Notify:FireClient(player, "Player battles happen in the Battle Coliseum. Take the portal in the hub, and bring a friend!", "fail")
		end
	end
	lastRequest[player] = os.clock()
	nextRequest += 1
	requests[nextRequest] = { from = player, to = target, kind = kind, expires = os.clock() + 30 }
	Social:FireClient(target, "incoming", { id = nextRequest, from = player.DisplayName, kind = kind })
	Notify:FireClient(player, ("%s request sent to %s."):format(kind == "trade" and "Trade" or "Battle", target.DisplayName), "info")
end

local function onRespond(player: Player, id, accepted)
	local r = typeof(id) == "number" and requests[id]
	if not r or r.to ~= player then
		return
	end
	requests[id] = nil
	local from = r.from
	if not from.Parent or os.clock() > r.expires then
		return Notify:FireClient(player, "That request expired.", "fail")
	end
	if accepted ~= true then
		return Notify:FireClient(from, ("%s declined your %s request."):format(player.DisplayName, r.kind), "fail")
	end
	for _, p in { from, player } do
		local reason = busyReason(p)
		if reason then
			Notify:FireClient(from, ("%s %s."):format(p.DisplayName, reason), "fail")
			return Notify:FireClient(player, ("%s %s."):format(p.DisplayName, reason), "fail")
		end
	end
	if r.kind == "trade" then
		if not tradeLocation(from, player) or not canPersist(from) or not canPersist(player) then
			return Notify:FireClient(player, "That trade cannot start. Stand together in the Trade Center with saving enabled.", "fail")
		end
		openTrade(from, player)
	else
		if not from:GetAttribute("InColiseum") or not player:GetAttribute("InColiseum") then return end
		local ok, reason = BattleService.startPvP(from, player)
		if not ok then
			Notify:FireClient(from, reason or "The battle couldn't start.", "fail")
			Notify:FireClient(player, reason or "The battle couldn't start.", "fail")
		end
	end
end

-- Hold-E prompts on other players (Coliseum and Trade Plaza) send the same requests as the Players menu
function SocialService.request(player: Player, target: Player, kind: string)
	if target and target.Parent then
		onRequest(player, target.UserId, kind)
	end
end


-- Server-only Trade Center fixtures. No free-form user text is broadcast.
local function plazaCenter()
	local plaza = workspace.Map:FindFirstChild("TradePlaza")
	local floor = plaza and (plaza:FindFirstChild("Sand") or plaza:FindFirstChild("ArenaFloor"))
	return plaza, floor and floor.Position
end
local function fixture(parent, name, pos, size, color)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.Position, p.Size, p.Color = name, true, pos, size, color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end
local function caption(parent, text, size)
	local g = Instance.new("BillboardGui")
	g.Name, g.Size, g.StudsOffset, g.MaxDistance, g.AlwaysOnTop = "Label", UDim2.fromOffset(size or 260, 62), Vector3.new(0, 4, 0), 65, false
	local l = Instance.new("TextLabel")
	l.Size, l.BackgroundTransparency, l.Text, l.TextWrapped, l.TextScaled = UDim2.fromScale(1, 1), 1, text, true, true
	l.Font, l.TextColor3, l.TextStrokeTransparency = Enum.Font.FredokaOne, Color3.new(1, 1, 1), 0.35
	l.Parent, g.Parent = g, parent
	return l
end
local function promptAt(parent, action, object)
	local p = Instance.new("ProximityPrompt")
	p.ActionText, p.ObjectText, p.MaxActivationDistance, p.HoldDuration, p.RequiresLineOfSight = action, object, 12, 0.3, false
	p.Parent = parent
	return p
end
local function boardRows()
	local rows = {}
	for owner, listing in listings do
		local record = owner.Parent and owner:GetAttribute("InPlaza") and BaseManager.findById(owner, listing.id)
		if record then
			table.insert(rows, { userId = owner.UserId, trainer = owner.DisplayName, offering = description(record), looking = listing.looking })
		else listings[owner] = nil end
	end
	table.sort(rows, function(a, b) return a.userId < b.userId end)
	return rows
end
function SocialService.sendBoard(player)
	if player:GetAttribute("InPlaza") and not busyReason(player) then
		Social:FireClient(player, "board", { listings = boardRows(), team = BaseManager.snapshot(player) })
	end
end
function SocialService.postListing(player, creatureId, looking)
	if not player:GetAttribute("InPlaza") or busyReason(player) then return end
	if typeof(creatureId) ~= "number" or typeof(looking) ~= "string" or not GameData.Creatures[looking] then
		return Notify:FireClient(player, "Choose a creature you own and a real species name to look for.", "fail")
	end
	if not BaseManager.findById(player, creatureId) then return end
	listings[player] = { id = creatureId, looking = looking }
	if boardChanged then boardChanged() end
	SocialService.sendBoard(player)
end
function SocialService.display(player, creatureId, slot)
	if not player:GetAttribute("InPlaza") or busyReason(player) then return end
	if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > 4 then return end
	local plaza, c = plazaCenter()
	local pedestal = plaza and plaza:FindFirstChild("CommunityFixtures") and plaza.CommunityFixtures:FindFirstChild("Showcase" .. slot)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not pedestal or not root or (pedestal.Position - root.Position).Magnitude > 18 then return end
	local r = typeof(creatureId) == "number" and BaseManager.findById(player, creatureId)
	if not r or not (r.shiny or r.sizeClass == "Huge") then
		return Notify:FireClient(player, "Choose a Shiny or Huge creature for this showcase.", "info")
	end
	if displaySlots[slot] and displaySlots[slot] ~= player then return Notify:FireClient(player, "This showcase is already in use.", "info") end
	if displays[player] then displays[player]:Destroy() end
	for n, owner in displaySlots do if owner == player then displaySlots[n] = nil end end
	local builder = require(ReplicatedStorage.Shared.CreatureBuilder)
	local model = builder.build(r.name, r.level, { shiny = r.shiny, sizeClass = r.sizeClass })
	-- Display is cosmetic; the actual creature stays safely in its owner's team.
	model:PivotTo(CFrame.new(pedestal.Position + Vector3.new(0, 1 + (model:GetAttribute("GroundOffset") or 3), 0)))
	for _, d in model:GetDescendants() do if d:IsA("BasePart") then d.CanCollide = false end end
	model:SetAttribute("DisplayOwnerId", player.UserId)
	model.Parent, displays[player], displaySlots[slot] = plaza.CommunityFixtures, model, player
	caption(model.PrimaryPart, player.DisplayName .. "'s " .. (r.shiny and "Shiny " or "Huge ") .. r.name, 220)
end

local function setupCommunity()
	local plaza, c = plazaCenter()
	if not c or plaza:FindFirstChild("CommunityFixtures") then return end
	local folder = Instance.new("Folder") folder.Name, folder.Parent = "CommunityFixtures", plaza
	local board = fixture(folder, "TradeBoard", c + Vector3.new(-48, 9, -48), Vector3.new(20, 12, 1), Color3.fromRGB(70, 48, 32))
	local boardLabel = caption(board, "TRADE BOARD\nLooking for a creature? Post an offer.", 300)
	promptAt(board, "Browse and post", "Trade Board").Triggered:Connect(SocialService.sendBoard)
	boardChanged = function()
		local rows = boardRows()
		local text = { "TRADE BOARD" }
		for i = 1, math.min(3, #rows) do
			local r = rows[i]
			table.insert(text, r.trainer .. ": " .. r.offering.name .. " → " .. r.looking)
		end
		if #rows == 0 then table.insert(text, "No offers yet. Be the first!") end
		boardLabel.Text = table.concat(text, "\n")
		for _, p in Players:GetPlayers() do if p:GetAttribute("InPlaza") then Social:FireClient(p, "boardRefresh", rows) end end
	end
	for i = 1, 3 do
		local x = -48 + (i - 1) * 48
		local desk = fixture(folder, "TradeBooth" .. i, c + Vector3.new(x, 3, 24), Vector3.new(22, 4, 6), Color3.fromRGB(140, 90, 45))
		caption(desk, "TRADE BOOTH " .. i .. "\nStand on opposite sides")
		for _, side in { -1, 1 } do
			local pad = fixture(folder, "BoothPad" .. i .. "_" .. side, c + Vector3.new(x, 1.1, 24 + side * 9), Vector3.new(12, 0.2, 9), side < 0 and Color3.fromRGB(80, 160, 210) or Color3.fromRGB(235, 165, 60))
			pad.CanCollide = false
			promptAt(pad, "Trade across booth", "Trade Booth " .. i).Triggered:Connect(function(player)
				local pr = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not pr or (pr.Position - pad.Position).Magnitude > 14 then return end
				local opposite = c + Vector3.new(x, 4, 24 - side * 9)
				local candidate, distance = nil, 9
				for _, other in Players:GetPlayers() do
					local rr = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
					if other ~= player and rr and other:GetAttribute("InPlaza") and (rr.Position - opposite).Magnitude < distance then
						candidate, distance = other, (rr.Position - opposite).Magnitude
					end
				end
				if candidate then SocialService.request(player, candidate, "trade")
				else Notify:FireClient(player, "Ask your trading partner to stand on the opposite booth pad.", "info") end
			end)
		end
	end
	for i = 1, 4 do
		local pad = fixture(folder, "Showcase" .. i, c + Vector3.new(-54 + (i - 1) * 36, 2, 60), Vector3.new(14, 3, 14), Color3.fromRGB(105, 70, 150))
		caption(pad, "SHOWCASE\nShiny & Huge creatures", 180)
		promptAt(pad, "Choose your display", "Showcase " .. i).Triggered:Connect(function(player)
			if player:GetAttribute("InPlaza") and not busyReason(player) then Social:FireClient(player, "showcase", { slot = i, team = BaseManager.snapshot(player) }) end
		end)
	end
	-- A simple friendly guide at the entrance; no avatar web request is needed.
	local guide = Instance.new("Model") guide.Name, guide.Parent = "TradeGuide", folder
	local torso = fixture(guide, "Torso", c + Vector3.new(29, 4, -51), Vector3.new(3, 3, 1.5), Color3.fromRGB(55, 150, 145))
	local head = fixture(guide, "Head", torso.Position + Vector3.new(0, 2.3, 0), Vector3.new(2, 2, 2), Color3.fromRGB(236, 190, 150))
	guide.PrimaryPart = torso
	caption(head, "MARA · TRADE GUIDE", 220)
	local function explain(player)
		if not player:GetAttribute("InPlaza") then return end
		Social:FireClient(player, "guide", "Welcome! Meet at opposite booth pads, then offer creatures. Both players review and lock their offers, then both confirm again. A 3-second countdown follows; Cancel stays available. Check levels, size, Shiny status and held items. Every trade leaves a receipt in your Bag. Never trade for promises or Robux.")
		guides[player] = true; SaveService.requestSave(player)
	end
	promptAt(torso, "How trading works", "Mara").Triggered:Connect(explain)
	local function watch(player)
		player:GetAttributeChangedSignal("InPlaza"):Connect(function()
			if player:GetAttribute("InPlaza") and not guides[player] then explain(player) end
			if not player:GetAttribute("InPlaza") then
				listings[player] = nil
				if displays[player] then displays[player]:Destroy(); displays[player] = nil end
				for slot, owner in displaySlots do if owner == player then displaySlots[slot] = nil end end
				if boardChanged then boardChanged() end
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do watch(player) end
	boardChanged()
end

function SocialService.init()
	setupCommunity()
	Social.OnServerEvent:Connect(function(player, action, a1, a2)
		if action == "request" then
			return onRequest(player, a1, a2)
		elseif action == "respond" then
			return onRespond(player, a1, a2)
		end
		if action == "board" then return SocialService.sendBoard(player) end
		if action == "post" then return SocialService.postListing(player, a1, a2) end
		if action == "unpost" then listings[player] = nil; if boardChanged then boardChanged() end; return end
		if action == "display" then return SocialService.display(player, a1, a2) end
		local t = trades[player]
		if not t or t.executing or t.closed then
			return
		end
		if not tradeLocation(t.a, t.b) then return closeTrade(t, "Trade cancelled: stay together in the Trade Center.") end
		if action == "offer" and typeof(a1) == "table" then
			if t.deadline then return end
			local list, seen = {}, {}
			for index, id in a1 do
				if typeof(index) ~= "number" or index > 100 then break end
				if typeof(id) == "number" and not seen[id] and BaseManager.findById(player, id) and #list < GameData.TradeMax then
					seen[id] = true
					table.insert(list, id)
				end
			end
			t.offers[player] = list
			-- any change unlocks both sides, so nobody gets surprised
			t.ready, t.accepted, t.deadline = {}, {}, nil
			t.version += 1
			push(t)
		elseif action == "ready" then
			if a2 ~= t.version then return end
			t.ready[player] = a1 == true
			t.accepted, t.deadline = {}, nil
			t.version += 1
			push(t)
		elseif action == "accept" then
			if a1 ~= t.version or t.deadline then return end
			if t.ready[t.a] and t.ready[t.b] then
				t.accepted[player] = true
				if t.accepted[t.a] and t.accepted[t.b] then
					t.deadline = workspace:GetServerTimeNow() + 3
					local token = t.version
					push(t)
					task.spawn(function()
						while not t.closed and t.version == token and t.deadline do
							if not tradeLocation(t.a, t.b) or BattleService.isInBattle(t.a) or BattleService.isInBattle(t.b) then
								return closeTrade(t, "Trade cancelled: a player moved away or became busy.")
							end
							if workspace:GetServerTimeNow() >= t.deadline then return execute(t) end
							task.wait(0.25)
							if not t.closed and t.version == token then push(t) end
						end
					end)
				else
					push(t)
				end
			end
		elseif action == "cancel" then
			closeTrade(t, ("%s cancelled the trade."):format(player.DisplayName))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local t = trades[player]
		if t then
			closeTrade(t, ("%s left the game."):format(player.DisplayName))
		end
		lastRequest[player] = nil
		listings[player] = nil
		if displays[player] then displays[player]:Destroy(); displays[player] = nil end
		for slot, owner in displaySlots do if owner == player then displaySlots[slot] = nil end end
		if boardChanged then boardChanged() end
		for id, r in requests do
			if r.from == player or r.to == player then
				requests[id] = nil
			end
		end
	end)
end

function SocialService.isTrading(player: Player): boolean
	return trades[player] ~= nil
end

return SocialService
