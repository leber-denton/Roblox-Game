--[[
	Menus: the left-side buttons and their windows, plus pop-ups.
	  QUESTS  - login streak and today's quests
	  PLAYERS - everyone in the server, with Trade and Battle buttons
	  STORE   - game passes (also opens when you talk to Clerk Milo)
	Pop-ups: daily streak reward, incoming trade/battle requests, the trade window,
	the evolution animation, and the rare spawn timer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local GameData = require(Shared:WaitForChild("GameData"))
local BattleData = require(Shared:WaitForChild("BattleData"))
local CreatureBuilder = require(Shared:WaitForChild("CreatureBuilder"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Social = Remotes:WaitForChild("Social")
local Daily = Remotes:WaitForChild("Daily")
local Evolve = Remotes:WaitForChild("Evolve")
local OpenShop = Remotes:WaitForChild("OpenShop")

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 215, 80)
local PANEL = Color3.fromRGB(28, 30, 42)
local CARD = Color3.fromRGB(46, 50, 68)
local MUTED = Color3.fromRGB(190, 190, 205)
local GREEN = Color3.fromRGB(55, 165, 85)
local RED = Color3.fromRGB(200, 60, 60)
local BLUE = Color3.fromRGB(70, 130, 220)
local GREY = Color3.fromRGB(80, 80, 92)

local function new(className: string, props, parent)
	local inst = Instance.new(className)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end
local function round(inst, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 10) }, inst)
end
local function label(props, parent)
	local p = { BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE }
	for k, v in props do
		p[k] = v
	end
	return new("TextLabel", p, parent)
end
local function button(props, text: string, color: Color3, parent, onClick)
	local p = { BackgroundColor3 = color, Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = text, AutoButtonColor = true }
	for k, v in props do
		p[k] = v
	end
	local b = new("TextButton", p, parent)
	round(b, 10)
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end
local function decode(raw)
	if typeof(raw) ~= "string" or raw == "" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and data or nil
end

local gui = new("ScreenGui", { Name = "Menus", ResetOnSpawn = false, DisplayOrder = 8, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
UIStyle.mount(gui)

-- Windows -------------------------------------------------------------------------
local windows = {}
local openName = nil

local function makeWindow(name: string, titleText: string, accent: Color3)
	local w = new("Frame", {
		Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.9, 0.76),
		BackgroundColor3 = PANEL, Visible = false,
	}, gui)
	round(w, 18)
	new("UISizeConstraint", { MaxSize = Vector2.new(640, 520) }, w)
	new("UIStroke", { Color = accent, Thickness = 3 }, w)
	new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, w)
	label({ Size = UDim2.new(1, -50, 0, 34), Text = titleText, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = accent }, w)
	button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40) }, "X", RED, w, function()
		w.Visible = false
		openName = nil
	end)
	local body = new("Frame", { Name = "Body", Position = UDim2.new(0, 0, 0, 48), Size = UDim2.new(1, 0, 1, -48), BackgroundTransparency = 1 }, w)
	windows[name] = { frame = w, body = body }
	return windows[name]
end

local refreshers = {}
local function openWindow(name: string)
	for n, w in windows do
		w.frame.Visible = false
	end
	if openName == name then
		openName = nil
		return
	end
	openName = name
	windows[name].frame.Visible = true
	if refreshers[name] then
		refreshers[name]()
	end
end

-- Left-side buttons -----------------------------------------------------------------
local side = new("Frame", {
	Name = "SideButtons", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(78, 3 * 78 + 2 * 12), BackgroundTransparency = 1,
}, gui)
new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, side)

