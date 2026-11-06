--[[
	BattleUI: the battle screen. Classic layout: your creature front-left with you behind it, the
	opponent further off to the right. The opponent's HP card is at the top left, yours sits just
	above the bottom panel on the right. Each card shows a status badge (BRN, PSN, PAR, SLP, FRZ) and
	a row of stat-change pills (ATK ▲2, DEF ▼1...). The bottom panel holds the battle text and
	Fight / Bag / Switch / Run. Animations come from BattleFX.
	Move buttons are colour-coded:
	  green = super effective, red = not very effective,
	  black outline = no effect, white outline = normal, purple = status move.
	Each move also says it in words for colourblind players.
	During the tutorial battle, the server sends a hint ("fight" or "catch") and the other
	buttons are locked while the right one pulses.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BattleEvent = Remotes:WaitForChild("BattleEvent")
local BattleAction = Remotes:WaitForChild("BattleAction")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared:WaitForChild("GameData"))
local BattleData = require(Shared:WaitForChild("BattleData"))
local BattleFX = require(script.Parent:WaitForChild("BattleFX"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 215, 80)
local LINE_TIME = 1.1

local function new(className: string, props, parent)
	local inst = Instance.new(className)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function round(inst, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, inst)
end

local function pad(inst, px)
	new("UIPadding", {
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
	}, inst)
end

local function label(props, parent)
	local p = { BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE }
	for k, v in props do
		p[k] = v
	end
	return new("TextLabel", p, parent)
end

local function hex(c: Color3): string
	return c:ToHex()
end

-- Layout -----------------------------------------------------------------

local gui = new("ScreenGui", {
	Name = "BattleUI", ResetOnSpawn = false, Enabled = false, DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.96, 0, 0.3, 0), BackgroundColor3 = Color3.fromRGB(28, 30, 42), BackgroundTransparency = 0.06,
}, gui)
round(panel, 16)
pad(panel, 10)
new("UISizeConstraint", { MaxSize = Vector2.new(760, 230) }, panel)

local logLabel = label({
	Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.24),
	TextXAlignment = Enum.TextXAlignment.Left, Text = "",
}, panel)

local buttonArea = new("Frame", {
	Position = UDim2.fromScale(0, 0.3), Size = UDim2.fromScale(1, 0.7), BackgroundTransparency = 1,
}, panel)
local grid = new("UIGridLayout", {
	CellPadding = UDim2.new(0, 8, 0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, buttonArea)

-- Scrolling list for long menus (the bag), in the same spot as the buttons
local listArea = new("ScrollingFrame", {
	Position = UDim2.fromScale(0, 0.3), Size = UDim2.fromScale(1, 0.7), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, panel)
new("UIGridLayout", {
	CellPadding = UDim2.new(0, 8, 0, 8), CellSize = UDim2.new(1 / 3, -10, 0, 58), SortOrder = Enum.SortOrder.LayoutOrder,
}, listArea)

-- HP cards in fixed screen corners: the opponent's top left, yours just above the panel on the right.
local STAT_UP = Color3.fromRGB(230, 80, 65)
local STAT_DOWN = Color3.fromRGB(70, 135, 240)

local function makeCard(guiName: string, parent: Instance, anchor: Vector2, position: UDim2, showXP: boolean)
	local card = new("Frame", {
		Name = guiName, AnchorPoint = anchor, Position = position, Size = UDim2.fromOffset(290, showXP and 112 or 104),
		BackgroundColor3 = Color3.fromRGB(28, 30, 42), BackgroundTransparency = 0.06, Visible = false, ZIndex = 2,
	}, parent)
	round(card, 12)
	new("UIStroke", { Color = WHITE, Transparency = 0.7, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
	}, card)
	local name = label({ Size = UDim2.new(1, -60, 0, 26), TextXAlignment = Enum.TextXAlignment.Left }, card)
	local status = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 3), Size = UDim2.fromOffset(52, 20),
		Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "", Visible = false,
	}, card)
	round(status, 6)
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, status)
	local types = label({
		Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
	}, card)
	local barBack = new("Frame", {
		Position = UDim2.fromOffset(0, 49), Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = Color3.fromRGB(15, 15, 20),
	}, card)
	round(barBack, 6)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(80, 200, 100) }, barBack)
	round(fill, 6)
	-- stat-change pills (left) and HP numbers (right) share the bottom row
	local stages = new("Frame", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(0.7, 0, 0, 20), BackgroundTransparency = 1 }, card)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, stages)
	local hp = label({
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 66), Size = UDim2.new(0.32, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(205, 205, 215),
	}, card)
	local xpBack = new("Frame", {
		Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(15, 15, 20), Visible = false,
	}, card)
	round(xpBack, 6)
	local xpFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(90, 170, 255) }, xpBack)
	round(xpFill, 6)
	return { gui = card, name = name, types = types, fill = fill, hp = hp, xpBack = xpBack, xpFill = xpFill, status = status, stages = stages }
