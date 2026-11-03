--[[
	HUD: Wild Shift timer, team counter, and pop-up messages (catches, fails, announcements).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function pill(name: string, size: UDim2, position: UDim2, anchor: Vector2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.AnchorPoint = anchor
	label.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = label
	label.Parent = gui
	return label
end

-- Leave room for the coin panel, including on narrow screens.
local timerLabel = pill("Timer", UDim2.new(1, -186, 0, 36), UDim2.new(0.5, -81, 0, 60), Vector2.new(0.5, 0))
local timerSize = Instance.new("UISizeConstraint")
timerSize.MaxSize = Vector2.new(380, 36)
timerSize.Parent = timerLabel
local timerTextSize = Instance.new("UITextSizeConstraint")
timerTextSize.MaxTextSize = 18
timerTextSize.MinTextSize = 9
timerTextSize.Parent = timerLabel
timerLabel.TextColor3 = Color3.fromRGB(255, 215, 120)

-- SHOP / BASE / HEAL teleport buttons along the top --------------------------
local Teleport = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Teleport")
local topBar = Instance.new("Frame")
topBar.Name = "TopButtons"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 8)
topBar.Size = UDim2.fromOffset(398, 44)
topBar.Position = UDim2.new(0.5, -40, 0, 8) -- nudged left so it clears the Team counter
topBar.BackgroundTransparency = 1
topBar.Parent = gui
local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
barLayout.Padding = UDim.new(0, 8)
barLayout.SortOrder = Enum.SortOrder.LayoutOrder
barLayout.Parent = topBar

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.ZIndex = 20
flash.Parent = gui

local function topButton(order: number, text: string, color: Color3, destination: string)
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(94, 44)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.4)
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 2
	textStroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.55)
	textStroke.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 7)
	pad.PaddingBottom = UDim.new(0, 7)
	pad.Parent = b
	b.Activated:Connect(function()
		if player:GetAttribute("InBattle") or player:GetAttribute("InCutscene") then
			return
		end
		flash.BackgroundTransparency = 0.2
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		Teleport:FireServer(destination)
	end)
	b.Parent = topBar
	return b
end

topButton(1, "SHOP", Color3.fromRGB(45, 120, 230), "shop")
topButton(2, "BASE", Color3.fromRGB(50, 180, 80), "base")
topButton(3, "HEAL", Color3.fromRGB(220, 55, 70), "heal")

