--[[
	Bag: your items. A button above INDEX opens a panel listing everything you carry
	(right now just the unlimited Loop Ball). Tap an item to read what it does.
	Data comes from the server in the player's "Inventory" attribute (JSON, count -1 = unlimited).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(28, 30, 42)
local CARD = Color3.fromRGB(46, 50, 68)
local BAG_COLOR = Color3.fromRGB(150, 95, 55)

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

local function getInventory()
	local raw = player:GetAttribute("Inventory")
	if not raw or raw == "" then
		return {}
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return (ok and typeof(data) == "table") and data or {}
end

-- Look up an item's definition (balls for now; potions etc. will join later)
local function itemInfo(id: string)
	local ball = GameData.Balls[id]
	if ball then
		return { name = ball.name, category = "Balls", color = ball.color or Color3.fromRGB(225, 45, 45), description = ball.description or "", isBall = true, multiplier = ball.multiplier, unlimited = ball.unlimited }
	end
	local item = GameData.Items and GameData.Items[id]
	if item then
		return { name = item.name, category = item.category or "Items", color = item.color or Color3.fromRGB(150, 150, 160), description = item.description or "", move = item.move,
			medicine = (item.heal or item.revive or item.cure) ~= nil, revive = item.revive,
			held = item.held ~= nil, evolve = item.evolve == true, boost = item.boost ~= nil }
	end
	return { name = id, category = "Items", color = Color3.fromRGB(150, 150, 160), description = "" }
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function symbolFor(info)
	if info.isBall then
		return info.unlimited and "\u{221E}" or nil
	elseif info.medicine then
		return "+"
	elseif info.held then
		return "\u{2726}"
	elseif info.evolve then
		return "\u{25C6}"
	elseif info.boost then
		return "\u{25B2}"
	elseif info.move then
		return "\u{25C9}"
	end
	return nil
end

-- A little ball icon with the infinity sign
local function ballIcon(parent: GuiObject, color: Color3, symbol: string?)
	local icon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), BackgroundColor3 = color }, parent)
	new("UIAspectRatioConstraint", {}, icon)
	round(icon, 999)
	new("UIStroke", { Color = color:Lerp(Color3.new(0, 0, 0), 0.4), Thickness = 2 }, icon)
	local shine = new("Frame", { Position = UDim2.fromScale(0.22, 0.16), Size = UDim2.fromScale(0.22, 0.22), BackgroundColor3 = WHITE, BackgroundTransparency = 0.35 }, icon)
	round(shine, 999)
	if symbol then
		label({ Position = UDim2.fromScale(0.15, 0.2), Size = UDim2.fromScale(0.7, 0.6), Text = symbol, Font = Enum.Font.GothamBold }, icon)
	end
	return icon
end

local gui = new("ScreenGui", { Name = "BagUI", ResetOnSpawn = false, DisplayOrder = 6, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- the Bag button, just above INDEX on the right
local openButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, -90), Size = UDim2.fromOffset(78, 78),
	BackgroundColor3 = BAG_COLOR, Text = "",
}, gui)
round(openButton, 18)
new("UIStroke", { Color = BAG_COLOR:Lerp(Color3.new(0, 0, 0), 0.45), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, openButton)
label({ Size = UDim2.fromScale(1, 0.58), Position = UDim2.fromScale(0, 0.04), Text = "🎒" }, openButton)
local openText = label({ Size = UDim2.fromScale(1, 0.32), Position = UDim2.fromScale(0, 0.64), Text = "BAG" }, openButton)
new("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(70, 40, 15) }, openText)

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.9, 0.7),
	BackgroundColor3 = PANEL, Visible = false,
}, gui)
round(panel, 18)
new("UISizeConstraint", { MaxSize = Vector2.new(680, 460) }, panel)
new("UIStroke", { Color = BAG_COLOR, Thickness = 3 }, panel)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, panel)

label({ Size = UDim2.new(0.6, 0, 0, 36), Text = "🎒 Bag", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(240, 200, 150) }, panel)
local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = Color3.fromRGB(200, 60, 60), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "X",
}, panel)
round(closeButton, 10)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, closeButton)