end

local allyCard = makeCard("AllyHP", panel, Vector2.new(1, 1), UDim2.new(1, 0, 0, -12), true)
local wildCard = makeCard("WildHP", gui, Vector2.new(0, 0), UDim2.new(0, 16, 0, 64), false)

-- Show a card once its creature is in battle. Cards only hide when the battle ends, so a model
-- that is still streaming in never makes a card blink out.
local function attachCard(card, _model)
	card.gui.Visible = true
end

-- Status badge next to the name
local function setStatus(card, status: string?)
	local s = status and GameData.StatusInfo[status]
	card.status.Visible = s ~= nil
	if s then
		card.status.Text = s.short
		card.status.BackgroundColor3 = s.color
	end
end

-- Stat-change pills: ATK ▲2 (red = raised), DEF ▼1 (blue = lowered). Nothing shown at 0.
local function setStages(card, stages)
	for _, c in card.stages:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	if not stages then
		return
	end
	for i, stat in { "atk", "def", "spd" } do
		local v = stages[stat] or 0
		if v ~= 0 then
			local pill = new("TextLabel", {
				LayoutOrder = i, Size = UDim2.fromOffset(58, 20), BackgroundColor3 = v > 0 and STAT_UP or STAT_DOWN,
				Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = WHITE,
				Text = ("%s %s%d"):format(BattleData.StatShort[stat], v > 0 and "\u{25B2}" or "\u{25BC}", math.abs(v)),
			}, card.stages)
			round(pill, 6)
			new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, pill)
		end
	end
end

-- What the cards currently show, so stat changes can be added up during a turn
local function zeroStages()
	return { atk = 0, def = 0, spd = 0 }
end
local shownStages = { ally = zeroStages(), wild = zeroStages() }

-- State ------------------------------------------------------------------

local current = nil -- latest battle state from the server
local busy = false -- true while waiting for the server or playing the log
local showMenu

local function setColumns(cols: number)
	grid.CellSize = UDim2.new(1 / cols, -8 * (cols - 1) / cols, 0.5, -4)
end

local function clearButtons()
	for _, area in { buttonArea, listArea } do
		for _, child in area:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
	end
	listArea.Visible = false
	listArea.CanvasPosition = Vector2.zero
	buttonArea.Visible = true
end

-- Switch the panel to the scrolling list (for menus with many entries)
local function useList()
	buttonArea.Visible = false
	listArea.Visible = true
end

local function inventory()
	local HttpService = game:GetService("HttpService")
	local ok, data = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Inventory") or "{}")
	return (ok and typeof(data) == "table") and data or {}
end

local function act(action: string, arg)
	if busy then
		return
	end
	busy = true
	clearButtons()
	BattleAction:FireServer(action, arg)
end

