--[[
	CreatureBuilder: makes placeholder creature models out of parts.
	build(name, level, opts) where opts = { shiny = bool, sizeClass = "Tiny"|"Small"|"Normal"|"Large"|"Huge" }.
	The model's "GroundOffset" attribute is measured from its real bounding box, so placing the
	body at groundY + GroundOffset puts its lowest point exactly on the ground.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local BattleData = require(ReplicatedStorage.Shared.BattleData)

local CreatureBuilder = {}
-- sculpted 3D versions of creatures, when they exist (see build)
local MESHES = ReplicatedStorage:FindFirstChild("CreatureMeshes")

local BALL, BLOCK, CYL = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Cylinder
local UP = math.rad(90)
local SHINY_GOLD = Color3.fromRGB(255, 215, 80)

local function newPart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	-- Roblox draws a Ball part as a sphere the size of its smallest side, so stretched balls
	-- become a block with a sphere mesh: a real oval (ellipsoid) the full size asked for
	if shape == Enum.PartType.Ball and (math.abs(size.X - size.Y) > 0.01 or math.abs(size.Y - size.Z) > 0.01) then
		p.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	else
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function weld(root: BasePart, part: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = part
end

local function darker(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighter(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

-- Shiny palette: rotate the hue and punch up the colour
local function shinyColor(c: Color3): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV((h + 0.45) % 1, math.clamp(s * 1.1 + 0.15, 0, 1), math.clamp(v * 1.05, 0, 1))
end

function CreatureBuilder.sizeScale(sizeClass: string?): number
	for _, c in GameData.SizeClasses do
		if c.name == sizeClass then
			return c.scale
		end
	end
	return 1
end

-- Body plans. Each adds parts around the round body (front faces -Z).
local Shapes = {}

function Shapes.bird(add, s, look, accent)
	add("Beak", BALL, Vector3.new(s * 0.18, s * 0.12, s * 0.28), accent, CFrame.new(0, 0, -s * 0.55))
	for _, sx in { -1, 1 } do
		add("Wing", BALL, Vector3.new(s * 0.12, s * 0.45, s * 0.6), darker(look.color, 0.15),
			CFrame.new(sx * s * 0.5, 0, s * 0.05) * CFrame.Angles(0, 0, sx * math.rad(-25)))
		add("Foot", BALL, Vector3.new(s * 0.1, s * 0.08, s * 0.2), accent, CFrame.new(sx * s * 0.15, -s * 0.5, -s * 0.05))
	end
	add("Tail", BALL, Vector3.new(s * 0.3, s * 0.1, s * 0.35), darker(look.color, 0.2), CFrame.new(0, s * 0.1, s * 0.55) * CFrame.Angles(math.rad(25), 0, 0))
	add("Crest", BALL, Vector3.new(s * 0.08, s * 0.3, s * 0.25), darker(look.color, 0.25), CFrame.new(0, s * 0.55, -s * 0.05))
end

function Shapes.rodent(add, s, look, accent)
	for _, sx in { -1, 1 } do
		add("Ear", BALL, Vector3.one * s * 0.42, darker(look.color, 0.1), CFrame.new(sx * s * 0.32, s * 0.42, s * 0.05))
		add("EarInner", BALL, Vector3.one * s * 0.26, accent, CFrame.new(sx * s * 0.33, s * 0.44, -s * 0.06))
		add("Foot", BALL, Vector3.new(s * 0.2, s * 0.1, s * 0.26), darker(look.color, 0.25), CFrame.new(sx * s * 0.22, -s * 0.48, -s * 0.12))
	end
	add("Nose", BALL, Vector3.one * s * 0.12, accent, CFrame.new(0, -s * 0.02, -s * 0.5))
	add("Tail", BALL, Vector3.one * s * 0.24, lighter(look.color, 0.3), CFrame.new(0, -s * 0.15, s * 0.52))
end

function Shapes.spiky(add, s, look, accent)
	local directions = {
		Vector3.new(0, 1, 0.3), Vector3.new(-0.6, 0.8, 0.4), Vector3.new(0.6, 0.8, 0.4), Vector3.new(0, 0.6, 0.9),
		Vector3.new(-0.7, 0.4, 0.8), Vector3.new(0.7, 0.4, 0.8), Vector3.new(-0.35, 1, -0.1), Vector3.new(0.35, 1, -0.1),
	}
	for _, d in directions do
		local dir = d.Unit
		local len = s * 0.45
		local pos = dir * (s * 0.5 + len * 0.2)
		add("Spine", CYL, Vector3.new(len, s * 0.12, s * 0.12), accent, CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, UP, 0))
	end
	for _, sx in { -1, 1 } do
		add("Foot", BALL, Vector3.new(s * 0.2, s * 0.12, s * 0.24), darker(look.color, 0.3), CFrame.new(sx * s * 0.22, -s * 0.5, -s * 0.1))
	end
	add("Nose", BALL, Vector3.one * s * 0.1, darker(look.color, 0.5), CFrame.new(0, -s * 0.02, -s * 0.5))
end

function Shapes.fighter(add, s, look, accent)
	local band = Color3.fromRGB(60, 110, 220)
	for _, sx in { -1, 1 } do
		add("Glove", BALL, Vector3.one * s * 0.42, accent, CFrame.new(sx * s * 0.6, -s * 0.08, -s * 0.25))
		add("Foot", BALL, Vector3.new(s * 0.24, s * 0.14, s * 0.3), darker(look.color, 0.35), CFrame.new(sx * s * 0.2, -s * 0.52, -s * 0.02))
	end
	add("Headband", CYL, Vector3.new(s * 0.12, s * 0.78, s * 0.78), band, CFrame.new(0, s * 0.34, 0) * CFrame.Angles(0, 0, UP))
	add("Knot", BALL, Vector3.new(s * 0.08, s * 0.25, s * 0.3), band, CFrame.new(0, s * 0.3, s * 0.42) * CFrame.Angles(math.rad(30), 0, 0))
	add("Mouth", BLOCK, Vector3.new(s * 0.22, s * 0.05, s * 0.05), darker(look.color, 0.5), CFrame.new(0, -s * 0.12, -s * 0.48))
end

function Shapes.larva(add, s, look, accent)
	local r = s * 0.5
	local z, prevR, lastR, lastY = 0, r, r, 0
	for i, f in { 0.82, 0.68, 0.55 } do
		local sr = r * f
		z += prevR * 0.75 + sr * 0.6
		local y = sr - r
		add("Segment", BALL, Vector3.one * sr * 2, (i % 2 == 1) and darker(look.color, 0.1) or look.color, CFrame.new(0, y, z))
		prevR, lastR, lastY = sr, sr, y
	end
	for _, sx in { -1, 1 } do
		add("Antenna", CYL, Vector3.new(s * 0.3, s * 0.06, s * 0.06), darker(look.color, 0.35),
			CFrame.new(sx * s * 0.17, s * 0.55, -s * 0.1) * CFrame.Angles(0, 0, UP + sx * math.rad(-20)))
		add("AntennaTip", BALL, Vector3.one * s * 0.12, accent, CFrame.new(sx * s * 0.22, s * 0.7, -s * 0.1))
	end
	if look.stinger then
		add("Stinger", CYL, Vector3.new(s * 0.35, s * 0.1, s * 0.1), accent, CFrame.new(0, lastY, z + lastR + s * 0.12) * CFrame.Angles(0, UP, 0))
	end
end

function Shapes.cocoon(add, s, look, accent)
	add("Shell", CYL, Vector3.new(s * 0.8, s * 0.92, s * 0.92), darker(look.color, 0.05), CFrame.new(0, -s * 0.4, 0) * CFrame.Angles(0, 0, UP))
	add("Tip", BALL, Vector3.one * s * 0.85, darker(look.color, 0.12), CFrame.new(0, -s * 0.8, 0))
	for _, y in { -0.22, -0.58 } do
		add("Ridge", CYL, Vector3.new(s * 0.08, s * 0.97, s * 0.97), accent, CFrame.new(0, s * y, 0) * CFrame.Angles(0, 0, UP))
	end
end

-- Burrowing creature: digging claws and spark antennae
function Shapes.blob(add, s, look, accent)
	for _, sx in { -1, 1 } do
		add("Claw", BLOCK, Vector3.new(s * 0.3, s * 0.1, s * 0.24), Color3.fromRGB(235, 235, 240),
			CFrame.new(sx * s * 0.38, -s * 0.38, -s * 0.3) * CFrame.Angles(0, sx * math.rad(-15), 0))
		add("Antenna", CYL, Vector3.new(s * 0.4, s * 0.06, s * 0.06), darker(look.color, 0.3),
			CFrame.new(sx * s * 0.15, s * 0.6, 0) * CFrame.Angles(0, 0, UP + sx * math.rad(-15)))
		local spark = add("Spark", BALL, Vector3.one * s * 0.15, accent, CFrame.new(sx * s * 0.2, s * 0.8, 0))
		spark.Material = Enum.Material.Neon
	end
	add("Nose", BALL, Vector3.one * s * 0.14, Color3.fromRGB(255, 175, 185), CFrame.new(0, -s * 0.02, -s * 0.5))
end

-- Rocky boulder creature: craggy chunks, heavy brow, optional stone arms
function Shapes.rock(add, s, look, accent)
	local chunks = {
		{ Vector3.new(0.35, 0.3, 0.2), 0.42 }, { Vector3.new(-0.38, 0.25, 0.15), 0.38 }, { Vector3.new(0, 0.42, 0.25), 0.36 },
		{ Vector3.new(0.2, -0.1, 0.42), 0.34 }, { Vector3.new(-0.25, 0.05, 0.4), 0.3 }, { Vector3.new(0.05, 0.3, -0.2), 0.3 },
	}
	for i, c in chunks do
		add("Chunk", BLOCK, Vector3.one * s * c[2], (i % 2 == 0) and darker(look.color, 0.12) or lighter(look.color, 0.06),
			CFrame.new(c[1] * s) * CFrame.Angles(math.rad(i * 37), math.rad(i * 53), math.rad(i * 21)))
	end
	add("Brow", BLOCK, Vector3.new(s * 0.62, s * 0.12, s * 0.2), darker(look.color, 0.3), CFrame.new(0, s * 0.3, -s * 0.38) * CFrame.Angles(math.rad(-10), 0, 0))
	add("Vein", BLOCK, Vector3.new(s * 0.08, s * 0.4, s * 0.06), accent, CFrame.new(s * 0.22, -s * 0.05, -s * 0.46) * CFrame.Angles(0, 0, math.rad(25)))
	for _, sx in { -1, 1 } do
		add("Foot", BALL, Vector3.new(s * 0.26, s * 0.16, s * 0.3), darker(look.color, 0.35), CFrame.new(sx * s * 0.24, -s * 0.5, -s * 0.05))
		if look.arms then
			add("Arm", BALL, Vector3.new(s * 0.22, s * 0.5, s * 0.22), darker(look.color, 0.15),
				CFrame.new(sx * s * 0.58, -s * 0.05, -s * 0.05) * CFrame.Angles(0, 0, sx * math.rad(-15)))
			add("Fist", BALL, Vector3.one * s * 0.3, accent, CFrame.new(sx * s * 0.66, -s * 0.33, -s * 0.12))
		end
	end
end

function Shapes.quad(add, s, look, accent)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add("Leg", BALL, Vector3.new(s * 0.22, s * 0.3, s * 0.22), darker(look.color, 0.2), CFrame.new(sx * s * 0.25, -s * 0.5, sz * s * 0.22))
		end
		add("Ear", BLOCK, Vector3.new(s * 0.14, s * 0.32, s * 0.1), darker(look.color, 0.15),
			CFrame.new(sx * s * 0.25, s * 0.5, -s * 0.05) * CFrame.Angles(0, 0, sx * math.rad(-20)))
	end
	add("Tail", BALL, Vector3.one * s * 0.3, darker(look.color, 0.1), CFrame.new(0, s * 0.05, s * 0.55))
	add("Nose", BALL, Vector3.one * s * 0.1, Color3.fromRGB(40, 30, 30), CFrame.new(0, -s * 0.02, -s * 0.5))
end

-- Fish: tail fin, dorsal fin and side fins
function Shapes.fish(add, s, look, accent)
	add("TailFin", BALL, Vector3.new(s * 0.08, s * 0.55, s * 0.4), accent, CFrame.new(0, 0, s * 0.62) * CFrame.Angles(math.rad(20), 0, 0))
	add("TailFin2", BALL, Vector3.new(s * 0.08, s * 0.55, s * 0.4), accent, CFrame.new(0, -s * 0.05, s * 0.62) * CFrame.Angles(math.rad(-20), 0, 0))
	add("Dorsal", BALL, Vector3.new(s * 0.08, s * 0.35, s * 0.45), accent, CFrame.new(0, s * 0.5, s * 0.05) * CFrame.Angles(math.rad(-25), 0, 0))
	for _, sx in { -1, 1 } do
		add("Fin", BALL, Vector3.new(s * 0.28, s * 0.06, s * 0.22), darker(accent, 0.1),
			CFrame.new(sx * s * 0.5, -s * 0.15, -s * 0.05) * CFrame.Angles(0, 0, sx * math.rad(-30)))
	end
	add("Belly", BALL, Vector3.new(s * 0.7, s * 0.5, s * 0.75), lighter(look.color, 0.45), CFrame.new(0, -s * 0.2, -s * 0.05))
	add("Mouth", BLOCK, Vector3.new(s * 0.2, s * 0.05, s * 0.05), darker(look.color, 0.5), CFrame.new(0, -s * 0.1, -s * 0.49))
end

-- Ghost: wispy tapering tail and little arms (pair with floats = true)
function Shapes.ghost(add, s, look, accent)
	local y = -s * 0.35
	for i, f in { 0.8, 0.6, 0.4, 0.22 } do
		y -= s * 0.17
		local wisp = add("Wisp", BALL, Vector3.one * s * f, look.color, CFrame.new(math.sin(i) * s * 0.12, y, s * 0.12 * i))
		wisp.Transparency = 0.1 + i * 0.12
	end
	for _, sx in { -1, 1 } do
		add("Arm", BALL, Vector3.new(s * 0.22, s * 0.32, s * 0.22), darker(look.color, 0.1), CFrame.new(sx * s * 0.5, -s * 0.12, -s * 0.05) * CFrame.Angles(0, 0, sx * math.rad(40)))
	end
	local glow = add("Glow", BALL, Vector3.one * s * 0.18, accent, CFrame.new(0, s * 0.42, -s * 0.2))
	glow.Material = Enum.Material.Neon
	add("Mouth", BALL, Vector3.new(s * 0.16, s * 0.12, s * 0.06), darker(look.color, 0.6), CFrame.new(0, -s * 0.1, -s * 0.47))
end

-- Dragon: horns, wings, a long tail and a snout
function Shapes.dragon(add, s, look, accent)
	add("Snout", BALL, Vector3.new(s * 0.42, s * 0.3, s * 0.35), lighter(look.color, 0.1), CFrame.new(0, -s * 0.05, -s * 0.55))
	for _, sx in { -1, 1 } do
		add("Nostril", BALL, Vector3.one * s * 0.07, darker(look.color, 0.6), CFrame.new(sx * s * 0.1, 0, -s * 0.73))
		add("Horn", CYL, Vector3.new(s * 0.4, s * 0.1, s * 0.1), accent, CFrame.new(sx * s * 0.25, s * 0.55, s * 0.05) * CFrame.Angles(math.rad(-30), 0, UP + sx * math.rad(-20)))
		add("Wing", BALL, Vector3.new(s * 0.75, s * 0.06, s * 0.55), darker(look.color, 0.2),
			CFrame.new(sx * s * 0.75, s * 0.25, s * 0.15) * CFrame.Angles(0, sx * math.rad(15), sx * math.rad(25)))
		add("WingTip", BALL, Vector3.new(s * 0.3, s * 0.05, s * 0.3), accent, CFrame.new(sx * s * 1.1, s * 0.42, s * 0.25) * CFrame.Angles(0, 0, sx * math.rad(35)))
		add("Foot", BALL, Vector3.new(s * 0.24, s * 0.16, s * 0.3), darker(look.color, 0.3), CFrame.new(sx * s * 0.25, -s * 0.5, -s * 0.05))
	end
	add("Tail", CYL, Vector3.new(s * 0.7, s * 0.22, s * 0.22), look.color, CFrame.new(0, -s * 0.25, s * 0.75) * CFrame.Angles(math.rad(15), UP, 0))
	add("TailTip", BALL, Vector3.new(s * 0.08, s * 0.3, s * 0.3), accent, CFrame.new(0, -s * 0.35, s * 1.1) * CFrame.Angles(math.rad(45), 0, 0))
	add("Belly", BALL, Vector3.new(s * 0.6, s * 0.6, s * 0.4), lighter(accent, 0.3), CFrame.new(0, -s * 0.15, -s * 0.3))
end

-- Crystal: shards growing out of the body (fairy gems, ice)
function Shapes.crystal(add, s, look, accent)
	local dirs = { Vector3.new(0, 1, 0.2), Vector3.new(-0.7, 0.7, 0.3), Vector3.new(0.7, 0.7, 0.3), Vector3.new(-0.3, 0.9, 0.7), Vector3.new(0.3, 0.9, 0.7) }
	for i, d in dirs do
		local dir = d.Unit
		local len = s * (i == 1 and 0.6 or 0.42)
		local pos = dir * (s * 0.4 + len * 0.3)
		local shard = add("Shard", BLOCK, Vector3.new(s * 0.16, len, s * 0.16), i % 2 == 0 and accent or lighter(look.color, 0.25),
			CFrame.lookAt(pos, pos + dir) * CFrame.Angles(UP, 0, math.rad(45)))
		shard.Material = Enum.Material.Glass
		shard.Transparency = 0.15
	end
	for _, sx in { -1, 1 } do
		add("Foot", BALL, Vector3.new(s * 0.2, s * 0.12, s * 0.24), darker(look.color, 0.25), CFrame.new(sx * s * 0.22, -s * 0.5, -s * 0.08))
	end
	add("Cheek", BALL, Vector3.one * s * 0.12, accent, CFrame.new(0, -s * 0.05, -s * 0.48))
end

-- Fox: pointed ears, a snout and slim legs (fire starters)
function Shapes.fox(add, s, look, accent)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add("Leg", BALL, Vector3.new(s * 0.16, s * 0.34, s * 0.16), darker(look.color, 0.25), CFrame.new(sx * s * 0.22, -s * 0.5, sz * s * 0.2))
			add("Paw", BALL, Vector3.new(s * 0.2, s * 0.12, s * 0.24), lighter(look.color, 0.5), CFrame.new(sx * s * 0.22, -s * 0.66, sz * s * 0.2 - s * 0.03))
		end
		add("Ear", BLOCK, Vector3.new(s * 0.18, s * 0.42, s * 0.1), look.color,
			CFrame.new(sx * s * 0.24, s * 0.52, -s * 0.02) * CFrame.Angles(0, 0, sx * math.rad(-18)))
		add("EarInner", BLOCK, Vector3.new(s * 0.1, s * 0.28, s * 0.04), accent,
			CFrame.new(sx * s * 0.24, s * 0.5, -s * 0.08) * CFrame.Angles(0, 0, sx * math.rad(-18)))
	end
	add("Snout", BALL, Vector3.new(s * 0.38, s * 0.26, s * 0.3), lighter(look.color, 0.55), CFrame.new(0, -s * 0.12, -s * 0.42))
	add("Nose", BALL, Vector3.one * s * 0.1, Color3.fromRGB(45, 30, 30), CFrame.new(0, -s * 0.06, -s * 0.58))
	if not (look.features and table.find(look.features, "flameTail")) then
		add("Tail", BALL, Vector3.new(s * 0.3, s * 0.3, s * 0.55), look.color, CFrame.new(0, s * 0.05, s * 0.62) * CFrame.Angles(math.rad(-25), 0, 0))
	end
end

-- Turtle: a domed shell on its back, stubby legs (water starters)
function Shapes.turtle(add, s, look, accent)
	local shell = add("Shell", BALL, Vector3.new(s * 1.05, s * 0.75, s * 0.95), accent, CFrame.new(0, s * 0.1, s * 0.25))
	shell.Material = Enum.Material.SmoothPlastic
	add("ShellRim", CYL, Vector3.new(s * 0.12, s * 1.1, s * 1.0), lighter(accent, 0.35), CFrame.new(0, -s * 0.12, s * 0.25) * CFrame.Angles(0, 0, UP))
	for i, p in { Vector3.new(0, 0.45, 0.25), Vector3.new(-0.28, 0.32, 0.3), Vector3.new(0.28, 0.32, 0.3) } do
		add("Plate", BALL, Vector3.new(s * 0.26, s * 0.1, s * 0.26), darker(accent, 0.2), CFrame.new(p * s))
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add("Leg", BALL, Vector3.new(s * 0.26, s * 0.3, s * 0.26), look.color, CFrame.new(sx * s * 0.34, -s * 0.45, sz * s * 0.25))
		end
	end
	add("Tail", BALL, Vector3.one * s * 0.18, look.color, CFrame.new(0, -s * 0.2, s * 0.72))
	add("Mouth", BLOCK, Vector3.new(s * 0.18, s * 0.04, s * 0.04), darker(look.color, 0.5), CFrame.new(0, -s * 0.14, -s * 0.49))
end

-- Extra features any creature can list in GameData (features = { "flameTail", "horns", ... })
local Features = {}
function Features.blush(add, s, look, accent)
	for _, sx in { -1, 1 } do
		add("Blush", BALL, Vector3.new(s * 0.15, s * 0.08, s * 0.05), Color3.fromRGB(255, 140, 160), CFrame.new(sx * s * 0.3, -s * 0.04, -s * 0.42))
	end
end
function Features.leafBud(add, s, look, accent)
	add("Stem", CYL, Vector3.new(s * 0.2, s * 0.06, s * 0.06), darker(accent, 0.2), CFrame.new(0, s * 0.56, s * 0.12) * CFrame.Angles(0, 0, UP))
	for _, sx in { -1, 1 } do
		add("Leaf", BALL, Vector3.new(s * 0.34, s * 0.08, s * 0.18), accent, CFrame.new(sx * s * 0.14, s * 0.66, s * 0.12) * CFrame.Angles(0, 0, sx * math.rad(25)))
	end
end
function Features.bud(add, s, look, accent)
	add("Bud", BALL, Vector3.new(s * 0.42, s * 0.5, s * 0.42), accent, CFrame.new(0, s * 0.62, s * 0.15))
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		add("BudLeaf", BALL, Vector3.new(s * 0.36, s * 0.08, s * 0.16), Color3.fromRGB(60, 140, 70),
			CFrame.new(0, s * 0.46, s * 0.15) * CFrame.Angles(0, a, 0) * CFrame.new(s * 0.2, 0, 0) * CFrame.Angles(0, 0, math.rad(-20)))
	end
end
function Features.flower(add, s, look, accent)
	local center = CFrame.new(0, s * 0.62, s * 0.18)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		add("Petal", BALL, Vector3.new(s * 0.42, s * 0.1, s * 0.28), accent, center * CFrame.Angles(0, a, 0) * CFrame.new(s * 0.3, 0, 0) * CFrame.Angles(0, 0, math.rad(12)))
	end
	add("FlowerCenter", BALL, Vector3.new(s * 0.3, s * 0.16, s * 0.3), Color3.fromRGB(255, 220, 90), center * CFrame.new(0, s * 0.04, 0))
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.4
		add("BigLeaf", BALL, Vector3.new(s * 0.55, s * 0.08, s * 0.25), Color3.fromRGB(60, 140, 70), CFrame.new(0, s * 0.5, s * 0.18) * CFrame.Angles(0, a, 0) * CFrame.new(s * 0.38, 0, 0) * CFrame.Angles(0, 0, math.rad(-15)))
	end
end
function Features.spines(add, s, look, accent)
	for i = 0, 4 do
		local z = -s * 0.15 + i * s * 0.16
		local y = s * (0.5 - math.abs(i - 1.5) * 0.04)
		add("Spine", BLOCK, Vector3.new(s * 0.08, s * 0.2, s * 0.12), darker(accent, 0.15), CFrame.new(0, y, z) * CFrame.Angles(math.rad(-25), 0, math.rad(45)))
	end
end
function Features.horns(add, s, look, accent)
	for _, sx in { -1, 1 } do
		add("Horn", CYL, Vector3.new(s * 0.36, s * 0.1, s * 0.1), Color3.fromRGB(245, 235, 210),
			CFrame.new(sx * s * 0.2, s * 0.5, -s * 0.18) * CFrame.Angles(math.rad(-25), 0, UP + sx * math.rad(-25)))
	end
end
function Features.flameTail(add, s, look, accent)
	add("TailBase", BALL, Vector3.new(s * 0.22, s * 0.22, s * 0.4), look.color, CFrame.new(0, s * 0.02, s * 0.58) * CFrame.Angles(math.rad(-30), 0, 0))
	local flames = { { 0.3, 0.2, 0.75, Color3.fromRGB(255, 120, 40) }, { 0.22, 0.38, 0.82, Color3.fromRGB(255, 170, 50) }, { 0.14, 0.52, 0.86, Color3.fromRGB(255, 230, 100) } }
	for _, f in flames do
		local p = add("Flame", BALL, Vector3.one * s * f[1], f[4], CFrame.new(0, s * f[2], s * f[3]))
		p.Material = Enum.Material.Neon
	end
end
function Features.flameMane(add, s, look, accent)
	for i = 0, 4 do
		local a = (i - 2) * 0.45
		local p = add("ManeFlame", BALL, Vector3.one * s * 0.24, i % 2 == 0 and Color3.fromRGB(255, 150, 40) or Color3.fromRGB(255, 210, 80),
			CFrame.new(math.sin(a) * s * 0.35, s * 0.42 + math.cos(a) * s * 0.08, s * 0.15))
		p.Material = Enum.Material.Neon
	end
end
function Features.wings(add, s, look, accent)
	for _, sx in { -1, 1 } do
		-- swept up and back so they read from the front
		local base = CFrame.new(sx * s * 0.42, s * 0.3, s * 0.25) * CFrame.Angles(math.rad(-20), sx * math.rad(-35), sx * math.rad(-50))
		add("WingBone", BLOCK, Vector3.new(s * 0.1, s * 0.9, s * 0.1), darker(look.color, 0.3), base * CFrame.new(0, s * 0.4, 0))
		add("WingMembrane", BLOCK, Vector3.new(s * 0.06, s * 0.85, s * 0.6), accent, base * CFrame.new(0, s * 0.38, s * 0.3))
	end
end
function Features.finEars(add, s, look, accent)
	for _, sx in { -1, 1 } do
		add("FinEar", BLOCK, Vector3.new(s * 0.06, s * 0.36, s * 0.3), lighter(look.color, 0.35),
			CFrame.new(sx * s * 0.46, s * 0.25, 0) * CFrame.Angles(0, 0, sx * math.rad(-35)))
	end
end
function Features.swirlTail(add, s, look, accent)
	for i, f in { 0.3, 0.24, 0.18, 0.13 } do
		add("Swirl", BALL, Vector3.one * s * f, lighter(look.color, 0.2 + i * 0.1), CFrame.new(0, -s * 0.1 + i * s * 0.12, s * (0.6 + i * 0.08)))
	end
end
function Features.cannons(add, s, look, accent)
	for _, sx in { -1, 1 } do
		add("Cannon", CYL, Vector3.new(s * 0.45, s * 0.18, s * 0.18), Color3.fromRGB(170, 175, 190),
			CFrame.new(sx * s * 0.28, s * 0.5, s * 0.05) * CFrame.Angles(0, UP, 0))
		add("Muzzle", CYL, Vector3.new(s * 0.06, s * 0.22, s * 0.22), Color3.fromRGB(60, 60, 70), CFrame.new(sx * s * 0.28, s * 0.5, -s * 0.18) * CFrame.Angles(0, UP, 0))
	end
end
function Features.mane(add, s, look, accent)
	for i = 0, 6 do
		local a = (i - 3) * 0.35
		add("Mane", BLOCK, Vector3.new(s * 0.14, s * 0.32, s * 0.2), accent,
			CFrame.new(math.sin(a) * s * 0.42, s * 0.36 + math.cos(a) * s * 0.06, s * 0.12) * CFrame.Angles(math.rad(-20), 0, -a * 0.8))
	end
end
function Features.fangs(add, s, look, accent)
	for _, sx in { -1, 1 } do
		add("Fang", BLOCK, Vector3.new(s * 0.06, s * 0.12, s * 0.05), Color3.fromRGB(250, 250, 245), CFrame.new(sx * s * 0.08, -s * 0.2, -s * 0.47))
	end
end
function Features.boltTail(add, s, look, accent)
	local cf = CFrame.new(0, s * 0.05, s * 0.55)
	for i = 0, 2 do
		local p = add("Bolt", BLOCK, Vector3.new(s * 0.08, s * 0.26, s * 0.12), Color3.fromRGB(255, 230, 60),
			cf * CFrame.new(0, i * s * 0.18, i * s * 0.08) * CFrame.Angles(0, 0, (i % 2 == 0) and math.rad(35) or math.rad(-35)))
		p.Material = Enum.Material.Neon
	end
end
function Features.antennae(add, s, look, accent)
	for _, sx in { -1, 1 } do
		add("Antenna", CYL, Vector3.new(s * 0.34, s * 0.05, s * 0.05), darker(look.color, 0.3), CFrame.new(sx * s * 0.15, s * 0.6, -s * 0.05) * CFrame.Angles(0, 0, UP + sx * math.rad(-20)))
		local tip = add("AntennaTip", BALL, Vector3.one * s * 0.12, accent, CFrame.new(sx * s * 0.21, s * 0.76, -s * 0.05))
		tip.Material = Enum.Material.Neon
	end
end

-- shapes that get a lighter belly patch on the front
local BELLY = { bird = true, rodent = true, fighter = true, blob = true, quad = true, fox = true, turtle = true, spiky = true }

local function typeChip(parent: Instance, typeName: string)
	local chip = Instance.new("TextLabel")
	chip.Name = "Type"
	chip.Size = UDim2.fromScale(0.34, 1)
	chip.BackgroundColor3 = BattleData.TypeColors[typeName] or Color3.fromRGB(120, 120, 120)
	chip.Font = Enum.Font.FredokaOne
	chip.TextScaled = true
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.TextStrokeTransparency = 0.5
	chip.Text = typeName
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = chip
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = chip
	chip.Parent = parent
end

function CreatureBuilder.build(name: string, level: number?, opts): Model
	opts = opts or {}
	local info = GameData.Creatures[name]
	assert(info, "Unknown creature: " .. tostring(name))
	local rarity = GameData.Rarities[info.rarity]
	local shiny = opts.shiny == true
	local sizeClass = opts.sizeClass or "Normal"
	local s = info.size * CreatureBuilder.sizeScale(sizeClass)

	-- colours for this individual (shinies get a different palette)
	local look = table.clone(info)
	local accent = info.accent or Color3.fromRGB(245, 150, 50)
	if shiny then
		look.color = shinyColor(info.color)
		accent = shinyColor(accent)
	end

	local model = Instance.new("Model")
	model.Name = name

	-- "Body" is the invisible anchored root the server moves around (PrimaryPart).
	-- "Skin" is the visible body, on a joint ("Core") so the client can make it breathe and hop.
	-- Parts that move (ears, tails, wings, flames, eyelids...) get their own joints too; the rest are welded to Skin.
	-- CreatureLife (client) animates the joints' Transform, which never replicates.
	local body = newPart("Body", BALL, Vector3.one * s, look.color, CFrame.new(), model)
	body.Anchored = true
	body.Massless = false
	body.Transparency = 1
	model.PrimaryPart = body
	local skin = newPart("Skin", BALL, Vector3.one * s, look.color, CFrame.new(), model)
	do
		local core = Instance.new("Motor6D")
		core.Name = "Core"
		core.Part0, core.Part1 = body, skin
		core.Parent = body
	end

	-- what kind of motion a part gets (by name)
	local ANIM = {
		Wing = "wing", WingTip = "wing", WingBone = "wing", WingMembrane = "wing",
		Tail = "tail", TailBase = "tail", TailTip = "tail", TailFin = "tail", TailFin2 = "tail", Swirl = "tail", Bolt = "tail",
		Ear = "ear", EarInner = "ear", FinEar = "ear", Fin = "fin",
		Flame = "flame", ManeFlame = "flame",
		Antenna = "antenna", AntennaTip = "antenna", Leaf = "leaf", Petal = "leaf", BigLeaf = "leaf", BudLeaf = "leaf",
		Wisp = "wisp", Glove = "arm", Arm = "arm", Fist = "arm",
	}

	local function joint(p: BasePart, kind: string)
		-- hinge where the part meets the body, so it swings instead of spinning in place
		local toCenter = skin.Position - p.Position
		local reach = math.max(p.Size.X, p.Size.Y, p.Size.Z) * 0.4
		local hinge = CFrame.new(p.Position + (toCenter.Magnitude > 0.01 and toCenter.Unit * reach or Vector3.zero)) * p.CFrame.Rotation
		local m = Instance.new("Motor6D")
		m.Name = "J_" .. p.Name
		m.Part0, m.Part1 = skin, p
		m.C0 = skin.CFrame:Inverse() * hinge
		m.C1 = p.CFrame:Inverse() * hinge
		m:SetAttribute("Anim", kind)
		-- which side it's on (+1 right, -1 left) so pairs mirror each other
		m:SetAttribute("Side", (p.Position.X - skin.Position.X) >= 0 and 1 or -1)
		m.Parent = p
	end

	local function add(partName, shape, size, color, offset)
		local p = newPart(partName, shape, size, color, skin.CFrame * offset, model)
		if ANIM[partName] then
			joint(p, ANIM[partName])
		else
			weld(skin, p)
		end
		return p
	end

	-- 3D model version (ReplicatedStorage.CreatureMeshes.<name>): sculpted, textured mesh pieces.
	-- Each piece is jointed to Skin by what it is (tail, ears, wings, head...) so CreatureLife still animates it.
	local template = MESHES and MESHES:FindFirstChild(name)
	local usedMesh = false
	if template then
		usedMesh = true
		skin.Transparency = 1
		local clone = template:Clone()
		local _, tsize = clone:GetBoundingBox()
		local biggest = math.max(tsize.X, tsize.Y, tsize.Z)
		if biggest > 0 then
			clone:ScaleTo(clone:GetScale() * (s * 1.3 / biggest))
		end
		-- centre it on the body (templates are stored facing -Z, the game's "forward")
		local ccf = clone:GetBoundingBox()
		clone:PivotTo(clone:GetPivot() + (skin.Position - ccf.Position))
		for _, p in clone:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.CanCollide = false
				p.CanTouch = false
				p.CanQuery = false
				p.Massless = true
				p.CastShadow = true
				local n = p.Name:lower()
				local kind = (n:find("tail") and "tail") or (n:find("ear") and "ear") or (n:find("wing") and "wingpair")
					or (n:find("head") and "head") or (n:find("antenna") and "antenna") or (n:find("fin") and "fin")
					or ((n:find("mane") or n:find("flame")) and "flame") or ((n:find("leaves") or n:find("leaf") or n:find("bud")) and "leaf")
					or ((n:find("arm") or n:find("glove") or n:find("pincer") or n:find("claw")) and "arm")
				p.Name = "Mesh_" .. p.Name
				p.Parent = model
				if kind then
					joint(p, kind)
				else
					weld(skin, p)
				end
			end
		end
		clone:Destroy()
		if shiny then
			-- shinies glow gold (textured meshes can't be recoloured)
			local aura = Instance.new("ParticleEmitter")
			aura.Name = "ShinyAura"
			aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			aura.Color = ColorSequence.new(SHINY_GOLD)
			aura.LightEmission = 0.8
			aura.Size = NumberSequence.new(0.5, 0)
			aura.Lifetime = NumberRange.new(0.8, 1.4)
			aura.Rate = 8
			aura.Speed = NumberRange.new(0.5, 1.5)
			aura.SpreadAngle = Vector2.new(180, 180)
			aura.Parent = skin
		end
	end

	-- eyes: white, a big dark pupil and two shines (the 3D models have their own)
	for _, sx in usedMesh and {} or { -1, 1 } do
		add("EyeWhite", BALL, Vector3.new(s * 0.22, s * 0.25, s * 0.12), Color3.fromRGB(250, 250, 252), CFrame.new(sx * s * 0.19, s * 0.14, -s * 0.44))
		add("Eye", BALL, Vector3.new(s * 0.18, s * 0.22, s * 0.08), Color3.fromRGB(25, 22, 35), CFrame.new(sx * s * 0.19, s * 0.15, -s * 0.49))
		add("Shine", BALL, Vector3.one * s * 0.075, Color3.new(1, 1, 1), CFrame.new(sx * s * 0.19 - s * 0.035, s * 0.2, -s * 0.535))
		add("Shine2", BALL, Vector3.one * s * 0.035, Color3.new(1, 1, 1), CFrame.new(sx * s * 0.19 + s * 0.04, s * 0.1, -s * 0.535))
		-- eyelid tucked inside the body; slides forward over the eye to blink
		local lid = newPart("Lid", BALL, Vector3.new(s * 0.26, s * 0.29, s * 0.14), darker(look.color, 0.06), skin.CFrame * CFrame.new(sx * s * 0.19, s * 0.15, -s * 0.33), model)
		local m = Instance.new("Motor6D")
		m.Name = "J_Lid"
		m.Part0, m.Part1 = skin, lid
		m.C0 = skin.CFrame:Inverse() * lid.CFrame
		m:SetAttribute("Anim", "lid")
		m:SetAttribute("Reach", s * 0.15)
		m.Parent = lid
	end
	if not usedMesh then
		if BELLY[info.shape or "quad"] then
			add("Belly", BALL, Vector3.new(s * 0.62, s * 0.55, s * 0.4), lighter(look.color, 0.45), CFrame.new(0, -s * 0.18, -s * 0.28))
		end
		;(Shapes[info.shape] or Shapes.quad)(add, s, look, accent)
		for _, f in info.features or {} do
			if Features[f] then
				Features[f](add, s, look, accent)
			end
		end
	end

	-- Measure the visible model so it sits exactly on the ground
	local bottom, top = math.huge, -math.huge
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			-- how far this part reaches up/down, whatever way it's rotated
			local ext = math.abs(p.CFrame.RightVector.Y) * p.Size.X / 2 + math.abs(p.CFrame.UpVector.Y) * p.Size.Y / 2 + math.abs(p.CFrame.LookVector.Y) * p.Size.Z / 2
			bottom = math.min(bottom, p.Position.Y - ext)
			top = math.max(top, p.Position.Y + ext)
		end
	end
	if bottom == math.huge then
		bottom, top = -s / 2, s / 2
	end
	local groundOffset = -bottom + 0.05
	if info.floats then
		groundOffset += 2
	end

	-- Rare and Legendary creatures glow so players can spot them from a distance
	if rarity.order >= 3 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 12
		light.Brightness = 2
		light.Parent = body
	end
	if shiny or rarity.order >= 3 then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = shiny and SHINY_GOLD or rarity.color
		sparkles.Parent = body
	end

	-- Name tag: name + level, rarity/size, and type chips
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.new(8, 0, 2.6, 0)
	tag.StudsOffset = Vector3.new(0, top + 1.8, 0)
	tag.MaxDistance = 90
	tag.LightInfluence = 0
	tag.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.42)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = shiny and SHINY_GOLD or Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = (shiny and "★ " or "") .. (level and ("%s  Lv %d"):format(name, level) or name)
	nameLabel.Parent = tag

	local subLabel = nameLabel:Clone()
	subLabel.Name = "SubLabel"
	subLabel.Position = UDim2.fromScale(0, 0.42)
	subLabel.Size = UDim2.fromScale(1, 0.26)
	subLabel.TextColor3 = rarity.color
	local sub = info.rarity
	if sizeClass ~= "Normal" then
		sub ..= " · " .. sizeClass
	end
	if shiny then
		sub = "Shiny · " .. sub
	end
	subLabel.Text = sub
	subLabel.Parent = tag

	local row = Instance.new("Frame")
	row.Name = "TypeRow"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromScale(0, 0.72)
	row.Size = UDim2.fromScale(1, 0.28)
	row.Parent = tag
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.03, 0)
	layout.Parent = row
	typeChip(row, info.type)
	if info.type2 then
		typeChip(row, info.type2)
	end

	model:SetAttribute("CreatureName", name)
	model:SetAttribute("Scale", s)
	model:SetAttribute("Floats", info.floats == true)
	model:SetAttribute("Shape", info.shape or "quad")
	model:SetAttribute("Rarity", info.rarity)
	model:SetAttribute("GroundOffset", groundOffset)
	model:SetAttribute("Shiny", shiny)
	model:SetAttribute("SizeClass", sizeClass)
	return model
end

return CreatureBuilder
