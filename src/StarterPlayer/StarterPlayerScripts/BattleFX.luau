--[[
	BattleFX: client-side battle animations. Everything here only changes what this
	player sees; the server's copy of the creatures doesn't move.
	  attack   - per-move styles (lunge, leap, rocks, quake, bolt, beam, projectile) with charge-up, knockback, camera shake and flashes
	  faint    - topple over and fade out
	  throw    - per-ball models (ReplicatedStorage.Shared.BallModels): a spinning arc with a trail, the lid hinges open
	             and pulls the creature in, a bounce to the ground, up to three escalating rocks with a blinking latch,
	             then a gold click or a breakout where the creature springs back out
	  levelUp  - gold glow
	  sendOut  - white pop as a creature enters the field
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local GameData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameData"))

local BattleFX = {}

local TYPE_COLORS = {
	Normal = Color3.fromRGB(215, 210, 195),
	Flying = Color3.fromRGB(150, 195, 255),
	Grass = Color3.fromRGB(110, 205, 90),
	Fire = Color3.fromRGB(255, 120, 45),
	Water = Color3.fromRGB(70, 150, 255),
	Electric = Color3.fromRGB(255, 225, 60),
	Bug = Color3.fromRGB(165, 205, 55),
	Poison = Color3.fromRGB(175, 85, 210),
	Fighting = Color3.fromRGB(215, 75, 55),
	Psychic = Color3.fromRGB(250, 100, 160),
	Ice = Color3.fromRGB(150, 225, 230),
	Ground = Color3.fromRGB(225, 190, 105),
	Rock = Color3.fromRGB(185, 160, 60),
	Ghost = Color3.fromRGB(115, 90, 160),
	Dragon = Color3.fromRGB(115, 55, 250),
	Dark = Color3.fromRGB(110, 85, 70),
	Steel = Color3.fromRGB(185, 185, 210),
	Fairy = Color3.fromRGB(240, 150, 175),
}
local WHITE = Color3.new(1, 1, 1)
local BALL_RED = Color3.fromRGB(225, 45, 45)

local function rootOf(model: Model?): BasePart?
	if model and model.Parent and model.PrimaryPart then
		return model.PrimaryPart
	end
	return nil
end

local function play(inst: Instance, time: number, props, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

local function effectPart(shape: Enum.PartType, size: number, color: Color3, position: Vector3): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = Vector3.one * size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Position = position
	p.Parent = workspace
	return p
end

-- Expanding glowing sphere that fades out
local function burst(position: Vector3, color: Color3, size: number)
	local p = effectPart(Enum.PartType.Ball, 0.5, color, position)
	p.Transparency = 0.15
	play(p, 0.35, { Size = Vector3.one * size, Transparency = 1 })
	Debris:AddItem(p, 0.5)
end

-- Little glowing bits flying outward
local function sparkle(position: Vector3, color: Color3, count: number, spread: number)
	for _ = 1, count do
		local p = effectPart(Enum.PartType.Ball, 0.35, color, position)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.4, math.random() - 0.5).Unit
		play(p, 0.6, { Position = position + dir * spread, Transparency = 1, Size = Vector3.one * 0.1 })
		Debris:AddItem(p, 0.7)
	end
end

local function flash(model: Model?, color: Color3, times: number)
	if not model or not model.Parent then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineTransparency = 1
	h.FillTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	for _ = 1, times do
		h.FillTransparency = 0.1
		play(h, 0.18, { FillTransparency = 1 })
		task.wait(0.2)
	end
	h:Destroy()
end

local function shake(part: BasePart, amount: number)
	local start = part.CFrame
	for _ = 1, 3 do
		if not part.Parent then
			return
		end
		part.CFrame = start * CFrame.new(amount, 0, 0)
		task.wait(0.04)
		part.CFrame = start * CFrame.new(-amount, 0, 0)
		task.wait(0.04)
	end
	part.CFrame = start
end

-- Move styles: how each move is delivered. Anything not listed falls back to its type.
local MOVE_STYLE = {
	Tackle = "lunge", Gnaw = "lunge", ["Quick Peck"] = "lunge", Jab = "lunge", ["Power Punch"] = "lunge",
	["Bug Nibble"] = "lunge", Stinger = "lunge", ["Vine Snap"] = "lunge", ["Ember Nip"] = "lunge",
	["Pincer Snap"] = "lunge", ["Shade Claw"] = "lunge", ["Night Snap"] = "lunge", ["Frost Bite"] = "lunge",
	["Poison Prick"] = "lunge", ["Wing Slash"] = "lunge",
	["Shell Slam"] = "leap", ["Magma Slam"] = "leap", ["Sky Dive"] = "leap", ["Inferno Dive"] = "leap",
	["Dragon Rush"] = "leap", ["Flame Rush"] = "leap",
	["Rock Throw"] = "rocks", Rockfall = "rocks",
	["Quake Stomp"] = "quake", ["Sand Burst"] = "quake", ["Volt Burrow"] = "quake",
	Spark = "bolt", ["Static Buzz"] = "bolt", ["Thunder Lash"] = "bolt",
	Moonbeam = "beam", ["Glimmer Beam"] = "beam", ["Drake Breath"] = "beam", ["Tide Pulse"] = "beam",
	["Astral Gale"] = "beam", ["Torrent Blast"] = "beam", ["Steel Beam"] = "beam", ["Umbra Pulse"] = "beam",
	["Pixie Burst"] = "beam",
}
local TYPE_STYLE = {
	Normal = "lunge", Fighting = "lunge", Bug = "lunge", Dark = "lunge", Steel = "lunge",
	Rock = "rocks", Ground = "quake", Electric = "bolt", Psychic = "beam", Dragon = "beam",
}

local camera = workspace.CurrentCamera
local Lighting = game:GetService("Lighting")

-- Rattle the (scripted) battle camera, then put it back exactly where it was
local function shakeCamera(strength: number, duration: number)
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		return
	end
	task.spawn(function()
		local base = camera.CFrame
		local t0 = os.clock()
		while os.clock() - t0 < duration do
			local fade = 1 - (os.clock() - t0) / duration
			local o = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * strength * fade
			camera.CFrame = base * CFrame.new(o) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.02 * strength * fade)
			RunService.RenderStepped:Wait()
		end
		camera.CFrame = base
	end)
end

-- A quick bright wash over the whole screen (big hits and super-effective hits)
local function screenFlash(color: Color3, amount: number)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.TintColor = color
	cc.Brightness = amount
	cc.Parent = Lighting
	play(cc, 0.35, { Brightness = 0, TintColor = WHITE })
	Debris:AddItem(cc, 0.4)
end

-- Flat ring that spreads across the ground
local function groundRing(position: Vector3, color: Color3, size: number, time: number?)
	local p = effectPart(Enum.PartType.Cylinder, 1, color, position)
	p.Size = Vector3.new(0.2, 1, 1)
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	p.Transparency = 0.2
	play(p, time or 0.45, { Size = Vector3.new(0.2, size, size), Transparency = 1 })
	Debris:AddItem(p, (time or 0.45) + 0.1)
end

local function groundY(model: Model?, root: BasePart): number
	return root.Position.Y - ((model and model:GetAttribute("GroundOffset")) or 1) + 0.15
end

-- Charge-up: the attacker glows in the move's colour while light gathers around it
local function charge(model: Model?, root: BasePart, color: Color3, time: number)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	play(h, time, { FillTransparency = 0.45, OutlineTransparency = 0.2 })
	local orb = effectPart(Enum.PartType.Ball, root.Size.X * 2.6, color, root.Position)
	orb.Transparency = 0.85
	play(orb, time, { Size = Vector3.one * root.Size.X * 1.1, Transparency = 0.55 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _ = 1, 6 do
		local start = root.Position + Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit * root.Size.X * 2
		local bit = effectPart(Enum.PartType.Ball, 0.3, color, start)
		play(bit, time, { Position = root.Position, Size = Vector3.one * 0.1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(bit, time + 0.05)
	end
	task.wait(time)
	orb:Destroy()
	play(h, 0.3, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(h, 0.35)
end

-- Rear back before a physical move
local function rearBack(root: BasePart, home: CFrame, time: number)
	play(root, time, { CFrame = home * CFrame.new(0, 0.3, 0.9) * CFrame.Angles(math.rad(14), 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.wait(time)
end

-- Fly a glowing orb from a to b, leaving a fading trail
local function projectile(from: Vector3, to: Vector3, color: Color3, size: number, time: number, arc: number)
	local orb = effectPart(Enum.PartType.Ball, size, color, from)
	local t0, frame = os.clock(), 0
	while true do
		local t = math.min(1, (os.clock() - t0) / time)
		orb.Position = from:Lerp(to, t) + Vector3.new(0, arc * 4 * t * (1 - t), 0)
		frame += 1
		if frame % 2 == 0 then
			local ghost = effectPart(Enum.PartType.Ball, size * 0.8, color, orb.Position)
			ghost.Transparency = 0.4
			play(ghost, 0.25, { Size = Vector3.one * 0.05, Transparency = 1 })
			Debris:AddItem(ghost, 0.3)
		end
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	orb:Destroy()
end

-- A jagged lightning bolt from the sky down onto a point
local function lightning(target: Vector3, color: Color3)
	local top = target + Vector3.new((math.random() - 0.5) * 3, 22, (math.random() - 0.5) * 3)
	local points = { top }
	for i = 1, 6 do
		local t = i / 7
		table.insert(points, top:Lerp(target, t) + Vector3.new((math.random() - 0.5) * 2.2, 0, (math.random() - 0.5) * 2.2))
	end
	table.insert(points, target)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = effectPart(Enum.PartType.Block, 1, i % 2 == 0 and WHITE or color, a)
		seg.Size = Vector3.new(0.35, 0.35, (b - a).Magnitude)
		seg.CFrame = CFrame.lookAt((a + b) / 2, b)
		play(seg, 0.3, { Transparency = 1 })
		Debris:AddItem(seg, 0.35)
	end
end

-- What happens to the defender at the moment of contact
local function impact(defender: Model?, d: BasePart, fromDir: Vector3, color: Color3, strong: boolean, mult: number, onImpact)
	if onImpact then
		onImpact()
	end
	local gy = groundY(defender, d)
	burst(d.Position, color, d.Size.X * (strong and 4 or 2.6))
	burst(d.Position, WHITE, d.Size.X * 1.6)
	sparkle(d.Position, color, strong and 16 or 8, d.Size.X * (strong and 2.4 or 1.6))
	groundRing(Vector3.new(d.Position.X, gy, d.Position.Z), color, d.Size.X * (strong and 7 or 4.5))
	if mult <= 0 then
		return
	end
	-- knocked back and tipped over a little, then springs back
	local start = d.CFrame
	local push = fromDir * (strong and 2.2 or 1.3)
	d.CFrame = start + push * 0.3
	play(d, 0.12, { CFrame = (start + push + Vector3.new(0, 0.4, 0)) * CFrame.Angles(math.rad(strong and -22 or -12), 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.16, function()
		if d.Parent then
			play(d, 0.45, { CFrame = start }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end)
	task.spawn(flash, defender, WHITE, mult > 1 and 3 or 1)
	shakeCamera(strong and 1.1 or 0.45, strong and 0.45 or 0.25)
	if strong or mult > 1 then
		screenFlash(color, mult > 1 and 0.45 or 0.3)
	end
end

-- fx = { hit, mult, moveType, moveName, power }. onImpact runs at the moment of contact (drops the HP bar).
function BattleFX.attack(attacker: Model?, defender: Model?, fx, onImpact)
	local a, d = rootOf(attacker), rootOf(defender)
	if not a or not d then
		if onImpact then
			onImpact()
		end
		task.wait(0.6)
		return
	end

	local color = TYPE_COLORS[fx.moveType] or WHITE
	local style = MOVE_STYLE[fx.moveName or ""] or TYPE_STYLE[fx.moveType] or "projectile"
	local mult = fx.mult or 1
	local strong = (fx.power or 0) >= 75 or mult > 1
	local flat = Vector3.new(d.Position.X - a.Position.X, 0, d.Position.Z - a.Position.Z)
	-- a target that hasn't streamed onto the field yet: don't spin round to face it
	if flat.Magnitude < 0.1 or flat.Magnitude > 150 then
		if onImpact then
			onImpact()
		end
		task.wait(0.6)
		return
	end
	local dir = flat.Unit
	local home = CFrame.lookAt(a.Position, a.Position + dir)
	a.CFrame = home
	local reach = math.max(1, (flat.Magnitude - (a.Size.X + d.Size.X) * 0.5) * 0.9)

	local function hitOrMiss()
		if fx.hit then
			impact(defender, d, dir, color, strong, mult, onImpact)
		else
			-- sidestep with an afterimage
			local dStart = d.CFrame
			local ghost = effectPart(Enum.PartType.Ball, d.Size.X * 1.2, WHITE, d.Position)
			ghost.Transparency = 0.6
			play(ghost, 0.35, { Transparency = 1 })
			Debris:AddItem(ghost, 0.4)
			play(d, 0.12, { CFrame = dStart + dStart.RightVector * 3 + Vector3.new(0, 1, 0) })
			task.delay(0.35, function()
				if d.Parent then
					play(d, 0.2, { CFrame = dStart })
				end
			end)
			if onImpact then
				onImpact()
			end
		end
	end

	if style == "lunge" then
		rearBack(a, home, strong and 0.25 or 0.16)
		play(a, 0.14, { CFrame = home + dir * reach + Vector3.new(0, 0.8, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.14)
		hitOrMiss()
		task.wait(0.08)
		play(a, 0.3, { CFrame = home }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	elseif style == "leap" then
		charge(attacker, a, color, strong and 0.4 or 0.25)
		-- spring high into the air, then come crashing down on the target
		local from = a.Position
		local to = d.Position - dir * (d.Size.X * 0.4) + Vector3.new(0, d.Size.Y * 0.3, 0)
		local t0 = os.clock()
		local time = 0.5
		while true do
			local t = math.min(1, (os.clock() - t0) / time)
			local e = t * t
			local pos = from:Lerp(to, e) + Vector3.new(0, 10 * math.sin(math.pi * math.min(1, t * 1.15)), 0)
			a.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(math.rad(-30 * t), 0, 0)
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		hitOrMiss()
		task.wait(0.12)
		play(a, 0.4, { CFrame = home }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	elseif style == "rocks" then
		charge(attacker, a, color, 0.25)
		local count = strong and 5 or 3
		for i = 1, count do
			local off = Vector3.new((math.random() - 0.5) * 2.5, 0, (math.random() - 0.5) * 2.5)
			local rock = effectPart(Enum.PartType.Block, 1, Color3.fromRGB(120, 110, 95), d.Position + off + Vector3.new(0, 18, 0))
			rock.Material = Enum.Material.Slate
			rock.Size = Vector3.one * (strong and 2.2 or 1.6)
			rock.CFrame = CFrame.new(rock.Position) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
			play(rock, 0.3, { CFrame = CFrame.new(d.Position + off) * CFrame.Angles(math.random() * 6, math.random() * 6, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(rock, 0.5)
			task.wait(i == count and 0.3 or 0.12)
		end
		hitOrMiss()
	elseif style == "quake" then
		-- stomp, then shockwaves race across the ground to the target
		play(a, 0.15, { CFrame = home + Vector3.new(0, 2, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.wait(0.15)
		play(a, 0.1, { CFrame = home }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.1)
		shakeCamera(0.5, 0.3)
		local gy = groundY(attacker, a)
		for i = 1, 4 do
			local p = a.Position:Lerp(d.Position, i / 4)
			groundRing(Vector3.new(p.X, gy, p.Z), color, 3 + i * 1.5, 0.35)
			sparkle(Vector3.new(p.X, gy, p.Z), Color3.fromRGB(200, 175, 120), 4, 2)
			task.wait(0.08)
		end
		hitOrMiss()
	elseif style == "bolt" then
		charge(attacker, a, color, strong and 0.4 or 0.25)
		lightning(d.Position, color)
		if strong then
			task.wait(0.06)
			lightning(d.Position, color)
		end
		hitOrMiss()
	elseif style == "beam" then
		charge(attacker, a, color, strong and 0.5 or 0.3)
		local from = a.Position + dir * a.Size.X * 0.5
		local to = d.Position
		local len = (to - from).Magnitude
		local width = strong and 1.6 or 1
		local beam = effectPart(Enum.PartType.Block, 1, color, from)
		beam.Size = Vector3.new(0.1, 0.1, len)
		beam.CFrame = CFrame.lookAt((from + to) / 2, to)
		local core = effectPart(Enum.PartType.Block, 1, WHITE, from)
		core.Size = Vector3.new(0.05, 0.05, len)
		core.CFrame = beam.CFrame
		play(beam, 0.08, { Size = Vector3.new(width, width, len) })
		play(core, 0.08, { Size = Vector3.new(width * 0.4, width * 0.4, len) })
		task.wait(0.08)
		hitOrMiss()
		task.wait(strong and 0.35 or 0.2)
		play(beam, 0.2, { Size = Vector3.new(0.05, 0.05, len), Transparency = 1 })
		play(core, 0.2, { Size = Vector3.new(0.02, 0.02, len), Transparency = 1 })
		Debris:AddItem(beam, 0.25)
		Debris:AddItem(core, 0.25)
	else
		-- projectile volley
		charge(attacker, a, color, strong and 0.35 or 0.2)
		local count = strong and 3 or 1
		for i = 1, count do
			local from = a.Position + dir * a.Size.X * 0.5
			local aim = d.Position + Vector3.new((math.random() - 0.5) * 1.2, (math.random() - 0.5) * 1.2, 0)
			if i < count then
				task.spawn(projectile, from, aim, color, strong and 1.2 or 0.9, 0.3, 1.5)
				task.wait(0.09)
			else
				projectile(from, aim, color, strong and 1.2 or 0.9, 0.3, 1.5)
			end
		end
		hitOrMiss()
	end
	task.wait(strong and 0.7 or 0.5)
end

function BattleFX.faint(model: Model?)
	local r = rootOf(model)
	if not r then
		task.wait(0.6)
		return
	end
	local tag = r:FindFirstChild("NameTag")
	if tag then
		tag.Enabled = false
	end
	local start = r.CFrame
	task.spawn(flash, model, Color3.fromRGB(255, 70, 70), 2)
	-- a last jolt upward, then a spinning collapse in a puff of dust
	play(r, 0.18, { CFrame = start + Vector3.new(0, 1.2, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.wait(0.2)
	play(r, 0.55, { CFrame = start * CFrame.new(0, -r.Size.Y * 0.35, 0) * CFrame.Angles(0, math.rad(120), math.rad(88)) }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	task.wait(0.3)
	local gy = groundY(model, r)
	groundRing(Vector3.new(r.Position.X, gy, r.Position.Z), Color3.fromRGB(210, 200, 180), r.Size.X * 5, 0.6)
	sparkle(Vector3.new(r.Position.X, gy, r.Position.Z), Color3.fromRGB(210, 200, 180), 10, 3)
	shakeCamera(0.5, 0.3)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			play(p, 0.7, { Transparency = 1 })
		end
	end
	task.wait(0.8)
end

local function setHidden(model: Model, hidden: boolean, saved)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			if hidden then
				saved[p] = p.Transparency
				p.Transparency = 1
			else
				p.Transparency = saved[p] or 0
			end
		end
	end
	local light = model.PrimaryPart and model.PrimaryPart:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = not hidden
	end
	local sparkles = model.PrimaryPart and model.PrimaryPart:FindFirstChildOfClass("Sparkles")
	if sparkles then
		sparkles.Enabled = not hidden
	end
end

-- Thrown balls. Each ball type has its own model in ReplicatedStorage.Shared.BallModels (built from
-- two half shells, a metal belt, a glowing latch and per-ball trim). The lid really opens: it hinges
-- at the back, swallows the creature, snaps shut, then the ball rocks up to three times.
local BallModels = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BallModels", 5)

local function plainBall(def)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 1.5
	ball.Color = def and def.color or BALL_RED
	ball.Material = Enum.Material.SmoothPlastic
	local gui = Instance.new("BillboardGui")
	gui.Name = "Symbol"
	gui.Size = UDim2.new(1.3, 0, 1.3, 0)
	gui.LightInfluence = 0
	gui.Parent = ball
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.Text = (def and not def.unlimited) and "" or "∞"
	label.Parent = gui
	return ball
end

function BattleFX.makeBall(ballId: string?): BasePart
	local def = ballId and GameData and GameData.Balls[ballId]
	local tpl = BallModels and (BallModels:FindFirstChild(ballId or "") or BallModels:FindFirstChild("Default"))
	local ball = tpl and tpl:Clone() or plainBall(def)
	ball.Name = "ThrownBall"
	ball.Anchored = true
	ball.CanCollide, ball.CanQuery, ball.CanTouch = false, false, false
	-- everything on the upper half rides on the lid, so the lid can swing open as one piece
	local lid = ball:FindFirstChild("Top")
	if lid then
		for _, p in ball:GetChildren() do
			if p:IsA("BasePart") and p ~= lid and p.Name ~= "Bottom" and p.Name ~= "Belt" and p.Name ~= "Latch" then
				local w = p:FindFirstChildOfClass("WeldConstraint")
				if w and ball.CFrame:PointToObjectSpace(p.Position).Y > 0.12 then
					w.Part0 = lid
				end
			end
		end
	end
	return ball
end

local function ballParts(ball: BasePart)
	local list = {}
	for _, d in ball:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function fadeBall(ball: BasePart, time: number)
	for _, p in ballParts(ball) do
		play(p, time, { Transparency = 1 })
	end
	local sym = ball:FindFirstChild("Symbol")
	if sym then
		sym.Enabled = false
	end
end

local function glow(ball: BasePart, brightness: number, color: Color3?, time: number?)
	local light = ball:FindFirstChild("Glow")
	if light then
		if color then
			light.Color = color
		end
		play(light, time or 0.15, { Brightness = brightness })
	end
end

local function latch(ball: BasePart, color: Color3, time: number?)
	local l = ball:FindFirstChild("Latch")
	if l then
		play(l, time or 0.1, { Color = color })
	end
end

-- swing the lid open (angle in degrees, 0 = shut). The lid's weld is released while it moves.
local function setLid(ball: BasePart, angle: number, time: number)
	local lid = ball:FindFirstChild("Top")
	local weld = lid and lid:FindFirstChildOfClass("WeldConstraint")
	if not (lid and weld) then
		return
	end
	local shut = ball:GetAttribute("LidShut")
	if not shut then
		shut = ball.CFrame:ToObjectSpace(lid.CFrame)
		ball:SetAttribute("LidShut", shut)
	end
	local hinge = CFrame.new(0, 0, ball.Size.Z / 2)
	local goal = ball.CFrame * hinge * CFrame.Angles(math.rad(angle), 0, 0) * hinge:Inverse() * shut
	weld.Enabled = false
	lid.Anchored = true
	if time <= 0 then
		lid.CFrame = goal
	else
		play(lid, time, { CFrame = goal }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		task.wait(time)
	end
	if angle == 0 then
		lid.CFrame = ball.CFrame * shut
		weld.Enabled = true
		lid.Anchored = false
	end
end

-- shrink (or grow back) a creature toward a point
local function scaleModel(model: Model, from: number, to: number, time: number, toward: Vector3?, style)
	local ok, base = pcall(function()
		return model:GetScale()
	end)
	if not ok then
		return
	end
	local home = model:GetPivot()
	local t0 = os.clock()
	while true do
		local a = math.min(1, (os.clock() - t0) / time)
		local e = style == "back" and (1 + 2.2 * (a - 1) ^ 3 + 1.2 * (a - 1) ^ 2) or a * a
		local k = from + (to - from) * e
		pcall(function()
			model:ScaleTo(math.max(0.02, base * k))
			if toward then
				model:PivotTo(home.Rotation + home.Position:Lerp(toward, 1 - k))
			end
		end)
		if a >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	return base, home
end

-- onShake(i, total) is called on each wobble (the battle text shows ". . .")
function BattleFX.throw(fromPos: Vector3, wildModel: Model?, caught: boolean, shakes: number, ballId: string?, onShake)
	local w = rootOf(wildModel)
	if not w then
		task.wait(1)
		return
	end
	local def = ballId and GameData and GameData.Balls[ballId]
	local accent = (def and def.band) or Color3.fromRGB(255, 225, 120)
	local ball = BattleFX.makeBall(ballId)
	local D = ball.Size.Y
	ball.CFrame = CFrame.new(fromPos)
	ball.Parent = workspace
	local trail = ball:FindFirstChild("Trail")
	if trail then
		trail.Enabled = true
	end

	-- 1) wind-up and a spinning arc; higher arc for longer throws
	local hover = w.Position + Vector3.new(0, w.Size.Y * 0.55 + 1.4, 0)
	local flat = Vector3.new(hover.X - fromPos.X, 0, hover.Z - fromPos.Z)
	local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
	local height = math.clamp(flat.Magnitude * 0.35, 6, 18)
	local duration = math.clamp(flat.Magnitude / 40, 0.45, 0.75)
	local t0 = os.clock()
	while true do
		local t = math.min(1, (os.clock() - t0) / duration)
		local pos = fromPos:Lerp(hover, t) + Vector3.new(0, height * 4 * t * (1 - t), 0)
		ball.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-t * 20, 0, 0)
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	if trail then
		trail.Enabled = false
	end

	-- 2) bonk: the ball pops back a little and turns to face you
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or (hover - dir * 10)
	local face = Vector3.new(camPos.X, hover.Y, camPos.Z)
	local hoverCF = CFrame.lookAt(hover + Vector3.new(0, 0.8, 0) - dir * 0.6, face)
	task.spawn(shake, w, 0.25)
	play(ball, 0.18, { CFrame = hoverCF }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.wait(0.2)

	-- 3) the lid swings open and the creature is pulled in as light
	setLid(ball, 75, 0.18)
	glow(ball, 3, accent, 0.1)
	local beam = effectPart(Enum.PartType.Block, 1, accent, ball.Position)
	local dist = (w.Position - ball.Position).Magnitude
	beam.Size = Vector3.new(0.35, 0.35, dist)
	beam.CFrame = CFrame.lookAt(ball.Position, w.Position) * CFrame.new(0, 0, -dist / 2)
	beam.Transparency = 0.2
	task.spawn(flash, wildModel, accent, 1)
	local baseScale, home = scaleModel(wildModel, 1, 0.08, 0.38, ball.Position)
	play(beam, 0.15, { Transparency = 1, Size = Vector3.new(0.05, 0.05, dist) })
	Debris:AddItem(beam, 0.2)
	burst(ball.Position, accent, 3.5)
	local saved = {}
	setHidden(wildModel, true, saved)
	if baseScale then
		pcall(function()
			wildModel:ScaleTo(baseScale)
			wildModel:PivotTo(home)
		end)
	end
	setLid(ball, 0, 0.12)
	task.wait(0.12)
	setLid(ball, 0, 0)
	glow(ball, 0, nil, 0.25)
	shakeCamera(0.25, 0.15)

	-- 4) drops to the ground with a bounce and a puff of dust
	local groundY = w.Position.Y - (wildModel:GetAttribute("GroundOffset") or 1) + D * 0.5
	local restPos = Vector3.new(hover.X, groundY, hover.Z)
	local rest = CFrame.lookAt(restPos, Vector3.new(camPos.X, groundY, camPos.Z))
	play(ball, 0.5, { CFrame = rest }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	task.wait(0.22)
	groundRing(restPos - Vector3.new(0, D * 0.45, 0), Color3.fromRGB(230, 225, 210), 4, 0.4)
	task.wait(0.5)

	-- 5) the shakes: each rock is a damped wobble that leans a little harder than the last,
	-- with the latch blinking. A catch rocks three times; a miss breaks out on shake 1, 2 or 3.
	local total = caught and 3 or math.clamp(shakes, 1, 3)
	local pivot = rest * CFrame.new(0, -D / 2, 0)
	for i = 1, total do
		task.wait(i == 1 and 0.35 or 0.5)
		latch(ball, Color3.fromRGB(255, 70, 60), 0.08)
		glow(ball, 1.6, Color3.fromRGB(255, 80, 60), 0.08)
		local amp = math.rad(18 + i * 8)
		local side = i % 2 == 0 and -1 or 1
		local dur, s0 = 0.55, os.clock()
		while true do
			local t = math.min(1, (os.clock() - s0) / dur)
			local angle = side * amp * math.sin(t * math.pi * 2.5) * (1 - t)
			ball.CFrame = pivot * CFrame.Angles(0, 0, angle) * CFrame.new(0, D / 2, 0)
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		ball.CFrame = rest
		latch(ball, accent, 0.2)
		glow(ball, 0, nil, 0.2)
		sparkle(restPos - Vector3.new(0, D * 0.4, 0), Color3.fromRGB(230, 225, 210), 3, 1)
		if onShake then
			pcall(onShake, i, 3)
		end
		task.wait(0.25)
	end

	if caught then
		-- 6a) click! the latch locks gold, a little hop, a ring of stars
		task.wait(0.25)
		latch(ball, Color3.fromRGB(255, 215, 60), 0.05)
		glow(ball, 4, Color3.fromRGB(255, 215, 60), 0.05)
		play(ball, 0.12, { CFrame = rest * CFrame.new(0, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.wait(0.12)
		play(ball, 0.25, { CFrame = rest }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
		sparkle(ball.Position, Color3.fromRGB(255, 225, 80), 16, 5)
		burst(ball.Position, Color3.fromRGB(255, 225, 80), 4)
		groundRing(restPos - Vector3.new(0, D * 0.45, 0), Color3.fromRGB(255, 225, 80), 7, 0.6)
		task.wait(1)
		glow(ball, 0, nil, 0.4)
		play(ball, 0.45, { CFrame = rest * CFrame.new(0, 1.6, 0) })
		fadeBall(ball, 0.45)
		sparkle(ball.Position, Color3.fromRGB(255, 255, 255), 6, 2)
		task.wait(0.45)
	else
		-- 6b) breakout: the lid bursts open, a flash, and the creature springs back out
		task.wait(0.15)
		latch(ball, WHITE, 0.05)
		setLid(ball, 120, 0.12)
		burst(ball.Position, WHITE, w.Size.X * 2.4)
		sparkle(ball.Position, accent, 8, 3)
		shakeCamera(0.35, 0.2)
		if baseScale then
			pcall(function()
				wildModel:ScaleTo(baseScale * 0.1)
			end)
		end
		setHidden(wildModel, false, saved)
		if baseScale then
			pcall(function()
				wildModel:ScaleTo(baseScale)
			end)
			task.spawn(scaleModel, wildModel, 0.1, 1, 0.35, nil, "back")
		end
		local away = rest * CFrame.new(0, 0, 3)
		play(ball, 0.4, { CFrame = away * CFrame.Angles(math.rad(-80), 0, math.rad(25)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		fadeBall(ball, 0.4)
		task.wait(0.45)
		if baseScale then
			pcall(function()
				wildModel:ScaleTo(baseScale)
			end)
		end
	end
	ball:Destroy()
end

function BattleFX.levelUp(model: Model?)
	local r = rootOf(model)
	if r then
		burst(r.Position, Color3.fromRGB(255, 215, 60), r.Size.X * 2.5)
		sparkle(r.Position, Color3.fromRGB(255, 215, 60), 10, 5)
	end
	flash(model, Color3.fromRGB(255, 215, 60), 2)
end

-- Stat change: arrows streaming up (raised, red) or down (lowered, blue) around the creature
function BattleFX.statChange(model: Model?, stages: number)
	local r = rootOf(model)
	if not r then
		task.wait(0.6)
		return
	end
	local up = stages > 0
	local color = up and Color3.fromRGB(255, 90, 70) or Color3.fromRGB(80, 150, 255)
	task.spawn(flash, model, color, 2)
	for i = 1, 10 do
		local offset = Vector3.new((math.random() - 0.5) * r.Size.X * 1.6, 0, (math.random() - 0.5) * r.Size.X * 1.6)
		local startY = up and -r.Size.Y * 0.6 or r.Size.Y * 0.9
		local arrow = effectPart(Enum.PartType.Block, 0.3, color, r.Position + offset + Vector3.new(0, startY, 0))
		arrow.Size = Vector3.new(0.25, 1.1, 0.25)
		play(arrow, 0.6, { Position = arrow.Position + Vector3.new(0, up and 3 or -3, 0), Transparency = 1 })
		Debris:AddItem(arrow, 0.7)
		task.wait(0.05)
	end
	task.wait(0.4)
end

-- A status move: the user glows in the move's colour instead of lunging
function BattleFX.statusMove(attacker: Model?, moveType: string)
	local r = rootOf(attacker)
	if r then
		burst(r.Position, TYPE_COLORS[moveType] or WHITE, r.Size.X * 2)
		sparkle(r.Position, TYPE_COLORS[moveType] or WHITE, 6, 3)
	end
	flash(attacker, TYPE_COLORS[moveType] or WHITE, 1)
	task.wait(0.3)
end

-- A status condition taking hold (or hurting): the creature flashes in the status colour
function BattleFX.statusEffect(model: Model?, color: Color3)
	local r = rootOf(model)
	if not r then
		task.wait(0.3)
		return
	end
	task.spawn(flash, model, color, 2)
	sparkle(r.Position + Vector3.new(0, r.Size.Y * 0.3, 0), color, 8, 3)
	task.wait(0.4)
end

function BattleFX.sendOut(model: Model?)
	local r = rootOf(model)
	if not r then
		return
	end
	local home = r.CFrame
	local gy = groundY(model, r)
	local column = effectPart(Enum.PartType.Cylinder, 1, WHITE, Vector3.new(r.Position.X, gy + 10, r.Position.Z))
	column.Size = Vector3.new(20, r.Size.X * 1.8, r.Size.X * 1.8)
	column.CFrame = CFrame.new(r.Position.X, gy + 10, r.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	column.Transparency = 0.3
	play(column, 0.5, { Size = Vector3.new(20, 0.1, 0.1), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(column, 0.55)
	r.CFrame = home + Vector3.new(0, 3, 0)
	play(r, 0.35, { CFrame = home }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	burst(r.Position, WHITE, r.Size.X * 2.8)
	sparkle(r.Position, BALL_RED, 10, 4)
	groundRing(Vector3.new(r.Position.X, gy, r.Position.Z), WHITE, r.Size.X * 5)
	flash(model, WHITE, 1)
end

return BattleFX
