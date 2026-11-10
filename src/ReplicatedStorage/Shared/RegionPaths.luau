--[[
	RegionPaths: the road and the land shape for each region, as data plus pure geometry helpers.
	Theming Overhaul Phase A1 (Meadow Route pilot). Only Lane1 is filled in so far.

	Used by:
	  * ServerStorage.RegionTerrainBuilder  (writes the Terrain from this data)
	  * ServerStorage.RegionPathValidator   (checks the built world against this data)
	  * tests/RegionPathsTests.luau         (checks the data itself)

	Coordinates are studs. A region's road is a polyline of waypoints {x, y, z}; y is the walkable road
	surface. Everything is measured from the nearest point on that polyline:
	  d <= corridorWidth / 2                    road (kept clear, max slope maxSlopeDeg)
	  d <= corridorWidth / 2 + buffer           flat verge (route trainers stand here)
	  next `shoulder` studs                     blends from road height up to the wild land
	  beyond                                    rolling hills for the zone, rising into the boundary ridge
	The boundary ridge rises along the `boundary.sides` edges of `bounds` (fading out over `endTaper` at the
	ends of the region). The road never crosses it; the region's own walls and gate close the rest.

	Trainer spots are not copied here: they come from GameData.RouteTrainers by id, so the two can't drift.
	Lane1 numbers come from the read-only recon of 2026-11-10 (see vault/Systems/RegionPaths.md).
]]

local GameData = require(script.Parent:WaitForChild("GameData"))

local RegionPaths = {}

