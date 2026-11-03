--[[
	Tutorial (client): the intro cinematic when you join, plus the guidance that points you
	through the tutorial: an objective banner, a floating arrow that points at your goal,
	a bouncing marker over the target and a glowing highlight on it.
	The server sets the player's "TutorialStep" attribute and "TutorialTarget" ObjectValue.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FONT = Enum.Font.FredokaOne
local GOLD = Color3.fromRGB(255, 210, 60)
local WHITE = Color3.new(1, 1, 1)

local function new(className: string, props, parent)
	local inst = Instance.new(className)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function play(inst, time, props, style, dir)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local gui = new("ScreenGui", {
	Name = "TutorialUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 8,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

-- Other players' tutorial creatures are hidden for us ------------------------

local function hideIfNotMine(model: Instance)
	local owner = model:GetAttribute("TutorialOwner")
	if owner and owner ~= player.UserId then
		model:Destroy()
	end
end
task.spawn(function()
	local tutorialFolder = workspace:WaitForChild("TutorialCreatures", 30)
	if tutorialFolder then
		for _, m in tutorialFolder:GetChildren() do
			hideIfNotMine(m)
		end
		tutorialFolder.ChildAdded:Connect(function(m)
			task.defer(hideIfNotMine, m)
		end)
	end
end)

-- Intro cinematic ------------------------------------------------------------

local function intro()
	player:SetAttribute("InCutscene", true)
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart")

	local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 10 }, gui)
	local barTop = new("Frame", { Size = UDim2.new(1, 0, 0.1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5 }, gui)
	local barBottom = new("Frame", { Size = UDim2.new(1, 0, 0.1, 0), Position = UDim2.fromScale(0, 0.9), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5 }, gui)

	local title = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = GOLD, Text = "CREATURE QUEST", ZIndex = 6,
	}, gui)
	new("UIStroke", { Thickness = 4, Color = Color3.fromRGB(120, 40, 20) }, title)
	new("UISizeConstraint", { MaxSize = Vector2.new(900, 160) }, title)
	local caption = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.82), Size = UDim2.fromScale(0.8, 0.07),
		BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE, TextTransparency = 1, Text = "", ZIndex = 6,
	}, gui)
	new("UIStroke", { Thickness = 2, Transparency = 1 }, caption)

	local skipped = false
	local skip = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -80), Size = UDim2.fromOffset(110, 40),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40), BackgroundTransparency = 0.3, Font = FONT, TextScaled = true,
		TextColor3 = WHITE, Text = "Skip ▶", ZIndex = 11,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, skip)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, skip)
	skip.Activated:Connect(function()
		skipped = true
	end)

	local function setCaption(text)
		play(caption, 0.3, { TextTransparency = 1 })
		task.wait(0.3)
		caption.Text = text
		play(caption, 0.5, { TextTransparency = 0 })
		play(caption.UIStroke, 0.5, { Transparency = 0.3 })
	end

	-- wait (skippable)
	local function hold(seconds)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and not skipped do
			task.wait()
		end
	end

	local shots = {
		{ from = CFrame.lookAt(Vector3.new(0, 130, -180), Vector3.new(0, 0, 200)), to = CFrame.lookAt(Vector3.new(0, 85, -60), Vector3.new(0, 0, 320)), time = 4.5,
			caption = "Catch them. Battle them. Begin your Creature Quest." },
		{ from = CFrame.lookAt(Vector3.new(-22, 20, 255), Vector3.new(0, 4, 330)), to = CFrame.lookAt(Vector3.new(14, 16, 470), Vector3.new(0, 4, 560)), time = 4.5,
			caption = "Explore routes full of wild creatures" },
		{ from = CFrame.lookAt(Vector3.new(30, 80, 560), Vector3.new(0, 0, 900)), to = CFrame.lookAt(Vector3.new(-30, 120, 1000), Vector3.new(0, 0, 1800)), time = 4,
			caption = "Beat gym leaders to open the road ahead" },
	}

	task.wait(1) -- let the server move us to our base first
	camera.CameraType = Enum.CameraType.Scriptable
	for i, shot in shots do
		if skipped then
			break
		end
		camera.CFrame = shot.from
		play(black, 0.6, { BackgroundTransparency = 1 })
		play(camera, shot.time, { CFrame = shot.to }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		if i == 1 then
			-- title pops in with a little wobble
			task.wait(0.4)
			play(title, 0.7, { Size = UDim2.fromScale(0.75, 0.18) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			title.Rotation = -8
			play(title, 0.9, { Rotation = 0 }, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
		elseif i == 2 then
			play(title, 0.4, { TextTransparency = 1 })
			play(title.UIStroke, 0.4, { Transparency = 1 })
		end
		task.spawn(setCaption, shot.caption)
		hold(shot.time - 0.6)
		if skipped then
			break
		end
		play(black, 0.5, { BackgroundTransparency = 0 })
		hold(0.55)
	end

	-- back to the player
	play(black, 0.3, { BackgroundTransparency = 0 })
	task.wait(0.35)
	title:Destroy()
	caption:Destroy()
	skip:Destroy()
	camera.CameraType = Enum.CameraType.Custom
	play(barTop, 0.6, { Position = UDim2.fromScale(0, -0.1) })
	play(barBottom, 0.6, { Position = UDim2.fromScale(0, 1) })
	play(black, 0.8, { BackgroundTransparency = 1 })
	task.wait(0.8)
	black:Destroy()
	barTop:Destroy()
	barBottom:Destroy()
	player:SetAttribute("InCutscene", false)
end

-- Guidance ---------------------------------------------------------------

local STEP_TEXT = {
	meet_prof = "Visit Professor Maple at the lab in the hub",
	choose_starter = "Talk to Professor Maple to choose your partner",
	rival = "Talk to Rival Kai",
	battle_nibbit = "Battle the wild Nibbit, weaken it, then catch it!",
	heal = "Heal your team with Nurse Ivy at the Healing Center",
	guide_shop = "Trainer's Guide 1/3: Talk to Clerk Milo at the Shop",
	guide_tower = "Trainer's Guide 2/3: Visit the Dark Tower portal",
	guide_regions = "Trainer's Guide 3/3: Go to the Guide Post by the Meadow Route",
}

local banner = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 168), Size = UDim2.new(0.9, 0, 0, 52),
	BackgroundColor3 = Color3.fromRGB(30, 32, 46), BackgroundTransparency = 0.1, Visible = false,
}, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(620, 52) }, banner)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, banner)
local bannerStroke = new("UIStroke", { Color = GOLD, Thickness = 2 }, banner)
local badge = new("TextLabel", {
	Size = UDim2.new(0, 40, 1, -12), Position = UDim2.fromOffset(8, 6), BackgroundColor3 = GOLD,
	Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(60, 40, 0), Text = "!",
}, banner)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
local bannerText = new("TextLabel", {
	Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -66, 1, -12), BackgroundTransparency = 1,
	Font = FONT, TextScaled = true, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
}, banner)
TweenService:Create(bannerStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.7 }):Play()