-- MAP: the road ahead. Region 1 is one road you walk (no route-to-route teleports), so this lists every
-- region in order with what it needs. Only the Hub and (for Champions) Summit Town can be jumped to.
do
	local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))
	local PURPLE = Color3.fromRGB(140, 80, 220)
	local travelBtn = Instance.new("TextButton")
	travelBtn.LayoutOrder = 4
	travelBtn.Size = UDim2.fromOffset(94, 44)
	travelBtn.BackgroundColor3 = PURPLE
	travelBtn.Font = Enum.Font.FredokaOne
	travelBtn.TextScaled = true
	travelBtn.TextColor3 = Color3.new(1, 1, 1)
	travelBtn.Text = "MAP"
	Instance.new("UICorner", travelBtn).CornerRadius = UDim.new(0, 12)
	local st = Instance.new("UIStroke") st.Color = PURPLE:Lerp(Color3.new(0, 0, 0), 0.4) st.Thickness = 3 st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border st.Parent = travelBtn
	local ts = Instance.new("UIStroke") ts.Thickness = 2 ts.Color = PURPLE:Lerp(Color3.new(0, 0, 0), 0.55) ts.Parent = travelBtn
	local tp = Instance.new("UIPadding") tp.PaddingTop = UDim.new(0, 7) tp.PaddingBottom = UDim.new(0, 7) tp.Parent = travelBtn
	travelBtn.Parent = topBar

	local panel = Instance.new("Frame")
	panel.Name = "TravelPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.53)
	panel.Size = UDim2.fromScale(0.9, 0.74)
	panel.BackgroundColor3 = Color3.fromRGB(28, 30, 42)
	panel.Visible = false
	panel.ZIndex = 30
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 18)
	local ps = Instance.new("UIStroke") ps.Color = PURPLE ps.Thickness = 3 ps.Parent = panel
	local sc = Instance.new("UISizeConstraint") sc.MaxSize = Vector2.new(560, 560) sc.Parent = panel
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -70, 0, 40) title.Position = UDim2.fromOffset(16, 10)
	title.BackgroundTransparency = 1 title.Font = Enum.Font.FredokaOne title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(200, 160, 255) title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "The Road" title.ZIndex = 31 title.Parent = panel
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0) close.Position = UDim2.new(1, -10, 0, 10) close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = Color3.fromRGB(200, 60, 60) close.Font = Enum.Font.FredokaOne close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1) close.Text = "X" close.ZIndex = 31 close.Parent = panel
	Instance.new("UICorner", close).CornerRadius = UDim.new(0, 10)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 58) list.Size = UDim2.new(1, -24, 1, -70)
	list.BackgroundTransparency = 1 list.BorderSizePixel = 0 list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y list.CanvasSize = UDim2.new() list.ZIndex = 31 list.Parent = panel
	local ll = Instance.new("UIListLayout") ll.Padding = UDim.new(0, 6) ll.SortOrder = Enum.SortOrder.LayoutOrder ll.Parent = list

	local function go(where, arg)
		if player:GetAttribute("InBattle") or player:GetAttribute("InCutscene") then
			return
		end
		panel.Visible = false
		flash.BackgroundTransparency = 0.2
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		Teleport:FireServer(where, arg)
	end
	local order = 0
	local function header(text)
		order += 1
		local h = Instance.new("TextLabel")
		h.LayoutOrder = order h.Size = UDim2.new(1, -8, 0, 26) h.BackgroundTransparency = 1
		h.Font = Enum.Font.FredokaOne h.TextScaled = true h.TextXAlignment = Enum.TextXAlignment.Left
		h.TextColor3 = Color3.fromRGB(255, 215, 90) h.Text = text h.ZIndex = 31 h.Parent = list
	end
	local function row(name, sub, open, where, arg, color)
		order += 1
		local r = Instance.new("Frame")
		r.LayoutOrder = order r.Size = UDim2.new(1, -8, 0, 52)
		r.BackgroundColor3 = open and Color3.fromRGB(46, 50, 68) or Color3.fromRGB(36, 37, 48)
		r.ZIndex = 31 r.Parent = list
		Instance.new("UICorner", r).CornerRadius = UDim.new(0, 10)
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(12, 36) dot.Position = UDim2.fromOffset(8, 8)
		dot.BackgroundColor3 = open and (color or PURPLE) or Color3.fromRGB(90, 90, 100) dot.ZIndex = 32 dot.Parent = r
		Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 6)
		local n = Instance.new("TextLabel")
		n.Position = UDim2.fromOffset(28, 4) n.Size = UDim2.new(1, -140, 0, 26) n.BackgroundTransparency = 1
		n.Font = Enum.Font.FredokaOne n.TextScaled = true n.TextXAlignment = Enum.TextXAlignment.Left
		n.TextColor3 = open and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 160) n.Text = name n.ZIndex = 32 n.Parent = r
		local s = Instance.new("TextLabel")
		s.Position = UDim2.fromOffset(28, 30) s.Size = UDim2.new(1, -140, 0, 18) s.BackgroundTransparency = 1
		s.Font = Enum.Font.GothamMedium s.TextSize = 13 s.TextXAlignment = Enum.TextXAlignment.Left
		s.TextColor3 = open and Color3.fromRGB(150, 235, 160) or Color3.fromRGB(255, 140, 140) s.Text = sub s.ZIndex = 32 s.Parent = r
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(1, 0.5) b.Position = UDim2.new(1, -8, 0.5, 0) b.Size = UDim2.fromOffset(96, 38)
		local canGo = open and where ~= nil
		b.BackgroundColor3 = canGo and Color3.fromRGB(55, 165, 85) or (open and Color3.fromRGB(60, 110, 170) or Color3.fromRGB(80, 80, 92))
		b.Font = Enum.Font.FredokaOne b.TextScaled = true b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = canGo and "GO" or (open and "WALK" or "LOCKED") b.AutoButtonColor = canGo b.ZIndex = 32 b.Parent = r
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
		local pad = Instance.new("UIPadding") pad.PaddingTop = UDim.new(0, 6) pad.PaddingBottom = UDim.new(0, 6) pad.Parent = b
		b.Activated:Connect(function()
			if canGo then
				go(where, arg)
			end
		end)
	end
	local function refresh()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		order = 0
		local badges = player:GetAttribute("Badges") or 0
		local champion = (player:GetAttribute("Stat_leagueWins") or 0) > 0
		local function need(r)
			if badges < r.badges then
				return ("Needs %d gym badge%s (you have %d)"):format(r.badges, r.badges == 1 and "" or "s", badges)
			end
			return "Become the Champion to unlock"
		end
		local cap, starsOK = GameData.levelCap(badges, champion)
		header(starsOK and "Level cap: none  ·  stars unlocked" or ("Level cap: Lv %d  ·  your next badge raises it"):format(cap))
		header(GameData.Region1.name .. " Region  ·  one road, walk it in order")
		row("Hub", "Healing Center, Shop, Dark Tower", true, "hub", nil, Color3.fromRGB(80, 160, 255))
		local step = 0
		for _, r in GameData.Regions do
			if not r.region then
				step += 1
				local open = GameData.canEnter(r.lane, badges, champion)
				row(("%d. %s"):format(step, r.name), open and ("Open  ·  gym badge %d  ·  Heal Stop at the entrance"):format(r.badges + 1) or need(r), open, nil, nil)
			end
		end
		local leagueOpen = badges >= GameData.League.badges
		row(("%d. "):format(step + 1) .. GameData.VictoryRoads.League .. " + League", leagueOpen and (champion and "★ You're the Champion" or "Wild training ground, Elite Four and Champion") or ("Needs %d gym badges"):format(GameData.League.badges), leagueOpen, nil, nil, Color3.fromRGB(255, 200, 70))
		header(GameData.Region2.region .. " Region  ·  starts at " .. GameData.Region2.name)
		row(GameData.Region2.name, champion and "Healing Center and Shop" or "Become the Champion to unlock", champion, "town2", nil, Color3.fromRGB(255, 200, 70))
		local step2 = 0
		for _, r in GameData.Regions do
			if r.region == 2 then
				step2 += 1
				local open = GameData.canEnter(r.lane, badges, champion)
				row(("%d. %s"):format(step2, r.name), open and ("Open  ·  gym badge %d"):format(r.badges + 1) or need(r), open, nil, nil)
			end
		end
		if GameData.League2 then
			local need2 = GameData.League2.badges or 16
			local open2 = champion and badges >= need2
			local summitChamp = (player:GetAttribute("Stat_league2Wins") or 0) > 0
			row(("%d. "):format(step2 + 1) .. GameData.VictoryRoads.League2 .. " + League", open2 and (summitChamp and "★ You're the Grand Champion" or "Wild training ground, Elite Four and Champion") or ("Needs %d gym badges"):format(need2), open2, nil, nil, Color3.fromRGB(255, 200, 70))
		end
	end
	travelBtn.Activated:Connect(function()
		if player:GetAttribute("InBattle") or player:GetAttribute("InCutscene") then
			return
		end
		panel.Visible = not panel.Visible
		if panel.Visible then
			refresh()
		end
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	player:GetAttributeChangedSignal("InBattle"):Connect(function()
		panel.Visible = false
	end)
end

-- hide the teleport buttons during battles, the intro, and until a new player has met Professor Maple
local NO_TELEPORT_STEPS = { meet_prof = true, choose_starter = true }
local function updateTopBar()
	topBar.Visible = not (player:GetAttribute("InBattle") or player:GetAttribute("InCutscene")
		or NO_TELEPORT_STEPS[player:GetAttribute("TutorialStep")])
	-- the Wild Shift timer would sit on top of the opponent's HP card during battles
	timerLabel.Visible = not player:GetAttribute("InBattle")
end
player:GetAttributeChangedSignal("InBattle"):Connect(updateTopBar)
player:GetAttributeChangedSignal("InCutscene"):Connect(updateTopBar)
player:GetAttributeChangedSignal("TutorialStep"):Connect(updateTopBar)
updateTopBar()
timerLabel.Text = "Wild Shift · finding a Hot Zone"

local teamLabel = pill("Team", UDim2.fromOffset(150, 44), UDim2.new(1, -12, 0, 8), Vector2.new(1, 0))

-- (balls are shown in the Bag now)

-- Coins and trainer level, under the team counter -------------------------------
local coinLabel = pill("Coins", UDim2.fromOffset(150, 40), UDim2.new(1, -12, 0, 58), Vector2.new(1, 0))
coinLabel.TextXAlignment = Enum.TextXAlignment.Right
coinLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
-- drawn gold coin (emoji coins don't render on every device)
local coinIcon = Instance.new("TextLabel")
coinIcon.AnchorPoint = Vector2.new(0, 0.5)
coinIcon.Position = UDim2.new(0, -4, 0.5, 0)
coinIcon.Size = UDim2.fromOffset(24, 24)
coinIcon.BackgroundColor3 = Color3.fromRGB(245, 190, 40)
coinIcon.Font = Enum.Font.FredokaOne
coinIcon.TextScaled = true
coinIcon.TextColor3 = Color3.fromRGB(150, 100, 10)
coinIcon.Text = "C"
local coinCorner = Instance.new("UICorner") coinCorner.CornerRadius = UDim.new(1, 0) coinCorner.Parent = coinIcon
local coinStroke = Instance.new("UIStroke") coinStroke.Color = Color3.fromRGB(180, 125, 20) coinStroke.Thickness = 2 coinStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border coinStroke.Parent = coinIcon
coinIcon.Parent = coinLabel

local levelPill = pill("TrainerLevel", UDim2.fromOffset(150, 46), UDim2.new(1, -12, 0, 104), Vector2.new(1, 0))
levelPill.Text = ""
local levelText = Instance.new("TextLabel")
levelText.BackgroundTransparency = 1
levelText.Size = UDim2.fromScale(1, 0.58)
levelText.Font = Enum.Font.FredokaOne
levelText.TextScaled = true
levelText.TextColor3 = Color3.new(1, 1, 1)
levelText.Parent = levelPill
local xpBack = Instance.new("Frame")
xpBack.Position = UDim2.fromScale(0, 0.66)
xpBack.Size = UDim2.fromScale(1, 0.3)
xpBack.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
xpBack.Parent = levelPill
local xpCorner = Instance.new("UICorner") xpCorner.CornerRadius = UDim.new(1, 0) xpCorner.Parent = xpBack
local xpFill = Instance.new("Frame")
xpFill.Size = UDim2.fromScale(0, 1)
xpFill.BackgroundColor3 = Color3.fromRGB(90, 170, 255)
xpFill.Parent = xpBack
local xpFillCorner = Instance.new("UICorner") xpFillCorner.CornerRadius = UDim.new(1, 0) xpFillCorner.Parent = xpFill

local shownCoins = player:GetAttribute("Coins") or 0
local function floatText(text: string, color: Color3)
	local f = Instance.new("TextLabel")
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(1, 0)
	f.Position = UDim2.new(1, -170, 0, 60)
	f.Size = UDim2.fromOffset(120, 32)
	f.Font = Enum.Font.FredokaOne
	f.TextScaled = true
	f.TextColor3 = color
	f.TextStrokeTransparency = 0.3
	f.Text = text
	f.Parent = gui
	TweenService:Create(f, TweenInfo.new(1.2), { Position = UDim2.new(1, -170, 0, 20), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.3, function()
		f:Destroy()
	end)
end

local function updateCoins()
	local coins = player:GetAttribute("Coins") or 0
	local diff = coins - shownCoins
	if diff > 0 then
		floatText("+" .. diff, Color3.fromRGB(255, 215, 90))
	end
	-- count up/down smoothly
	local start, t0 = shownCoins, os.clock()
	shownCoins = coins
	task.spawn(function()
		while os.clock() - t0 < 0.5 do
			if shownCoins ~= coins then
				return
			end
			local a = (os.clock() - t0) / 0.5
			coinLabel.Text = tostring(math.floor(start + (coins - start) * a))
			task.wait()
		end
		coinLabel.Text = tostring(coins)
	end)
end

local function updateLevel()
	local level = player:GetAttribute("TrainerLevel") or 1
	local xp = player:GetAttribute("TrainerXP") or 0
	local nextXP = player:GetAttribute("TrainerXPNext") or 100
	levelText.Text = ("Trainer Lv %d"):format(level)
	TweenService:Create(xpFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(xp / nextXP, 0, 1), 1) }):Play()
end

player:GetAttributeChangedSignal("Coins"):Connect(updateCoins)
player:GetAttributeChangedSignal("TrainerXP"):Connect(updateLevel)
player:GetAttributeChangedSignal("TrainerLevel"):Connect(updateLevel)
do
	local Sfx = require(script.Parent:WaitForChild("Sfx"))
	local lastLevel = player:GetAttribute("TrainerLevel") or 1
	player:GetAttributeChangedSignal("TrainerLevel"):Connect(function()
		local level = player:GetAttribute("TrainerLevel") or 1
		-- a jump of many levels at once is a save loading, not a level up
		if level == lastLevel + 1 then
			Sfx.play("levelUp")
		end
		lastLevel = level
	end)
end
coinLabel.Text = tostring(shownCoins)
updateLevel()

local function updateTeam()
	teamLabel.Text = ("Team %d/%d"):format(player:GetAttribute("TeamCount") or 0, player:GetAttribute("TeamCapacity") or 6)
end
player:GetAttributeChangedSignal("TeamCount"):Connect(updateTeam)
player:GetAttributeChangedSignal("TeamCapacity"):Connect(updateTeam)
updateTeam()

-- Toast messages stack at the bottom centre
local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.BackgroundTransparency = 1
toastHolder.AnchorPoint = Vector2.new(0.5, 1)
toastHolder.Position = UDim2.new(0.5, 0, 1, -110)
toastHolder.Size = UDim2.fromOffset(520, 220)
toastHolder.Parent = gui
local layout = Instance.new("UIListLayout")
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = toastHolder

local kindColors = {
	success = Color3.fromRGB(50, 170, 90),
	fail = Color3.fromRGB(190, 65, 65),
	info = Color3.fromRGB(35, 40, 55),
}

local toastCount = 0
local function fadeAndDestroy(label: TextLabel, delaySeconds: number)
	task.delay(delaySeconds, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.5), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

local function showAnnouncement(text: string)
	local banner = pill("Announcement", UDim2.fromOffset(620, 60), UDim2.new(0.5, 0, 0, 62), Vector2.new(0.5, 0))
	banner.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	banner.BackgroundTransparency = 0.05
	banner.TextColor3 = Color3.fromRGB(40, 25, 0)
	banner.Text = "★ " .. text .. " ★"
	fadeAndDestroy(banner, 5)
end

local function onNotify(text: string, kind: string?)
	if kind == "announce" then
		showAnnouncement(text)
		return
	end
	toastCount += 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 40)
	label.LayoutOrder = toastCount
	label.BackgroundColor3 = kindColors[kind or "info"] or kindColors.info
	label.BackgroundTransparency = 0.1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.6
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = label
	label.Parent = toastHolder
	fadeAndDestroy(label, kind == "info" and 6 or 3.5)
end
Notify.OnClientEvent:Connect(onNotify)
-- messages from other client scripts (e.g. bumping a locked region gate)
local localToast = Instance.new("BindableEvent")
localToast.Name = "LocalToast"
localToast.Event:Connect(onNotify)
localToast.Parent = player

-- The server owns the zone and deadline; joining clients use the same clock.
local function updateWildShiftTimer()
	local endsAt = ReplicatedStorage:GetAttribute("WildShiftEndsAt")
	local zoneName = ReplicatedStorage:GetAttribute("HotZoneName")
	if typeof(endsAt) == "number" and typeof(zoneName) == "string" and zoneName ~= "" then
		local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
		timerLabel.Text = ("Hot Zone: %s · %d:%02d"):format(zoneName, remaining // 60, remaining % 60)
	else
		timerLabel.Text = "Wild Shift · finding a Hot Zone"
	end
end
ReplicatedStorage:GetAttributeChangedSignal("WildShiftEndsAt"):Connect(updateWildShiftTimer)
ReplicatedStorage:GetAttributeChangedSignal("HotZoneName"):Connect(updateWildShiftTimer)
while true do
	updateWildShiftTimer()
	task.wait(0.25)
end
