--[[
	Music: background music that follows where you are.
	  overworld - hub, bases and routes
	  tower     - inside the Dark Tower (InDungeon)
	  battle    - wild and trainer battles
	  boss      - gym leader, tower boss and PvP (server sets BattleKind = "boss")
	Tracks crossfade. The overworld and tower tracks pause and resume where they left off;
	battle tracks start from the top each fight. The ♪ button mutes music (saved with your progress).
	Track IDs live in GameData.Audio.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))
local SettingsRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Settings")
local Audio = GameData.Audio

local tracks = {}
for key, id in Audio.music do
	local s = Instance.new("Sound")
	s.Name = "Music_" .. key
	s.SoundId = "rbxassetid://" .. id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	tracks[key] = s
end
task.spawn(function()
	local list = {}
	for _, s in tracks do
		table.insert(list, s)
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, list)
end)

local RESUMES = { overworld = true, tower = true } -- these pause instead of restarting
local muted = player:GetAttribute("MusicMuted") == true
local current = nil
local tweens = {}

local function fadeTo(sound: Sound, volume: number, onDone)
	if tweens[sound] then
		tweens[sound]:Cancel()
	end
	local t = TweenService:Create(sound, TweenInfo.new(Audio.fade, Enum.EasingStyle.Sine), { Volume = volume })
	tweens[sound] = t
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and onDone then
			onDone()
		end
	end)
	t:Play()
end

local function targetVolume(): number
	return muted and 0 or Audio.musicVolume
end

local function wanted(): string
	if player:GetAttribute("InBattle") then
		return player:GetAttribute("BattleKind") == "boss" and "boss" or "battle"
	end
	if player:GetAttribute("InDungeon") then
		return "tower"
	end
	return "overworld"
end

local function switch(key: string)
	if key == current then
		return
	end
	local oldKey, old = current, tracks[current]
	current = key
	if old then
		fadeTo(old, 0, function()
			if current ~= oldKey then
				if RESUMES[oldKey] then
					old:Pause()
				else
					old:Stop()
				end
			end
		end)
	end
	local new = tracks[key]
	if new then
		if not RESUMES[key] then
			new.TimePosition = 0
		end
		if new.IsPaused then
			new:Resume()
		elseif not new.IsPlaying then
			new:Play()
		end
		fadeTo(new, targetVolume())
	end
end

local function update()
	switch(wanted())
end
for _, attr in { "InBattle", "BattleKind", "InDungeon" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		task.defer(update) -- BattleKind and InBattle change together; settle first
	end)
end
update()

-- Watchdog: every few seconds make sure the right track is really playing at the right volume.
-- Catches anything that leaves music silent (a fade that got interrupted, a track that failed
-- to load the first time, a stopped sound) and quietly brings it back.
task.spawn(function()
	while true do
		task.wait(4)
		local key = wanted()
		if key ~= current then
			switch(key)
		end
		local s = tracks[current]
		if s then
			if not s.IsLoaded then
				pcall(ContentProvider.PreloadAsync, ContentProvider, { s })
			end
			if not s.IsPlaying then
				if s.IsPaused then
					s:Resume()
				else
					s:Play()
				end
			end
			local tween = tweens[s]
			local fading = tween and tween.PlaybackState == Enum.PlaybackState.Playing
			if not fading and math.abs(s.Volume - targetVolume()) > 0.01 then
				fadeTo(s, targetVolume())
			end
		end
		-- anything else that's somehow still audible gets faded out
		for k, other in tracks do
			if k ~= current and other.IsPlaying and other.Volume > 0.01 and not (tweens[other] and tweens[other].PlaybackState == Enum.PlaybackState.Playing) then
				fadeTo(other, 0, function()
					if current ~= k then
						other:Pause()
					end
				end)
			end
		end
	end
end)

-- Mute button (under the left-side menu buttons) ------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MusicUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 8
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "MusicButton"
button.AnchorPoint = Vector2.new(0, 0)
button.Position = UDim2.new(0, 12, 0.5, 141)
button.Size = UDim2.fromOffset(78, 36)
button.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
button.BackgroundTransparency = 0.2
button.Font = Enum.Font.FredokaOne
button.TextScaled = true
button.TextColor3 = Color3.new(1, 1, 1)
button.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5, 0)
corner.Parent = button
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.Parent = button

-- out of the way during battles (it sat on the battle panel) and dialogue
local function updateVisible()
	button.Visible = not (player:GetAttribute("InBattle") or player:GetAttribute("InDialogue") or player:GetAttribute("InCutscene"))
end
for _, attr in { "InBattle", "InDialogue", "InCutscene" } do
	player:GetAttributeChangedSignal(attr):Connect(updateVisible)
end
updateVisible()

local function render()
	button.Text = muted and "♪ OFF" or "♪ ON"
	button.TextColor3 = muted and Color3.fromRGB(170, 170, 180) or Color3.fromRGB(140, 235, 160)
end
local function applyMute()
	local s = tracks[current]
	if s then
		fadeTo(s, targetVolume())
	end
	render()
end
button.Activated:Connect(function()
	muted = not muted
	applyMute()
	SettingsRemote:FireServer("musicMuted", muted)
end)
player:GetAttributeChangedSignal("MusicMuted"):Connect(function()
	-- the saved setting arrives after loading
	local saved = player:GetAttribute("MusicMuted") == true
	if saved ~= muted then
		muted = saved
		applyMute()
	end
end)
render()