-- left: item grid, right: details of the selected item
local grid = new("ScrollingFrame", {
	Position = UDim2.new(0, 0, 0, 50), Size = UDim2.new(0.5, -6, 1, -50), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, panel)
new("UIGridLayout", { CellSize = UDim2.new(0.48, 0, 0, 120), CellPadding = UDim2.new(0.04, 0, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)

local detail = new("Frame", { Position = UDim2.new(0.5, 6, 0, 50), Size = UDim2.new(0.5, -6, 1, -50), BackgroundColor3 = CARD }, panel)
round(detail, 14)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, detail)

local showPicker, refresh

local function showDetail(id: string, count: number)
	detail:ClearAllChildren()
	new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, detail)
	local info = itemInfo(id)
	local iconHolder = new("Frame", { Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1 }, detail)
	ballIcon(iconHolder, info.color, symbolFor(info))
	label({ Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 30), Text = info.name })
		.Parent = detail
	label({
		Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, 0, 0, 20),
		Text = info.category .. "  ·  " .. (count < 0 and "Unlimited" or ("x" .. count)) .. "  ·  " .. GameData.itemSummary(id),
		TextColor3 = Color3.fromRGB(190, 190, 205),
	}, detail)
	label({
		Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, 0, 1, -206), Text = info.description,
		TextScaled = false, TextSize = 17, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(225, 225, 235),
	}, detail)
	if info.move or info.medicine or info.held or info.evolve then
		local use = new("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = Color3.fromRGB(60, 160, 90), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = info.held and "Give to a creature" or "Use",
		}, detail)
		round(use, 10)
		new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, use)
		use.Activated:Connect(function()
			showPicker(id, info)
		end)
	end
end

-- Choose which creature learns the move from a Skill Disc
function showPicker(id: string, info)
	detail:ClearAllChildren()
	new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, detail)
	label({ Size = UDim2.new(1, 0, 0, 28), Text = info.move and ("Teach %s to:"):format(info.move) or (info.held and ("Give %s to:"):format(info.name)) or ("Use %s on:"):format(info.name), TextColor3 = Color3.fromRGB(240, 200, 150) }, detail)
	local status = label({ Position = UDim2.new(0, 0, 1, -66), Size = UDim2.new(1, 0, 0, 22), Text = "", TextColor3 = Color3.fromRGB(200, 230, 200) }, detail)
	local list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -106), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	}, detail)
	new("UIListLayout", { Padding = UDim.new(0, 6) }, list)
	local back = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Color3.fromRGB(70, 75, 98), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "\u{2190} Back",
	}, detail)
	round(back, 10)
	new("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7) }, back)
	back.Activated:Connect(refresh)

	local ok, team = pcall(function()
		return Remotes.GetTeam:InvokeServer()
	end)
	if not ok or #team == 0 then
		status.Text = "You don't have any creatures yet."
		return
	end
	local using = false
	for _, c in team do
		local row = new("TextButton", { Size = UDim2.new(1, -6, 0, 50), BackgroundColor3 = Color3.fromRGB(60, 65, 88), Text = "" }, list)
		round(row, 10)
		local stars = c.stars or 0
		label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.6, -10, 0, 22), Text = ("%s  Lv %d"):format(c.name, c.level) .. (stars > 0 and (" " .. string.rep("\u{2B50}", stars)) or ""), TextXAlignment = Enum.TextXAlignment.Left }, row)
		-- IVs (0-31 each; stars perfect them, 3 stars = IV Trained)
		if c.ivs and not (info.held and c.held) then
			local function iv(k)
				local v = c.ivs[k] or 0
				return v >= 31 and ('<font color="#FFD24D">%d</font>'):format(v) or tostring(v)
			end
			label({
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.new(0.4, -10, 0, 18), RichText = true,
				Text = stars >= 3 and '<font color="#FFD24D">IV TRAINED</font>' or ("IV  %s / %s / %s / %s"):format(iv("hp"), iv("atk"), iv("def"), iv("spd")),
				TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(170, 200, 255),
			}, row)
		end
		local heldName = c.held and GameData.Items[c.held] and GameData.Items[c.held].name
		local sub
		if info.medicine then
			sub = (c.hp <= 0 and "Fainted" or ("HP %d/%d"):format(c.hp or 0, c.maxHP or 0))
				.. (c.status and GameData.StatusInfo[c.status] and ("  \u{00B7}  " .. GameData.StatusInfo[c.status].short) or "")
		elseif info.held then
			sub = heldName and ("Holding: " .. heldName) or "Not holding anything"
		elseif info.evolve then
			local into = GameData.StoneEvolutions[c.name] and GameData.StoneEvolutions[c.name][id]
			sub = into and ("Can evolve into " .. into .. "!") or "No effect"
		else
			sub = table.concat(c.moves or {}, " \u{00B7} ")
		end
		label({
			Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 16), Text = sub,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(185, 185, 200),
		}, row)
		-- held items: a small "Take" button to put a creature's item back in the bag
		if info.held and heldName then
			local take = new("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(64, 34),
				BackgroundColor3 = Color3.fromRGB(190, 120, 50), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "Take", ZIndex = 3,
			}, row)
			round(take, 8)
			new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, take)
			take.Activated:Connect(function()
				if using then
					return
				end
				using = true
				local success, message = Remotes.UseItem:InvokeServer("__takeHeld", c.id)
				status.Text = message or ""
				status.TextColor3 = success and Color3.fromRGB(150, 240, 150) or Color3.fromRGB(255, 140, 140)
				task.wait(1.2)
				using = false
				if success then
					showPicker(id, info)
				end
			end)
		end
		row.Activated:Connect(function()
			if using then
				return
			end
			using = true
			local success, message = Remotes.UseItem:InvokeServer(id, c.id)
			status.Text = message or ""
			status.TextColor3 = success and Color3.fromRGB(150, 240, 150) or Color3.fromRGB(255, 140, 140)
			task.wait(1.6)
			using = false
			if success then
				refresh()
			end
		end)
	end
