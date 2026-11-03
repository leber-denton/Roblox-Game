--[[
	ArenaManager: isolated battle arenas far away from the map, one per active battle.
	Arenas are built the first time they're needed and reused afterwards.
	Each arena is a round grassy clearing ringed by trees, with the player's side at -X
	and the wild creature's side at +X.
]]

local ArenaManager = {}

local BASE = Vector3.new(4000, 0, 0) -- far outside the playable map
local SPACING = 400

local folder = workspace:FindFirstChild("BattleArenas")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "BattleArenas"
	folder.Parent = workspace
end

local slots = {} -- [index] = { center = Vector3, busy = boolean }

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Shape" then
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function disc(name, radius, height, topY, center, color, material, parent)
	-- a cylinder lying flat (its axis turned to point up)
	return part({
		Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(center.X, topY - height / 2, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color, Material = material or Enum.Material.SmoothPlastic,
	}, parent)
end

local function build(center: Vector3, index: number)
	local model = Instance.new("Model")
	model.Name = "Arena" .. index
	local rng = Random.new(index * 17)

	disc("Ground", 90, 4, center.Y, center, Color3.fromRGB(95, 175, 75), Enum.Material.Grass, model)
	disc("Field", 24, 0.2, center.Y + 0.1, center, Color3.fromRGB(150, 205, 110), Enum.Material.Grass, model)
	-- your creature stands just ahead of you (front left on screen); the opponent is further off to the right
	disc("PlayerPad", 4.5, 0.2, center.Y + 0.2, center + Vector3.new(-7, 0, -1), Color3.fromRGB(235, 240, 225), nil, model)
	disc("WildPad", 5.5, 0.2, center.Y + 0.2, center + Vector3.new(9, 0, 7), Color3.fromRGB(235, 240, 225), nil, model)

	-- ring of trees and bushes around the clearing
	for i = 1, 26 do
		local a = i / 26 * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local r = rng:NextNumber(30, 44)
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		local h = rng:NextNumber(10, 16)
		part({
			Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.2, 2.2),
			CFrame = CFrame.new(x, center.Y + h / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(110, 75, 48), Material = Enum.Material.Wood,
		}, model)
		part({
			Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(10, 14),
			Position = Vector3.new(x, center.Y + h + 2, z),
			Color = Color3.fromRGB(60, 145, 60):Lerp(Color3.fromRGB(95, 180, 70), rng:NextNumber()), Material = Enum.Material.Grass,
		}, model)
	end
	for i = 1, 18 do
		local a = i / 18 * math.pi * 2
		local r = rng:NextNumber(23, 27)
		local s = rng:NextNumber(3, 5)
		part({
			Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.one * s,
			Position = Vector3.new(center.X + math.cos(a) * r, center.Y + s * 0.3, center.Z + math.sin(a) * r),
			Color = Color3.fromRGB(70, 155, 60), Material = Enum.Material.Grass,
		}, model)
	end
	-- distant hills
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local s = rng:NextNumber(120, 180)
		part({
			Name = "Hill", Shape = Enum.PartType.Ball, Size = Vector3.one * s,
			Position = Vector3.new(center.X + math.cos(a) * 140, center.Y - s * 0.3, center.Z + math.sin(a) * 140),
			Color = Color3.fromRGB(110, 175, 90), Material = Enum.Material.Grass, CanCollide = false,
		}, model)
	end
	model.Parent = folder
end

-- Reserve an arena. Returns its index and the centre point (ground level).
function ArenaManager.acquire(): (number, Vector3)
	for index, slot in slots do
		if not slot.busy then
			slot.busy = true
			return index, slot.center
		end
	end
	local index = #slots + 1
	local center = BASE + Vector3.new(SPACING * (index - 1), 0, 0)
	build(center, index)
	slots[index] = { center = center, busy = true }
	return index, center
end

function ArenaManager.release(index: number?)
	if index and slots[index] then
		slots[index].busy = false
	end
end

return ArenaManager
