--[[
	Story (client):
	  - Juniper's scenes (Remotes.Story "scene"): she fades in next to you, talks, then glitches out of
	    existence. Only you can see her. Tells the server "seen" when the scene ends.
	  - The Trainer's Guide region tour (Remotes.Tutorial "tour"): a camera flyover of the route trainers,
	    the gym and the locked regions. Tells the server "tourDone".
	  - The Journey tracker (top left): what to do next to unlock the next region
	    (route trainers beaten 0/3, then the gym leader).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared:WaitForChild("GameData"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StoryRemote = Remotes:WaitForChild("Story")
local TutorialRemote = Remotes:WaitForChild("Tutorial")

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 210, 60)
local PURPLE = Color3.fromRGB(150, 70, 200)
local HAVOC = Color3.fromRGB(190, 30, 50)

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

local gui = new("ScreenGui", { Name = "StoryUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 12, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- Enter or Space also advances dialogue and the tour (PC / controller players)
local UserInputService = game:GetService("UserInputService")
local advanceKey = Instance.new("BindableEvent")
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		advanceKey:Fire()
	end
end)

local function waitUntilFree()
	while player:GetAttribute("InBattle") or player:GetAttribute("InCutscene") or player:GetAttribute("InDialogue") do
		task.wait(0.3)
	end
end

-- While someone is talking, hide the E prompts so a battle can't start under the dialogue box
do
	local PromptService = game:GetService("ProximityPromptService")
	player:GetAttributeChangedSignal("InDialogue"):Connect(function()
		PromptService.Enabled = not player:GetAttribute("InDialogue")
	end)
end

-- Camera safety net: a battle or cutscene can leave the camera scripted (frozen) if something interrupts it.
-- If it stays scripted for 2 seconds while nothing is using it, hand it back to the player.
task.spawn(function()
	local camera = workspace.CurrentCamera
	local stuckSince
	local lastPos
	while true do
		task.wait(0.5)
		camera = workspace.CurrentCamera
		local busy = player:GetAttribute("InBattle") or player:GetAttribute("InCutscene")
		-- after a teleport (HEAL, TRAVEL, waking up at the Healing Center) put the camera behind the player,
		-- so they face where they're going instead of into a wall
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			if lastPos and not busy and camera.CameraType == Enum.CameraType.Custom and (hrp.Position - lastPos).Magnitude > 60 then
				local back = hrp.CFrame * CFrame.new(0, 5, 12)
				camera.CFrame = CFrame.lookAt(back.Position, hrp.Position + Vector3.new(0, 2, 0))
			end
			lastPos = (not busy) and hrp.Position or nil
		end
		if camera.CameraType == Enum.CameraType.Scriptable and not busy then
			stuckSince = stuckSince or os.clock()
			if os.clock() - stuckSince > 2 then
				camera.CameraType = Enum.CameraType.Custom
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					camera.CameraSubject = hum
				end
				stuckSince = nil
			end
		else
			stuckSince = nil
		end
	end
end)

----------------------------------------------------------------------------------------------
-- dialogue box (purple for Juniper, crimson once she shows her true colours)
----------------------------------------------------------------------------------------------
local function runLines(lines)
	player:SetAttribute("InDialogue", true)
	local box = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0.94, 0, 0, 150),
		BackgroundColor3 = Color3.fromRGB(245, 240, 250), Text = "", AutoButtonColor = false, ZIndex = 30,
	}, gui)
	new("UISizeConstraint", { MaxSize = Vector2.new(760, 150) }, box)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, box)
	local stroke = new("UIStroke", { Color = PURPLE, Thickness = 4 }, box)
	local nameTag = new("TextLabel", {
		Position = UDim2.fromOffset(18, -20), Size = UDim2.fromOffset(260, 36), BackgroundColor3 = PURPLE,
		Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "", ZIndex = 31,
	}, box)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, nameTag)
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, nameTag)
	local text = new("TextLabel", {
		Position = UDim2.fromOffset(22, 26), Size = UDim2.new(1, -44, 1, -50), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(40, 35, 55), Text = "", ZIndex = 31,
	}, box)
	new("UITextSizeConstraint", { MaxTextSize = 28 }, text)
	local more = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -8), Size = UDim2.fromOffset(150, 22), BackgroundTransparency = 1,
		Font = FONT, TextScaled = true, TextColor3 = PURPLE, Text = "tap to continue ▼", ZIndex = 31,
	}, box)
	local clicked = false
	box.Activated:Connect(function()
		clicked = true
	end)
	local keyConn = advanceKey.Event:Connect(function()
		clicked = true
	end)
	for i, line in lines do
		local havoc = line.speaker:find("Havoc") ~= nil
		local guest = line.speaker ~= "Juniper" and not havoc
		local color = havoc and HAVOC or (guest and Color3.fromRGB(60, 125, 175) or PURPLE)
		nameTag.Text = line.speaker
		nameTag.BackgroundColor3 = color
		stroke.Color = color
		more.TextColor3 = color
		box.BackgroundColor3 = havoc and Color3.fromRGB(30, 20, 28) or Color3.fromRGB(245, 240, 250)
		text.TextColor3 = havoc and Color3.fromRGB(255, 225, 230) or Color3.fromRGB(40, 35, 55)
		clicked = false
		more.Visible = false
		for c = 1, #line.text do
			if clicked then
				break
			end
			text.Text = line.text:sub(1, c)
			task.wait(0.02)
		end
		text.Text = line.text
		clicked = false
		more.Text = i == #lines and "tap to close ▼" or "tap to continue ▼"
		more.Visible = true
		local t0 = os.clock()
		while not clicked do
			more.Position = UDim2.new(1, -16, 1, -8 + math.sin((os.clock() - t0) * 6) * 2)
			-- a trainer can still spot you mid-chat: tuck the box away until the battle is over
			if player:GetAttribute("InBattle") then
				box.Visible = false
				while player:GetAttribute("InBattle") do
					task.wait(0.3)
				end
				box.Visible = true
				clicked = false
			end
			task.wait()
		end
	end
	keyConn:Disconnect()
	box:Destroy()
	player:SetAttribute("InDialogue", false)