local badges = {}
local function sideButton(order: number, text: string, icon: string, color: Color3, window: string)
	local b = new("TextButton", { Name = window .. "Button", LayoutOrder = order, Size = UDim2.fromOffset(78, 78), BackgroundColor3 = color, Text = "" }, side)
	round(b, 18)
	new("UIStroke", { Color = color:Lerp(Color3.new(0, 0, 0), 0.4), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	label({ Size = UDim2.fromScale(1, 0.56), Position = UDim2.fromScale(0, 0.05), Text = icon }, b)
	local t = label({ Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.64), Text = text }, b)
	new("UIStroke", { Thickness = 1.5, Color = color:Lerp(Color3.new(0, 0, 0), 0.55) }, t)
	local dot = label({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 0, BackgroundColor3 = RED, Text = "!", Visible = false, ZIndex = 3,
	}, b)
	round(dot, 999)
	badges[window] = dot
	b.Activated:Connect(function()
		openWindow(window)
	end)
	return b
end
sideButton(1, "QUESTS", "★", Color3.fromRGB(40, 165, 160), "Quests")
sideButton(2, "PLAYERS", "☺", BLUE, "Players")
sideButton(3, "STORE", "$", Color3.fromRGB(50, 170, 80), "Shop")

local function updateSide()
	local hidden = player:GetAttribute("InBattle") or player:GetAttribute("InCutscene") or player:GetAttribute("InDialogue")
	side.Visible = not hidden
	if hidden then
		for _, w in windows do
			if w.frame.Name ~= "Trade" then
				w.frame.Visible = false
			end
		end
		openName = nil
	end
end
player:GetAttributeChangedSignal("InBattle"):Connect(updateSide)
player:GetAttributeChangedSignal("InCutscene"):Connect(updateSide)
player:GetAttributeChangedSignal("InDialogue"):Connect(updateSide)
updateSide()

-- QUESTS ------------------------------------------------------------------------------
do
	local w = makeWindow("Quests", "Daily Quests", Color3.fromRGB(60, 200, 190))
	local body = w.body
	local streakLabel = label({ Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, body)
	local chips = new("Frame", { Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1 }, body)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }, chips)
	local list = new("Frame", { Position = UDim2.new(0, 0, 0, 90), Size = UDim2.new(1, 0, 1, -124), BackgroundTransparency = 1 }, body)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local resetLabel = label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 22), TextColor3 = MUTED }, body)

	local function refresh()
		local streak = player:GetAttribute("Streak") or 0
		streakLabel.Text = ("Login streak: Day %d   (come back tomorrow to keep it!)"):format(streak)
		for _, c in chips:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local today = ((math.max(streak, 1) - 1) % 7) + 1
		for i, coins in GameData.DailyRewards do
			local chip = new("Frame", { Size = UDim2.new(1 / 7, -6, 1, 0), BackgroundColor3 = i == today and Color3.fromRGB(235, 165, 40) or (i < today and GREEN or CARD) }, chips)
			round(chip, 8)
			label({ Size = UDim2.fromScale(1, 0.45), Text = "Day " .. i }, chip)
			label({ Position = UDim2.fromScale(0, 0.45), Size = UDim2.fromScale(1, 0.5), Text = i == 7 and "Apex Ball" or tostring(coins), TextColor3 = GOLD }, chip)
		end
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local quests = decode(player:GetAttribute("Quests")) or {}
		for i, q in quests do
			local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = q.done and Color3.fromRGB(40, 90, 60) or CARD }, list)
			round(row, 12)
			new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, row)
			label({ Size = UDim2.new(0.65, 0, 0, 26), Text = (q.done and "✓ " or "") .. q.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
			label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.34, 0, 0, 24), Text = ("+%d coins  +%d XP"):format(q.coins, q.xp), TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Right }, row)
			local back = new("Frame", { Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(0.8, 0, 0, 16), BackgroundColor3 = Color3.fromRGB(15, 15, 22) }, row)
			round(back, 8)
			local fill = new("Frame", { Size = UDim2.fromScale(math.clamp(q.progress / q.goal, 0, 1), 1), BackgroundColor3 = q.done and GOLD or Color3.fromRGB(60, 200, 190) }, back)
			round(fill, 8)
			label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 30), Size = UDim2.new(0.18, 0, 0, 22), Text = ("%d/%d"):format(q.progress, q.goal), TextXAlignment = Enum.TextXAlignment.Right }, row)
		end
		badges.Quests.Visible = false
	end
	refreshers.Quests = refresh
	player:GetAttributeChangedSignal("Quests"):Connect(function()
		if w.frame.Visible then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("QuestDay"):Connect(function()
		badges.Quests.Visible = true
	end)
	if player:GetAttribute("QuestDay") then
		badges.Quests.Visible = true
	end
	task.spawn(function()
		while true do
			local now = os.time()
			local left = 86400 - (now % 86400)
			resetLabel.Text = ("New quests in %d:%02d:%02d"):format(left // 3600, (left % 3600) // 60, left % 60)
			task.wait(1)
		end
	end)
end

-- PLAYERS ------------------------------------------------------------------------------
do
	local w = makeWindow("Players", "Players", BLUE)
	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, w.body)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

	local function refresh()
		for _, c in scroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local others = {}
		for _, p in Players:GetPlayers() do
			if p ~= player then
				table.insert(others, p)
			end
		end
		if #others == 0 then
			label({ Size = UDim2.new(1, 0, 0, 30), Text = "Nobody else is here yet. Invite a friend!", TextColor3 = MUTED }, scroll)
			return
		end
		for i, p in others do
			local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -8, 0, 58), BackgroundColor3 = CARD }, scroll)
			round(row, 12)
			new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, row)
			label({ Size = UDim2.new(0.5, 0, 0.6, 0), Text = p.DisplayName, TextXAlignment = Enum.TextXAlignment.Left }, row)
			label({ Position = UDim2.fromScale(0, 0.6), Size = UDim2.new(0.5, 0, 0.4, 0), TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left,
				Text = ("Lv %d  ·  %d caught"):format(p:GetAttribute("TrainerLevel") or 1, p:GetAttribute("Stat_caught") or 0) }, row)
			button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -112, 0.5, 0), Size = UDim2.new(0, 100, 1, 0) }, "Trade", Color3.fromRGB(235, 165, 40), row, function()
				Social:FireServer("request", p.UserId, "trade")
			end)
			button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 100, 1, 0) }, "Battle", RED, row, function()
				Social:FireServer("request", p.UserId, "battle")
			end)
		end
	end
	refreshers.Players = refresh
	Players.PlayerAdded:Connect(function()
		if w.frame.Visible then
			refresh()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.wait()
		if w.frame.Visible then
			refresh()
		end
	end)
