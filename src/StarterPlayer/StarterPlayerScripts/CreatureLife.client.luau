--[[
	CreatureLife: makes nearby creatures look alive. Only this player sees it (Motor6D.Transform
	doesn't replicate), so it costs the server nothing.
	  - breathing bob and a little sway; a bouncy hop while walking
	  - blinking every few seconds
	  - tail wags, ear twitches, wing flaps (faster when moving or floating), flickering flames,
	    swaying leaves/antennae, drifting ghost wisps, bobbing fists
	Only creatures within RANGE studs of the camera animate.
]]

local RunService = game:GetService("RunService")

local RANGE = 140
local tracked = {} -- [Model] = state

local function register(model: Model)
	if tracked[model] or not model:GetAttribute("CreatureName") then
		return
	end
	local body = model:FindFirstChild("Body")
	local core = body and body:FindFirstChild("Core")
	if not core then
		return -- built before creatures had joints
	end
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d:GetAttribute("Anim") then
			table.insert(joints, { m = d, kind = d:GetAttribute("Anim"), side = d:GetAttribute("Side") or 1, reach = d:GetAttribute("Reach") or 0.5 })
		end
	end
	tracked[model] = {
		body = body, core = core, joints = joints,
		s = model:GetAttribute("Scale") or 3.5,
		floats = model:GetAttribute("Floats") == true,
		flier = model:GetAttribute("Shape") == "bird" or model:GetAttribute("Shape") == "dragon",
		phase = math.random() * 10,
		speed = 0.9 + math.random() * 0.25,
		nextBlink = os.clock() + 1 + math.random() * 3,
		blinkUntil = 0,
		lastPos = body.Position,
		moving = 0,
		twitchAt = os.clock() + math.random() * 4,
	}
end

local function scan(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("Model") then
			register(d)
		end
	end
end

workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Model") then
		-- parts stream in a moment after the model
		task.delay(0.2, register, d)
	elseif d:IsA("Motor6D") and d.Name == "Core" then
		local model = d:FindFirstAncestorOfClass("Model")
		if model then
			tracked[model] = nil
			task.delay(0.2, register, model)
		end
	end
end)
scan(workspace)

local sin, abs, rad = math.sin, math.abs, math.rad

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local now = os.clock()
	for model, st in tracked do
		local body = st.body
		if not model.Parent or not body.Parent then
			tracked[model] = nil
			continue
		end
		local pos = body.Position
		if (pos - camPos).Magnitude > RANGE then
			continue
		end
		-- are we walking? (smoothed)
		local moved = (pos - st.lastPos).Magnitude / math.max(dt, 1 / 240)
		st.lastPos = pos
		st.moving += ((moved > 0.6 and 1 or 0) - st.moving) * math.min(1, dt * 6)
		local t = now * st.speed + st.phase
		local s = st.s

		-- body: breathe + sway, hop while walking, float gently if it floats
		local breathe = sin(t * 2.4)
		local hop = abs(sin(t * 9)) * s * 0.12 * st.moving
		local float = st.floats and sin(t * 1.6) * s * 0.12 or 0
		st.core.Transform = CFrame.new(0, breathe * s * 0.025 + hop + float, 0)
			* CFrame.Angles(breathe * 0.03 + st.moving * 0.08, 0, sin(t * 1.3) * 0.04 + st.moving * sin(t * 9) * 0.06)

		-- blink
		if now >= st.nextBlink then
			st.blinkUntil = now + 0.13
			st.nextBlink = now + 2 + math.random() * 3.5
			if math.random() < 0.2 then
				st.nextBlink = now + 0.3 -- double blink
			end
		end
		local blinking = now < st.blinkUntil
		-- occasional ear twitch
		local twitch = 0
		if now >= st.twitchAt then
			if now < st.twitchAt + 0.25 then
				twitch = sin((now - st.twitchAt) / 0.25 * math.pi)
			else
				st.twitchAt = now + 2 + math.random() * 5
			end
		end

		for _, j in st.joints do
			local k, side = j.kind, j.side
			local tf
			if k == "lid" then
				tf = blinking and CFrame.new(0, 0, -j.reach) or CFrame.identity
			elseif k == "wing" then
				local fast = (st.flier and (st.moving > 0.3 or st.floats)) and 1 or 0
				local flap = sin(t * (fast > 0 and 16 or 3)) * (fast > 0 and 0.55 or 0.12)
				tf = CFrame.Angles(0, 0, flap * side)
			elseif k == "tail" then
				tf = CFrame.Angles(0, sin(t * (4 + st.moving * 4)) * 0.35, 0)
			elseif k == "ear" then
				tf = CFrame.Angles(twitch * -0.35, 0, sin(t * 1.7) * 0.05 * side)
			elseif k == "fin" then
				tf = CFrame.Angles(0, 0, sin(t * 5) * 0.25 * side)
			elseif k == "flame" then
				tf = CFrame.new(0, abs(sin(t * 11 + side)) * s * 0.03, 0) * CFrame.Angles(sin(t * 13) * 0.12, 0, sin(t * 9) * 0.12)
			elseif k == "antenna" or k == "leaf" then
				tf = CFrame.Angles(sin(t * 2.2) * 0.12, 0, sin(t * 1.8 + side) * 0.15)
			elseif k == "wisp" then
				tf = CFrame.new(sin(t * 2 + side) * s * 0.06, 0, 0)
			elseif k == "arm" then
				tf = CFrame.new(0, sin(t * 3 + side) * s * 0.04, 0)
			elseif k == "head" then
				-- look around a little, nod while walking
				tf = CFrame.Angles(sin(t * 1.4) * 0.05 + st.moving * sin(t * 9) * 0.06, sin(t * 0.7 + st.phase) * 0.18, sin(t * 1.1) * 0.04)
			elseif k == "wingpair" then
				-- both wings in one piece: bob them up and down
				local fast = (st.flier and (st.moving > 0.3 or st.floats)) and 1 or 0
				tf = CFrame.new(0, sin(t * (fast > 0 and 16 or 3)) * s * (fast > 0 and 0.05 or 0.015), 0)
			end
			if tf then
				j.m.Transform = tf
			end
		end
	end
end)