-- bouncing marker above the target
local marker = new("BillboardGui", {
	Name = "TutorialMarker", Size = UDim2.fromOffset(70, 70), AlwaysOnTop = true, Enabled = false,
	LightInfluence = 0, ResetOnSpawn = false,
}, player:WaitForChild("PlayerGui"))
local markerLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
	TextColor3 = GOLD, Text = "▼",
}, marker)
new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(110, 60, 0) }, markerLabel)

-- floating 3D arrow next to the player that points at the goal
local arrow = Instance.new("Model")
arrow.Name = "TutorialArrow"
local function arrowPart(name, size, offset)
	local p = new("Part", {
		Name = name, Size = size, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		Material = Enum.Material.Neon, Color = GOLD, CastShadow = false,
	}, arrow)
	p:SetAttribute("Offset", offset)
	return p
end
local arrowParts = {
	{ arrowPart("Shaft", Vector3.new(0.5, 0.25, 2.2), CFrame.new(0, 0, 0.5)) },
	{ arrowPart("HeadL", Vector3.new(0.45, 0.25, 1.6), CFrame.new(-0.45, 0, -0.75) * CFrame.Angles(0, math.rad(-40), 0)) },
	{ arrowPart("HeadR", Vector3.new(0.45, 0.25, 1.6), CFrame.new(0.45, 0, -0.75) * CFrame.Angles(0, math.rad(40), 0)) },
}