local function button(order: number, title: string, subtitle: string?, color: Color3, onClick, strokeColor: Color3?, parent: Instance?)
	local b = new("TextButton", { LayoutOrder = order, Text = "", AutoButtonColor = true, BackgroundColor3 = color }, parent or buttonArea)
	round(b, 10)
	pad(b, 4)
	if strokeColor then
		new("UIStroke", { Color = strokeColor, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	end
	label({ Size = UDim2.fromScale(1, subtitle and 0.6 or 1), Text = title }, b)
	if subtitle then
		label({
			Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4),
			Text = subtitle, TextColor3 = Color3.fromRGB(235, 235, 235),
		}, b)
	end
	b.Activated:Connect(function()
		if not busy then
			onClick()
		end
	end)
	return b
end

-- Greyed-out, unclickable button (used to lock buttons during the tutorial)
local function lockButton(b: GuiButton)
	b.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
	b.AutoButtonColor = false
	b.Active = false
	for _, c in b:GetChildren() do
		if c:IsA("TextLabel") then
			c.TextTransparency = 0.5
		end
	end
end

-- Pulsing gold outline to point at the button the tutorial wants you to press
local function pulse(b: GuiButton)
	local stroke = new("UIStroke", { Color = GOLD, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	TweenService:Create(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 1 }):Play()
end

local function moveStyle(move)
	if move.status then
		return Color3.fromRGB(120, 85, 175), "Status", nil
	end
	local mult = move.mult
	if mult == 0 then
		return Color3.fromRGB(95, 95, 100), "No effect", Color3.new(0, 0, 0)
	elseif mult > 1 then
		return Color3.fromRGB(55, 165, 85), mult >= 4 and "Super effective x4" or "Super effective", nil
	elseif mult < 1 then
		return Color3.fromRGB(185, 65, 65), "Not very effective", nil
	end
	return Color3.fromRGB(70, 75, 98), "Normal", WHITE
end

local function promptText(): string
	if not current then
		return ""
	end
	if current.waiting then
		return "Waiting for your opponent..."
	elseif current.mustSwitch then
		return "Choose your next creature!"
	elseif current.tutorialHint == "fight" then
		return "Tap Fight, then use Tackle to attack!"
	elseif current.tutorialHint == "catch" then
		return "It's weakened! Tap Bag to throw a Loop Ball!"
	end
	return ("What will %s do?"):format(current.ally.name)
end

function showMenu(kind: string, extra)
	clearButtons()
	if not current then
		return
	end
	local hint = current.tutorialHint
	if kind == "main" then
		setColumns(2)
		local fight = button(1, "Fight", nil, Color3.fromRGB(225, 95, 60), function()
			if not hint or hint == "fight" then
				showMenu("fight")
			end
		end)
		-- Bag: balls (wild battles) and medicine. During the tutorial it throws the Loop Ball straight away.
		local catch = button(2, "Bag", current.pvp and "Not in PvP" or (current.trainer and "Medicine" or "Balls & medicine"), Color3.fromRGB(215, 50, 50), function()
			if hint == "catch" then
				act("catch", "LoopBall")
			elseif not hint and not current.pvp then
				showMenu("bag")
			end
		end)
		if current.pvp then
			lockButton(catch)
		end
		local switch = button(3, "Switch", nil, Color3.fromRGB(70, 130, 220), function()
			if not hint then
				showMenu("switch")
			end
		end)
		local run = button(4, current.trainer and "Forfeit" or "Run", current.noRun and "Can't escape!" or nil, Color3.fromRGB(100, 100, 115), function()
			if not hint and not current.noRun then
				act("run")
			end
		end)
		if current.noRun then
			lockButton(run)
		end
		if hint == "fight" then
			pulse(fight)
			lockButton(catch)
			lockButton(switch)
			lockButton(run)
		elseif hint == "catch" then
			pulse(catch)
			lockButton(fight)
			lockButton(switch)
			lockButton(run)
		end
	elseif kind == "fight" then
		setColumns(3)
		for i, move in current.moves do
			local bg, effect, stroke = moveStyle(move)
			local b = button(i, move.name, move.type .. " · " .. effect, bg, function()
				if not hint or move.name == "Tackle" then
					act("fight", move.name)
				end
			end, stroke)
			if hint == "fight" then
				if move.name == "Tackle" then
					pulse(b)
				else
					lockButton(b)
				end
			end
		end
		button(10, "Back", nil, Color3.fromRGB(60, 60, 72), function()
			showMenu("main")
		end)
	elseif kind == "bag" then
		-- two pockets: Balls (wild battles only) and Medicine
		setColumns(3)
		local inv = inventory()
		local balls, meds = 0, 0
		for _, id in GameData.ballOrder() do
			if inv[id] and inv[id] ~= 0 then
				balls += 1
			end
		end
		for _, id in GameData.medicineOrder() do
			if inv[id] and inv[id] > 0 then
				meds += 1
			end
		end
		local ballButton = button(1, "Balls", current.trainer and "Wild battles only" or ("%d kind%s"):format(balls, balls == 1 and "" or "s"), Color3.fromRGB(215, 50, 50), function()
			if not current.trainer then
				showMenu("bagBalls")
			end
		end)
		if current.trainer then
			lockButton(ballButton)
		end
		button(2, "Medicine", meds == 0 and "Empty" or ("%d kind%s"):format(meds, meds == 1 and "" or "s"), Color3.fromRGB(70, 165, 105), function()
			showMenu("bagMeds")
		end)
		local boosts = 0
		for _, id in GameData.battleItemOrder() do
			if inv[id] and inv[id] > 0 then
				boosts += 1
			end
		end
		button(3, "Draughts", boosts == 0 and "Empty" or "Stat boosts", Color3.fromRGB(190, 120, 50), function()
			showMenu("bagBoosts")
		end)
		button(4, "Back", nil, Color3.fromRGB(60, 60, 72), function()
			logLabel.Text = promptText()
			showMenu("main")
		end)
	elseif kind == "bagBalls" then
		useList()
		local inv = inventory()
		logLabel.Text = current.canCatch and "Which ball? (the number is your catch bonus right now)" or "Your base is full! Make room before catching more."
		button(0, "\u{2190} Back", nil, Color3.fromRGB(60, 60, 72), function()
			logLabel.Text = promptText()
			showMenu("bag")
		end, nil, listArea)
		local ctx = {
			turn = current.turn or 0, allyLevel = current.ally.level, wildLevel = current.wild.level,
			wildName = current.wild.name, wildSize = current.wild.sizeClass,
		}
		for i, id in GameData.ballOrder() do
			local ball = GameData.Balls[id]
			local count = inv[id]
			if count and count ~= 0 then
				local mult = GameData.ballMultiplier(id, ctx)
				local b = button(i, ball.name, ("%s · Catch x%s"):format(count < 0 and "∞" or ("x" .. count), ("%g"):format(mult)), ball.color, function()
					if current.canCatch then
						act("catch", id)
					end
				end, mult > (ball.multiplier or 1) and GOLD or nil, listArea)
				if not current.canCatch then
					lockButton(b)
				end
			end
		end
	elseif kind == "bagBoosts" then
		useList()
		local inv = inventory()
		local n = 0
		button(0, "\u{2190} Back", nil, Color3.fromRGB(60, 60, 72), function()
			logLabel.Text = promptText()
			showMenu("bag")
		end, nil, listArea)
		for i, id in GameData.battleItemOrder() do
			local item = GameData.Items[id]
			local count = inv[id]
			if count and count > 0 then
				n += 1
				button(i, item.name, ("x%d · %s"):format(count, GameData.itemSummary(id)), item.color, function()
					act("item", { id = id, target = current.allyId })
				end, nil, listArea)
			end
		end
		logLabel.Text = n == 0 and "No draughts! Clerk Milo sells them once you have a badge." or ("Boost %s? (it uses your turn)"):format(current.ally.name)
	elseif kind == "bagMeds" then
		useList()
		local inv = inventory()
		local n = 0
		button(0, "\u{2190} Back", nil, Color3.fromRGB(60, 60, 72), function()
			logLabel.Text = promptText()
			showMenu("bag")
		end, nil, listArea)
		for i, id in GameData.medicineOrder() do
			local item = GameData.Items[id]
			local count = inv[id]
			if count and count > 0 then
				n += 1
				button(i, item.name, ("x%d · %s"):format(count, GameData.itemSummary(id)), item.color, function()
					showMenu("medTarget", id)
				end, nil, listArea)
			end
		end
		logLabel.Text = n == 0 and "No medicine! Buy some from Clerk Milo." or "Use which medicine? (it uses your turn)"
	elseif kind == "medTarget" then
		useList()
		local item = GameData.Items[extra]
		logLabel.Text = ("Use %s on which creature?"):format(item.name)
		button(0, "\u{2190} Back", nil, Color3.fromRGB(60, 60, 72), function()
			showMenu("bagMeds")
		end, nil, listArea)
		for i, c in current.team do
			local fainted = c.hp <= 0
			local curable = item.cure ~= nil and c.status ~= nil and (item.cure == "all" or item.cure == c.status)
			local usable = (item.revive and fainted) or (not item.revive and not fainted and ((item.heal and c.hp < c.maxHP) or curable))
			local s = c.status and GameData.StatusInfo[c.status]
			local sub = (fainted and "Fainted" or ("HP %d/%d"):format(c.hp, c.maxHP)) .. (s and (" · " .. s.short) or "")
			button(i, (c.shiny and "★ " or "") .. ("%s Lv%d"):format(c.name, c.level), sub,
				usable and item.color or Color3.fromRGB(60, 60, 70), function()
					if usable then
						act("item", { id = extra, target = c.id })
					end
				end, nil, listArea)
		end
	elseif kind == "switch" then
		setColumns(4)
		for i, c in current.team do
			local active = c.id == current.allyId
			local fainted = c.hp <= 0
			local sub = active and "In battle" or (fainted and "Fainted" or ("HP %d/%d"):format(c.hp, c.maxHP))
			local bg = (active or fainted) and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(70, 130, 220)
			button(i, (c.shiny and "★ " or "") .. ("%s Lv%d"):format(c.name, c.level) .. string.rep("⭐", c.stars or 0), sub, bg, function()
				if not active and not fainted then
					act("switch", c.id)
				end
			end)
		end
		if not current.mustSwitch then
			button(20, "Back", nil, Color3.fromRGB(60, 60, 72), function()
				showMenu("main")
			end)
		end
	end
end

local function hpColor(f: number): Color3
	if f > 0.5 then
		return Color3.fromRGB(80, 200, 100)
	elseif f > 0.2 then
		return Color3.fromRGB(240, 190, 50)
	end
	return Color3.fromRGB(225, 70, 60)
end

local function setCardHP(card, hp: number, maxHP: number)
	local f = math.clamp(hp / maxHP, 0, 1)
	TweenService:Create(card.fill, TweenInfo.new(0.4), { Size = UDim2.fromScale(f, 1), BackgroundColor3 = hpColor(f) }):Play()
	card.hp.Text = ("HP %d/%d"):format(hp, maxHP)
end

local function typeText(c): string
	local parts = {}
	for _, t in { c.type, c.type2 } do
		if t then
			local col = BattleData.TypeColors[t] or WHITE
			table.insert(parts, ('<font color="#%s">%s</font>'):format(hex(col), t))
		end
	end
	local size = (c.sizeClass and c.sizeClass ~= "Normal") and ("  ·  " .. c.sizeClass) or ""
	return table.concat(parts, " / ") .. size
end

local function setCard(card, c, nameColor: Color3?)
	local stars = c.stars or 0
	card.name.Text = (c.shiny and "★ " or "") .. ("%s  Lv %d"):format(c.name, c.level) .. (stars > 0 and (" " .. string.rep("⭐", stars)) or "")
	card.name.TextColor3 = c.shiny and GOLD or (nameColor or WHITE)
	card.types.Text = typeText(c)
	setCardHP(card, c.hp, c.maxHP)
	setStatus(card, c.status)
	if c.xpFrac then
		card.xpBack.Visible = true
		card.xpFill.Size = UDim2.fromScale(c.xpFrac, 1)
	else
		card.xpBack.Visible = false
	end
end

-- XP bar fills up (wrapping around for each level gained)
local function animateXP(card, from: number, to: number, levels: number)
	card.xpBack.Visible = true
	card.xpFill.Size = UDim2.fromScale(from, 1)
	for _ = 1, levels do
		local t = TweenService:Create(card.xpFill, TweenInfo.new(0.5), { Size = UDim2.fromScale(1, 1) })
		t:Play()
		t.Completed:Wait()
		card.xpFill.Size = UDim2.fromScale(0, 1)
	end
	TweenService:Create(card.xpFill, TweenInfo.new(0.6), { Size = UDim2.fromScale(to, 1) }):Play()
end

local function applyState(s)
	current = s
	setCard(allyCard, s.ally)
	local rarity = GameData.Rarities[s.wild.rarity]
	setCard(wildCard, s.wild, rarity and rarity.color)
	attachCard(allyCard, s.allyModel)
	attachCard(wildCard, s.wildModel)
	shownStages.ally = s.allyStages and table.clone(s.allyStages) or zeroStages()
	shownStages.wild = s.wildStages and table.clone(s.wildStages) or zeroStages()
	setStages(allyCard, shownStages.ally)
	setStages(wildCard, shownStages.wild)
end

-- Floating damage number (and "Super effective!" tag) over the creature that got hit
local function floatDamage(model: Model?, damage: number, mult: number?)
	local root = model and model.Parent and model.PrimaryPart
	if not root or not damage or damage <= 0 then
		return
	end
	local _, size = model:GetBoundingBox()
	local bb = new("BillboardGui", {
		Adornee = root, Size = UDim2.fromOffset(170, 80), StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.5 + 1, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 250,
	}, player:WaitForChild("PlayerGui"))
	local big = mult and mult > 1
	local color = big and Color3.fromRGB(255, 200, 60) or (mult and mult < 1 and Color3.fromRGB(200, 200, 210) or WHITE)
	local num = label({ Size = UDim2.fromScale(1, big and 0.6 or 0.7), Text = "-" .. damage, TextColor3 = color }, bb)
	new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(40, 10, 10) }, num)
	local tag
	if big then
		tag = label({ Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), Text = mult >= 4 and "SUPER EFFECTIVE x4!" or "SUPER EFFECTIVE!", TextColor3 = Color3.fromRGB(120, 255, 140) }, bb)
		new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(10, 40, 15) }, tag)
	elseif mult and mult < 1 then
		tag = label({ Position = UDim2.fromScale(0, 0.7), Size = UDim2.fromScale(1, 0.3), Text = "not very effective", TextColor3 = Color3.fromRGB(190, 190, 200) }, bb)
		new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(20, 20, 25) }, tag)
	end
	num.Size = UDim2.fromScale(0.2, 0.2)
	num.Position = UDim2.fromScale(0.4, 0.2)
	TweenService:Create(num, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromScale(1, big and 0.6 or 0.7), Position = UDim2.fromScale(0, 0) }):Play()
	TweenService:Create(bb, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = bb.StudsOffsetWorldSpace + Vector3.new(0, 2.5, 0) }):Play()
	task.delay(0.8, function()
		for _, l in { num, tag } do
			if l then
				TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
				local s = l:FindFirstChildOfClass("UIStroke")
				if s then
					TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				end
			end
		end
	end)
	task.delay(1.3, function()
		bb:Destroy()
	end)