end

-- SHOP ----------------------------------------------------------------------------------
-- Two tabs: Items (bought with coins) and Passes (Robux game passes).
-- Items are split into sections (Balls, Medicine, Battle, Held, Evolve). Each section starts with a
-- short explanation, and every row says what the item does. Items you can't buy yet are listed
-- at the bottom of the section by how many badges unlock them.
local SHOP_SECTIONS = {
	{ key = "Balls", label = "Balls", color = Color3.fromRGB(220, 70, 70),
		intro = "Throw a ball in a wild battle to catch the creature. Weaken it first (low HP, asleep, paralyzed) for a better chance. The bigger the number, the better the odds." },
	{ key = "Medicine", label = "Medicine", color = Color3.fromRGB(80, 190, 120),
		intro = "Heal HP, revive fainted creatures, and cure burn, poison, sleep, freeze or paralysis. Use them from your Bag or during a battle." },
	{ key = "Battle", label = "Battle", color = Color3.fromRGB(235, 150, 50),
		intro = "Drink one during a battle to raise a stat by 2 stages for the rest of that battle." },
	{ key = "Held", label = "Held", color = Color3.fromRGB(170, 120, 230),
		intro = "Open your Bag and give one to a creature. It works by itself in battle: charms power up one type of move, berries heal or cure it automatically." },
	{ key = "Evolution", label = "Evolve", color = Color3.fromRGB(90, 170, 240),
		intro = "Use a crystal on the right creature to make it evolve right away. Each crystal lists the creatures it works on." },
}
local function shopSection(id: string): string
	if GameData.Balls[id] then
		return "Balls"
	end
	local item = GameData.Items[id] or {}
	if item.evolve then
		return "Evolution"
	elseif item.held then
		return "Held"
	elseif item.boost then
		return "Battle"
	end
	return "Medicine"
end
-- "Works on: Pebblit -> Cinderock" for evolution crystals
local function crystalTargets(id: string): string?
	local list = {}
	for species, byItem in GameData.StoneEvolutions or {} do
		if byItem[id] then
			table.insert(list, species .. " \u{2192} " .. byItem[id])
		end
	end
	table.sort(list)
	return #list > 0 and ("Works on: " .. table.concat(list, ", ")) or nil
end