RegionPaths.Lane1 = {
	lane = "Lane1",
	name = "Meadow Route",
	seed = 11,

	-- The place today (recon): Lane1 is a 130-stud corridor between glass Walls.Divider parts at x = +-65,
	-- floored by Workspace.Baseplate (top y 0) and RoadGround.LaneGround.Ground_Lane1 (z 695-770). It
	-- opens south onto Map.Walkway (pavement, top 0.4) and ends at Gates.Gate_Lane1B (z 770) behind
	-- the gym. There was no road; decor stood on the centreline.
	-- Road: straight up x = 0 between the trainers, then east round the gym to the gate, ending on
	-- Boulder Pass's PathDirt (x 0, top 0.5). y 0.4 matches the walkway and sits above the baseplate.
	waypoints = {
		{ x = 0, y = 0.4, z = 226 },
		{ x = 0, y = 0.4, z = 380 },
		{ x = 0, y = 0.4, z = 510 },
		{ x = 0, y = 0.4, z = 640 },
		{ x = 0, y = 0.4, z = 712 },
		{ x = 40, y = 0.4, z = 736 },
		{ x = 40, y = 0.4, z = 764 },
		{ x = 0, y = 0.4, z = 794 },
	},
	corridorWidth = 16,
	buffer = 12,
	shoulder = 20,
	maxSlopeDeg = 10,
	-- How far below the road surface the terrain top sits. 0: the terrain is the road.
	surfaceSink = 0,
	-- Terrain must not sit level with these part tops (it flickers). Within 0.25 of one, it drops 0.35 below.
	avoidY = { 0 },
	-- Ground under protected parts may rise this far above their bottom (sinks them a little, keeps
	-- terrain clear of the y 0 baseplate under the many props that stand on it)
	protectSink = 0.6,
	-- Parts that are the old ground: never protected (the builder would otherwise flatten the land to
	-- their bottoms). Full names under Workspace.
	groundParts = { "Baseplate", "Map.RoadGround", "Map.Walkway" },

	-- The area the builder owns. Nothing outside it is written. The corridor plus 71 studs of mountain
	-- outside each glass wall; the Region 1/2 range starts at x ~170.
	bounds = { minX = -136, maxX = 136, minZ = 250, maxZ = 770 },
	floorY = -24, -- bottom of the terrain fill

	-- Places kept flat at floorY, with `margin` studs of blend. The gym box is x -19..19, z 733.7..767;
	-- floorY just under the baseplate so no terrain shows inside it.
	keepClear = {
		{ name = "MeadowGym", minX = -20, maxX = 20, minZ = 733, maxZ = 768, floorY = -0.4, margin = 4 },
	},

	-- Decor standing in the road or verge is shifted (never deleted) by RegionTerrainBuilder.build.
	decor = {
		root = "Map.Decor",
		skipFolders = { "Fresh_GymFacades", "BoulderPass", "BaseSurroundings" },
		margin = 2, -- extra clearance from the verge edge
		interior = { minX = -62, maxX = 62, minZ = 254, maxZ = 766 }, -- inside the walls
		clusterGap = 4, -- loose parts in one folder closer than this move together (flower patches, fences)
		overlapShrink = 0.4, -- decor may overlap others' outer 60% (tree canopies)
		maxShift = 112, -- sideways; far enough to carry the bypass trees from the east wall to west of the gym
		maxShiftAlong = 64,
	},

	-- Route dressing placed by ServerStorage.RegionDecorator. Each rule walks the road every `every` studs
	-- inside its depth band and places a clone of `template` (an existing decor item, so ModelSync still
	-- finds it by name) `offset` studs out from the centreline. sides: "both" | "alternate".
	-- kind = "fence" builds short rail runs from the Fence folder's Post and Rail parts instead.
	-- Spots that hit other decor, a trainer, the gym or the walls are skipped. The verge (d <= 20) is kept
	-- for trainers, so only low things (fence, mushrooms) sit inside it.
	dressing = {
		folder = "Lane1Dressing", -- under Map.Decor; the builder's decor shifting leaves it alone
		sink = 0.3, -- studs pushed into the ground so nothing floats on the terrain
		trainerClear = 9, -- no dressing within this many studs of a route trainer
		rules = {
			-- Meadow: low split-rail fence runs edging the road, flower bushes along the verge edge,
			-- the odd oak further out
			{ name = "meadow fence", kind = "fence", from = 0.02, to = 0.6, offset = 9.5, every = 28, length = 12, sides = "both" },
			{ name = "verge bushes", template = "Map.Decor.Bushes.FlowerBush", from = 0.0, to = 0.64, offset = 22, every = 16, sides = "alternate", jitter = 2 },
			{ name = "meadow oaks", template = "Map.Decor.Trees.OakTree", from = 0.04, to = 0.6, offset = 38, every = 52, sides = "alternate", jitter = 5 },
			-- Middle stretch: boulders start to crop up in the grass
			{ name = "middle boulders", template = "Map.Decor.Rocks.Boulder", from = 0.33, to = 0.66, offset = 28, every = 36, sides = "alternate", jitter = 4 },
			-- Whisperwood: an oak avenue on both sides, glowing mushrooms lighting the road edge
			{ name = "wood avenue", template = "Map.Decor.Whisperwood.OakTree", from = 0.62, to = 0.95, offset = 34, every = 22, sides = "both", jitter = 3 },
			{ name = "wood mushrooms", template = "Map.Decor.Whisperwood.GlowMushrooms", from = 0.64, to = 0.97, offset = 10.5, every = 12, sides = "alternate", jitter = 1 },
			-- Entrance: a boulder either side of the road where it leaves the hub walkway
			{ name = "gateway boulders", template = "Map.Decor.Rocks.Boulder", from = 0.0, to = 0.05, start = 34, offset = 14, every = 1000, sides = "both", jitter = 0 },
		},
	},

	trainerIds = { "r1a", "r1b", "r1c" },
	gym = "MeadowGym",

	roadMaterial = Enum.Material.Ground,

	-- Theme zones by depth along the road (0 = south entrance, 1 = gym). They follow the wild spawn
	-- bands in GameData.Lanes.Lane1. hill = height of the rolling land above the road, scale = how
	-- wide the hills are. accent covers the patches where the noise is above accentAt.
	zones = {
		{
			name = "Meadow",
			from = 0,
			to = 0.35,
			ground = Enum.Material.Grass,
			accent = Enum.Material.LeafyGrass,
			accentAt = 0.62,
			under = Enum.Material.Ground,
			cliff = Enum.Material.Rock,
			hill = 7,
			scale = 90,
		},
		{
			name = "Middle stretch",
			from = 0.35,
			to = 0.65,
			ground = Enum.Material.Grass,
			accent = Enum.Material.Ground,
			accentAt = 0.7,
			under = Enum.Material.Ground,
			cliff = Enum.Material.Rock,
			hill = 13,
			scale = 75,
		},
		{
			name = "Whisperwood",
			from = 0.65,
			to = 1,
			-- Same ground as the middle stretch so the gym approach reads as part of the meadow
			-- (LeafyGrass/Mud showed as a dark grey-green band). Repainted in the place 2026-11-10.
			-- The place's steep banks inside the walls (z 584-770) were also hand-repainted Rock -> Ground;
			-- a rebuild brings that rock back unless `hill` is lowered.
			ground = Enum.Material.Grass,
			accent = Enum.Material.Ground,
			accentAt = 0.6,
			under = Enum.Material.Ground,
			cliff = Enum.Material.Rock,
			hill = 19,
			scale = 60,
		},
	},
	zoneBlend = 0.06, -- depth over which neighbouring zones' hill heights blend

	-- Mountains outside the glass walls. The walls, the invisible Bounds caps and the gate close the
	-- corridor itself; the south end is the entrance from the hub.
	boundary = {
		sides = { west = true, east = true },
		height = 64, -- ridge peak above the road
		width = 72, -- how far in from the bounds edge the ridge reaches (to the wall at x +-64)
		endTaper = 40, -- the ridge fades out over this many studs at the south and north ends
		minWall = 30, -- the validator wants at least this much above the road along the ridge line
		rock = Enum.Material.Rock,
		peak = Enum.Material.Slate,
		peakAbove = 44, -- above this height (over the road) the top is `peak`
		openings = {}, -- extra allowed gaps: { { minX, maxX, minZ, maxZ } }
	},
	cliffSlopeDeg = 38, -- steeper than this shows the zone's cliff material
}