local highlight = nil
local highlightTarget = nil

local function setHighlight(model: Model?)
	if highlightTarget == model then
		return
	end
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	highlightTarget = model
	if model then
		highlight = new("Highlight", {
			FillColor = GOLD, FillTransparency = 0.65, OutlineColor = GOLD, OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Adornee = model,
		}, model)
		TweenService:Create(highlight, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.95 }):Play()
	end
end

local function targetValue(): ObjectValue?
	return player:FindFirstChild("TutorialTarget")
end

local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	local step = player:GetAttribute("TutorialStep")
	local tv = targetValue()
	local target = tv and tv.Value
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local root = target and target.Parent and target:IsA("Model") and target.PrimaryPart
	local active = STEP_TEXT[step] ~= nil and root ~= nil and hrp ~= nil
		and not player:GetAttribute("InBattle") and not player:GetAttribute("InCutscene")
		and not player:GetAttribute("InDialogue")

	if not active then
		banner.Visible = false
		marker.Enabled = false
		arrow.Parent = nil
		setHighlight(nil)
		return
	end

	local toTarget = Vector3.new(root.Position.X - hrp.Position.X, 0, root.Position.Z - hrp.Position.Z)
	local distance = toTarget.Magnitude

	banner.Visible = true
	bannerText.Text = STEP_TEXT[step] .. ("  ·  %dm"):format(math.floor(distance))

	marker.Adornee = root
	local cf, size = target:GetBoundingBox()
	marker.StudsOffsetWorldSpace = Vector3.new(0, (cf.Position.Y + size.Y / 2) - root.Position.Y + 4 + math.sin(t * 4) * 0.6, 0)
	marker.Enabled = true
	setHighlight(target)

	if distance > 10 then
		local dir = toTarget.Unit
		local base = CFrame.lookAt(hrp.Position + dir * 4.5 + Vector3.new(0, -1.2 + math.sin(t * 5) * 0.2, 0), hrp.Position + dir * 10 + Vector3.new(0, -1.2, 0))
		for _, entry in arrowParts do
			local p = entry[1]
			p.CFrame = base * p:GetAttribute("Offset")
		end
		arrow.Parent = workspace
	else
		arrow.Parent = nil
	end
end)