do
	local w = makeWindow("Shop", "Clerk Milo's Store", Color3.fromRGB(80, 200, 110))
	local section = "Balls"
	local BuyItem = Remotes:WaitForChild("BuyItem")
	local tab = "items"
	local tabs = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, w.body)
	local status = label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 22), Text = "", TextColor3 = MUTED }, w.body)
	local list = new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(1, 0, 1, -72), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, w.body)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local refresh
	local tabButtons = {}
	for i, t in { { "items", "Items" }, { "passes", "Passes" } } do
		tabButtons[t[1]] = button({ Position = UDim2.new((i - 1) * 0.5, i == 1 and 0 or 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0) }, t[2], CARD, tabs, function()
			tab = t[1]
			refresh()
		end)
	end
	local function clear()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end
	local function inventory()
		return decode(player:GetAttribute("Inventory")) or {}
	end
	function refresh()
		for k, b in tabButtons do
			b.BackgroundColor3 = k == tab and GREEN or CARD
		end
		clear()
		if tab == "items" then
			local badges = player:GetAttribute("Badges") or 0
			local inv = inventory()
			local sec
			for _, s in SHOP_SECTIONS do
				if s.key == section then
					sec = s
				end
			end
			-- section chips
			local chips = new("Frame", { LayoutOrder = -2, Size = UDim2.new(1, -8, 0, 34), BackgroundTransparency = 1 }, list)
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, chips)
			for i, s in SHOP_SECTIONS do
				local chip = button({ LayoutOrder = i, Size = UDim2.new(1 / #SHOP_SECTIONS, -5, 1, 0) }, s.label, s.key == section and s.color or GREY, chips, function()
					section = s.key
					status.Text = ""
					refresh()
					list.CanvasPosition = Vector2.zero
				end)
				chip.AutoButtonColor = true
			end
			-- what this section is for
			local introBox = new("Frame", { LayoutOrder = -1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = sec.color:Lerp(PANEL, 0.7) }, list)
			round(introBox, 10)
			new("UIStroke", { Color = sec.color, Thickness = 1.5 }, introBox)
			new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, introBox)
			new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
				TextSize = 15, TextWrapped = true, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = sec.intro,
			}, introBox)
			-- this section's items: ones you can buy first, cheapest first
			local open, lockedByBadges = {}, {}
			for _, e in GameData.Shop do
				if shopSection(e.id) == section then
					if badges >= e.badges then
						table.insert(open, e)
					else
						lockedByBadges[e.badges] = lockedByBadges[e.badges] or {}
						table.insert(lockedByBadges[e.badges], e)
					end
				end
			end
			table.sort(open, function(a, b)
				if a.badges ~= b.badges then
					return a.badges < b.badges
				end
				return a.price < b.price
			end)
			for i, e in open do
				local def = GameData.Balls[e.id] or GameData.Items[e.id]
				local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = CARD }, list)
				round(row, 12)
				new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, row)
				local icon = new("Frame", { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(0, 4), BackgroundColor3 = def.color or WHITE }, row)
				round(icon, 999)
				new("UIStroke", { Color = (def.color or WHITE):Lerp(Color3.new(0, 0, 0), 0.4), Thickness = 2 }, icon)
				if def.band then
					new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = def.band, BorderSizePixel = 0 }, icon)
				end
				-- text column (name, what it does in short, the full description)
				local text = new("Frame", { Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -56 - 120, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, row)
				new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, text)
				label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 24), Text = def.name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, text)
				label({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(150, 235, 160),
					Text = GameData.itemSummary(e.id) .. "   ·   You have " .. tostring(inv[e.id] or 0) }, text)
				local desc = def.description or ""
				local works = def.evolve and crystalTargets(e.id)
				if works then
					desc = desc .. (desc ~= "" and "\n" or "") .. works
				end
				if desc ~= "" then
					new("TextLabel", {
						LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
						Font = Enum.Font.GothamMedium, TextSize = 13, TextWrapped = true, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Text = desc,
					}, text)
				end
				-- buy buttons stacked on the right
				for j, qty in { 1, 5 } do
					button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, (j - 1) * 40), Size = UDim2.fromOffset(112, 34) },
						("x%d · %d"):format(qty, e.price * qty), GREEN, row, function()
							local ok, message = BuyItem:InvokeServer(e.id, qty)
							status.Text = message or ""
							status.TextColor3 = ok and Color3.fromRGB(150, 240, 150) or Color3.fromRGB(255, 140, 140)
						end)
				end
				new("Frame", { Size = UDim2.fromOffset(1, 74), BackgroundTransparency = 1 }, row) -- keeps the row tall enough for both buttons
			end
			if #open == 0 then
				label({ LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 24), Text = "Nothing here yet. Earn gym badges to unlock these!", TextColor3 = MUTED }, list)
			end
			-- coming later: one line per badge count
			local tiers = {}
			for n in lockedByBadges do
				table.insert(tiers, n)
			end
			table.sort(tiers)
			for k, n in tiers do
				local names = {}
				for _, e in lockedByBadges[n] do
					local def = GameData.Balls[e.id] or GameData.Items[e.id]
					table.insert(names, def.name)
				end
				local box = new("Frame", { LayoutOrder = 1000 + k, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(36, 38, 52) }, list)
				round(box, 10)
				new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, box)
				new("TextLabel", {
					Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
					TextSize = 13, TextWrapped = true, TextColor3 = Color3.fromRGB(150, 150, 165), TextXAlignment = Enum.TextXAlignment.Left,
					Text = ("LOCKED until %d badge%s: %s"):format(n, n == 1 and "" or "s", table.concat(names, ", ")),
				}, box)
			end
		else
			label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 22), Text = "Game passes (Robux)", TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left }, list)
			for i, key in GameData.PassOrder do
				local pass = GameData.GamePasses[key]
				local owned = player:GetAttribute("Pass_" .. key) == true
				local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -8, 0, 78), BackgroundColor3 = CARD }, list)
				round(row, 12)
				new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, row)
				label({ Size = UDim2.new(0.65, 0, 0.5, 0), Text = pass.name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, row)
				label({ Position = UDim2.fromScale(0, 0.52), Size = UDim2.new(0.65, 0, 0.42, 0), Text = pass.description, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left }, row)
				local text, color = ("R$ %d"):format(pass.price), GREEN
				if owned then
					text, color = "Owned", GREY
				elseif not pass.id or pass.id == 0 then
					text, color = "Coming soon", GREY
				end
				button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.3, 0, 0.8, 0), AutoButtonColor = color == GREEN }, text, color, row, function()
					if not owned and pass.id and pass.id > 0 then
						MarketplaceService:PromptGamePassPurchase(player, pass.id)
					end
				end)
			end
			-- one-time boosts (developer products)
			label({ LayoutOrder = 100, Size = UDim2.new(1, 0, 0, 22), Text = "Boosts (Robux each time you use one)", TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left }, list)
			for i, key in GameData.ProductOrder do
				local prod = GameData.Products[key]
				local row = new("Frame", { LayoutOrder = 100 + i, Size = UDim2.new(1, -8, 0, 78), BackgroundColor3 = CARD }, list)
				round(row, 12)
				new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, row)
				label({ Size = UDim2.new(0.65, 0, 0.45, 0), Text = prod.name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, row)
				new("TextLabel", {
					Position = UDim2.fromScale(0, 0.48), Size = UDim2.new(0.65, 0, 0.52, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
					TextSize = 13, TextWrapped = true, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = prod.description,
				}, row)
				local ready = prod.id and prod.id > 0
				button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.3, 0, 0.8, 0), AutoButtonColor = ready },
					ready and ("R$ %d"):format(prod.price) or "Coming soon", ready and BLUE or GREY, row, function()
						if ready then
							MarketplaceService:PromptProductPurchase(player, prod.id)
						end
					end)
			end
		end
	end
	refreshers.Shop = function()
		status.Text = ""
		refresh()
	end
	for key in GameData.GamePasses do
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(function()
			if w.frame.Visible then
				refresh()
			end
		end)
	end
	for _, attr in { "Inventory", "Coins", "Badges" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if w.frame.Visible then
				refresh()
			end
		end)
	end
	OpenShop.OnClientEvent:Connect(function()
		if openName ~= "Shop" then
			tab = "items"
			openWindow("Shop")
		end
	end)