end

-- Play the battle log line by line with its animations, then show the final state
local function playTurn(entries, state)
	local function modelFor(side: string)
		return side == "ally" and state.allyModel or state.wildModel
	end
	local function cardFor(side: string)
		return side == "ally" and allyCard or wildCard
	end

	for _, entry in entries or {} do
		local text, fx = entry, nil
		if typeof(entry) == "table" then
			text, fx = entry.text, entry.fx
		end
		logLabel.Text = text or ""
		local fxType = fx and fx.type

		if fxType == "attack" then
			local target = fx.side == "ally" and "wild" or "ally"
			if fx.status then
				BattleFX.statusMove(fx.attackerModel or modelFor(fx.side), fx.moveType)
			else
				local defender = fx.defenderModel or modelFor(target)
				BattleFX.attack(fx.attackerModel or modelFor(fx.side), defender, fx, function()
					if fx.hit and fx.targetHp then
						setCardHP(cardFor(target), fx.targetHp, fx.targetMax)
					end
					if fx.hit and fx.damage then
						floatDamage(defender, fx.damage, fx.mult)
						Sfx.play("hit")
					end
				end)
			end
			task.wait(0.3)
		elseif fxType == "stat" then
			local st = shownStages[fx.side]
			if st and fx.stat then
				st[fx.stat] = math.clamp((st[fx.stat] or 0) + (fx.stages or 0), -6, 6)
				setStages(cardFor(fx.side), st)
			end
			BattleFX.statChange(fx.model or modelFor(fx.side), fx.stages)
			task.wait(0.3)
		elseif fxType == "status" then
			-- a status condition starting, stopping a move, or wearing off
			setStatus(cardFor(fx.side), fx.status)
			local s = fx.status and GameData.StatusInfo[fx.status]
			if s then
				BattleFX.statusEffect(fx.model or modelFor(fx.side), s.color)
			end
			task.wait(LINE_TIME * 0.7)
		elseif fxType == "residual" then
			-- burn / poison damage at the end of the turn
			local model = fx.model or modelFor(fx.side)
			if fx.targetHp then
				setCardHP(cardFor(fx.side), fx.targetHp, fx.targetMax)
			end
			floatDamage(model, fx.damage, nil)
			local s = fx.status and GameData.StatusInfo[fx.status]
			BattleFX.statusEffect(model, s and s.color or WHITE)
			task.wait(LINE_TIME * 0.7)
		elseif fxType == "faint" then
			BattleFX.faint(fx.model or modelFor(fx.side))
			task.wait(0.4)
		elseif fxType == "throw" then
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local from = hrp and (hrp.Position + Vector3.new(0, 1.5, 0)) or Vector3.zero
			BattleFX.throw(from, state.wildModel, fx.caught, fx.shakes or 0, fx.ball, function(i, total)
				logLabel.Text = ("%s"):format(string.rep(". ", i)):sub(1, -2) .. (i == total and (fx.caught and "  Click!" or "") or "")
			end)
		elseif fxType == "heal" then
			if fx.targetHp then
				setCardHP(cardFor(fx.side or "ally"), fx.targetHp, fx.targetMax)
			end
			if fx.statusSet then
				setStatus(cardFor(fx.side or "ally"), fx.status)
			end
			BattleFX.levelUp(modelFor(fx.side or "ally"))
			task.wait(LINE_TIME)
		elseif fxType == "levelup" then
			Sfx.play("levelUp")
			BattleFX.levelUp(fx.model or state.allyModel)
			task.wait(0.6)
		elseif fxType == "sendout" then
			local side = fx.side or "ally"
			local creature = fx.creature or (side == "ally" and state.ally or state.wild)
			local model = fx.model or modelFor(side)
			local rarity = side == "wild" and GameData.Rarities[creature.rarity]
			setCard(cardFor(side), creature, rarity and rarity.color or nil)
			attachCard(cardFor(side), model)
			-- a fresh creature starts with no stat changes
			shownStages[side] = zeroStages()
			setStages(cardFor(side), shownStages[side])
			BattleFX.sendOut(model)
			task.wait(0.7)
		elseif fxType == "xp" then
			task.spawn(animateXP, allyCard, fx.from or 0, fx.to or 0, fx.levels or 0)
			task.wait(LINE_TIME)
		else
			task.wait(LINE_TIME)
		end
	end
	if state then
		applyState(state)
	end