end

----------------------------------------------------------------------------------------------
-- Juniper
----------------------------------------------------------------------------------------------
local function setVisible(model: Model, alpha: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.LocalTransparencyModifier = 1 - alpha
		elseif d:IsA("Decal") then
			d.Transparency = 1 - alpha
		end
	end
end

local function burst(at: Vector3, color: Color3, amount: number)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(at) }, workspace)
	local e = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 0, Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(180, 180), Color = ColorSequence.new(color),
		Size = NumberSequence.new(0.6, 0), LightEmission = 1,
	}, p)
	e:Emit(amount)
	task.delay(2, function()
		p:Destroy()
	end)
end

local function spawnJuniper(): Model?
	local template = ReplicatedStorage:FindFirstChild("Companion") and ReplicatedStorage.Companion:FindFirstChild("Juniper")
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not template or not hrp then
		return nil
	end
	local m = template:Clone()
	-- stand beside the player on the camera's side, so she's in view, facing them
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local camLook = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	local camRight = camera.CFrame.RightVector * Vector3.new(1, 0, 1)
	if camLook.Magnitude < 0.1 then
		camLook = Vector3.new(0, 0, -1)
	end
	if camRight.Magnitude < 0.1 then
		camRight = Vector3.new(1, 0, 0)
	end
	camLook, camRight = camLook.Unit, camRight.Unit
	local spot
	for _, offset in { camRight * 5 - camLook * 1, -camRight * 5 - camLook * 1, -camLook * 5, camLook * 5 } do
		local blocked = workspace:Raycast(hrp.Position, offset, params)
		if not blocked then
			spot = hrp.Position + offset
			break
		end
	end
	spot = spot or (hrp.Position + camRight * 3)
	local hit = workspace:Raycast(spot + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), params)
	local groundY = hit and hit.Position.Y or (hrp.Position.Y - 3)
	local hipHeight = m.Humanoid.HipHeight + m.HumanoidRootPart.Size.Y / 2
	m:PivotTo(CFrame.lookAt(Vector3.new(spot.X, groundY + hipHeight, spot.Z), Vector3.new(hrp.Position.X, groundY + hipHeight, hrp.Position.Z)))
	m.Parent = workspace
	setVisible(m, 0)
	return m
