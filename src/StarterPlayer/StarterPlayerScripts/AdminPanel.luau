--[[
	AdminPanel: test tools for admins only (the server decides who: the owner, listed admins, Studio).
	Open with F2 or the ADMIN button (bottom-right). Everything is checked again on the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Admin = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Admin")

-- wait to find out if we're an admin (the server sets this right after joining)
local t0 = os.clock()
while not player:GetAttribute("IsAdmin") and os.clock() - t0 < 20 do
	task.wait(0.5)
end
if not player:GetAttribute("IsAdmin") then
	return
end

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local function new(c, props, parent)
	local i = Instance.new(c)
	for k, v in props do
		i[k] = v
	end
	i.Parent = parent
	return i
end
local function corner(i, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, i)
end

local gui = new("ScreenGui", { Name = "AdminUI", ResetOnSpawn = false, DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local openBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(90, 34),
	BackgroundColor3 = Color3.fromRGB(170, 40, 40), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "ADMIN",
}, gui)
corner(openBtn, 10)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, openBtn)

local panel = new("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -54), Size = UDim2.fromOffset(380, 520),
	BackgroundColor3 = Color3.fromRGB(25, 22, 30), Visible = false,
}, gui)
corner(panel, 14)
new("UIStroke", { Color = Color3.fromRGB(200, 60, 60), Thickness = 2 }, panel)
new("UISizeConstraint", { MaxSize = Vector2.new(380, 520) }, panel)
new("TextLabel", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 28), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
	TextColor3 = Color3.fromRGB(255, 120, 120), Text = "Admin tools (F2)", TextXAlignment = Enum.TextXAlignment.Left }, panel)
local status = new("TextLabel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -6), Size = UDim2.new(1, -24, 0, 40), BackgroundTransparency = 1,
	Font = Enum.Font.Gotham, TextWrapped = true, TextSize = 14, TextColor3 = Color3.fromRGB(210, 210, 220), Text = "", TextXAlignment = Enum.TextXAlignment.Left }, panel)
local scroll = new("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 1, -90), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, panel)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

local order = 0
local function nextOrder()
	order += 1
	return order
end
local function run(cmd, args)
	status.Text = "..."
	local ok, msg = Admin:InvokeServer(cmd, args)
	status.TextColor3 = ok and Color3.fromRGB(150, 240, 150) or Color3.fromRGB(255, 140, 140)
	status.Text = typeof(msg) == "string" and msg or (ok and "Done." or "Failed.")
	return ok, msg
end
local function header(text)
	new("TextLabel", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 200, 120), Text = text, TextXAlignment = Enum.TextXAlignment.Left }, scroll)
end
local function row()
	local f = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, -6, 0, 34), BackgroundTransparency = 1 }, scroll)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, f)
	return f
end
local function btn(parent, text, color, width, onClick)
	local b = new("TextButton", { Size = UDim2.new(width or 0.5, -4, 1, 0), BackgroundColor3 = color or Color3.fromRGB(60, 65, 90),
		Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = text }, parent)
	corner(b, 8)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, b)
	b.Activated:Connect(onClick)
	return b
end

local RED, GREEN, BLUE, GOLD = Color3.fromRGB(190, 60, 60), Color3.fromRGB(55, 150, 80), Color3.fromRGB(60, 110, 200), Color3.fromRGB(190, 140, 40)

-- saving toggle
header("Saving")
local saveRow = row()
local saving = false
local saveBtn
saveBtn = btn(saveRow, "Saving: OFF (test session)", RED, 1, function()
	saving = not saving
	run("saving", { on = saving })
	saveBtn.Text = saving and "Saving: ON (changes are kept!)" or "Saving: OFF (test session)"
	saveBtn.BackgroundColor3 = saving and GREEN or RED
end)

header("Creatures")
local r1 = row()
btn(r1, "OP team (Lv100 x6)", GOLD, 0.5, function() run("opTeam") end)
btn(r1, "Max my team to Lv100", GOLD, 0.5, function() run("maxTeam") end)
local r2 = row()
btn(r2, "Heal team", GREEN, 0.5, function() run("heal") end)
btn(r2, "Team space 60", BLUE, 0.5, function() run("capacity") end)
local rStar = row()
btn(rStar, "+1 Star (Lv100 team)", Color3.fromRGB(255, 190, 40), 1, function() run("addStar") end)
-- give any creature
local giveRow = row()
local nameBox = new("TextBox", { Size = UDim2.new(0.38, -4, 1, 0), BackgroundColor3 = Color3.fromRGB(45, 45, 60), Font = Enum.Font.Gotham, TextSize = 15,
	TextColor3 = WHITE, PlaceholderText = "Creature", Text = "Lunaryx", ClearTextOnFocus = false }, giveRow)