end

local function showTradeHistory()
	detail:ClearAllChildren()
	local scroll = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, detail)
	new("UIListLayout", { Padding = UDim.new(0, 10) }, scroll)
	local ok, receipts = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("TradeHistory") or "[]")
	if not ok or typeof(receipts) ~= "table" then receipts = {} end
	label({ Size = UDim2.new(1, -8, 0, 32), Text = "Trade history · last 20", TextColor3 = Color3.fromRGB(240, 200, 150) }, scroll)
	if #receipts == 0 then label({ Size = UDim2.new(1, -8, 0, 70), Text = "Completed trades will appear here.", TextWrapped = true }, scroll) end
	local function names(list)
		local out = {}
		for _, c in list or {} do table.insert(out, (c.shiny and "★ " or "") .. c.name .. " Lv" .. c.level .. " (" .. (c.sizeClass or "Normal") .. ")") end
		return #out > 0 and table.concat(out, ", ") or "Nothing"
	end
	for _, row in receipts do
		label({ Size = UDim2.new(1, -8, 0, 132), Text = os.date("!%b %d · %H:%M UTC", row.at) .. "\n" .. (row.partner or ("Trainer " .. row.partnerId)) .. "\nSent: " .. names(row.sent) .. "\nReceived: " .. names(row.received),
			TextScaled = false, TextSize = 14, Font = Enum.Font.GothamMedium, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundColor3 = Color3.fromRGB(35, 39, 56), BackgroundTransparency = 0, TextYAlignment = Enum.TextYAlignment.Top }, scroll)
	end
end

function refresh()
	for _, c in grid:GetChildren() do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	local historyButton = new("TextButton", { LayoutOrder = -1, BackgroundColor3 = Color3.fromRGB(80, 65, 115), Text = "TRADE\nHISTORY", Font = FONT, TextScaled = true, TextColor3 = WHITE }, grid)
	round(historyButton, 14)
	historyButton.Activated:Connect(showTradeHistory)
	local inventory = getInventory()
	local ids = {}
	for id in inventory do
		table.insert(ids, id)
	end
	-- balls first, then medicine, then everything else (each in its own order)
	local function rank(id)
		local ball, item = GameData.Balls[id], GameData.Items[id]
		if ball then
			return (ball.order or 99)
		elseif item and item.category == "Medicine" then
			return 100 + (item.order or 99)
		end
		return 300
	end
	table.sort(ids, function(a, b)
		if rank(a) == rank(b) then
			return a < b
		end
		return rank(a) < rank(b)
	end)
	for i, id in ids do
		local count = inventory[id]
		local info = itemInfo(id)
		local slot = new("TextButton", { LayoutOrder = i, BackgroundColor3 = CARD, Text = "" }, grid)
		round(slot, 14)
		local holder = new("Frame", { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1 }, slot)
		ballIcon(holder, info.color, symbolFor(info))
		label({ Position = UDim2.fromOffset(6, 70), Size = UDim2.new(1, -12, 0, 22), Text = info.name }, slot)
		label({ Position = UDim2.fromOffset(6, 94), Size = UDim2.new(1, -12, 0, 18), Text = count < 0 and "∞" or ("x" .. count), TextColor3 = Color3.fromRGB(240, 200, 150) }, slot)
		slot.Activated:Connect(function()
			showDetail(id, count)
		end)
		if i == 1 then
			showDetail(id, count)
		end
	end
end

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		refresh()
		panel.Size = UDim2.fromScale(0.82, 0.62)
		TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.9, 0.7) }):Play()
		-- close the Index if it's open so they don't stack
		local index = player.PlayerGui:FindFirstChild("CreatureIndexUI")
		if index then
			for _, c in index:GetChildren() do
				if c:IsA("Frame") then
					c.Visible = false
				end
			end
		end
	end
end

openButton.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
player:GetAttributeChangedSignal("Inventory"):Connect(function()
	if panel.Visible then
		refresh()
	end
end)

-- hide during battles and the intro
local function updateVisible()
	local hidden = player:GetAttribute("InBattle") or player:GetAttribute("InCutscene")
	openButton.Visible = not hidden
	if hidden then
		setOpen(false)
	end
end
player:GetAttributeChangedSignal("InBattle"):Connect(updateVisible)
player:GetAttributeChangedSignal("InCutscene"):Connect(updateVisible)
updateVisible()