end

local sceneBusy = false
local function playScene(data)
	if sceneBusy then return end
	sceneBusy = true
	waitUntilFree()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local oldSpeed = humanoid and humanoid.WalkSpeed
	local oldAuto = humanoid and humanoid.AutoRotate
	local oldType, oldCF = camera.CameraType, camera.CFrame
	local m, bars = nil, {}
	player:SetAttribute("InCutscene", true)
	if humanoid then humanoid.WalkSpeed = 0; humanoid.AutoRotate = false end
	local ok, err = pcall(function()
		for _, y in {0, 0.91} do
			table.insert(bars, new("Frame", { Size=UDim2.fromScale(1,0.09), Position=UDim2.fromScale(0,y), BackgroundColor3=Color3.new(0,0,0), BorderSizePixel=0, ZIndex=20 }, gui))
		end
		local title = new("TextLabel", { Position=UDim2.fromScale(0.1,0.025),Size=UDim2.fromScale(0.8,0.045),BackgroundTransparency=1,Text=data.chapter or "Juniper",TextColor3=WHITE,TextScaled=true,Font=FONT,ZIndex=21 },gui)
		table.insert(bars,title)
		local audio = GameData.Audio and GameData.Audio.sfx and GameData.Audio.sfx.levelUp
		if audio and audio.id then
			local sting = new("Sound", {SoundId="rbxassetid://"..audio.id,Volume=0.35,PlaybackSpeed=data.final and 0.55 or 0.8},gui)
			sting:Play();game:GetService("Debris"):AddItem(sting,8)
		end
		if data.actor ~= false then m = spawnJuniper() end
		local head = m and m:FindFirstChild("Head")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		camera.CameraType = Enum.CameraType.Scriptable
		if m then
			burst(m:GetPivot().Position, Color3.fromRGB(200, 140, 255), 40)
			if root and head then
				local center=(root.Position+head.Position)/2+Vector3.new(0,1,0)
				local side=(camera.CFrame.Position-center)*Vector3.new(1,0,1)
				if side.Magnitude<1 then side=Vector3.new(0,0,1) end
				camera.CFrame=CFrame.lookAt(center+side.Unit*15+Vector3.new(0,4,0),center)
			end
			for a = 0, 1, 0.1 do setVisible(m, a);task.wait(0.03) end
			setVisible(m, 1)
		end
		if data.tour then
			local town=GameData.Arms[2].town
			camera.CFrame=CFrame.lookAt(town+Vector3.new(-25,35,-65),town)
			play(camera,5,{CFrame=CFrame.lookAt(town+Vector3.new(20,25,-35),town+Vector3.new(0,3,30))},Enum.EasingStyle.Sine)
		end
		runLines(data.lines)
		if m then
			local color=data.final and Color3.fromRGB(255,60,80) or Color3.fromRGB(170,90,255)
			for i=1,8 do
				setVisible(m,i%2==0 and 1 or 0.15)
				m:PivotTo(m:GetPivot()*CFrame.new((math.random()-0.5)*0.4,0,0))
				task.wait(0.06)
			end
			burst(m:GetPivot().Position,color,70)
		end
	end)
	if m then m:Destroy() end
	for _,bar in bars do bar:Destroy() end
	camera.CameraType = oldType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or oldType
	if camera.CameraType ~= Enum.CameraType.Scriptable then camera.CFrame = oldCF end
	if humanoid and humanoid.Parent then humanoid.WalkSpeed=oldSpeed;humanoid.AutoRotate=oldAuto end
	player:SetAttribute("InDialogue", false)
	player:SetAttribute("InCutscene", false)
	sceneBusy=false
	if ok then StoryRemote:FireServer("seen", data.id)
	else warn("Story scene:",err) end