corner(nameBox, 8)
local levelBox = new("TextBox", { Size = UDim2.new(0.16, -4, 1, 0), BackgroundColor3 = Color3.fromRGB(45, 45, 60), Font = Enum.Font.Gotham, TextSize = 15,
	TextColor3 = WHITE, PlaceholderText = "Lv", Text = "100", ClearTextOnFocus = false }, giveRow)
corner(levelBox, 8)
local shiny = true
local shinyBtn
shinyBtn = btn(giveRow, "Shiny", GOLD, 0.2, function()
	shiny = not shiny
	shinyBtn.BackgroundColor3 = shiny and GOLD or Color3.fromRGB(70, 70, 80)
end)
btn(giveRow, "Give", GREEN, 0.26, function()
	run("give", { name = nameBox.Text, level = tonumber(levelBox.Text) or 100, shiny = shiny, size = "Huge" })
end)

header("Progress")
local r3 = row()
btn(r3, "+1,000,000 coins", GOLD, 0.5, function() run("coins") end)
btn(r3, "99 of every item", GOLD, 0.5, function() run("items") end)
local r4 = row()
btn(r4, "All 8 badges", BLUE, 0.5, function() run("badges") end)
btn(r4, "Skip tutorial", BLUE, 0.5, function() run("finishTutorial") end)
-- start over as a brand-new player to test the tutorial (team cleared, saving stays off)
local r9 = row()
btn(r9, "New player (redo tutorial)", RED, 0.6, function() run("newPlayer") end)
btn(r9, "Juniper drop-in", Color3.fromRGB(150, 90, 220), 0.4, function() run("juniper") end)
local r10 = row()
btn(r10, "Become Champion", GOLD, 0.5, function() run("champion") end)
btn(r10, "All 16 badges", BLUE, 0.5, function() run("allBadges") end)
local r5 = row()
btn(r5, "Reset route trainers", BLUE, 0.5, function() run("resetTrainers") end)
btn(r5, "Beat all trainers", BLUE, 0.5, function() run("beatTrainers") end)
local r6 = row()
btn(r6, "Tower: top floor", BLUE, 0.5, function() run("towerTop") end)
btn(r6, "Start rare spawn", BLUE, 0.5, function() run("rare") end)
local rStorm = row()
btn(rStorm, "Start Rare Storm (10 min)", Color3.fromRGB(150, 90, 220), 1, function() run("storm") end)

header("Stress test")
local r7 = row()
btn(r7, "Swarm 50", RED, 0.33, function() run("swarm", { count = 50 }) end)
btn(r7, "Swarm 150", RED, 0.33, function() run("swarm", { count = 150 }) end)
btn(r7, "Clear wild", Color3.fromRGB(70, 70, 80), 0.34, function() run("clearWild") end)
local fps = new("TextLabel", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 14,
	TextColor3 = Color3.fromRGB(180, 220, 255), Text = "", TextXAlignment = Enum.TextXAlignment.Left }, scroll)

header("Teleport")
local tpHolder = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, scroll)
new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 30), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tpHolder)

local loaded = false
local function load()
	if loaded then
		return
	end
	local ok, info = Admin:InvokeServer("info")
	if ok and typeof(info) == "table" then
		loaded = true
		for i, spot in info.spots do
			local b = btn(tpHolder, spot, Color3.fromRGB(60, 65, 90), 1, function()
				run("teleport", { spot = spot })
			end)
			b.LayoutOrder = i
		end
		saving = info.saving == true
		saveBtn.Text = saving and "Saving: ON (changes are kept!)" or "Saving: OFF (test session)"
		saveBtn.BackgroundColor3 = saving and GREEN or RED
	end
end

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		load()
	end
end
openBtn.Activated:Connect(toggle)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.F2 then
		toggle()
	end
end)

-- live FPS and creature count while the panel is open (for stress tests)
task.spawn(function()
	local frames, last = 0, os.clock()
	game:GetService("RunService").RenderStepped:Connect(function()
		frames += 1
	end)
	while true do
		task.wait(1)
		local now = os.clock()
		local wild = workspace:FindFirstChild("WildCreatures")
		fps.Text = ("FPS %d  ·  wild creatures loaded: %d"):format(math.floor(frames / (now - last) + 0.5), wild and #wild:GetChildren() or 0)
		frames, last = 0, now
	end
end)