end

-- Camera -----------------------------------------------------------------

local camera = workspace.CurrentCamera

local function battleCamera(state)
	local model = state and state.wildModel
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local t0 = os.clock()
	while model and model.Parent and not model.PrimaryPart and os.clock() - t0 < 3 do
		task.wait()
	end
	if not hrp or not model or not model.PrimaryPart then
		return
	end
	local a = hrp.Position
	local dir = state.fieldLook
	if typeof(dir) ~= "Vector3" then
		local b = model.PrimaryPart.Position
		dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	end
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.1 then
		return
	end
	dir = dir.Unit
	local right = dir:Cross(Vector3.yAxis)
	-- behind and to the right of the trainer, looking down the field: you and your creature end up
	-- on the left of the screen, the opponent further back on the right
	local camPos = a - dir * 6 + right * 5 + Vector3.new(0, 4.5, 0)
	local focus = a + dir * 14 - Vector3.new(0, 1.5, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { CFrame = CFrame.lookAt(camPos, focus) }):Play()
end

local function restoreCamera()
	camera.CameraType = Enum.CameraType.Custom
end

-- Events -----------------------------------------------------------------

-- The arena is far away, so the creature models can arrive a moment after the battle message.
-- Fill them in from the server's ObjectValues (waiting up to 3 seconds) so the camera and cards work.
local function resolveModels(state)
	if not state then
		return
	end
	local refs = player:FindFirstChild("BattleRefs")
	if not refs then
		return
	end
	local t0 = os.clock()
	while os.clock() - t0 < 3 do
		state.allyModel = state.allyModel or refs.Ally.Value
		state.wildModel = state.wildModel or refs.Wild.Value
		local a, w = state.allyModel, state.wildModel
		if a and w and a.PrimaryPart and w.PrimaryPart then
			return
		end
		task.wait()
	end