end

-- Daily streak pop-up --------------------------------------------------------------------
Daily.OnClientEvent:Connect(function(kind, data)
	if kind ~= "streak" then
		return
	end
	task.wait(player:GetAttribute("InCutscene") and 1 or 0)
	while player:GetAttribute("InCutscene") do
		task.wait(0.5)
	end
	local pop = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = PANEL, ZIndex = 10,
	}, gui)
	round(pop, 18)
	new("UIStroke", { Color = GOLD, Thickness = 3 }, pop)
	label({ Position = UDim2.fromScale(0.05, 0.08), Size = UDim2.fromScale(0.9, 0.22), Text = ("Daily Reward · Day %d!"):format(data.streak), TextColor3 = GOLD, ZIndex = 11 }, pop)
	label({ Position = UDim2.fromScale(0.05, 0.34), Size = UDim2.fromScale(0.9, 0.26), Text = ("+%d coins"):format(data.coins) .. (data.apex and " + 1 Apex Ball" or ""), ZIndex = 11 }, pop)
	label({ Position = UDim2.fromScale(0.05, 0.62), Size = UDim2.fromScale(0.9, 0.12), ZIndex = 11, TextColor3 = MUTED,
		Text = (data.cycleDay or (((data.streak - 1) % 7) + 1)) == 6 and "Tomorrow: guaranteed Apex Ball!" or "A guaranteed Apex Ball every seventh consecutive login." }, pop)
	button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.94), Size = UDim2.fromScale(0.4, 0.16), ZIndex = 11 }, "Nice!", GREEN, pop, function()
		pop:Destroy()
	end)
	TweenService:Create(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(380, 220) }):Play()
	task.delay(10, function()
		if pop.Parent then
			pop:Destroy()
		end
	end)
end)

-- Incoming requests ------------------------------------------------------------------------
local requestHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140), Size = UDim2.fromOffset(420, 300), BackgroundTransparency = 1,
}, gui)
new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }, requestHolder)

local function incoming(data)
	local card = new("Frame", { Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = PANEL }, requestHolder)
	round(card, 14)
	new("UIStroke", { Color = data.kind == "trade" and Color3.fromRGB(235, 165, 40) or RED, Thickness = 3 }, card)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, card)
	label({ Size = UDim2.new(1, 0, 0, 30), Text = ("%s wants to %s!"):format(data.from, data.kind == "trade" and "trade" or "battle you") }, card)
	local timer = label({ Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 16), Text = "", TextColor3 = MUTED }, card)
	local answered = false
	local function answer(yes: boolean)
		if answered then
			return
		end
		answered = true
		Social:FireServer("respond", data.id, yes)
		card:Destroy()
	end
	button({ Position = UDim2.new(0, 0, 1, -36), Size = UDim2.new(0.48, 0, 0, 36) }, "Accept", GREEN, card, function()
		answer(true)
	end)
	button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 1, -36), Size = UDim2.new(0.48, 0, 0, 36) }, "Decline", RED, card, function()
		answer(false)
	end)
	task.spawn(function()
		for s = 30, 1, -1 do
			if not card.Parent then
				return
			end
			timer.Text = ("Expires in %ds"):format(s)
			task.wait(1)
		end
		if card.Parent then
			answered = true
			card:Destroy()
		end
	end)
