--[[
	CreatureIndex: the book of every creature you've collected.
	A button on the middle-right opens a grid of all catchable creatures (silhouettes until caught).
	Tap one to see which sizes (Tiny to Huge) you've caught it in, its stat bonus per size, and shinies.
	Data comes from the server in the player's "IndexData" attribute (JSON).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared:WaitForChild("GameData"))
local BattleData = require(Shared:WaitForChild("BattleData"))
local CreatureBuilder = require(Shared:WaitForChild("CreatureBuilder"))

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 215, 80)
local PANEL = Color3.fromRGB(28, 30, 42)
local CARD = Color3.fromRGB(46, 50, 68)

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

local function getIndex()
	local raw = player:GetAttribute("IndexData")
	if not raw or raw == "" then
		return {}
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return (ok and typeof(data) == "table") and data or {}
end

-- 3D preview of a creature inside a ViewportFrame (black silhouette if not caught yet)
local function preview(parent: GuiObject, name: string, caught: boolean, sizeClass: string?)
	local vp = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 180), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-0.5, -1, -0.7),
	}, parent)
	local model = CreatureBuilder.build(name, nil, { sizeClass = sizeClass or "Normal" })
	for _, d in model:GetDescendants() do
		if d:IsA("BillboardGui") or d:IsA("PointLight") or d:IsA("Sparkles") then
			d:Destroy()
		elseif d:IsA("BasePart") and not caught then
			d.Color = Color3.fromRGB(18, 18, 26)
			d.Material = Enum.Material.SmoothPlastic
		end
	end
	model:PivotTo(CFrame.Angles(0, math.rad(-30), 0))
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude * 0.5
	local cam = new("Camera", { FieldOfView = 40 }, vp)
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, radius * 0.35, -radius * 2.6), cf.Position)
	vp.CurrentCamera = cam
	return vp, model
end

local function typeChips(parent: GuiObject, name: string)
	local info = GameData.Creatures[name]
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, row)
	for _, t in { info.type, info.type2 } do
		if t then
			local chip = label({
				Size = UDim2.new(0, 84, 1, 0), BackgroundTransparency = 0, BackgroundColor3 = BattleData.TypeColors[t] or CARD,
				Text = t, TextStrokeTransparency = 0.5,
			}, row)
			round(chip, 999)
			new("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0) }, chip)
		end
	end
	return row
end

-- Screen ------------------------------------------------------------------

local gui = new("ScreenGui", { Name = "CreatureIndexUI", ResetOnSpawn = false, DisplayOrder = 6, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- the button on the middle-right
local openButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(78, 78),
	BackgroundColor3 = Color3.fromRGB(235, 165, 40), Text = "",
}, gui)
round(openButton, 18)
new("UIStroke", { Color = Color3.fromRGB(150, 90, 10), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, openButton)
label({ Size = UDim2.fromScale(1, 0.58), Position = UDim2.fromScale(0, 0.04), Text = "📖" }, openButton)
local openText = label({ Size = UDim2.fromScale(1, 0.32), Position = UDim2.fromScale(0, 0.64), Text = "INDEX" }, openButton)
new("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(120, 70, 0) }, openText)

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.92, 0.78),
	BackgroundColor3 = PANEL, Visible = false,
}, gui)
round(panel, 18)
new("UISizeConstraint", { MaxSize = Vector2.new(760, 560) }, panel)
new("UIStroke", { Color = Color3.fromRGB(235, 165, 40), Thickness = 3 }, panel)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, panel)

local title = label({ Size = UDim2.new(0.6, 0, 0, 36), Text = "Creature Index", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, panel)
local progress = label({ Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(0.6, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 190, 205) }, panel)
local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = Color3.fromRGB(200, 60, 60), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "X",
}, panel)
round(closeButton, 10)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, closeButton)

local body = new("Frame", { Position = UDim2.new(0, 0, 0, 66), Size = UDim2.new(1, 0, 1, -66), BackgroundTransparency = 1 }, panel)

-- Views --------------------------------------------------------------------

local spinning = {} -- models in the detail view that slowly turn
local showGrid, showDetail

local function clearBody()
	body:ClearAllChildren()
	table.clear(spinning)
end