end

-- your own name tag hovers right where the opponent's HP card goes, so hide it during battles
local function showOwnTag(visible: boolean)
	local tag = player.Character and player.Character:FindFirstChild("TrainerTag", true)
	if tag and tag:IsA("BillboardGui") then
		tag.Enabled = visible
	end
end

local function handle(kind: string, data)
	if kind == "start" then
		resolveModels(data.state)
		showOwnTag(false)
		busy = true
		gui.Enabled = true
		clearButtons()
		applyState(data.state)
		battleCamera(data.state)
		playTurn(data.log, data.state)
		busy = false
		logLabel.Text = promptText()
		showMenu("main")
	elseif kind == "update" then
		busy = true
		clearButtons()
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			battleCamera(data.state)
		end
		playTurn(data.log, data.state)
		busy = false
		logLabel.Text = promptText()
		if current.waiting then
			clearButtons()
		else
			showMenu(current.mustSwitch and "switch" or "main")
		end
	elseif kind == "end" then
		busy = true
		clearButtons()
		playTurn(data.log, data.state)
		task.wait(0.4)
		gui.Enabled = false
		allyCard.gui.Visible = false
		wildCard.gui.Visible = false
		-- tell the server we're done so it can send us back from the arena
		BattleAction:FireServer("done")
		task.wait(0.15)
		restoreCamera()
		showOwnTag(true)
		current = nil
		busy = false
	end
end

-- play battle events one at a time, in order (PvP updates can arrive mid-animation)
local queue, running = {}, false
BattleEvent.OnClientEvent:Connect(function(kind: string, data)
	table.insert(queue, { kind, data })
	if running then
		return
	end
	running = true
	while #queue > 0 do
		local e = table.remove(queue, 1)
		local ok, err = pcall(handle, e[1], e[2])
		if not ok then
			warn("BattleUI:", err)
		end
	end
	running = false
end)