--[[
	Every other route: built from its RegionStyle theme with Meadow's geometry (Overhaul Phase 2).
	The road runs straight up the lane centre, swings 40 studs east round the gym and back, and runs
	24 studs past both lane ends so neighbouring routes join cleanly. Land, verge, hills, ridge and the
	decor bands copy Meadow's numbers (RegionStyle.spec); materials and decor come from the theme.
]]
local RegionStyle = require(script.Parent:WaitForChild("RegionStyle"))

local function gymModelFor(laneKey: string): string?
	for _, g in GameData.GymLeaders or {} do
		if type(g) == "table" and g.lane == laneKey then
			return g.model
		end
	end
	return nil
end

local function trainerIdsFor(laneKey: string): { string }
	local ids = {}
	for _, t in GameData.RouteTrainers or {} do
		if t.lane == laneKey then
			table.insert(ids, t.id)
		end
	end
	table.sort(ids)
	return ids
end

local function leafName(dotted: string): string
	return dotted:match("([^%.]+)$") or dotted
end

function RegionPaths.fromStyle(laneKey: string)
	local theme = RegionStyle.lanes[laneKey]
	if not theme then
		return nil
	end
	local spec = RegionStyle.spec
	local region = RegionStyle.regions[theme.region]
	local box = RegionStyle.laneBox(laneKey)
	local x, y, z0, z1, gz = box.x, region.roadY, box.z0, box.z1, theme.gymZ
	local gymName = gymModelFor(laneKey)

	local rules = {}
	for _, d in theme.decor do
		local role, template, from, to = d[1], d[2], d[3] or 0, d[4] or 1
		local base = spec.roles[role]
		assert(base, ("RegionStyle %s: unknown decor role %s"):format(laneKey, tostring(role)))
		local rule = table.clone(base)
		rule.name = role .. " " .. (if template ~= "" then leafName(template) else "fence")
		rule.template = if template ~= "" then template else nil
		rule.from, rule.to = from, to
		table.insert(rules, rule)
	end

	local keepClear = {}
	if gymName then
		table.insert(keepClear, { name = gymName, minX = x - 20, maxX = x + 20, minZ = gz - 17, maxZ = gz + 17, floorY = region.gymFloorY, margin = 4 })
	end
	for _, k in theme.keepClear or {} do
		table.insert(keepClear, { name = k.name, minX = x + k.minX, maxX = x + k.maxX, minZ = k.minZ, maxZ = k.maxZ, floorY = k.floorY, margin = k.margin })
	end

	local zones = {}
	local cuts = { 0, 0.35, 0.65, 1 }
	local scales = { 90, 75, 60 }
	for i = 1, 3 do
		table.insert(zones, {
			name = theme.name .. " " .. spec.zoneNames[i],
			from = cuts[i],
			to = cuts[i + 1],
			ground = theme.ground,
			accent = theme.accent,
			accentAt = theme.accentAt or 0.62,
			under = theme.under,
			cliff = theme.cliff,
			hill = spec.hills[i],
			scale = scales[i],
		})
	end

	return {
		lane = laneKey,
		name = theme.name,
		seed = theme.seed,
		generated = true, -- from RegionStyle; edit the theme, not this table
		waypoints = {
			{ x = x, y = y, z = z0 - 24 },
			{ x = x, y = y, z = z0 + 130 },
			{ x = x, y = y, z = z0 + 260 },
			{ x = x, y = y, z = gz - 38 },
			{ x = x + 40, y = y, z = gz - 14 },
			{ x = x + 40, y = y, z = gz + 14 },
			{ x = x, y = y, z = z1 + 24 },
		},
		corridorWidth = spec.road.width,
		buffer = spec.road.verge,
		shoulder = spec.road.shoulder,
		maxSlopeDeg = spec.road.maxSlopeDeg,
		surfaceSink = 0,
		avoidY = region.avoidY,
		protectSink = 0.6,
		groundParts = { "Baseplate", "Map.RoadGround", "Map.Walkway" },
		keepParts = RegionStyle.keepParts,
		protectInsideOnly = 66, -- parts further out than the lane walls don't hold the ridge down
		stashNames = RegionStyle.stashNames,
		bounds = { minX = x - 136, maxX = x + 136, minZ = z0, maxZ = z1 },
		floorY = -24,
		keepClear = keepClear,
		decor = {
			root = "Map.Decor",
			skipFolders = { "Fresh_GymFacades", "BaseSurroundings", laneKey .. "Dressing", "Lane1Dressing" },
			margin = 2,
			interior = { minX = x - 62, maxX = x + 62, minZ = z0 + 4, maxZ = z1 - 4 },
			clusterGap = 4,
			overlapShrink = 0.4,
			maxShift = 112,
			maxShiftAlong = 64,
		},
		dressing = {
			folder = laneKey .. "Dressing",
			sink = 0.3,
			trainerClear = spec.trainerClear,
			rules = rules,
		},
		trainerIds = trainerIdsFor(laneKey),
		gym = gymName,
		roadMaterial = theme.road,
		zones = zones,
		zoneBlend = 0.06,
		boundary = {
			sides = { west = true, east = true },
			height = spec.boundary.height,
			width = spec.boundary.width,
			endTaper = 0, -- neighbouring routes' ridges meet, so the sides stay closed end to end
			minWall = spec.boundary.minWall,
			rock = theme.boundaryRock or theme.cliff,
			peak = theme.peak,
			peakAbove = 44,
			openings = {},
		},
		cliffSlopeDeg = 38,
		palette = theme.palette,
	}