end

StoryRemote.OnClientEvent:Connect(function(kind, data)
	if kind == "scene" then
		task.spawn(playScene, data)
	end
end)

----------------------------------------------------------------------------------------------
-- Trainer's Guide: region tour
----------------------------------------------------------------------------------------------
local function regionTour()
	waitUntilFree()
	player:SetAttribute("InCutscene", true)
	local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 10 }, gui)
	local barTop = new("Frame", { Size = UDim2.new(1, 0, 0.09, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5 }, gui)
	local barBottom = new("Frame", { Size = UDim2.new(1, 0, 0.09, 0), Position = UDim2.fromScale(0, 0.91), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5 }, gui)
	local caption = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.89, -8), Size = UDim2.new(0.9, 0, 0, 90),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35), BackgroundTransparency = 0.25, Font = FONT, TextScaled = true, TextWrapped = true,
		TextColor3 = WHITE, Text = "", ZIndex = 6,
	}, gui)
	new("UISizeConstraint", { MaxSize = Vector2.new(820, 90) }, caption)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, caption)
	new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, caption)
	local nextBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -16), Size = UDim2.fromOffset(130, 42), BackgroundColor3 = Color3.fromRGB(55, 165, 85),
		Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "Next ▶", ZIndex = 11,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, nextBtn)
	new("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7) }, nextBtn)
	local advance = false
	nextBtn.Activated:Connect(function()
		advance = true
	end)
	local keyConn = advanceKey.Event:Connect(function()
		if nextBtn.Visible then
			advance = true
		end
	end)

	-- highlight the three Meadow Route trainers while they're on screen
	local highlights = {}
	local function glow(model: Instance?)
		if model then
			table.insert(highlights, new("Highlight", { FillColor = GOLD, FillTransparency = 0.6, OutlineColor = GOLD, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, model))
		end
	end
	local function clearGlow()
		for _, h in highlights do
			h:Destroy()
		end
		highlights = {}
	end
	local rt = workspace.Map:FindFirstChild("RouteTrainers")
	local gymName
	for _, g in GameData.GymLeaders do
		if g.lane == "Lane1" then
			gymName = g.name
		end
	end

	local shots = {
		{
			from = CFrame.lookAt(Vector3.new(0, 34, 530), Vector3.new(0, 4, 620)), to = CFrame.lookAt(Vector3.new(0, 30, 620), Vector3.new(0, 4, 705)),
			text = "Near the end of every region, three trainers are waiting. Walk into their line of sight and they'll battle you.",
			glow = { "r1a", "r1b", "r1c" },
		},
		{
			from = CFrame.lookAt(Vector3.new(20, 26, 700), Vector3.new(0, 8, 750)), to = CFrame.lookAt(Vector3.new(-20, 26, 705), Vector3.new(0, 8, 750)),
			text = ("Beat all three, then challenge the Gym Leader%s. Win to earn a badge."):format(gymName and (" (" .. gymName .. ")") or ""),
		},
		{
			from = CFrame.lookAt(Vector3.new(0, 30, 720), Vector3.new(0, 4, 880)), to = CFrame.lookAt(Vector3.new(0, 42, 780), Vector3.new(0, 4, 940)),
			text = "Each badge opens a new region. Boulder Pass, behind this gym, opens with your first badge.",
		},
		{
			from = CFrame.lookAt(Vector3.new(0, 70, 760), Vector3.new(0, 0, 1120)), to = CFrame.lookAt(Vector3.new(0, 110, 1220), Vector3.new(0, 0, 2020)),
			text = "The road keeps going, one region after another. Grey regions are still locked: their signs show how many badges you need, and each one has a Heal Stop at its entrance.",
		},
	}

	camera.CameraType = Enum.CameraType.Scriptable
	for _, shot in shots do
		advance = false
		camera.CFrame = shot.from
		play(camera, 7, { CFrame = shot.to }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		clearGlow()
		for _, id in shot.glow or {} do
			glow(rt and rt:FindFirstChild(id))
		end
		caption.Text = shot.text
		local t0 = os.clock()
		-- give people time to read; Next unlocks after a moment so it can't be skipped blindly
		nextBtn.Visible = false
		while os.clock() - t0 < 2.5 do
			task.wait()
		end
		nextBtn.Visible = true
		while not advance and os.clock() - t0 < 12 do
			task.wait()
		end
		play(black, 0.3, { BackgroundTransparency = 0 })
		task.wait(0.32)
		play(black, 0.4, { BackgroundTransparency = 1 })
	end
	keyConn:Disconnect()
	clearGlow()
	camera.CameraType = Enum.CameraType.Custom
	black:Destroy()
	caption:Destroy()
	nextBtn:Destroy()
	play(barTop, 0.5, { Position = UDim2.fromScale(0, -0.1) })
	play(barBottom, 0.5, { Position = UDim2.fromScale(0, 1) })
	task.delay(0.6, function()
		barTop:Destroy()
		barBottom:Destroy()
	end)
	player:SetAttribute("InCutscene", false)
end

TutorialRemote.OnClientEvent:Connect(function(kind)
	if kind == "tour" then
		task.spawn(function()
			local ok, err = pcall(regionTour)
			if not ok then
				warn("Region tour:", err)
				camera.CameraType = Enum.CameraType.Custom
				player:SetAttribute("InCutscene", false)
			end
			TutorialRemote:FireServer("tourDone")
		end)
	end
end)

----------------------------------------------------------------------------------------------
-- Journey tracker: Adventure goals and the saved milestone story.
----------------------------------------------------------------------------------------------
local panel = new("Frame", { Name="Journey",Position=UDim2.new(0,12,0,118),Size=UDim2.fromOffset(210,146),BackgroundColor3=Color3.fromRGB(25,25,35),BackgroundTransparency=0.12,Visible=false },gui)
new("UICorner",{CornerRadius=UDim.new(0,12)},panel)
new("UIStroke",{Color=GOLD,Thickness=2,Transparency=0.3},panel)
local selectedTab="Adventure"
local adventureBtn=new("TextButton",{Position=UDim2.fromOffset(7,6),Size=UDim2.fromOffset(95,26),BackgroundColor3=Color3.fromRGB(80,65,35),Text="Journey",Font=FONT,TextScaled=true,TextColor3=GOLD},panel)
local storyBtn=new("TextButton",{Position=UDim2.fromOffset(108,6),Size=UDim2.fromOffset(95,26),BackgroundColor3=Color3.fromRGB(55,35,75),Text="Story",Font=FONT,TextScaled=true,TextColor3=Color3.fromRGB(210,165,255),Visible=false},panel)
for _,button in {adventureBtn,storyBtn} do new("UICorner",{CornerRadius=UDim.new(0,7)},button) end
local function row(y,height,color)
 return new("TextLabel",{Position=UDim2.fromOffset(9,y),Size=UDim2.new(1,-18,0,height),BackgroundTransparency=1,Font=FONT,TextScaled=true,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextColor3=color or WHITE},panel)
end
local jRegion,jTrainers,jGym=row(37,23,GOLD),row(64,29),row(96,40)
local storyText=row(63,73,Color3.fromRGB(230,210,255));storyText.Visible=false
local journalBtn=new("TextButton",{Position=UDim2.fromOffset(9,111),Size=UDim2.new(1,-18,0,26),BackgroundColor3=Color3.fromRGB(75,45,100),Text="Journal & milestones",TextColor3=WHITE,Font=FONT,TextScaled=true,Visible=false},panel)
new("UICorner",{CornerRadius=UDim.new(0,7)},journalBtn)
local function decode(raw)
 if typeof(raw)~="string" or raw=="" then return {} end
 local ok,v=pcall(HttpService.JSONDecode,HttpService,raw)
 return ok and v or {}
end
local function updateJourney()
 local step=player:GetAttribute("TutorialStep")
 panel.Visible=step=="done" and not player:GetAttribute("InBattle") and not player:GetAttribute("InCutscene")
 storyBtn.Visible=player:GetAttribute("MetJuniper")==true
 if selectedTab=="Story" and not storyBtn.Visible then selectedTab="Adventure" end
 local story=selectedTab=="Story"
 storyText.Visible=story;jTrainers.Visible=not story;jGym.Visible=not story
 journalBtn.Visible=story and player:GetAttribute("JournalUnlocked")==true
 if story then
  jRegion.Text=player:GetAttribute("StoryChapter") or "Juniper"
  storyText.Size=UDim2.new(1,-18,0,journalBtn.Visible and 45 or 73)
  storyText.Text=player:GetAttribute("StoryObjective") or "Heal at Nurse Ivy's Healing Center."
  return
 end
 local badges=player:GetAttribute("Badges") or 0
 local champion=(player:GetAttribute("Stat_leagueWins") or 0)>0
 local index,region
 for i,r in GameData.Regions do if r.badges==badges and (not r.champion or champion) then index,region=i,r end end
 jTrainers.TextColor3=WHITE;jGym.TextColor3=GOLD
 if not region then
  if badges>=16 and champion then
   jRegion.Text=GameData.Region2.region.." League";jTrainers.Text="Defeat the Summit Elite Four";jGym.Text="Story → Juniper → Champion"
  elseif champion then
   jRegion.Text="★ Champion!";jTrainers.Text="Follow the east road to Summit";jGym.Text="Catch, explore and face Havoc."
  else
   local stage=player:GetAttribute("LeagueStage") or 1
   jRegion.Text=GameData.Region1.name.." League";jTrainers.Text=stage<=4 and ("Elite Four %d/4"):format(stage-1) or "✓ Elite Four 4/4";jGym.Text="Story → Juniper → Champion"
  end
  return
 end
 local beaten=decode(player:GetAttribute("BeatenTrainers"));local total,done=0,0
 for _,t in GameData.RouteTrainers do if t.lane==region.lane then total+=1;if table.find(beaten,t.id) then done+=1 end end end
 local leader
 for _,g in GameData.GymLeaders do if g.lane==region.lane then leader=g end end
 jRegion.Text=region.name
 jTrainers.Text=(done>=total and "✓ " or "• ")..("Trainers %d/%d"):format(done,total)
 jTrainers.TextColor3=done>=total and Color3.fromRGB(140,235,140) or WHITE
 if badges==0 and done<total then
  jGym.Text="Beat 3 trainers, then Gym Leader Slate"
 else
  jGym.Text="Beat "..(leader and leader.name:gsub("^Gym Leader ","") or "the gym")
 end
 jGym.TextColor3=done>=total and GOLD or Color3.fromRGB(185,185,200)
end
adventureBtn.Activated:Connect(function() selectedTab="Adventure";updateJourney() end)
storyBtn.Activated:Connect(function() selectedTab="Story";updateJourney() end)
local journalWindow
journalBtn.Activated:Connect(function()
 if journalWindow then journalWindow:Destroy();journalWindow=nil;return end
 journalWindow=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(0.88,0.74),BackgroundColor3=Color3.fromRGB(28,22,40),ZIndex=40},gui)
 new("UISizeConstraint",{MaxSize=Vector2.new(600,520)},journalWindow)
 new("UICorner",{CornerRadius=UDim.new(0,16)},journalWindow)
 local close=new("TextButton",{Position=UDim2.new(1,-80,0,10),Size=UDim2.fromOffset(68,32),Text="Close",Font=FONT,TextScaled=true,TextColor3=WHITE,BackgroundColor3=HAVOC,ZIndex=42},journalWindow)
 close.Activated:Connect(function() journalWindow:Destroy();journalWindow=nil end)
 local scroll=new("ScrollingFrame",{Position=UDim2.fromOffset(16,50),Size=UDim2.new(1,-32,1,-66),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=5,ZIndex=41},journalWindow)
 new("UIListLayout",{Padding=UDim.new(0,10)},scroll)
 local function entry(text,color)
  return new("TextLabel",{Size=UDim2.new(1,-8,0,60),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Text=text,TextColor3=color or WHITE,TextWrapped=true,TextSize=19,Font=FONT,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=42},scroll)
 end
 entry("Juniper's Journal",GOLD)
 entry("Day 714: If Father remembers me, the timeline will collapse. He must believe I am a stranger.")
 entry("Havoc follows my orders. But is the future fixed? One trainer keeps changing the numbers.")
 entry("The three anchors are a relay in Coral Reef, a reactor in Toxic Bog and an archive in Phantom Manor. When they fall, the future can change.")
 for _,milestone in decode(player:GetAttribute("StoryMilestones")) do entry((milestone.done and "✓ " or "• ")..milestone.title,milestone.done and Color3.fromRGB(145,235,170) or Color3.fromRGB(195,180,215)) end
end)
for _,attr in {"TutorialStep","Badges","BeatenTrainers","InBattle","InCutscene","LeagueStage","Stat_leagueWins","MetJuniper","StoryChapter","StoryObjective","StoryNext","JournalUnlocked"} do player:GetAttributeChangedSignal(attr):Connect(updateJourney) end
updateJourney()
-- A private world marker points to the next earned event; it never moves the player.
local marker=new("Part",{Name="PrivateStoryMarker",Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Transparency=1,Size=Vector3.new(1,1,1)},workspace)
local markerGui=new("BillboardGui",{Size=UDim2.fromOffset(140,56),StudsOffset=Vector3.new(0,6,0),AlwaysOnTop=true,MaxDistance=1000,Enabled=false},marker)
new("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(55,30,75),BackgroundTransparency=0.2,Text="◆ STORY",TextColor3=Color3.fromRGB(230,185,255),TextScaled=true,Font=FONT},markerGui)
local function updateMarker()
 local target=player:GetAttribute("StoryTarget")
 markerGui.Enabled=typeof(target)=="Vector3" and player:GetAttribute("MetJuniper")==true and player:GetAttribute("StoryReady")==true and not player:GetAttribute("InBattle") and not player:GetAttribute("InCutscene")
 if typeof(target)=="Vector3" then marker.Position=target end
end
for _,attr in {"StoryTarget","StoryReady","MetJuniper","InBattle","InCutscene"} do player:GetAttributeChangedSignal(attr):Connect(updateMarker) end
updateMarker()
local function updateStoryPrompts()
 local folder=workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("StoryMilestones")
 if not folder then return end
 for _,d in folder:GetDescendants() do
  if d:IsA("ProximityPrompt") and d:GetAttribute("StoryId") then
   d.Enabled=d:GetAttribute("StoryId")==player:GetAttribute("StoryNext") and player:GetAttribute("StoryReady")==true
  elseif d:IsA("BasePart") then
   local model=d:FindFirstAncestorOfClass("Model")
   if model and model.Name=="Havoc Route Grunt" then d.LocalTransparencyModifier=player:GetAttribute("HavocRoutesActive") and 0 or 1 end
  end
 end
end
for _,attr in {"StoryNext","StoryReady","HavocRoutesActive"} do player:GetAttributeChangedSignal(attr):Connect(updateStoryPrompts) end
workspace.DescendantAdded:Connect(function(d) if d:IsA("ProximityPrompt") and d:GetAttribute("StoryId") then task.defer(updateStoryPrompts) end end)
task.defer(updateStoryPrompts)
