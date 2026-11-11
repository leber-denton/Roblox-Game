--!strict
--[[
	ObstacleCourseBuilder: Edit-only tool that builds the optional parkour courses into
	Workspace.Obstacles.<Name> (one Folder per route) from ReplicatedStorage.Shared.CourseConfig.
	Same conventions as MountainPartBuilder: build(id) only creates a course that is missing, so
	manual Studio edits are never overwritten; delete the folder first to regenerate it.

	Placement is read from the place and the route data, never hand-picked:
	  * lane box: RegionStyle.laneBox (falls back to the Map.Lanes.<Lane> spawn part, e.g. Meadow)
	  * the road runs up the lane centre (RegionPaths), so courses sit on the west side, in the strip
	    between the wild-spawn area (WildSpawner: lane half-width - 10) and the first wall or hint part
	  * trainers: Map.RouteTrainers models inside the lane; a course avoids each trainer's sight box
	    (RouteTrainerService: 26 studs toward the hub, whole lane width) plus a margin
	  * the lane start (signs, junction) and the gym end stay clear

	Command bar (Edit, test place only):
	  local B = loadstring(game.ServerStorage.ObstacleCourseBuilder.Source)()
	  B.plan("Lane1")   -- prints the placement without building
	  B.build("Lane1")  -- or B.buildAll()
	See vault/Systems/ObstacleCourses.md.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local function loadShared(name: string): any
	local module = ReplicatedStorage:WaitForChild("Shared"):WaitForChild(name) :: ModuleScript
	-- Load the current source: require caches the first copy for the whole Studio session, so it would
	-- miss CourseConfig edits. The shared modules used here have no requires of their own.
	local ok, result = pcall(function() return (loadstring :: any)(module.Source)() end)
	if ok then
		return result
	end
	return require(module) :: any
end

local CourseConfig = loadShared("CourseConfig")
local RegionStyle = loadShared("RegionStyle")

local Builder = {}

local START_CLEAR = 40 -- studs kept clear after the lane start (sign, junction)
local GYM_CLEAR = 60 -- studs kept clear before the lane end (gym)
-- Trainer sight box: 26 studs ahead (toward the hub) and 4 behind, plus margin. The behind margin
-- also covers the access steps that can run up to ~8 studs back from a start pad.
local SIGHT_AHEAD, SIGHT_BEHIND = 32, 16
local ROW_GAP = 6.5 -- centre-to-centre spacing of the two rows on a switchback course
local PLATFORM_W = 5

type Theme = {
	Platform: Color3,
	PlatformMaterial: Enum.Material,
	Accent: Color3,
	AccentMaterial: Enum.Material,
	Hazard: Color3,
	Shape: string, -- "Block" | "Rock" | "Log"
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local M = Enum.Material
Builder.THEMES = {
	Meadow = { Platform = rgb(106, 160, 78), PlatformMaterial = M.Grass, Accent = rgb(139, 104, 68), AccentMaterial = M.Wood, Hazard = rgb(255, 120, 60), Shape = "Log" },
	Boulder = { Platform = rgb(124, 118, 108), PlatformMaterial = M.Rock, Accent = rgb(96, 132, 70), AccentMaterial = M.LeafyGrass, Hazard = rgb(255, 120, 60), Shape = "Rock" },
	Tide = { Platform = rgb(214, 196, 150), PlatformMaterial = M.Sandstone, Accent = rgb(150, 118, 84), AccentMaterial = M.WoodPlanks, Hazard = rgb(255, 120, 60), Shape = "Block" },
	Volt = { Platform = rgb(120, 124, 132), PlatformMaterial = M.DiamondPlate, Accent = rgb(250, 214, 60), AccentMaterial = M.Neon, Hazard = rgb(255, 90, 40), Shape = "Block" },
	Ember = { Platform = rgb(70, 62, 60), PlatformMaterial = M.Basalt, Accent = rgb(150, 70, 40), AccentMaterial = M.CrackedLava, Hazard = rgb(255, 110, 30), Shape = "Rock" },
	Frost = { Platform = rgb(196, 222, 236), PlatformMaterial = M.Glacier, Accent = rgb(236, 242, 248), AccentMaterial = M.Snow, Hazard = rgb(255, 120, 60), Shape = "Block" },
	Shadow = { Platform = rgb(74, 70, 86), PlatformMaterial = M.Slate, Accent = rgb(150, 100, 220), AccentMaterial = M.Neon, Hazard = rgb(255, 80, 120), Shape = "Block" },
	Sky = { Platform = rgb(240, 242, 246), PlatformMaterial = M.Marble, Accent = rgb(120, 190, 240), AccentMaterial = M.SmoothPlastic, Hazard = rgb(255, 120, 60), Shape = "Block" },
	Sunpetal = { Platform = rgb(110, 168, 80), PlatformMaterial = M.Grass, Accent = rgb(240, 196, 60), AccentMaterial = M.SmoothPlastic, Hazard = rgb(255, 110, 60), Shape = "Log" },
	Mirage = { Platform = rgb(198, 160, 110), PlatformMaterial = M.Sandstone, Accent = rgb(222, 204, 160), AccentMaterial = M.Sand, Hazard = rgb(255, 110, 40), Shape = "Rock" },
	Reef = { Platform = rgb(220, 204, 162), PlatformMaterial = M.Sandstone, Accent = rgb(240, 120, 128), AccentMaterial = M.Pebble, Hazard = rgb(255, 110, 60), Shape = "Block" },
	Mesa = { Platform = rgb(176, 100, 68), PlatformMaterial = M.Sandstone, Accent = rgb(110, 116, 128), AccentMaterial = M.Metal, Hazard = rgb(255, 210, 60), Shape = "Rock" },
	Bog = { Platform = rgb(80, 90, 64), PlatformMaterial = M.LeafyGrass, Accent = rgb(96, 76, 58), AccentMaterial = M.Wood, Hazard = rgb(140, 255, 80), Shape = "Log" },
	Crystal = { Platform = rgb(150, 190, 230), PlatformMaterial = M.Glass, Accent = rgb(190, 140, 250), AccentMaterial = M.Neon, Hazard = rgb(255, 90, 150), Shape = "Block" },
	Manor = { Platform = rgb(80, 82, 94), PlatformMaterial = M.Slate, Accent = rgb(120, 230, 210), AccentMaterial = M.Neon, Hazard = rgb(190, 90, 255), Shape = "Block" },
	Dragon = { Platform = rgb(64, 60, 60), PlatformMaterial = M.Basalt, Accent = rgb(236, 242, 248), AccentMaterial = M.Snow, Hazard = rgb(255, 100, 30), Shape = "Rock" },
} :: { [string]: Theme }

local WOOD, GOLD = rgb(120, 78, 44), rgb(232, 186, 64)
-- Map folders that only hold scenery: rays pass through them and clipping models are moved aside.
local DECOR_ROOTS = { "Decor", "MeadowMidDecor", "MeadowGateDecor" }

local function checkEdit()
	local RunService = game:GetService("RunService")
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Edit tool only")
	assert(game.PlaceId == 94034385545160, "Cloud test place only")
end

local function folderName(course): string
	return (course.RouteName:gsub("[^%w]", ""))
end

local function newPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, class: string?): BasePart
	local p = Instance.new((class or "Part") :: any) :: BasePart
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Anchored, p.Color, p.Material = true, color, material or M.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function decorPart(p: BasePart): BasePart
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	return p
end

local function sign(parent: Instance, name: string, cf: CFrame, title: string, body: string): BasePart
	local p = newPart(parent, name, Vector3.new(10, 4.5, 0.5), cf, rgb(55, 91, 82))
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.CanvasSize, gui.Parent = face, Vector2.new(600, 270), p
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Font, label.TextSize = Enum.Font.FredokaOne, 30
		label.TextColor3 = rgb(255, 240, 204)
		label.TextWrapped = true
		label.RichText = true
		label.Text = ('<font size="44">%s</font>\n%s'):format(title, body)
		label.Parent = gui
	end
	return p
end

-- Things a placement ray should ignore: decor, other courses, creatures, players, invisible bounds.
local function ignoreList(): { Instance }
	local list: { Instance } = {}
	local map = workspace:FindFirstChild("Map")
	for _, n in { "RouteTrainers", table.unpack(DECOR_ROOTS) } do
		local f = map and map:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	for _, n in { "Obstacles", "WildCreatures", "TutorialCreatures" } do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	return list
end

local function groundAt(x: number, z: number, top: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = ignoreList()
	local map = workspace:FindFirstChild("Map")
	for _, n in { "Bounds", "MountainHints" } do
		local f = map and map:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	params.FilterDescendantsInstances = list
	params.RespectCanCollide = true
	local hit = workspace:Raycast(Vector3.new(x, top + 80, z), Vector3.new(0, -200, 0), params)
	return hit and hit.Position.Y or 0
end

-- Distance from (x, y, z) to the first wall, bound or hint part in direction dir (studs).
local function clearance(origin: Vector3, dir: Vector3, maxDist: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = ignoreList()
	table.insert(list, workspace.Terrain)
	params.FilterDescendantsInstances = list
	local hit = workspace:Raycast(origin, dir * maxDist, params)
	return hit and (hit.Position - origin).Magnitude or maxDist
end

type Plan = {
	course: any,
	tuning: any,
	theme: Theme,
	laneX: number,
	side: number, -- -1 = west of the road
	innerX: number, -- inner edge of the strip (world x)
	width: number, -- usable strip width (studs, outward from innerX)
	z0: number, -- course start (world z)
	length: number, -- usable length along +z
	padTop: number,
	trainers: { number },
	notes: { string },
}

local function laneInfo(lane: string)
	local part = workspace.Map.Lanes:FindFirstChild(lane) :: BasePart?
	assert(part, "No Map.Lanes." .. lane .. " spawn part")
	local box = RegionStyle.laneBox(lane)
	local x = box and box.x or part.Position.X
	local z0 = box and box.z0 or part.Position.Z - part.Size.Z / 2
	local z1 = box and box.z1 or part.Position.Z + part.Size.Z / 2
	if box then
		assert(math.abs(part.Position.X - box.x) < 1, lane .. ": RegionStyle and Map.Lanes disagree on the lane centre")
	end
	-- WildSpawner.spawnInLane picks x within the part's half-width minus 10.
	return x, z0, z1, part.Size.X / 2 - 10, part.Position.Y + part.Size.Y / 2
end

function Builder.plan(id: string): Plan
	local course = assert(CourseConfig.get(id), "No CourseConfig entry " .. id)
	local tuning = CourseConfig.tuning(course)
	local theme = assert(Builder.THEMES[course.Theme], "No theme " .. tostring(course.Theme))
	local laneX, z0, z1, spawnHalf, laneTop = laneInfo(course.Lane)
	local side = -1
	local innerX = laneX + side * (spawnHalf + 1)
	local notes = {}

	-- Trainer sight boxes inside this lane.
	local blocked = { { z0, z0 + START_CLEAR }, { z1 - GYM_CLEAR, z1 } }
	local trainers = {}
	local rt = workspace.Map:FindFirstChild("RouteTrainers")
	for _, m in rt and rt:GetChildren() or {} do
		if m:IsA("Model") then
			local p = m:GetPivot().Position
			if math.abs(p.X - laneX) < 70 and p.Z >= z0 and p.Z <= z1 then
				table.insert(trainers, p.Z)
				table.insert(blocked, { p.Z - SIGHT_AHEAD, p.Z + SIGHT_BEHIND })
			end
		end
	end
	table.sort(blocked, function(a, b) return a[1] < b[1] end)
	-- Longest free stretch between blocked ranges.
	local bestA, bestB, cursor = 0, 0, z0
	for _, r in blocked do
		if r[1] - cursor > bestB - bestA then bestA, bestB = cursor, r[1] end
		cursor = math.max(cursor, r[2])
	end
	if z1 - cursor > bestB - bestA then bestA, bestB = cursor, z1 end
	local length = bestB - bestA - 4

	-- Strip width: first wall, bound or hint part outward from the strip, sampled along the stretch.
	local width = 40
	for t = 0, 1, 0.25 do
		local z = bestA + 2 + t * length
		for _, dy in { 3, 12 } do
			width = math.min(width, clearance(Vector3.new(innerX, laneTop + dy, z), Vector3.new(side, 0, 0), 40) - 1)
		end
	end
	-- MountainHints are touch-only (CanQuery off), so rays miss them: keep the course clear of them by hand.
	local hints = workspace.Map:FindFirstChild("MountainHints")
	for _, h in hints and hints:GetChildren() or {} do
		if h:IsA("BasePart") and math.abs(h.Position.Z - (bestA + bestB) / 2) < (h.Size.Z + bestB - bestA) / 2 then
			local inner = h.Position.X - side * h.Size.X / 2 -- the hint face nearest the road
			local dist = (innerX - inner) * -side
			if dist > 0 and dist < width + 2 then width = math.min(width, dist - 1.5) end
		end
	end
	-- Highest ground under the footprint, so no terrain pokes through a platform.
	local floor = laneTop
	for t = 0, 1, 0.1 do
		for w = 0.5, width - 0.5, math.max(1, (width - 1) / 3) do
			floor = math.max(floor, groundAt(innerX + side * w, bestA + 2 + t * length, laneTop))
		end
	end
	table.insert(notes, ("lane x %.0f, z %.0f-%.0f; strip x %.0f to %.0f (%.1f wide); course z %.0f-%.0f; floor y %.1f; trainers at z %s")
		:format(laneX, z0, z1, innerX, innerX + side * width, width, bestA + 2, bestA + 2 + length, floor, table.concat(trainers, ", ")))
	return {
		course = course, tuning = tuning, theme = theme, laneX = laneX, side = side,
		innerX = innerX, width = width, z0 = bestA + 2, length = length, padTop = floor + 1,
		trainers = trainers, notes = notes,
	}
end

-- Course geometry -----------------------------------------------------------------------------
type Ctx = {
	plan: Plan,
	rng: Random,
	path: Instance,
	theme: Theme,
	parts: number,
	route: { Vector3 }, -- landing points in climb order (used by tests)
}

local function world(ctx: Ctx, lx: number, y: number, lz: number): Vector3
	return Vector3.new(ctx.plan.innerX + ctx.plan.side * lx, y, ctx.plan.z0 + lz)
end

local function support(ctx: Ctx, pos: Vector3, size: Vector3)
	local ground = groundAt(pos.X, pos.Z, pos.Y)
	local h = pos.Y - size.Y / 2 - ground
	if h > 1.5 then
		local post = decorPart(newPart(ctx.path, "Support", Vector3.new(1, h, 1), CFrame.new(pos.X, ground + h / 2, pos.Z), ctx.theme.Accent, M.Wood))
		if ctx.theme.Shape ~= "Log" then
			post.Color, post.Material = ctx.theme.Platform, ctx.theme.PlatformMaterial
		end
	end
end

-- A static landing. lx/lz = centre (local), sx/sz = footprint, top = surface height.
local function platform(ctx: Ctx, name: string, lx: number, lz: number, sx: number, sz: number, top: number, noSupport: boolean?): BasePart
	local theme = ctx.theme
	local thick = theme.Shape == "Rock" and 3 or 1.2
	local pos = world(ctx, lx, top - thick / 2, lz)
	local p: BasePart
	if theme.Shape == "Log" and sx <= PLATFORM_W and sz <= PLATFORM_W and ctx.rng:NextNumber() < 0.5 then
		-- Log end-on: a cylinder lying across the course, flat enough to land on.
		local d = 3.2
		p = newPart(ctx.path, name, Vector3.new(sx, d, d), CFrame.new(pos.X, top - d / 2, pos.Z), theme.Accent, M.Wood)
		local log = p :: Part
		log.Shape = Enum.PartType.Cylinder
		local ring = decorPart(newPart(p, "Ring", Vector3.new(sx + 0.1, d - 0.6, d - 0.6), p.CFrame, rgb(196, 160, 110), M.Wood)) :: Part
		ring.Shape = Enum.PartType.Cylinder
	else
		local yaw = theme.Shape == "Rock" and math.rad(ctx.rng:NextNumber(-8, 8)) or 0
		p = newPart(ctx.path, name, Vector3.new(sx, thick, sz), CFrame.new(pos) * CFrame.Angles(0, yaw, 0), theme.Platform, theme.PlatformMaterial)
		if theme.Shape ~= "Rock" then
			decorPart(newPart(p, "Trim", Vector3.new(sx + 0.3, 0.3, sz + 0.3), p.CFrame * CFrame.new(0, -thick / 2 + 0.15, 0), theme.Accent, theme.AccentMaterial))
		end
	end
	if not noSupport then support(ctx, Vector3.new(pos.X, top - thick / 2, pos.Z), Vector3.new(sx, thick, sz)) end
	table.insert(ctx.route, world(ctx, lx, top, lz))
	return p
end

local function pickElement(ctx: Ctx): string
	local total = 0
	for _, w in ctx.plan.tuning.Elements do total += w end
	local roll = ctx.rng:NextNumber() * total
	for name, w in ctx.plan.tuning.Elements do
		roll -= w
		if roll <= 0 then return name end
	end
	return "Hop"
end

-- Max rise for an edge-to-edge gap: a default jump (height 7.2, speed 16) clears ~7.5 studs on the flat.
local function maxRise(gap: number, rise: number): number
	return math.min(rise, math.max(0, (7.2 - gap) / 0.9))
end

type Cursor = { lz: number, top: number, lx: number, dir: number }

-- Each element starts `gap` past cur.lz (in direction cur.dir), adds parts, and moves the cursor.
local ELEMENTS: { [string]: (ctx: Ctx, cur: Cursor, budget: number) -> boolean } = {}

local function nextTop(ctx: Ctx, cur: Cursor, gap: number): number
	local t = ctx.plan.tuning
	local up = ctx.rng:NextNumber(0, maxRise(gap, t.Rise))
	local top = cur.top + up
	if top > ctx.plan.padTop + t.MaxHeight then top = cur.top - ctx.rng:NextNumber(0, 1) end
	return math.max(top, ctx.plan.padTop + 1)
end

ELEMENTS.Hop = function(ctx, cur, budget)
	local t = ctx.plan.tuning
	local gap = ctx.rng:NextNumber(t.GapMin, t.GapMax)
	local size = ctx.rng:NextNumber(3.6, 5)
	if gap + size > budget then return false end
	local top = nextTop(ctx, cur, gap)
	platform(ctx, "Hop", cur.lx, cur.lz + cur.dir * (gap + size / 2), math.min(PLATFORM_W, size + 0.5), size, top)
	cur.lz += cur.dir * (gap + size)
	cur.top = top
	return true
end

-- Three short hops that each climb most of a jump: how harder courses gain height.
ELEMENTS.Climb = function(ctx, cur, budget)
	local t = ctx.plan.tuning
	local gap, size = 3, 4
	if 3 * (gap + size) > budget or cur.top + 3 * 2.4 > ctx.plan.padTop + t.MaxHeight then return false end
	for _ = 1, 3 do
		cur.top += math.min(2.4, maxRise(gap, t.Rise + 0.5))
		platform(ctx, "Climb", cur.lx, cur.lz + cur.dir * (gap + size / 2), 4, size, cur.top)
		cur.lz += cur.dir * (gap + size)
	end
	return true
end

ELEMENTS.Stairs = function(ctx, cur, budget)
	local steps = 4
	if steps * 3 + 1 > budget or cur.top + steps * 1.8 > ctx.plan.padTop + ctx.plan.tuning.MaxHeight then return false end
	for i = 1, steps do
		cur.top += 1.8
		platform(ctx, "Stair", cur.lx, cur.lz + cur.dir * (1 + (i - 0.5) * 3), PLATFORM_W, 3, cur.top)
	end
	cur.lz += cur.dir * (1 + steps * 3)
	return true
end

ELEMENTS.Beam = function(ctx, cur, budget)
	local len = ctx.plan.course.Difficulty == "Medium" and 12 or 16
	local w = ctx.plan.course.Difficulty == "Medium" and 1.4 or 1.1
	if len + 2 + 5 > budget then return false end
	local beam = newPart(ctx.path, "Beam", Vector3.new(w, 1, len), CFrame.new(world(ctx, cur.lx, cur.top - 0.5, cur.lz + cur.dir * (len / 2))), ctx.theme.Accent, ctx.theme.Shape == "Log" and M.Wood or ctx.theme.AccentMaterial)
	if ctx.theme.AccentMaterial == M.Neon then beam.Material = M.Metal end
	support(ctx, beam.Position, beam.Size)
	table.insert(ctx.route, world(ctx, cur.lx, cur.top, cur.lz + cur.dir * 1))
	table.insert(ctx.route, world(ctx, cur.lx, cur.top, cur.lz + cur.dir * (len - 1)))
	cur.lz += cur.dir * len
	-- A rest platform after the beam.
	platform(ctx, "Rest", cur.lx, cur.lz + cur.dir * 2.5, PLATFORM_W, 5, cur.top)
	cur.lz += cur.dir * 5
	return true
end

ELEMENTS.Mover = function(ctx, cur, budget)
	local span = 15 -- gap the mover shuttles across
	if span + 5 > budget then return false end
	local amp = (span - 5 - 3) / 2
	local mid = cur.lz + cur.dir * span / 2
	local p = newPart(ctx.path, "Mover", Vector3.new(PLATFORM_W, 1.2, 5), CFrame.new(world(ctx, cur.lx, cur.top - 0.6, mid)), ctx.theme.Accent, ctx.theme.AccentMaterial == M.Neon and M.Metal or ctx.theme.AccentMaterial)
	p:SetAttribute("MoveAxis", Vector3.new(0, 0, 1))
	p:SetAttribute("MoveAmplitude", amp)
	p:SetAttribute("MovePeriod", ctx.plan.tuning.MoverPeriod)
	p:SetAttribute("MovePhase", ctx.rng:NextNumber(0, 1))
	CollectionService:AddTag(p, "CourseMover")
	table.insert(ctx.route, world(ctx, cur.lx, cur.top, mid))
	cur.lz += cur.dir * span
	platform(ctx, "Landing", cur.lx, cur.lz + cur.dir * 2.5, PLATFORM_W, 5, cur.top)
	cur.lz += cur.dir * 5
	return true
end

ELEMENTS.Spinner = function(ctx, cur, budget)
	local gap = ctx.plan.tuning.GapMin
	if gap + 8 > budget then return false end
	local top = cur.top
	local centre = cur.lz + cur.dir * (gap + 4)
	platform(ctx, "SpinnerBase", cur.lx, centre, PLATFORM_W, 8, top)
	local hub = world(ctx, cur.lx, top + 1.4, centre)
	decorPart(newPart(ctx.path, "SpinnerHub", Vector3.new(1, 1.4, 1), CFrame.new(hub - Vector3.new(0, 0.7, 0)), rgb(70, 74, 84), M.Metal))
	local bar = newPart(ctx.path, "SpinnerBar", Vector3.new(0.7, 0.7, 7), CFrame.new(hub), ctx.theme.Hazard, M.Neon)
	bar:SetAttribute("SpinSpeed", ctx.plan.tuning.SpinSpeed * (ctx.rng:NextNumber() < 0.5 and -1 or 1))
	CollectionService:AddTag(bar, "CourseSpinner")
	cur.lz = centre + cur.dir * 4
	return true
end

ELEMENTS.Vanish = function(ctx, cur, budget)
	local count, size, gap = 3, 4, 3
	if count * (size + gap) > budget then return false end
	local period = ctx.plan.tuning.VanishPeriod
	for i = 1, count do
		local mid = cur.lz + cur.dir * (gap + size / 2)
		local p = newPart(ctx.path, "Vanish", Vector3.new(size, 1, size), CFrame.new(world(ctx, cur.lx, cur.top - 0.5, mid)), ctx.theme.Accent, M.Glass)
		p.Transparency = 0.1
		p:SetAttribute("VanishPeriod", period)
		p:SetAttribute("VanishOn", 0.65)
		p:SetAttribute("VanishPhase", (i - 1) * 0.18)
		CollectionService:AddTag(p, "CourseVanish")
		table.insert(ctx.route, world(ctx, cur.lx, cur.top, mid))
		cur.lz += cur.dir * (gap + size)
	end
	platform(ctx, "Landing", cur.lx, cur.lz + cur.dir * (gap + 2.5), PLATFORM_W, 5, cur.top)
	cur.lz += cur.dir * (gap + 5)
	return true
end

ELEMENTS.Hazard = function(ctx, cur, budget)
	local gap = ctx.plan.tuning.GapMin
	if gap + 13 > budget then return false end
	local centre = cur.lz + cur.dir * (gap + 6.5)
	platform(ctx, "HazardRun", cur.lx, centre, PLATFORM_W, 13, cur.top)
	-- Touching the glowing strip sends you back to the start pad (it never hurts).
	local strip = newPart(ctx.path, "ResetStrip", Vector3.new(PLATFORM_W + 0.2, 0.3, 2.4), CFrame.new(world(ctx, cur.lx, cur.top + 0.15, centre)), ctx.theme.Hazard, M.Neon)
	strip.CanCollide = false
	strip:SetAttribute("CourseId", ctx.plan.course.Id)
	CollectionService:AddTag(strip, "CourseHazard")
	cur.lz = centre + cur.dir * 6.5
	return true
end

local function buildChest(parent: Instance, cf: CFrame, id: string): Model
	local chest = Instance.new("Model")
	chest.Name = "Chest"
	chest:SetAttribute("CourseChest", id)
	local base = newPart(chest, "Base", Vector3.new(4, 2.2, 2.8), cf * CFrame.new(0, 1.1, 0), WOOD, M.WoodPlanks)
	chest.PrimaryPart = base
	for _, x in { -1.6, 1.6 } do
		newPart(chest, "Band", Vector3.new(0.35, 2.3, 2.9), base.CFrame * CFrame.new(x, 0, 0), GOLD, M.Metal)
	end
	local coins = newPart(chest, "Coins", Vector3.new(3.4, 0.5, 2.2), base.CFrame * CFrame.new(0, 1.0, 0), GOLD, M.Neon)
	coins.CanCollide = false
	-- The chest faces the road (its local -Z); the lid hinges on its back edge (+Z).
	local lid = newPart(chest, "Lid", Vector3.new(4, 1, 2.8), base.CFrame * CFrame.new(0, 1.6, 0), WOOD, M.WoodPlanks)
	-- The band rides on the lid: unanchored and welded, so moving the anchored lid moves both.
	local band = newPart(chest, "LidBand", Vector3.new(4.1, 0.3, 2.9), lid.CFrame * CFrame.new(0, 0.4, 0), GOLD, M.Metal)
	band.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = lid, band, lid
	newPart(chest, "Lock", Vector3.new(0.7, 0.8, 0.25), base.CFrame * CFrame.new(0, 0.6, -1.45), GOLD, M.Metal)
	for _, p in chest:GetDescendants() do
		if p:IsA("BasePart") and p ~= base then (p :: BasePart).CanCollide = false end
	end
	local glow = Instance.new("PointLight")
	glow.Name, glow.Color, glow.Range, glow.Brightness = "Glow", GOLD, 10, 1.5
	glow.Parent = coins
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Color = ColorSequence.new(GOLD)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Rate = 6
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.SpreadAngle = Vector2.new(60, 60)
	sparkle.Parent = coins
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "CoinBurst"
	burst.Color = ColorSequence.new(GOLD)
	burst.LightEmission = 0.6
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.2) })
	burst.Lifetime = NumberRange.new(0.8, 1.2)
	burst.Rate = 0
	burst.Speed = NumberRange.new(12, 18)
	burst.SpreadAngle = Vector2.new(35, 35)
	burst.Acceleration = Vector3.new(0, -40, 0)
	burst.EmissionDirection = Enum.NormalId.Top
	burst.Parent = coins
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChestPrompt"
	prompt.ActionText, prompt.ObjectText = "Open", "Treasure Chest"
	prompt.HoldDuration = 1
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = CourseConfig.PromptDistance - 1
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	chest.Parent = parent
	return chest
end

local function generate(ctx: Ctx, root: Instance)
	local plan = ctx.plan
	local start = Instance.new("Folder")
	start.Name, start.Parent = "Start", root
	local twoRows = plan.course.Difficulty ~= "Easy" and plan.width >= ROW_GAP + PLATFORM_W + 1
	local innerLx = twoRows and 3 or math.min(3.5, plan.width / 2)
	local outerLx = innerLx + ROW_GAP

	-- Start pad, with steps up from the lane floor if the ground under it is lower.
	local pad = newPart(start, "StartPad", Vector3.new(PLATFORM_W + 1, 1, 6), CFrame.new(world(ctx, innerLx, plan.padTop - 0.5, 3)), plan.theme.Accent, plan.theme.AccentMaterial == M.Neon and M.Metal or plan.theme.AccentMaterial)
	pad:SetAttribute("CourseStart", plan.course.Id)
	local below = plan.padTop - groundAt(pad.Position.X, pad.Position.Z - 4, plan.padTop)
	local steps = math.ceil((below - 1) / 1.5)
	for i = 1, math.max(0, steps) do
		local top = plan.padTop - i * 1.5
		local s = newPart(start, "AccessStep", Vector3.new(PLATFORM_W + 1, 1, 2.5), CFrame.new(world(ctx, innerLx, top - 0.5, -1.25 - (i - 1) * 2.5)), plan.theme.Platform, plan.theme.PlatformMaterial)
		support(ctx, s.Position, s.Size)
	end
	support(ctx, pad.Position, pad.Size)
	local t = plan.tuning
	-- On the strip's inner edge (outside the spawn area), just past the pad, facing the road.
	local signCf = CFrame.lookAt(world(ctx, 0, plan.padTop + 3.2, 11), world(ctx, -20, plan.padTop + 3.2, 11))
	sign(start, "StartSign", signCf, "Parkour Challenge: " .. t.Label,
		("%s · %d coins in the chest\nFalling just sends you back here"):format(plan.course.RouteName, plan.course.CoinReward))
	local postH = plan.padTop + 3.2 - groundAt(signCf.Position.X, signCf.Position.Z, plan.padTop)
	for _, dx in { -4.4, 4.4 } do
		decorPart(newPart(start, "SignPost", Vector3.new(0.6, postH, 0.6), signCf * CFrame.new(dx, -postH / 2, 0), WOOD, M.Wood))
	end
	table.insert(ctx.route, world(ctx, innerLx, plan.padTop, 3))

	-- Row 1 runs +z on the inner row; a switchback course turns and comes back on the outer row.
	local cur: Cursor = { lz = 6, top = plan.padTop, lx = innerLx, dir = 1 }
	local remaining = t.Steps
	local rowEnd = plan.length - (twoRows and 9 or 12)
	local function runRow(limit: number)
		local tries = 0
		while remaining > 0 and tries < 40 do
			local budget = cur.dir > 0 and (limit - cur.lz) or (cur.lz - limit)
			if budget < 6 then break end
			local kind = pickElement(ctx)
			-- An element that doesn't fit falls back to a plain hop; stop when even that doesn't fit.
			if not (ELEMENTS[kind](ctx, cur, budget) or ELEMENTS.Hop(ctx, cur, budget)) then
				break
			end
			remaining -= 1
			tries += 1
		end
	end
	runRow(rowEnd)
	if twoRows then
		-- Turn platform spanning both rows.
		local gap = t.GapMin
		local top = nextTop(ctx, cur, gap)
		local turnLz = cur.lz + gap + 3
		platform(ctx, "Turn", (innerLx + outerLx) / 2, turnLz, ROW_GAP + PLATFORM_W, 6, top)
		cur.lz, cur.top, cur.lx, cur.dir = turnLz, top, outerLx, -1
		cur.lz -= 3
		runRow(14)
	end
	-- Chest platform at the end.
	local gap = t.GapMin
	local top = nextTop(ctx, cur, gap)
	local chestLz = cur.lz + cur.dir * (gap + 4)
	local chestLx = cur.lx
	local chestPad = platform(ctx, "ChestPlatform", chestLx, chestLz, math.min(8, 2 * math.min(chestLx, plan.width - chestLx) - 0.5), 8, top)
	chestPad.Name = "ChestPlatform"
	local chestPos = world(ctx, chestLx, top, chestLz)
	local face = world(ctx, chestLx - 10, top, chestLz)
	buildChest(root, CFrame.lookAt(chestPos, face), plan.course.Id)
	local flag = decorPart(newPart(root, "FlagPole", Vector3.new(0.3, 9, 0.3), CFrame.new(world(ctx, chestLx + 2.5, top + 4.5, chestLz - cur.dir * 3)), rgb(230, 230, 230), M.Metal))
	decorPart(newPart(root, "Flag", Vector3.new(0.2, 2.4, 3.6), flag.CFrame * CFrame.new(0, 3.2, 1.8), plan.theme.Hazard, M.Fabric))
end

-- Half-size of a part's world-axis bounding box (parts may be rotated).
local function extents(part: BasePart): Vector3
	local cf, h = part.CFrame, part.Size / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return Vector3.new(
		math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(l.X) * h.Z,
		math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(l.Y) * h.Z,
		math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(l.Z) * h.Z
	)
end

local function displaceDecor(plan: Plan, box: BasePart): number
	local store = game.ServerStorage:FindFirstChild("ObstacleDisplacedDecor") or Instance.new("Folder")
	store.Name, store.Parent = "ObstacleDisplacedDecor", game.ServerStorage
	local dest = store:FindFirstChild(plan.course.Id) or Instance.new("Folder")
	dest.Name, dest.Parent = plan.course.Id, store
	local inv = box.CFrame:Inverse()
	local half = box.Size / 2
	local moved, models = 0, {}
	for _, rootName in DECOR_ROOTS do
		local root = workspace.Map:FindFirstChild(rootName)
		for _, d in root and root:GetDescendants() or {} do
			if d:IsA("BasePart") then
				-- Anything whose bounds reach into the footprint (tree canopies overhang their trunks).
				local p = inv * d.Position
				local reach = extents(d)
				if math.abs(p.X) < half.X + reach.X and math.abs(p.Z) < half.Z + reach.Z and p.Y - reach.Y < half.Y then
					local top: Instance = d
					while top.Parent and top.Parent ~= root and not (top.Parent :: Instance):IsA("Folder") do top = top.Parent :: Instance end
					models[top] = true
				end
			end
		end
	end
	for m in models do
		m:SetAttribute("OriginalParentPath", (m.Parent :: Instance):GetFullName())
		m.Parent = dest
		moved += 1
	end
	return moved
end

-- Builds the course for one CourseConfig id if it is missing. Returns the folder, whether it was
-- created, and a short report.
function Builder.build(id: string): (Folder, boolean, string)
	checkEdit()
	local plan = Builder.plan(id)
	local obstacles = workspace:FindFirstChild("Obstacles") or Instance.new("Folder")
	obstacles.Name, obstacles.Parent = "Obstacles", workspace
	local name = folderName(plan.course)
	local existing = obstacles:FindFirstChild(name)
	if existing then return existing :: Folder, false, name .. " already built" end
	local root = Instance.new("Folder")
	root.Name = name
	root:SetAttribute("CourseId", plan.course.Id)
	root:SetAttribute("Lane", plan.course.Lane)
	root:SetAttribute("RouteName", plan.course.RouteName)
	root:SetAttribute("Difficulty", plan.course.Difficulty)
	root:SetAttribute("FloorY", plan.padTop)
	local path = Instance.new("Folder")
	path.Name, path.Parent = "Path", root
	local seed = plan.course.Seed or 0
	for i = 1, #plan.course.Id do seed = (seed * 31 + string.byte(plan.course.Id, i)) % 2147483647 end
	local ctx: Ctx = { plan = plan, rng = Random.new(seed), path = path, theme = plan.theme, parts = 0, route = {} }
	generate(ctx, root)
	-- Footprint the server uses for fall resets (invisible, never collides or blocks rays).
	local minP, maxP = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local e = extents(d)
			minP = minP:Min(d.Position - e)
			maxP = maxP:Max(d.Position + e)
		end
	end
	local box = newPart(root, "CourseBounds", Vector3.new(maxP.X - minP.X + 1, maxP.Y - plan.padTop + 40, maxP.Z - minP.Z + 1),
		CFrame.new((minP.X + maxP.X) / 2, plan.padTop - 20 + (maxP.Y - plan.padTop + 40) / 2, (minP.Z + maxP.Z) / 2), rgb(255, 255, 255))
	box.Transparency, box.CanCollide, box.CanQuery, box.CanTouch = 1, false, false, false
	local route = {}
	for _, p in ctx.route do table.insert(route, ("%.1f,%.1f,%.1f"):format(p.X, p.Y, p.Z)) end
	root:SetAttribute("Route", table.concat(route, ";"))
	root.Parent = obstacles
	local moved = displaceDecor(plan, box)
	local n = 0
	for _, d in root:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	game:GetService("ChangeHistoryService"):SetWaypoint("Built obstacle course " .. name)
	return root, true, ("%s: %d parts, decor moved %d. %s"):format(name, n, moved, plan.notes[1])
end

-- Removes a course and puts back the decor it moved aside.
function Builder.remove(id: string): number
	checkEdit()
	local course = assert(CourseConfig.get(id), "No CourseConfig entry " .. id)
	local obstacles = workspace:FindFirstChild("Obstacles")
	local folder = obstacles and obstacles:FindFirstChild(folderName(course))
	if folder then folder:Destroy() end
	local store = game.ServerStorage:FindFirstChild("ObstacleDisplacedDecor")
	local moved = store and store:FindFirstChild(id)
	local restored = 0
	for _, m in moved and moved:GetChildren() or {} do
		local parent: Instance? = game
		for name in tostring(m:GetAttribute("OriginalParentPath")):gmatch("[^%.]+") do
			parent = parent and parent:FindFirstChild(name)
		end
		if parent then
			m:SetAttribute("OriginalParentPath", nil)
			m.Parent = parent
			restored += 1
		end
	end
	game:GetService("ChangeHistoryService"):SetWaypoint("Removed obstacle course " .. id)
	return restored
end

function Builder.buildAll(): { string }
	local out = {}
	for _, course in CourseConfig.Courses do
		local _, _, report = Builder.build(course.Id)
		table.insert(out, report)
		task.wait()
	end
	return out
end

return Builder