end

for laneKey in RegionStyle.lanes do
	if RegionPaths[laneKey] == nil then
		RegionPaths[laneKey] = RegionPaths.fromStyle(laneKey)
	end
end

function RegionPaths.get(laneKey: string)
	return RegionPaths[laneKey]
end

-- Every region with path data, sorted by lane key
function RegionPaths.list(): { string }
	local keys = {}
	for key, value in RegionPaths do
		if type(value) == "table" and value.waypoints then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
RegionPaths.smoothstep = smoothstep

-- Total horizontal length of the road
function RegionPaths.length(path): number
	local total = 0
	local w = path.waypoints
	for i = 2, #w do
		total += math.sqrt((w[i].x - w[i - 1].x) ^ 2 + (w[i].z - w[i - 1].z) ^ 2)
	end
	return total
end

-- Nearest point on the road to (x, z).
-- Returns: horizontal distance, distance along the road from the first waypoint, road y there.
function RegionPaths.nearest(path, x: number, z: number): (number, number, number)
	local w = path.waypoints
	local best, bestAlong, bestY = math.huge, 0, w[1].y
	local walked = 0
	for i = 2, #w do
		local a, b = w[i - 1], w[i]
		local dx, dz = b.x - a.x, b.z - a.z
		local len2 = dx * dx + dz * dz
		local len = math.sqrt(len2)
		local s = if len2 > 0 then math.clamp(((x - a.x) * dx + (z - a.z) * dz) / len2, 0, 1) else 0
		local px, pz = a.x + dx * s, a.z + dz * s
		local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if d < best then
			best, bestAlong, bestY = d, walked + s * len, a.y + (b.y - a.y) * s
		end
		walked += len
	end
	return best, bestAlong, bestY