end

-- Trade window -------------------------------------------------------------------------------
local trade = {}
do
	local w = makeWindow("Trade", "Trade", Color3.fromRGB(235, 165, 40))
	local frame, body = w.frame, w.body
	-- the X cancels the trade
	for _, c in frame:GetChildren() do
		if c:IsA("TextButton") and c.Text == "X" then
			c.Activated:Connect(function()
				Social:FireServer("cancel")
			end)
		end
	end
	local titleLabel = frame:FindFirstChildOfClass("TextLabel")

	local left = new("Frame", { Size = UDim2.new(0.5, -6, 1, -50), BackgroundTransparency = 1 }, body)
	label({ Size = UDim2.new(1, 0, 0, 22), Text = "Your team (tap to offer)", TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left }, left)
	local teamScroll = new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 1, -26), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, left)
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 48), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, teamScroll)

	local right = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, -6, 1, -50), BackgroundTransparency = 1 }, body)
	local function offerBox(y: number, titleText: string)
		label({ Position = UDim2.new(0, 0, y, 0), Size = UDim2.new(1, 0, 0, 22), Text = titleText, TextXAlignment = Enum.TextXAlignment.Left }, right)
		local box = new("Frame", { Position = UDim2.new(0, 0, y, 26), Size = UDim2.new(1, 0, 0.5, -56), BackgroundColor3 = Color3.fromRGB(20, 22, 32) }, right)
		round(box, 10)
		new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, box)
		new("UIListLayout", { Padding = UDim.new(0, 4) }, box)
		local status = label({ Position = UDim2.new(0, 0, y + 0.5, -28), Size = UDim2.new(1, 0, 0, 20), Text = "", TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left }, right)
		return box, status
	end
	local myBox, myStatus = offerBox(0, "You offer")
	local theirBox, theirStatus = offerBox(0.5, "They offer")

	local readyButton = button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(0.32, 0, 0, 42) }, "Ready", BLUE, body)
	local acceptButton = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(0.32, 0, 0, 42) }, "Accept", GREY, body)
	button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.new(0.32, 0, 0, 42) }, "Cancel", RED, body, function()
		Social:FireServer("cancel")
	end)

	local state = nil
	local function creatureText(c)
		return (c.shiny and "★ " or "") .. ("%s Lv%d"):format(c.name, c.level) .. ((c.sizeClass and c.sizeClass ~= "Normal") and (" · " .. c.sizeClass) or "")
	end
	local function fillBox(box, list)
		for _, c in box:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		if #list == 0 then
			label({ Size = UDim2.new(1, 0, 0, 24), Text = "Nothing yet", TextColor3 = MUTED }, box)
		end
		for _, c in list do
			local held = c.held and GameData.Items[c.held] and GameData.Items[c.held].name or "None"
			local ivs = c.ivs and ("IV %d/%d/%d/%d"):format(c.ivs.hp or 0, c.ivs.atk or 0, c.ivs.def or 0, c.ivs.spd or 0) or ""
			local l = label({ Size = UDim2.new(1, 0, 0, 38), Text = creatureText(c) .. "\nHeld: " .. held .. " · " .. ivs, TextWrapped = true, TextColor3 = c.shiny and GOLD or WHITE, TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 0, BackgroundColor3 = CARD }, box)
			round(l, 6)
		end
	end

	local function render()
		if not state then
			return
		end
		titleLabel.Text = state.countdown and ("Confirming trade · %ds · Cancel anytime"):format(state.countdown) or ("Trade with " .. state.partner)
		local offered = {}
		for _, c in state.myOffer do
			offered[c.id] = true
		end
		for _, c in teamScroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, c in state.myTeam do
			local on = offered[c.id]
			local b = button({ LayoutOrder = i }, creatureText(c), on and Color3.fromRGB(235, 165, 40) or CARD, teamScroll, function()
				if state.countdown or state.myReady then return end
				local ids = {}
				for id in offered do
					if id ~= c.id then
						table.insert(ids, id)
					end
				end
				if not on then
					if #ids >= state.max then
						return
					end
					table.insert(ids, c.id)
				end
				Social:FireServer("offer", ids)
			end)
			b.TextColor3 = c.shiny and GOLD or WHITE
		end
		fillBox(myBox, state.myOffer)
		fillBox(theirBox, state.theirOffer)
		myStatus.Text = state.myAccepted and "You accepted" or (state.myReady and "You're ready" or "Not ready")
		theirStatus.Text = state.theirAccepted and "They accepted" or (state.theirReady and "They're ready" or "Not ready")
		readyButton.Text = state.myReady and "Unlock offer" or "Lock offer"
		local bothReady = state.myReady and state.theirReady
		acceptButton.BackgroundColor3 = (bothReady and not state.myAccepted) and GREEN or GREY
		acceptButton.Text = state.countdown and ("%ds..."):format(state.countdown) or (state.myAccepted and "Confirmed" or "Confirm again")
	end
	readyButton.Activated:Connect(function()
		if state then
			Social:FireServer("ready", not state.myReady, state.version)
		end
	end)
	acceptButton.Activated:Connect(function()
		if state and not state.countdown and state.myReady and state.theirReady and not state.myAccepted then
			Social:FireServer("accept", state.version)
		end
	end)

	function trade.update(s)
		state = s
		for n, win in windows do
			if n ~= "Trade" then
				win.frame.Visible = false
			end
		end
		openName = "Trade"
		frame.Visible = true
		render()
	end
	function trade.close()
		state = nil
		frame.Visible = false
		if openName == "Trade" then
			openName = nil
		end
	end