function showGrid()
	clearBody()
	title.Text = "Creature Index"
	local index = getIndex()
	local caughtCount = 0
	for _, name in GameData.IndexOrder do
		if index[name] then
			caughtCount += 1
		end
	end
	progress.Text = ("Collected %d / %d"):format(caughtCount, #GameData.IndexOrder)

	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	}, body)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.31, 0, 0, 176), CellPadding = UDim2.new(0.02, 0, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
	}, scroll)

	for i, name in GameData.IndexOrder do
		local entry = index[name]
		local caught = entry ~= nil
		local info = GameData.Creatures[name]
		local card = new("TextButton", { LayoutOrder = i, BackgroundColor3 = CARD, Text = "", AutoButtonColor = caught }, scroll)
		round(card, 14)
		if caught then
			new("UIStroke", { Color = GameData.Rarities[info.rarity].color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
		end
		label({ Position = UDim2.fromOffset(8, 6), Size = UDim2.new(0, 40, 0, 18), Text = ("#%02d"):format(i), TextColor3 = Color3.fromRGB(150, 150, 165), TextXAlignment = Enum.TextXAlignment.Left }, card)
		local holder = new("Frame", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 1 }, card)
		preview(holder, name, caught)
		label({ Position = UDim2.fromOffset(6, 118), Size = UDim2.new(1, -12, 0, 24), Text = caught and name or "???" }, card)
		local sub
		if caught then
			local sizes = 0
			for _ in entry.sizes or {} do
				sizes += 1
			end
			sub = ("Caught %d  ·  %d/5 sizes"):format(entry.count or 0, sizes) .. (((entry.shiny or 0) > 0) and "  ★" or "")
		else
			sub = "Not caught yet"
		end
		label({ Position = UDim2.fromOffset(6, 146), Size = UDim2.new(1, -12, 0, 20), Text = sub, TextColor3 = caught and Color3.fromRGB(200, 230, 200) or Color3.fromRGB(140, 140, 150) }, card)
		if caught then
			card.Activated:Connect(function()
				showDetail(name)
			end)
		end
	end
end

function showDetail(name: string)
	clearBody()
	local index = getIndex()
	local entry = index[name] or { count = 0, sizes = {}, shiny = 0 }
	local info = GameData.Creatures[name]
	title.Text = name
	progress.Text = ("%s  ·  Caught %d"):format(info.rarity, entry.count or 0)

	-- left: big spinning preview + types
	local left = new("Frame", { Size = UDim2.fromScale(0.42, 1), BackgroundColor3 = CARD }, body)
	round(left, 14)
	local holder = new("Frame", { Size = UDim2.new(1, 0, 1, -50), BackgroundTransparency = 1 }, left)
	local _, model = preview(holder, name, true)
	table.insert(spinning, model)
	local chips = new("Frame", { Position = UDim2.new(0, 10, 1, -42), Size = UDim2.new(1, -20, 0, 32), BackgroundTransparency = 1 }, left)
	typeChips(chips, name)

	-- right: sizes caught
	local right = new("Frame", { Position = UDim2.fromScale(0.45, 0), Size = UDim2.fromScale(0.55, 1), BackgroundTransparency = 1 }, body)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, right)
	label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 24), Text = "Sizes collected", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, right)

	for i, size in GameData.SizeClasses do
		local n = (entry.sizes or {})[size.name] or 0
		local has = n > 0
		local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = has and Color3.fromRGB(45, 95, 60) or CARD }, right)
		round(row, 10)
		label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.38, -10, 0, 22), Text = size.name, TextXAlignment = Enum.TextXAlignment.Left }, row)
		local pct = math.floor((size.statMult - 1) * 100 + 0.5)
		local statText = pct == 0 and "normal stats" or ((pct > 0 and "+" or "") .. pct .. "% stats")
		label({
			Position = UDim2.fromOffset(10, 26), Size = UDim2.new(0.6, -10, 0, 14),
			Text = ("x%s size  ·  %s"):format(tostring(size.scale), statText), TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(185, 185, 200),
		}, row)
		label({
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.38, 0, 0, 24),
			Text = has and ("✓ x%d"):format(n) or "Not yet", TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = has and Color3.fromRGB(150, 240, 150) or Color3.fromRGB(140, 140, 150),
		}, row)
	end

	local shinyCount = entry.shiny or 0
	local shinyRow = new("Frame", { LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = shinyCount > 0 and Color3.fromRGB(110, 90, 25) or CARD }, right)
	round(shinyRow, 10)
	label({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(0.6, -10, 1, -12), Text = "★ Shiny", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left }, shinyRow)
	label({
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.38, 0, 0, 22),
		Text = shinyCount > 0 and ("✓ x%d"):format(shinyCount) or "Not yet", TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = shinyCount > 0 and GOLD or Color3.fromRGB(140, 140, 150),
	}, shinyRow)

	local back = new("TextButton", {
		LayoutOrder = 11, Size = UDim2.new(0.4, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(70, 75, 98),
		Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "← Back",
	}, right)
	round(back, 10)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, back)
	back.Activated:Connect(showGrid)
end

-- Open / close ---------------------------------------------------------------

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		showGrid()
		panel.Size = UDim2.fromScale(0.85, 0.7)
		TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.92, 0.78) }):Play()
	else
		clearBody()
	end
end

openButton.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)

-- refresh if something gets caught while the grid is open
player:GetAttributeChangedSignal("IndexData"):Connect(function()
	if panel.Visible and title.Text == "Creature Index" then
		showGrid()
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

RunService.RenderStepped:Connect(function(dt)
	for _, model in spinning do
		if model.Parent then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 0.8, 0))
		end
	end
end)
