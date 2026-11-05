--[[
	TrainerAnimations: plays R15 animations on the trainer rig (ReplicatedStorage.Companion.Trainer).
	Uses Roblox's standard R15 animations (owned by Roblox, free for any game), so no custom animation
	upload is needed. The rig is a normal R15 Humanoid, so any R15 animation can be added to IDS.

	  local TrainerAnimations = require(ReplicatedStorage.Shared.TrainerAnimations)
	  local anim = TrainerAnimations.new(trainerModel)
	  anim:play("walk")         -- loops until another looping state replaces it
	  anim:play("idle")
	  anim:play("command")      -- battle: point at the target (one shot, then back to idle)
	  anim:play("victory")      -- battle won: cheer (one shot, then back to idle)

	NPCAnimator already starts the idle loop on any model with the "R15" attribute; call :play("idle") only
	if you stopped it.
]]

local TrainerAnimations = {}
TrainerAnimations.__index = TrainerAnimations

local IDS = {
	idle = "rbxassetid://507766666",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
	command = "rbxassetid://507770453", -- point
	victory = "rbxassetid://507770677", -- cheer
	wave = "rbxassetid://507770239",
}
local LOOPED = { idle = true, walk = true, run = true }
local PRIORITY = {
	idle = Enum.AnimationPriority.Idle,
	walk = Enum.AnimationPriority.Movement,
	run = Enum.AnimationPriority.Movement,
}

function TrainerAnimations.new(model: Model)
	local self = setmetatable({}, TrainerAnimations)
	local hum = model:FindFirstChildOfClass("Humanoid")
	assert(hum, "TrainerAnimations needs a Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	self.animator = animator
	self.tracks = {}
	self.current = nil
	return self
end

function TrainerAnimations:_track(name: string): AnimationTrack?
	local cached = self.tracks[name]
	if cached then
		return cached
	end
	local id = IDS[name]
	if not id then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(self.animator.LoadAnimation, self.animator, anim)
	if not ok or not track then
		return nil
	end
	track.Looped = LOOPED[name] == true
	track.Priority = PRIORITY[name] or Enum.AnimationPriority.Action
	self.tracks[name] = track
	return track
end

function TrainerAnimations:play(name: string)
	local track = self:_track(name)
	if not track then
		return
	end
	if LOOPED[name] then
		if self.current and self.current ~= track then
			self.current:Stop(0.2)
		end
		self.current = track
		if not track.IsPlaying then
			track:Play(0.2)
		end
	else
		track:Play(0.15)
	end
end

function TrainerAnimations:stopAll()
	for _, track in self.tracks do
		track:Stop(0.1)
	end
	self.current = nil
end

return TrainerAnimations