-- Celebrate progress made this session, not a completed save arriving on join.
-- A saved step can replicate after this script starts (nil -> "done").
local previousTutorialStep = player:GetAttribute("TutorialStep")
player:GetAttributeChangedSignal("TutorialStep"):Connect(function()
	local step = player:GetAttribute("TutorialStep")
	local previousStep = previousTutorialStep
	previousTutorialStep = step -- update before the animation yields
	if step ~= "done" or previousStep == nil or previousStep == "done" then
		return
	end
	local text = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = GOLD, Text = "TUTORIAL COMPLETE!",
	}, gui)
	new("UIStroke", { Thickness = 4, Color = Color3.fromRGB(120, 40, 20) }, text)
	new("UISizeConstraint", { MaxSize = Vector2.new(800, 120) }, text)
	play(text, 0.6, { Size = UDim2.fromScale(0.7, 0.14) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.wait(2.5)
	play(text, 0.5, { TextTransparency = 1 })
	play(text.UIStroke, 0.5, { Transparency = 1 })
	task.wait(0.5)
	text:Destroy()
end)

-- Dialogue box (Professor Maple, Rival Kai) ------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TutorialRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Tutorial")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared:WaitForChild("GameData"))
local BattleData = require(Shared:WaitForChild("BattleData"))
local CreatureBuilder = require(Shared:WaitForChild("CreatureBuilder"))

local dialogueQueue, inDialogue = {}, false

local function runDialogue(d)
	player:SetAttribute("InDialogue", true)
	local box = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0.94, 0, 0, 150),
		BackgroundColor3 = Color3.fromRGB(250, 248, 240), Text = "", AutoButtonColor = false, ZIndex = 30,
	}, gui)
	new("UISizeConstraint", { MaxSize = Vector2.new(760, 150) }, box)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, box)
	new("UIStroke", { Color = Color3.fromRGB(60, 120, 80), Thickness = 4 }, box)
	local nameTag = new("TextLabel", {
		Position = UDim2.fromOffset(18, -20), Size = UDim2.fromOffset(220, 36), BackgroundColor3 = Color3.fromRGB(60, 120, 80),
		Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = d.speaker, ZIndex = 31,
	}, box)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, nameTag)
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, nameTag)
	local text = new("TextLabel", {
		Position = UDim2.fromOffset(22, 26), Size = UDim2.new(1, -44, 1, -50), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(40, 40, 50), Text = "", ZIndex = 31,
	}, box)
	new("UITextSizeConstraint", { MaxTextSize = 28 }, text)
	local more = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -8), Size = UDim2.fromOffset(150, 22), BackgroundTransparency = 1,
		Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(60, 120, 80), Text = "tap to continue ▼", ZIndex = 31,
	}, box)
	local clicked = false
	box.Activated:Connect(function()
		clicked = true
	end)
	-- Enter / Space / controller A also advance
	local keyConn = game:GetService("UserInputService").InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			clicked = true
		end
	end)
	for i, line in d.lines do
		clicked = false
		more.Visible = false
		-- type the line out (tap to finish it early)
		for c = 1, #line do
			if clicked then
				break
			end
			text.Text = line:sub(1, c)
			task.wait(0.018)
		end
		text.Text = line
		clicked = false
		more.Text = i == #d.lines and "tap to close ▼" or "tap to continue ▼"
		more.Visible = true
		local t0 = os.clock()
		while not clicked do
			more.Position = UDim2.new(1, -16, 1, -8 + math.sin((os.clock() - t0) * 6) * 2)
			task.wait()
		end
	end
	keyConn:Disconnect()
	box:Destroy()
	player:SetAttribute("InDialogue", false)
	TutorialRemote:FireServer("dialogueDone", d.id)
end

local function queueDialogue(d)
	table.insert(dialogueQueue, d)
	if inDialogue then
		return
	end
	inDialogue = true
	while #dialogueQueue > 0 do
		-- wait out battles and the intro
		while player:GetAttribute("InBattle") or player:GetAttribute("InCutscene") do
			task.wait(0.3)
		end
		local ok, err = pcall(runDialogue, table.remove(dialogueQueue, 1))
		if not ok then
			warn("Dialogue:", err)
			player:SetAttribute("InDialogue", false)
		end
	end
	inDialogue = false
end

-- Starter picker ------------------------------------------------------------------
local picking = false
local function preview(parent, name)
	local vp = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 33,
		Ambient = Color3.fromRGB(170, 170, 180), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-0.5, -1, -0.7),
	}, parent)
	local model = CreatureBuilder.build(name, nil, {})
	for _, d in model:GetDescendants() do
		if d:IsA("BillboardGui") or d:IsA("PointLight") or d:IsA("Sparkles") then
			d:Destroy()
		end
	end
	model:PivotTo(CFrame.Angles(0, math.rad(-25), 0))
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude * 0.5
	local cam = new("Camera", { FieldOfView = 40 }, vp)
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, radius * 0.3, -radius * 2.5), cf.Position)
	vp.CurrentCamera = cam
	-- slow spin
	task.spawn(function()
		while vp.Parent do
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, 0.02, 0))
			task.wait()
		end
	end)
end