end

-- Point on the road at `along` studs from the first waypoint. Returns x, y, z and the unit direction.
function RegionPaths.pointAt(path, along: number): (number, number, number, number, number)
	local w = path.waypoints
	local walked = 0
	for i = 2, #w do
		local a, b = w[i - 1], w[i]
		local dx, dz = b.x - a.x, b.z - a.z
		local len = math.sqrt(dx * dx + dz * dz)
		if along <= walked + len or i == #w then
			local s = if len > 0 then math.clamp((along - walked) / len, 0, 1) else 0
			local ux, uz = if len > 0 then dx / len else 0, if len > 0 then dz / len else 1
			return a.x + dx * s, a.y + (b.y - a.y) * s, a.z + dz * s, ux, uz
		end
		walked += len
	end
	local last = w[#w]
	return last.x, last.y, last.z, 0, 1
end

-- Depth 0..1 for a point: 0 at the south bounds edge, 1 at the north edge (matches the spawn bands)
function RegionPaths.depthAt(path, z: number): number
	local b = path.bounds
	return math.clamp((z - b.minZ) / (b.maxZ - b.minZ), 0, 1)
end

--[[
	The zone at a depth. Near a border it also returns the neighbouring zone and how much of it
	(0..0.5) to blend in, so the land has no seam where the zones meet.
]]
function RegionPaths.zoneAt(path, depth: number)
	local zones = path.zones
	local zone = zones[#zones]
	local index = #zones
	for i, z in zones do
		if depth < z.to or i == #zones then
			zone, index = z, i
			break
		end
	end
	local blend = path.zoneBlend or 0
	if blend > 0 then
		local nextZone, prevZone = zones[index + 1], zones[index - 1]
		if nextZone and depth > zone.to - blend then
			return zone, nextZone, smoothstep((depth - (zone.to - blend)) / (2 * blend))
		elseif prevZone and depth < zone.from + blend then
			return zone, prevZone, 1 - smoothstep((depth - (zone.from - blend)) / (2 * blend))
		end
	end
	return zone, nil, 0
end

-- Two-octave noise mapped to roughly 0..1
local function fbm(x: number, z: number, scale: number, seed: number): number
	local n = math.noise(x / scale, z / scale, seed * 0.37) + 0.5 * math.noise(x / (scale * 0.45), z / (scale * 0.45), seed * 0.37 + 9.1)
	return math.clamp(n / 1.5 + 0.5, 0, 1)
end
RegionPaths.fbm = fbm

-- How much of the keep-clear box (0..1) covers (x, z); 1 inside, blending to 0 over the margin
local function keepClearWeight(box, x: number, z: number): number
	local margin = box.margin or 0
	local ox = math.max(box.minX - x, 0, x - box.maxX)
	local oz = math.max(box.minZ - z, 0, z - box.maxZ)
	local out = math.sqrt(ox * ox + oz * oz)
	if out <= 0 then
		return 1
	elseif margin <= 0 or out >= margin then
		return 0
	end
	return 1 - smoothstep(out / margin)
end

-- Inside one of the allowed boundary openings?
function RegionPaths.inOpening(path, x: number, z: number): boolean
	for _, o in path.boundary.openings do
		if x >= o.minX and x <= o.maxX and z >= o.minZ and z <= o.maxZ then
			return true
		end
	end
	return false
end

-- Distance in from the nearest bounds edge that carries a ridge (math.huge if no side has one)
function RegionPaths.ridgeEdge(path, x: number, z: number): number
	local b, sides = path.bounds, path.boundary.sides or { west = true, east = true, south = true, north = true }
	local edge = math.huge
	if sides.west then
		edge = math.min(edge, x - b.minX)
	end
	if sides.east then
		edge = math.min(edge, b.maxX - x)
	end
	if sides.south then
		edge = math.min(edge, z - b.minZ)
	end
	if sides.north then
		edge = math.min(edge, b.maxZ - z)
	end
	return edge
end

-- Height of the boundary ridge above the road at (x, z)
function RegionPaths.ridgeAt(path, x: number, z: number): number
	local ridge, b = path.boundary, path.bounds
	if RegionPaths.inOpening(path, x, z) then
		return 0
	end
	local edge = RegionPaths.ridgeEdge(path, x, z)
	if edge >= ridge.width then
		return 0
	end
	local jag = 0.8 + 0.2 * fbm(x, z, 28, path.seed + 3)
	local h = ridge.height * smoothstep(1 - edge / ridge.width) * jag
	local taper = ridge.endTaper or 0
	if taper > 0 then
		local sides = ridge.sides or {}
		local fromEnd = math.huge
		if not sides.south then
			fromEnd = math.min(fromEnd, z - b.minZ)
		end
		if not sides.north then
			fromEnd = math.min(fromEnd, b.maxZ - z)
		end
		h *= smoothstep(fromEnd / taper)
	end
	return h
end

--[[
	The designed ground height at (x, z), before the builder's protection for existing parts.
	Returns: height, kind ("road" | "verge" | "shoulder" | "wild"), road y at the nearest point,
	the zone, and the ridge height there (above the road).
]]
function RegionPaths.heightAt(path, x: number, z: number)
	local d, _, roadY = RegionPaths.nearest(path, x, z)
	local half = path.corridorWidth / 2
	local inner = half + path.buffer
	local zone, other, mix = RegionPaths.zoneAt(path, RegionPaths.depthAt(path, z))

	-- rolling land from road height up to `hill` above it (no dips: the old ground parts sit just below)
	local function land(zn)
		return zn.hill * fbm(x, z, zn.scale, path.seed)
	end
	local lift = land(zone)
	if other and mix > 0 then
		lift += (land(other) - lift) * mix
	end
	local natural = roadY + lift

	local ridgeH = RegionPaths.ridgeAt(path, x, z)
	local wild = math.max(natural, roadY + ridgeH)

	local h, kind
	local sunk = roadY - (path.surfaceSink or 0)
	if d <= half then
		h, kind = sunk, "road"
	elseif d <= inner then
		h, kind = sunk, "verge"
	elseif d <= inner + path.shoulder then
		local k = smoothstep((d - inner) / path.shoulder)
		h, kind = sunk + (wild - sunk) * k, "shoulder"
	else
		h, kind = wild, "wild"
	end

	for _, box in path.keepClear do
		local k = keepClearWeight(box, x, z)
		if k > 0 then
			h = h + (box.floorY - h) * k
		end
	end
	return h, kind, roadY, zone, ridgeH
end

-- Surface material for a column. slopeDeg is the ground steepness there.
function RegionPaths.materialAt(path, x: number, z: number, h: number, kind: string, roadY: number, zone, slopeDeg: number)
	if kind == "road" then
		return path.roadMaterial or zone.ground
	end
	local ridge = path.boundary
	if h - roadY >= ridge.peakAbove then
		return ridge.peak
	end
	if slopeDeg >= path.cliffSlopeDeg then
		return if h - roadY > 18 then ridge.rock else zone.cliff
	end
	if kind ~= "verge" and zone.accent and fbm(x, z, 22, path.seed + 7) >= zone.accentAt then
		return zone.accent
	end
	return zone.ground
end

-- Route trainers that stand in this region: { id, name, x, z } from GameData.RouteTrainers
function RegionPaths.trainerSpots(path)
	local spots = {}
	for _, id in path.trainerIds or {} do
		for _, t in GameData.RouteTrainers do
			if t.id == id then
				table.insert(spots, { id = t.id, name = t.name, x = t.x, z = t.z })
			end
		end
	end
	return spots
end

--[[
	Checks the data alone (no Studio world needed). Returns a list of problem strings; empty = fine.
	Covers: waypoint slopes, the road spanning the bounds, trainer spots on the verge and before the gym,
	zones covering 0..1 in order, keep-clear boxes inside the bounds.
]]
function RegionPaths.check(path): { string }
	local problems = {}
	local function add(fmt, ...)
		table.insert(problems, (fmt):format(...))
	end
	local w = path.waypoints
	if #w < 2 then
		add("needs at least 2 waypoints")
		return problems
	end
	local maxRise = math.tan(math.rad(path.maxSlopeDeg))
	for i = 2, #w do
		local run = math.sqrt((w[i].x - w[i - 1].x) ^ 2 + (w[i].z - w[i - 1].z) ^ 2)
		if run <= 0 then
			add("waypoints %d and %d are on top of each other", i - 1, i)
		elseif math.abs(w[i].y - w[i - 1].y) / run > maxRise + 1e-6 then
			add("slope between waypoints %d and %d is %.1f deg (max %d)", i - 1, i, math.deg(math.atan(math.abs(w[i].y - w[i - 1].y) / run)), path.maxSlopeDeg)
		end
	end

	local b = path.bounds
	local first, last = w[1], w[#w]
	if first.z > b.minZ - path.shoulder or last.z < b.maxZ + path.shoulder then
		add("road should run at least `shoulder` (%d) studs past the south and north bounds edges", path.shoulder)
	end

	local half, inner = path.corridorWidth / 2, path.corridorWidth / 2 + path.buffer
	local gymZ = math.huge
	for _, box in path.keepClear do
		if box.name == path.gym then
			gymZ = box.minZ
		end
		if box.minX < b.minX or box.maxX > b.maxX or box.minZ < b.minZ or box.maxZ > b.maxZ then
			add("keep-clear box %s sticks out of the bounds", box.name)
		end
	end
	local spots = RegionPaths.trainerSpots(path)
	if #spots ~= #(path.trainerIds or {}) then
		add("found %d of %d trainer ids in GameData.RouteTrainers", #spots, #(path.trainerIds or {}))
	end
	for _, s in spots do
		local d = RegionPaths.nearest(path, s.x, s.z)
		if d > inner then
			add("trainer %s is %.1f studs from the road, outside the verge (%d)", s.id, d, inner)
		elseif d < half + 2 then
			add("trainer %s stands on the road (%.1f studs from the centre)", s.id, d)
		end
		if s.z >= gymZ then
			add("trainer %s is not before the gym", s.id)
		end
		if s.x < b.minX or s.x > b.maxX or s.z < b.minZ or s.z > b.maxZ then
			add("trainer %s is outside the bounds", s.id)
		end
	end

	local expect = 0
	for _, z in path.zones do
		if math.abs(z.from - expect) > 1e-6 then
			add("zone %s starts at %.2f, expected %.2f", z.name, z.from, expect)
		end
		if z.to <= z.from then
			add("zone %s is empty", z.name)
		end
		expect = z.to
	end
	if math.abs(expect - 1) > 1e-6 then
		add("zones end at %.2f, expected 1", expect)
	end

	local ridge = path.boundary
	if ridge.minWall > ridge.height * 0.8 then
		add("boundary.minWall (%d) is above 80%% of the ridge height (%d); the jagged top would fail it", ridge.minWall, ridge.height)
	end
	if ridge.width * 2 >= (b.maxX - b.minX) then
		add("boundary ridges from both sides meet in the middle")
	end
	return problems
end

return RegionPaths
