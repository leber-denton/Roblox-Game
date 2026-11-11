--[[
	EventHUD (client): the "other players are content" layer.
	  - Weekly Rare Storm pill under the rare spawn timer: a countdown all week, then LIVE with time left
	  - your active 2x boosts (bought, from VIP passes, or server-wide) as small chips
	  - big banner + sound when ANYONE in the server catches something rare (RareCatch remote, sent by
	    BattleService: shiny, Rare, Legendary, Huge or the rare spawn event creature), plus a feed of
	    the last few rare catches on the left
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UIStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIStyle"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RareCatch = Remotes:WaitForChild("RareCatch", 20)

local gui = Instance.new("ScreenGui")
gui.Name = "EventHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")
UIStyle.mount(gui)

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in props do
		i[k] = v
	end
	i.Parent = parent
	return i
end
local function round(i, r)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, i)
end

-- Weekly event pill ---------------------------------------------------------------------
local storm = new("TextLabel", {
	Name = "Storm", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(300, 26),
	BackgroundColor3 = Color3.fromRGB(40, 30, 80), BackgroundTransparency = 0.2, Font = Enum.Font.FredokaOne, TextScaled = true,
	TextColor3 = Color3.fromRGB(200, 190, 255), Visible = false,
}, gui)
round(storm, 999)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, storm)

local chips = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 162), Size = UDim2.fromOffset(420, 22), BackgroundTransparency = 1 }, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }, chips)

local function fmt(sec)
	sec = math.max(0, math.floor(sec))
	if sec >= 86400 then
		return ("%dd %dh"):format(sec // 86400, (sec % 86400) // 3600)
	elseif sec >= 3600 then
		return ("%dh %dm"):format(sec // 3600, (sec % 3600) // 60)
	end
	return ("%d:%02d"):format(sec // 60, sec % 60)
end

local BOOSTS = { { "DoubleCoins", "2x Coins", Color3.fromRGB(230, 170, 30) }, { "DoubleXP", "2x XP", Color3.fromRGB(70, 170, 240) }, { "DoubleBP", "2x BP", Color3.fromRGB(220, 80, 80) } }
local chipLabels = {}
for i, b in BOOSTS do
	local c = new("TextLabel", { LayoutOrder = i, Size = UDim2.fromOffset(110, 22), BackgroundColor3 = b[3], BackgroundTransparency = 0.15,
		Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Visible = false }, chips)
	round(c, 999)
	new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, c)
	chipLabels[b[1]] = c
end

task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()
		local hidden = player:GetAttribute("InBattle") or player:GetAttribute("InCutscene") or player:GetAttribute("TutorialStep") ~= "done"
		local name = ReplicatedStorage:GetAttribute("WeeklyEventName") or "Rare Storm"
		local ends = ReplicatedStorage:GetAttribute("WeeklyEventEnds")
		local nextAt = ReplicatedStorage:GetAttribute("WeeklyEventNext")
		if ends and ends > now then
			storm.Text = ("\u{26C8} %s LIVE: %s left · 2x coins & XP"):format(name:upper(), fmt(ends - now))
			storm.BackgroundColor3 = Color3.fromRGB(110, 50, 200)
			storm.TextColor3 = Color3.new(1, 1, 1)
			storm.Visible = not hidden
		elseif nextAt then
			storm.Text = ("\u{26C8} %s in %s"):format(name, fmt(nextAt - now))
			storm.BackgroundColor3 = Color3.fromRGB(40, 30, 80)
			storm.TextColor3 = Color3.fromRGB(200, 190, 255)
			storm.Visible = not hidden
		else
			storm.Visible = false
		end
		for _, b in BOOSTS do
			local key = b[1]
			local label = chipLabels[key]
			local pass = player:GetAttribute("Pass_" .. key)
			local mine = player:GetAttribute("Boost_" .. key)
			local server = ReplicatedStorage:GetAttribute("ServerBoost_" .. key)
			local left = math.max(type(mine) == "number" and mine - now or 0, type(server) == "number" and server - now or 0)
			-- pass owners always have it, so only timed boosts are worth a chip
			if not pass and left > 0 then
				label.Text = ("%s · %s"):format(b[2], fmt(left))
				label.Visible = not hidden
			else
				label.Visible = false
			end
		end
		task.wait(0.5)
	end
end)

-- Rare catch banner + feed ---------------------------------------------------------------
local RARITY_COLORS = {
	Rare = Color3.fromRGB(70, 140, 255), Legendary = Color3.fromRGB(255, 170, 30), Shiny = Color3.fromRGB(255, 90, 200),
	Huge = Color3.fromRGB(120, 200, 90), Event = Color3.fromRGB(255, 200, 60),
}
-- bottom-left, just right of the menu buttons
local feed = new("Frame", { Name = "RareFeed", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 136, 1, -12), Size = UDim2.fromOffset(260, 150), BackgroundTransparency = 1 }, gui)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 4) }, feed)
local feedCount = 0

local chime = Instance.new("Sound")
chime.SoundId = "rbxassetid://135996502799215" -- same licensed level-up sting the game already uses
chime.Volume = 0.5
chime.Parent = SoundService

local function describe(info)
	local tag = info.shiny and "SHINY " or ""
	if info.size == "Huge" then
		tag ..= "HUGE "
	end
	if info.rarity == "Legendary" or info.rarity == "Rare" then
		tag ..= info.rarity:upper() .. " "
	end
	return ("%s%s"):format(tag, info.name)
end

local function onRareCatch(info)
	if typeof(info) ~= "table" then
		return
	end
	local key = info.shiny and "Shiny" or (info.event and "Event") or (info.rarity == "Legendary" and "Legendary") or (info.rarity == "Rare" and "Rare") or "Huge"
	local color = RARITY_COLORS[key] or RARITY_COLORS.Rare
	local mine = info.userId == player.UserId
	-- the banner
	local banner = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80), Size = UDim2.fromOffset(580, 54),
		BackgroundColor3 = Color3.fromRGB(22, 22, 34), BackgroundTransparency = 0.08, Font = Enum.Font.FredokaOne, TextScaled = true,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35), TextStrokeTransparency = 0.3,
		Text = ("\u{2605} %s caught a %s (Lv %d)! \u{2605}"):format(mine and "You" or tostring(info.player), describe(info), info.level or 1),
	}, gui)
	round(banner, 16)
	new("UIStroke", { Color = color, Thickness = 3, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, banner)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, banner)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 340) }):Play()
	chime:Play()
	task.delay(4.5, function()
		local t = TweenService:Create(banner, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1, TextStrokeTransparency = 1 })
		local stroke = banner:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		t:Play()
		t.Completed:Wait()
		banner:Destroy()
	end)
	-- the feed
	feedCount += 1
	local row = new("TextLabel", {
		LayoutOrder = feedCount, Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Color3.fromRGB(20, 22, 32), BackgroundTransparency = 0.25,
		Font = Enum.Font.GothamBold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color,
		Text = ("%s: %s"):format(mine and "You" or tostring(info.player), describe(info)),
	}, feed)
	round(row, 8)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, row)
	local rows = {}
	for _, c in feed:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(rows, c)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #rows - 5 do
		rows[i]:Destroy()
	end
	task.delay(120, function()
		if row.Parent then
			row:Destroy()
		end
	end)
end
if RareCatch then
	RareCatch.OnClientEvent:Connect(onRareCatch)
end
