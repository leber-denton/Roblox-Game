--[[
	DungeonNPCStyler: gives every Dark Tower trainer its own spooky look at server start.
	The trainer models are built in Studio (Map.DungeonTower.RoomN.Trainer); this restyles them in code,
	so nothing in the place file changes and it is safe to re-run (it skips NPCs it already styled).
	Look = rank palette (Trainee / Adept / Veteran / Warden) + a small per-NPC tint + signature props.
	Props are welded, massless, non-colliding parts kept in a "DungeonStyle" folder inside the model.
]]

local DungeonNPCStyler = {}

local RANKS = {
	Trainee = {
		cloth = Color3.fromRGB(58, 48, 78),
		skin = Color3.fromRGB(176, 170, 190),
		bone = Color3.fromRGB(205, 200, 215),
		glow = Color3.fromRGB(170, 120, 255),
	},
	Adept = {
		cloth = Color3.fromRGB(34, 36, 76),
		skin = Color3.fromRGB(150, 152, 178),
		bone = Color3.fromRGB(190, 195, 220),
		glow = Color3.fromRGB(110, 160, 255),
	},
	Veteran = {
		cloth = Color3.fromRGB(46, 24, 36),
		skin = Color3.fromRGB(140, 130, 142),
		bone = Color3.fromRGB(200, 185, 185),
		glow = Color3.fromRGB(255, 90, 110),
	},
	Warden = {
		cloth = Color3.fromRGB(14, 10, 22),
		skin = Color3.fromRGB(110, 105, 125),
		bone = Color3.fromRGB(70, 64, 88),
		glow = Color3.fromRGB(255, 200, 90),
	},
}

-- Per-NPC signature props (keyed by the last word of the trainer's name) and optional glow tint
local LOOKS = {
	Pip = { props = { "hood", "lantern" } },
	Rue = { props = { "hood", "raven" }, glow = Color3.fromRGB(120, 230, 220) },
	Bo = { props = { "chains", "hood" }, glow = Color3.fromRGB(200, 150, 255) },
	Lin = { props = { "mask", "runering" } },
	Kade = { props = { "pauldrons", "embers" }, glow = Color3.fromRGB(150, 120, 255) },
	Juno = { props = { "horns", "cape" }, glow = Color3.fromRGB(90, 220, 255) },
	Moss = { props = { "vines", "hood" }, glow = Color3.fromRGB(130, 255, 140), cloth = Color3.fromRGB(34, 40, 30) },
	Ash = { props = { "mask", "ashcloud" }, glow = Color3.fromRGB(255, 150, 90), cloth = Color3.fromRGB(44, 38, 40) },
	Quill = { props = { "quill", "hood" }, glow = Color3.fromRGB(120, 200, 255) },
	Nyx = { props = { "crown", "shards", "cape" } },
}

local BODY_PARTS = {
	Torso = "cloth",
	UpperTorso = "cloth",
	LowerTorso = "cloth",
	["Left Arm"] = "cloth",
	["Right Arm"] = "cloth",
	LeftUpperArm = "cloth",
	RightUpperArm = "cloth",
	LeftLowerArm = "cloth",
	RightLowerArm = "cloth",
	["Left Leg"] = "legs",
	["Right Leg"] = "legs",
	LeftUpperLeg = "legs",
	RightUpperLeg = "legs",
	LeftLowerLeg = "legs",
	RightLowerLeg = "legs",
	Head = "skin",
	LeftHand = "skin",
	RightHand = "skin",
}

-- Small deterministic per-NPC shift so no two NPCs of a rank are exactly the same shade
local function jitter(color: Color3, name: string): Color3
	local seed = 17
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 100003
	end
	local rng = Random.new(seed)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(
		(h + rng:NextNumber(-0.02, 0.02)) % 1,
		math.clamp(s + rng:NextNumber(-0.05, 0.05), 0, 1),
		math.clamp(v + rng:NextNumber(-0.04, 0.04), 0, 1)
	)
end

local function darker(color: Color3, by: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * by, 0, 1))
end

local function findPart(model: Model, names: { string }): BasePart?
	for _, n in names do
		local p = model:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