end

Social.OnClientEvent:Connect(function(kind, data)
	if kind == "incoming" then
		incoming(data)
	elseif kind == "trade" then
		trade.update(data)
	elseif kind == "tradeClosed" then
		trade.close()
	end
end)

-- Trade Center board, guide and showcase picker.
do
	local board = makeWindow("TradeBoard", "Trade Center · Looking for / Offering", GOLD)
	local intro = label({ Size = UDim2.new(1, 0, 0, 32), Text = "Offers are invitations. Meet the trainer before confirming a trade.", TextColor3 = MUTED }, board.body)
	local looking = new("TextBox", { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(0.6, -6, 0, 38), BackgroundColor3 = CARD,
		Font = Enum.Font.GothamMedium, TextSize = 16, TextColor3 = WHITE, PlaceholderText = "Looking for a species, e.g. Nibbit", Text = "", ClearTextOnFocus = false }, board.body)
	round(looking, 8)
	local list = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 1, -88), BackgroundTransparency = 1,
		BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6 }, board.body)
	new("UIListLayout", { Padding = UDim.new(0, 6) }, list)
	local boardData, selected = { listings = {}, team = {} }, nil
	local status = label({ Position = UDim2.new(0.6, 0, 0, 38), Size = UDim2.new(0.4, 0, 0, 38), Text = "Choose your offer below", TextColor3 = MUTED }, board.body)
	local function rebuildBoard()
		for _, child in list:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
		label({ Size = UDim2.new(1, -8, 0, 24), Text = "Choose a creature you own to post", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, list)
		for _, c in boardData.team or {} do
			button({ Size = UDim2.new(1, -8, 0, 34) }, (selected == c.id and "✓ " or "") .. c.name .. " Lv" .. c.level, selected == c.id and BLUE or CARD, list, function() selected = c.id; status.Text = "Offering " .. c.name; rebuildBoard() end)
		end
		button({ Size = UDim2.new(1, -8, 0, 36) }, "Post selected offer", GREEN, list, function()
			local species = looking.Text:match("^%s*(.-)%s*$")
			if not selected or not GameData.Creatures[species] then status.Text = "Choose an offer and a real species name"; return end
			Social:FireServer("post", selected, species)
		end)
		button({ Size = UDim2.new(1, -8, 0, 30) }, "Remove my listing", GREY, list, function() Social:FireServer("unpost") end)
		label({ Size = UDim2.new(1, -8, 0, 28), Text = "Community offers · tap a trainer to request", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, list)
		for _, r in boardData.listings or {} do
			button({ Size = UDim2.new(1, -8, 0, 48) }, r.trainer .. " · Offering " .. (r.offering.shiny and "★ " or "") .. r.offering.name .. " Lv" .. r.offering.level .. "\nLooking for " .. r.looking, CARD, list, function() Social:FireServer("request", r.userId, "trade") end)
		end
	end
	local guide = makeWindow("TradeGuide", "Mara · Safe trading", GOLD)
	label({ Size = UDim2.new(1, 0, 1, -50), Text = "", TextScaled = false, TextSize = 19, Font = Enum.Font.GothamMedium, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top }, guide.body).Name = "GuideText"
	button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 40) }, "I understand", GREEN, guide.body, function() guide.frame.Visible = false end)
	local showcase = makeWindow("Showcase", "Choose a Shiny or Huge creature", GOLD)
	local showList = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6 }, showcase.body)
	new("UIListLayout", { Padding = UDim.new(0, 8) }, showList)
	Social.OnClientEvent:Connect(function(kind, data)
		if kind == "board" then boardData = data; rebuildBoard(); openWindow("TradeBoard")
		elseif kind == "boardRefresh" then boardData.listings = data; if board.frame.Visible then rebuildBoard() end
		elseif kind == "guide" then guide.body.GuideText.Text = data; openWindow("TradeGuide")
		elseif kind == "showcase" then
			for _, child in showList:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
			local count = 0
			for _, c in data.team do
				if c.shiny or c.sizeClass == "Huge" then
					count += 1
					button({ Size = UDim2.new(1, -8, 0, 48) }, (c.shiny and "★ " or "") .. c.name .. " Lv" .. c.level .. " · " .. (c.sizeClass or "Normal"), CARD, showList, function() Social:FireServer("display", c.id, data.slot); showcase.frame.Visible = false end)
				end
			end
			if count == 0 then label({ Size = UDim2.new(1, -8, 0, 80), Text = "Catch a Shiny or Huge creature, then show it here!", TextWrapped = true }, showList) end
			openWindow("Showcase")
		end
	end)