local function showPicker(data)
	if picking then
		return
	end
	picking = true
	while player:GetAttribute("InDialogue") or player:GetAttribute("InBattle") do
		task.wait(0.2)
	end
	player:SetAttribute("InDialogue", true)
	local overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(15, 20, 30), BackgroundTransparency = 0.25, ZIndex = 32 }, gui)
	-- if the step moves on (a starter was given some other way), close the picker
	local stepConn
	stepConn = player:GetAttributeChangedSignal("TutorialStep"):Connect(function()
		if player:GetAttribute("TutorialStep") ~= "choose_starter" then
			stepConn:Disconnect()
			if overlay.Parent then
				overlay:Destroy()
				player:SetAttribute("InDialogue", false)
				picking = false
			end
		end
	end)
	local title = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.06, 0), Size = UDim2.new(0.9, 0, 0, 56), BackgroundTransparency = 1,
		Font = FONT, TextScaled = true, TextColor3 = GOLD, Text = "Choose your partner!", ZIndex = 33,
	}, overlay)
	new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(90, 50, 0) }, title)
	local row = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromScale(0.94, 0.7), BackgroundTransparency = 1, ZIndex = 33,
	}, overlay)
	new("UISizeConstraint", { MaxSize = Vector2.new(900, 460) }, row)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder }, row)

	local function confirm(s)
		local typeColor = BattleData.TypeColors[s.type] or WHITE
		local modal = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 190),
			BackgroundColor3 = Color3.fromRGB(250, 248, 240), ZIndex = 40,
		}, overlay)
		new("UICorner", { CornerRadius = UDim.new(0, 16) }, modal)
		new("UIStroke", { Color = typeColor, Thickness = 4 }, modal)
		new("TextLabel", {
			Position = UDim2.fromOffset(20, 18), Size = UDim2.new(1, -40, 0, 80), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextWrapped = true,
			TextColor3 = Color3.fromRGB(40, 40, 50), Text = ("So you want %s, the %s type?"):format(s.name, s.type), ZIndex = 41,
		}, modal)
		local function btn(x, text, color, onClick)
			local b = new("TextButton", {
				Position = UDim2.new(x, 10, 1, -70), Size = UDim2.new(0.5, -20, 0, 52), BackgroundColor3 = color, Font = FONT, TextScaled = true,
				TextColor3 = WHITE, Text = text, ZIndex = 41,
			}, modal)
			new("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
			new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, b)
			b.Activated:Connect(onClick)
		end
		btn(0, "Yes!", Color3.fromRGB(55, 165, 85), function()
			TutorialRemote:FireServer("choose", s.name)
			overlay:Destroy()
			player:SetAttribute("InDialogue", false)
			picking = false
		end)
		btn(0.5, "Not yet", Color3.fromRGB(120, 120, 135), function()
			modal:Destroy()
		end)
	end

	for i, s in data.starters do
		local typeColor = BattleData.TypeColors[s.type] or WHITE
		local card = new("TextButton", {
			LayoutOrder = i, Size = UDim2.fromScale(0.31, 1), BackgroundColor3 = Color3.fromRGB(32, 36, 52), Text = "", AutoButtonColor = true, ZIndex = 33,
		}, row)
		new("UICorner", { CornerRadius = UDim.new(0, 18) }, card)
		new("UIStroke", { Color = typeColor, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
		local view = new("Frame", { Position = UDim2.fromScale(0.05, 0.03), Size = UDim2.fromScale(0.9, 0.5), BackgroundTransparency = 1, ZIndex = 33 }, card)
		preview(view, s.name)
		new("TextLabel", {
			Position = UDim2.fromScale(0.05, 0.54), Size = UDim2.fromScale(0.9, 0.11), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
			TextColor3 = WHITE, Text = s.name, ZIndex = 34,
		}, card)
		local chip = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromScale(0.42, 0.07), BackgroundColor3 = typeColor,
			Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = s.type, ZIndex = 34,
		}, card)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, chip)
		new("TextLabel", {
			Position = UDim2.fromScale(0.07, 0.75), Size = UDim2.fromScale(0.86, 0.2), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextWrapped = true,
			TextColor3 = Color3.fromRGB(200, 200, 215), Text = s.blurb, ZIndex = 34,
		}, card)
		card.Activated:Connect(function()
			confirm(s)
		end)
	end
end

TutorialRemote.OnClientEvent:Connect(function(kind, data)
	if kind == "dialogue" then
		task.spawn(queueDialogue, data)
	elseif kind == "pickStarter" then
		task.spawn(showPicker, data)
	end
end)

-- The intro cinematic plays for new players (saved players are marked "done" when they load),
-- and every time you press Play/Run in Studio so you can see it while testing.
do
	local t0 = os.clock()
	while player:GetAttribute("TutorialStep") == nil and os.clock() - t0 < 15 do
		task.wait(0.2)
	end
	if player:GetAttribute("TutorialStep") ~= "done" or RunService:IsStudio() then
		intro()
	else
		player:SetAttribute("InCutscene", false)
	end
end