-- Adds a welded, massless, non-colliding part (offset is relative to `base`)
local function addPart(
	folder: Folder,
	base: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = "DT_" .. name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Slate
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CFrame = base.CFrame * offset
	p.Parent = folder
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function addLight(parent: Instance, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
end

local function addParticles(base: BasePart, name: string, color: Color3, rate: number, glowy: boolean, rise: number)
	local att = Instance.new("Attachment")
	att.Name = "DT_" .. name
	att.Parent = base
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = glowy and 0.8 or 0
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(1.5, 2.6)
	pe.Speed = NumberRange.new(0.3, 0.9)
	pe.Acceleration = Vector3.new(0, rise, 0)
	pe.SpreadAngle = Vector2.new(60, 60)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Parent = att
end

-- Prop builders. ctx = { folder, head, torso, leftArm, rightArm, cloth, bone, glow }
local PROPS = {}

function PROPS.hood(ctx)
	local h = ctx.head
	addPart(ctx.folder, h, "HoodTop", h.Size * Vector3.new(1.15, 0.35, 1.2), CFrame.new(0, h.Size.Y * 0.5, h.Size.Z * 0.08), ctx.cloth)
	addPart(ctx.folder, h, "HoodBack", h.Size * Vector3.new(1.15, 1.05, 0.3), CFrame.new(0, 0.05, h.Size.Z * 0.58), ctx.cloth)
	for _, side in { -1, 1 } do
		addPart(
			ctx.folder,
			h,
			"HoodSide",
			h.Size * Vector3.new(0.18, 0.95, 1.05),
			CFrame.new(side * h.Size.X * 0.56, 0.05, h.Size.Z * 0.05),
			ctx.cloth
		)
	end
end

function PROPS.cape(ctx)
	local t = ctx.torso
	local length = ctx.long and 2.1 or 1.6
	addPart(
		ctx.folder,
		t,
		"Cape",
		Vector3.new(t.Size.X * 1.1, t.Size.Y * length, 0.15),
		CFrame.new(0, -t.Size.Y * (length - 1) / 2, t.Size.Z / 2 + 0.12) * CFrame.Angles(math.rad(4), 0, 0),
		darker(ctx.cloth, 0.7),
		Enum.Material.Fabric
	)
end

function PROPS.lantern(ctx)
	local arm = ctx.rightArm or ctx.torso
	local at = CFrame.new(0, -arm.Size.Y / 2 - 0.3, -0.7)
	addPart(ctx.folder, arm, "LanternCase", Vector3.new(0.7, 0.9, 0.7), at, Color3.fromRGB(30, 28, 38), Enum.Material.Metal)
	local flame =
		addPart(ctx.folder, arm, "LanternFlame", Vector3.new(0.45, 0.6, 0.45), at, ctx.glow, Enum.Material.Neon, Enum.PartType.Ball)
	addLight(flame, ctx.glow, 14, 1.5)
end

function PROPS.raven(ctx)
	local t = ctx.torso
	local base = CFrame.new(-t.Size.X / 2 - 0.35, t.Size.Y / 2 + 0.45, 0.1)
	addPart(
		ctx.folder,
		t,
		"RavenBody",
		Vector3.new(0.7, 0.55, 1),
		base,
		Color3.fromRGB(14, 14, 20),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	addPart(
		ctx.folder,
		t,
		"RavenHead",
		Vector3.new(0.4, 0.4, 0.4),
		base * CFrame.new(0, 0.25, -0.5),
		Color3.fromRGB(14, 14, 20),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	addPart(ctx.folder, t, "RavenBeak", Vector3.new(0.12, 0.1, 0.3), base * CFrame.new(0, 0.22, -0.8), Color3.fromRGB(120, 100, 60))
	addPart(
		ctx.folder,
		t,
		"RavenEye",
		Vector3.new(0.12, 0.12, 0.12),
		base * CFrame.new(0.15, 0.32, -0.65),
		ctx.glow,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	addPart(
		ctx.folder,
		t,
		"RavenTail",
		Vector3.new(0.4, 0.1, 0.6),
		base * CFrame.new(0, 0, 0.7) * CFrame.Angles(math.rad(-15), 0, 0),
		Color3.fromRGB(14, 14, 20)
	)
end

function PROPS.chains(ctx)
	local t = ctx.torso
	for _, tilt in { -35, 35 } do
		addPart(
			ctx.folder,
			t,
			"Chain",
			Vector3.new(0.22, t.Size.Y * 1.3, 0.22),
			CFrame.new(0, 0, -t.Size.Z / 2 - 0.06) * CFrame.Angles(0, 0, math.rad(tilt)),
			Color3.fromRGB(70, 70, 82),
			Enum.Material.Metal
		)
	end
	addPart(ctx.folder, t, "ChainLock", Vector3.new(0.5, 0.5, 0.25), CFrame.new(0, 0, -t.Size.Z / 2 - 0.12), ctx.glow, Enum.Material.Neon)
end

function PROPS.mask(ctx)
	local h = ctx.head
	addPart(
		ctx.folder,
		h,
		"Mask",
		Vector3.new(h.Size.X * 0.92, h.Size.Y * 0.62, 0.14),
		CFrame.new(0, -h.Size.Y * 0.06, -h.Size.Z / 2 - 0.08),
		ctx.bone,
		Enum.Material.Marble
	)
	for _, side in { -1, 1 } do
		addPart(
			ctx.folder,
			h,
			"MaskSlit",
			Vector3.new(h.Size.X * 0.2, 0.08, 0.05),
			CFrame.new(side * h.Size.X * 0.2, h.Size.Y * 0.04, -h.Size.Z / 2 - 0.16),
			ctx.glow,
			Enum.Material.Neon
		)
	end
end

function PROPS.runering(ctx)
	local t = ctx.torso
	local ring = addPart(
		ctx.folder,
		t,
		"RuneRing",
		Vector3.new(0.12, 5.2, 5.2),
		CFrame.new(0, -t.Size.Y * 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		ctx.glow,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	ring.Transparency = 0.55
end

function PROPS.pauldrons(ctx)
	local t = ctx.torso
	for _, side in { -1, 1 } do
		local at = CFrame.new(side * (t.Size.X / 2 + 0.5), t.Size.Y / 2 + 0.05, 0)
		addPart(ctx.folder, t, "Pauldron", Vector3.new(1.4, 0.5, 1.4), at, Color3.fromRGB(34, 32, 44), Enum.Material.Metal)
		addPart(
			ctx.folder,
			t,
			"PauldronSpike",
			Vector3.new(0.25, 0.9, 0.25),
			at * CFrame.new(side * 0.25, 0.6, 0) * CFrame.Angles(0, 0, math.rad(-side * 20)),
			ctx.glow,
			Enum.Material.Neon
		)
	end
end

function PROPS.embers(ctx)
	addParticles(ctx.torso, "Embers", ctx.glow, 6, true, 1.5)
end

function PROPS.horns(ctx)
	local h = ctx.head
	for _, side in { -1, 1 } do
		addPart(
			ctx.folder,
			h,
			"Horn",
			Vector3.new(0.25, 1, 0.25),
			CFrame.new(side * h.Size.X * 0.38, h.Size.Y * 0.62, 0) * CFrame.Angles(0, 0, math.rad(-side * 25)),
			ctx.bone,
			Enum.Material.Marble
		)
	end
end

function PROPS.vines(ctx)
	local t = ctx.torso
	local green = Color3.fromRGB(46, 90, 52)
	for i, side in { -1, 1, -1, 1 } do
		local len = 1.4 + (i % 2) * 0.8
		addPart(
			ctx.folder,
			t,
			"Vine",
			Vector3.new(0.14, len, 0.14),
			CFrame.new(side * (t.Size.X / 2 - 0.1 * i), t.Size.Y / 2 - len / 2 + 0.2, -t.Size.Z / 2 - 0.1 + (i > 2 and t.Size.Z + 0.2 or 0)),
			green,
			Enum.Material.Grass
		)
	end
	addPart(
		ctx.folder,
		t,
		"MossPatch",
		Vector3.new(t.Size.X * 0.6, 0.3, t.Size.Z * 1.1),
		CFrame.new(-t.Size.X * 0.2, t.Size.Y / 2, 0),
		green,
		Enum.Material.Grass
	)
end

function PROPS.ashcloud(ctx)
	addParticles(ctx.torso, "Ash", Color3.fromRGB(150, 140, 140), 10, false, 0.6)
end

function PROPS.quill(ctx)
	local t = ctx.torso
	local at = CFrame.new(t.Size.X * 0.3, t.Size.Y * 0.3, t.Size.Z / 2 + 0.25) * CFrame.Angles(0, 0, math.rad(-30))
	addPart(ctx.folder, t, "QuillShaft", Vector3.new(0.12, 3.2, 0.12), at, ctx.bone, Enum.Material.SmoothPlastic)
	local vane =
		addPart(ctx.folder, t, "QuillVane", Vector3.new(0.6, 1.8, 0.06), at * CFrame.new(0.25, 0.7, 0), ctx.glow, Enum.Material.Neon)
	vane.Transparency = 0.35
	addParticles(ctx.torso, "Ink", Color3.fromRGB(70, 110, 200), 3, true, -1)
end

function PROPS.crown(ctx)
	local h = ctx.head
	for i = 0, 5 do
		local a = math.rad(i * 60)
		addPart(
			ctx.folder,
			h,
			"CrownShard",
			Vector3.new(0.22, 1.1 + (i % 2) * 0.5, 0.22),
			CFrame.new(math.cos(a) * h.Size.X * 0.55, h.Size.Y * 0.7, math.sin(a) * h.Size.Z * 0.55)
				* CFrame.Angles(math.rad(math.sin(a) * 12), 0, math.rad(-math.cos(a) * 12)),
			ctx.glow,
			Enum.Material.Neon
		)
	end
end

function PROPS.shards(ctx)
	local t = ctx.torso
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		local shard = addPart(
			ctx.folder,
			t,
			"VoidShard",
			Vector3.new(0.4, 0.9, 0.4),
			CFrame.new(math.cos(a) * 3.2, -0.5 + (i % 2) * 1.2, math.sin(a) * 3.2) * CFrame.Angles(math.rad(25 * i), math.rad(40 * i), 0),
			Color3.fromRGB(30, 20, 50),
			Enum.Material.Neon
		)
		shard.Transparency = 0.2
	end
	addParticles(t, "VoidAura", ctx.glow, 14, true, 0.8)
	addLight(t, ctx.glow, 18, 1.2)
end

local function rankAndName(trainerName: string): (string, string)
	local words = string.split(trainerName, " ")
	local rank = words[2] or "Trainee"
	if not RANKS[rank] then
		rank = "Trainee"
	end
	return rank, words[#words]
end

-- Restyle one trainer model. `trainerName` is e.g. "Tower Veteran Moss" (from GameData.Dungeon.floors)
function DungeonNPCStyler.apply(model: Model, trainerName: string)
	if model:GetAttribute("DungeonStyled") then
		return
	end
	local rankName, shortName = rankAndName(trainerName)
	local look = LOOKS[shortName] or { props = {} }
	local palette = RANKS[rankName]
	local cloth = jitter(look.cloth or palette.cloth, shortName)
	local colors = {
		cloth = cloth,
		legs = darker(cloth, 0.75),
		skin = jitter(palette.skin, shortName .. "skin"),
	}
	local glow = look.glow or palette.glow

	-- body paint: shirt/pants textures would hide the palette, and they only change at runtime
	for _, d in model:GetChildren() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		elseif d:IsA("BodyColors") then
			d.HeadColor3 = colors.skin
			d.TorsoColor3 = colors.cloth
			d.LeftArmColor3 = colors.cloth
			d.RightArmColor3 = colors.cloth
			d.LeftLegColor3 = colors.legs
			d.RightLegColor3 = colors.legs
		end
	end
	for _, part in model:GetChildren() do
		local kind = BODY_PARTS[part.Name]
		if kind and part:IsA("BasePart") then
			part.Color = colors[kind]
			if kind ~= "skin" then
				part.Material = Enum.Material.Fabric
			end
		end
	end

	local head = findPart(model, { "Head" })
	local torso = findPart(model, { "Torso", "UpperTorso" })
	if not head or not torso then
		warn("DungeonNPCStyler: no Head/Torso on", model:GetFullName())
		model:SetAttribute("DungeonStyled", true)
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "DungeonStyle"
	folder.Parent = model

	-- face: fade the painted face and add glowing eyes
	for _, d in head:GetChildren() do
		if d:IsA("Decal") then
			d.Transparency = 0.85
		end
	end
	for _, side in { -1, 1 } do
		addPart(
			folder,
			head,
			"Eye",
			Vector3.new(head.Size.X * 0.16, head.Size.Y * 0.1, 0.05),
			CFrame.new(side * head.Size.X * 0.2, head.Size.Y * 0.08, -head.Size.Z / 2 - 0.02),
			glow,
			Enum.Material.Neon
		)
	end

	local ctx = {
		folder = folder,
		head = head,
		torso = torso,
		leftArm = findPart(model, { "Left Arm", "LeftUpperArm" }),
		rightArm = findPart(model, { "Right Arm", "RightUpperArm" }),
		cloth = cloth,
		bone = palette.bone,
		glow = glow,
		long = rankName == "Warden",
	}
	for _, prop in look.props do
		local build = PROPS[prop]
		if build then
			local ok, err = pcall(build, ctx)
			if not ok then
				warn("DungeonNPCStyler:", shortName, prop, "failed:", err)
			end
		end
	end

	-- a soft glow, and a small name plate in the NPC's color
	addLight(torso, glow, 10, 0.6)
	local plate = Instance.new("BillboardGui")
	plate.Name = "DT_NamePlate"
	plate.Size = UDim2.fromOffset(200, 28)
	plate.StudsOffset = Vector3.new(0, head.Size.Y + 1.6, 0)
	plate.MaxDistance = 45
	plate.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Fondamento
	label.TextScaled = true
	label.TextColor3 = glow
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.fromRGB(10, 6, 16)
	label.Text = trainerName
	label.Parent = plate
	plate.Parent = head

	model:SetAttribute("DungeonStyled", true)
end

return DungeonNPCStyler