end

-- Evolution animation ----------------------------------------------------------------------
local function viewport(parent, c)
	local vp = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 180), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-0.5, -1, -0.7),
	}, parent)
	local model = CreatureBuilder.build(c.name, c.level, { shiny = c.shiny, sizeClass = c.sizeClass })
	for _, d in model:GetDescendants() do
		if d:IsA("BillboardGui") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	model:PivotTo(CFrame.Angles(0, math.rad(-25), 0))
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude * 0.5
	local cam = new("Camera", { FieldOfView = 40 }, vp)
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, radius * 0.35, -radius * 2.6), cf.Position)
	vp.CurrentCamera = cam
	return vp, model
end

local evolveQueue = {}
local evolving = false
local function playEvolution(before, after)
	-- reaches up over the top bar inset too
	local overlay = new("Frame", { Position = UDim2.fromOffset(0, -80), Size = UDim2.new(1, 0, 1, 80), BackgroundColor3 = Color3.fromRGB(10, 8, 20), BackgroundTransparency = 1, ZIndex = 20 }, gui)
	TweenService:Create(overlay, TweenInfo.new(0.5), { BackgroundTransparency = 0.15 }):Play()
	local stage = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(320, 320), BackgroundTransparency = 1, ZIndex = 21 }, overlay)
	local text = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromOffset(600, 50), ZIndex = 22, Text = ("What? %s is evolving!"):format(before.name) }, overlay)
	new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(40, 20, 70) }, text)
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 23 }, overlay)

	local vp1 = viewport(stage, before)
	vp1.ZIndex = 21
	task.wait(1)
	-- pulse faster and faster, flashing white
	local interval = 0.45
	for _ = 1, 7 do
		TweenService:Create(vp1, TweenInfo.new(interval / 2), { ImageTransparency = 0.7 }):Play()
		task.wait(interval / 2)
		TweenService:Create(vp1, TweenInfo.new(interval / 2), { ImageTransparency = 0 }):Play()
		task.wait(interval / 2)
		interval *= 0.8
	end
	flash.BackgroundTransparency = 0
	vp1:Destroy()
	local vp2 = viewport(stage, after)
	vp2.ZIndex = 21
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	text.Text = ("%s evolved into %s!"):format(before.name, after.name)
	text.TextColor3 = GOLD
	task.wait(2.4)
	TweenService:Create(overlay, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	text:Destroy()
	vp2:Destroy()
	task.wait(0.5)
	overlay:Destroy()
end

Evolve.OnClientEvent:Connect(function(before, after)
	table.insert(evolveQueue, { before, after })
	if evolving then
		return
	end
	evolving = true
	while #evolveQueue > 0 do
		local e = table.remove(evolveQueue, 1)
		local ok, err = pcall(playEvolution, e[1], e[2])
		if not ok then
			warn("Evolution animation:", err)
		end
	end
	evolving = false
end)

-- Rare spawn timer -------------------------------------------------------------------------
do
	local pill = label({
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.fromOffset(260, 28),
		BackgroundTransparency = 0.25, BackgroundColor3 = Color3.fromRGB(25, 25, 35), TextColor3 = GOLD,
	}, gui)
	round(pill, 999)
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, pill)
	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			local ends = ReplicatedStorage:GetAttribute("RareEventEnds")
			local nextAt = ReplicatedStorage:GetAttribute("RareEventNext")
			-- hidden in battles, the intro, and the tutorial (its objective banner sits here)
			local hidden = player:GetAttribute("InBattle") or player:GetAttribute("InCutscene")
				or player:GetAttribute("TutorialStep") ~= "done"
			if ends and ends > now then
				local left = math.floor(ends - now)
				pill.Text = ("★ RARE %s: %d:%02d left"):format(ReplicatedStorage:GetAttribute("RareEventName") or "spawn", left // 60, left % 60)
				pill.BackgroundColor3 = Color3.fromRGB(120, 80, 10)
				pill.Visible = not hidden
			elseif nextAt then
				local left = math.max(0, math.floor(nextAt - now))
				pill.Text = ("Rare spawn in %d:%02d"):format(left // 60, left % 60)
				pill.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
				pill.Visible = not hidden
			else
				pill.Visible = false
			end
			task.wait(0.5)
		end
	end)
end
