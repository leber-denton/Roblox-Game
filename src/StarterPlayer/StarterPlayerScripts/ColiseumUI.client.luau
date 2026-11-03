--[[
	ColiseumUI (client): Battle Points counter while you're in the Battle Coliseum, the Arena Master's
	BP shop, and hiding your own "hold E" trainer prompt (so you can't challenge yourself).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ColiseumRemote = Remotes:WaitForChild("Coliseum")
local BuyRemote = Remotes:WaitForChild("ColiseumBuy")
local Notify = Remotes:WaitForChild("Notify")

local FONT = Enum.Font.FredokaOne
local GOLD = Color3.fromRGB(255, 205, 80)
local RED = Color3.fromRGB(200, 50, 55)
local WHITE = Color3.new(1, 1, 1)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function round(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o)
end

-- your own trainer prompt stays hidden for you
local function hideOwn(p: Instance)
	if p:IsA("ProximityPrompt") and p.Name == "TrainerPrompt" and p:GetAttribute("OwnerId") == player.UserId then
		p.Enabled = false
		p:GetPropertyChangedSignal("Enabled"):Connect(function()
			if p.Enabled then
				p.Enabled = false
			end
		end)
	end
end
player.CharacterAdded:Connect(function(character)
	character.DescendantAdded:Connect(hideOwn)
	for _, d in character:GetDescendants() do
		hideOwn(d)
	end
end)
if player.Character then
	player.Character.DescendantAdded:Connect(hideOwn)
	for _, d in player.Character:GetDescendants() do
		hideOwn(d)
	end
end

local gui = new("ScreenGui", { Name = "ColiseumUI", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 30 }, player:WaitForChild("PlayerGui"))

-- BP pill (only inside the Coliseum)
local pill = new("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 158), Size = UDim2.fromOffset(196, 40),
	BackgroundColor3 = Color3.fromRGB(60, 20, 25), BackgroundTransparency = 0.1, Font = FONT, TextScaled = true,
	TextColor3 = GOLD, Text = "", Visible = false,
}, gui)
round(pill, 14)
new("UIStroke", { Color = RED, Thickness = 2 }, pill)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, pill)
local function refreshPill()
	pill.Visible = player:GetAttribute("InColiseum") == true
	pill.Text = ("\u{2694} %d Battle Points"):format(player:GetAttribute("Stat_bp") or 0)
end
player:GetAttributeChangedSignal("InColiseum"):Connect(refreshPill)
player:GetAttributeChangedSignal("Stat_bp"):Connect(refreshPill)
refreshPill()

-- Arena Master shop
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.92, 0.78),
	BackgroundColor3 = Color3.fromRGB(32, 22, 24), Visible = false, ZIndex = 40,
}, gui)
round(panel, 18)
new("UIStroke", { Color = GOLD, Thickness = 3 }, panel)
new("UISizeConstraint", { MaxSize = Vector2.new(600, 600) }, panel)
local title = new("TextLabel", {
	Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -70, 0, 36), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, Text = "Arena Master \u{00B7} BP Exchange", ZIndex = 41,
}, panel)
local balance = new("TextLabel", {
	Position = UDim2.fromOffset(16, 48), Size = UDim2.new(1, -32, 0, 22), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = WHITE, Text = "", ZIndex = 41,
}, panel)
local close = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = RED,
	Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "X", ZIndex = 41,
}, panel)
round(close, 10)
close.Activated:Connect(function()
	panel.Visible = false
end)
local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 78), Size = UDim2.new(1, -24, 1, -90), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 41,
}, panel)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local function header(text, order)
	new("TextLabel", {
		LayoutOrder = order, Size = UDim2.new(1, -8, 0, 26), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, Text = text, ZIndex = 42,
	}, list)
end

local function row(order, name, sub, buttonText, color, onClick)
	local r = new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 58), BackgroundColor3 = Color3.fromRGB(52, 38, 40), ZIndex = 42 }, list)
	round(r, 10)
	new("TextLabel", {
		Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -150, 0, 26), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = WHITE, Text = name, ZIndex = 43,
	}, r)
	new("TextLabel", {
		Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -150, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(215, 200, 190), Text = sub, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 43,
	}, r)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(124, 40), BackgroundColor3 = color,
		Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = buttonText, ZIndex = 43,
	}, r)
	round(b, 10)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, b)
	b.Activated:Connect(onClick)
end

local function build()
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	balance.Text = ("You have %d Battle Points. Win player battles to earn more."):format(player:GetAttribute("Stat_bp") or 0)
	header("Coliseum exclusives", 1)
	for i, e in GameData.Coliseum.shop do
		local item = GameData.Items[e.id]
		if item then
			row(10 + i, item.name, GameData.itemSummary(e.id), ("%d BP"):format(e.bp), Color3.fromRGB(190, 120, 30), function()
				local ok, message = BuyRemote:InvokeServer(e.id)
				local toast = player:FindFirstChild("LocalToast")
				if toast then
					toast:Fire(message, ok and "success" or "fail")
				end
				build()
			end)
		end
	end
	header("Robux (no Battle Points for sale, so it stays fair)", 100)
	-- 2x BP is a 30-minute boost now (a developer product), the Gladiator tag comes with VIP
	local bp = GameData.Products.BoostBP
	if bp then
		local ends = player:GetAttribute("Boost_DoubleBP")
		local left = type(ends) == "number" and math.max(0, ends - workspace:GetServerTimeNow()) or 0
		row(100, bp.name, left > 0 and ("Active: %d min left"):format(math.ceil(left / 60)) or bp.description, bp.price .. " R$", Color3.fromRGB(40, 120, 200), function()
			if bp.id and bp.id > 0 then
				MarketplaceService:PromptProductPurchase(player, bp.id)
			else
				local toast = player:FindFirstChild("LocalToast")
				if toast then
					toast:Fire("This boost isn't on sale yet.", "info")
				end
			end
		end)
	end
	for i, key in { "VIP" } do
		local pass = GameData.GamePasses[key]
		if pass then
			local owned = player:GetAttribute("Pass_" .. key) == true
			row(100 + i, pass.name, pass.description, owned and "Owned" or (pass.price .. " R$"), owned and Color3.fromRGB(60, 140, 80) or Color3.fromRGB(40, 150, 90), function()
				if owned then
					return
				end
				if pass.id and pass.id > 0 then
					MarketplaceService:PromptGamePassPurchase(player, pass.id)
				else
					local toast = player:FindFirstChild("LocalToast")
					if toast then
						toast:Fire("This pass isn't on sale yet.", "info")
					end
				end
			end)
		end
	end
end

ColiseumRemote.OnClientEvent:Connect(function(kind)
	if kind == "openShop" then
		build()
		panel.Visible = true
	end
end)
player:GetAttributeChangedSignal("InColiseum"):Connect(function()
	if not player:GetAttribute("InColiseum") then
		panel.Visible = false
	end
end)
