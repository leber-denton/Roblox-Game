--[[
	RegionTerrainBuilder: writes one region's Terrain from ReplicatedStorage.Shared.RegionPaths.
	Theming Overhaul Phase A1. Studio only; run in the command bar in Edit mode:

	  local B = require(game.ServerStorage.RegionTerrainBuilder)
	  B.preview("Lane1")                  -- dry run: bounds, heights, what would be buried. Changes nothing.
	  B.build("Lane1")                    -- snapshot the area, then write the new terrain
	  B.build("Lane1", { stashGround = true })  -- also moves the old flat ground parts there into the backup
	  B.restore("Lane1")                  -- puts back the newest snapshot (call again to step back further)
	  B.snapshots("Lane1")                -- lists the saved snapshots

	Then check the result with ServerStorage.RegionPathValidator.validate("Lane1").

	What it touches:
	  * Terrain inside the region's `bounds`, from floorY up to `clearAbove` studs over the road. Everything
	    in that box is replaced: new ground below the designed height, air above it.
	  * Before writing, that box is copied to ServerStorage.RegionTerrainBackups as a TerrainRegion, so
	    restore() can paste it back exactly. Snapshots are kept until restore() uses them.
	  * With stashGround, flat ground parts that lie completely inside the bounds are moved into the same
	    backup folder (never deleted) and restore() puts them back.
	  * Decor (path.decor, under Workspace.Map.Decor) that stands in the road or verge is shifted to the
	    nearest free spot inside the region's walls, never deleted. preview() lists every move; build()
	    records each old position in the snapshot and restore() moves them back.
	  * Parts and models are never moved or edited otherwise. Visible anchored parts in the bounds are
	    protected: the ground under and around each one is held at or below its bottom, so nothing gets
	    buried. Flat ground slabs (thin and wide, top near the road) and invisible parts are not protected.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local RegionPaths = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RegionPaths"))

local Builder = {}

local VOXEL = 4
local BACKUP_FOLDER = "RegionTerrainBackups"
local PROTECT_RADIUS = 12 -- studs around a protected part over which the ground may rise again
local PROTECT_RISE = 1 -- studs of rise per stud of distance (45 degrees)
local CLEAR_ABOVE = 110 -- default: studs above the highest road point that the write box reaches
-- Smooth terrain puts the surface about half a voxel above "bottom of the top voxel + occupancy * 4"
-- (measured in the place 2026-11-10: designed 0.4 came out at 2.41, and the same +2 held up to y 60),
-- so voxels are written for (height - SURFACE_OFFSET).
local SURFACE_OFFSET = 2

local function log(fmt, ...)
	print("[RegionTerrain] " .. (fmt):format(...))
end

local function getPath(laneKey: string)
	local path = RegionPaths.get(laneKey)
	assert(path, ("RegionPaths has no data for %s"):format(tostring(laneKey)))
	local problems = RegionPaths.check(path)
	if #problems > 0 then
		for _, p in problems do
			warn("[RegionTerrain] data: " .. p)
		end
		error(("RegionPaths.%s has %d data problem(s); fix them first"):format(laneKey, #problems))
	end
	return path
end

local function snap(v: number, down: boolean): number
	return if down then math.floor(v / VOXEL) * VOXEL else math.ceil(v / VOXEL) * VOXEL
end

-- The voxel-aligned box the builder writes
local function writeBox(path)
	local b = path.bounds
	local top = -math.huge
	for _, w in path.waypoints do
		top = math.max(top, w.y)
	end
	local minY = snap(path.floorY, true)
	local maxY = snap(top + (path.clearAbove or CLEAR_ABOVE), false)
	return Vector3.new(snap(b.minX, true), minY, snap(b.minZ, true)), Vector3.new(snap(b.maxX, false), maxY, snap(b.maxZ, false))
end

local function fullName(inst: Instance): string
	return inst:GetFullName()
end

-- World-space axis-aligned box of a part
local function partAABB(part: BasePart): (Vector3, Vector3)
	local cf, half = part.CFrame, part.Size / 2
	local r = cf - cf.Position
	local ex = (r * Vector3.new(half.X, 0, 0))
	local ey = (r * Vector3.new(0, half.Y, 0))
	local ez = (r * Vector3.new(0, 0, half.Z))
	local extent = Vector3.new(
		math.abs(ex.X) + math.abs(ey.X) + math.abs(ez.X),
		math.abs(ex.Y) + math.abs(ey.Y) + math.abs(ez.Y),
		math.abs(ex.Z) + math.abs(ey.Z) + math.abs(ez.Z)
	)
	return cf.Position - extent, cf.Position + extent
end

local function isCharacterPart(part: BasePart): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if Players:GetPlayerFromCharacter(model) then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

-- "Map.Decor" -> workspace.Map.Decor (nil if any step is missing)
local function resolve(dotted: string): Instance?
	local inst: Instance? = workspace
	for name in dotted:gmatch("[^%.]+") do
		inst = inst and inst:FindFirstChild(name)
	end
	return inst
end

-- Old ground: listed in path.groundParts, or a flat slab (thin, wide, top near the road). Not protected.
local function isGroundSlab(path, part: BasePart, lo: Vector3, hi: Vector3, roadTop: number): boolean
	-- features (sea, lava, pools, piers) are kept and protected, never treated as old floor
	for _, keep in path.keepParts or {} do
		if part.Name:find(keep, 1, true) then
			return false
		end
	end
	for _, name in path.groundParts or { "Map.RoadGround" } do
		local inst = resolve(name)
		if inst and (part == inst or part:IsDescendantOf(inst)) then
			return true
		end
	end
	local sizeY = hi.Y - lo.Y
	local area = (hi.X - lo.X) * (hi.Z - lo.Z)
	return sizeY <= 6 and area >= 400 and hi.Y <= roadTop + 1.5
end

-- Sorts the parts in the bounds into: protected (keep ground below them), ground slabs, ignored
local function scanParts(path, lo: Vector3, hi: Vector3)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.Terrain, workspace.CurrentCamera }
	local center = (lo + hi) / 2
	local parts = workspace:GetPartBoundsInBox(CFrame.new(center), hi - lo, params)
	local roadTop = -math.huge
	for _, w in path.waypoints do
		roadTop = math.max(roadTop, w.y)
	end
	-- never protected or stashed: wild spawn zones (WildSpawner reads them) and invisible walls
	local skip = {}
	local map = workspace:FindFirstChild("Map")
	for _, name in { "Lanes", "Bounds" } do
		local f = map and map:FindFirstChild(name)
		if f then
			table.insert(skip, f)
		end
	end
	local protected, slabs = {}, {}
	for _, part in parts do
		if not part.Anchored or part.Transparency >= 0.95 or isCharacterPart(part) then
			continue
		end
		local skipped = false
		for _, f in skip do
			if part:IsDescendantOf(f) then
				skipped = true
				break
			end
		end
		if skipped then
			continue
		end
		local plo, phi = partAABB(part)
		local mid = (plo + phi) / 2
		local b = path.bounds
		if mid.X < b.minX or mid.X > b.maxX or mid.Z < b.minZ or mid.Z > b.maxZ then
			continue -- belongs to the next region (Boulder Pass's Hill mesh reaches 70 studs underground)
		end
		-- outside the lane walls the boundary ridge wins: scenery there isn't protected (it stays embedded
		-- in the ridge as it was in the old cliffs). Generated routes set this; Meadow doesn't.
		if path.protectInsideOnly and math.abs(mid.X - (b.minX + b.maxX) / 2) > path.protectInsideOnly then
			continue
		end
		if isGroundSlab(path, part, plo, phi, roadTop) or plo.Y < roadTop - 4 then
			-- old ground, or a sunken mesh: protecting its bottom would dig a pit
			table.insert(slabs, { part = part, lo = plo, hi = phi })
		else
			table.insert(protected, { part = part, lo = plo, hi = phi })
		end
	end
	return protected, slabs
end

--[[
	Designed heights for every 4-stud column, with the protection caps applied.
	Returns a grid object: nx, nz, x0, z0 (world x/z of column 1's centre), h[i][k], plus per-column info.
]]
local function computeGrid(path, lo: Vector3, hi: Vector3, protected)
	local nx, nz = (hi.X - lo.X) / VOXEL, (hi.Z - lo.Z) / VOXEL
	local x0, z0 = lo.X + VOXEL / 2, lo.Z + VOXEL / 2
	local h, info, cap = table.create(nx), table.create(nx), table.create(nx)
	for i = 1, nx do
		h[i], info[i], cap[i] = table.create(nz), table.create(nz), table.create(nz, math.huge)
	end

	-- protection: the ground may not rise above a part's bottom (plus protectSink), then rises again around it
	local sink = path.protectSink or 0
	for _, p in protected do
		local i1 = math.max(1, math.floor((p.lo.X - PROTECT_RADIUS - lo.X) / VOXEL) + 1)
		local i2 = math.min(nx, math.floor((p.hi.X + PROTECT_RADIUS - lo.X) / VOXEL) + 1)
		local k1 = math.max(1, math.floor((p.lo.Z - PROTECT_RADIUS - lo.Z) / VOXEL) + 1)
		local k2 = math.min(nz, math.floor((p.hi.Z + PROTECT_RADIUS - lo.Z) / VOXEL) + 1)
		for i = i1, i2 do
			local x = x0 + (i - 1) * VOXEL
			local ox = math.max(p.lo.X - x, 0, x - p.hi.X)
			for k = k1, k2 do
				local z = z0 + (k - 1) * VOXEL
				local oz = math.max(p.lo.Z - z, 0, z - p.hi.Z)
				local out = math.sqrt(ox * ox + oz * oz)
				if out <= PROTECT_RADIUS then
					local c = p.lo.Y + sink + out * PROTECT_RISE
					if c < cap[i][k] then
						cap[i][k] = c
					end
				end
			end
		end
	end

	local capped, minH, maxH = 0, math.huge, -math.huge
	for i = 1, nx do
		local x = x0 + (i - 1) * VOXEL
		for k = 1, nz do
			local z = z0 + (k - 1) * VOXEL
			local height, kind, roadY, zone = RegionPaths.heightAt(path, x, z)
			if cap[i][k] < height then
				height = cap[i][k]
				capped += 1
			end
			-- never level with an old ground top (flicker): drop just under it
			for _, y in path.avoidY or {} do
				if math.abs(height - y) < 0.25 then
					height = y - 0.35
				end
			end
			height = math.clamp(height, lo.Y, hi.Y)
			h[i][k] = height
			info[i][k] = { kind = kind, roadY = roadY, zone = zone }
			minH, maxH = math.min(minH, height), math.max(maxH, height)
		end
	end
	return { nx = nx, nz = nz, x0 = x0, z0 = z0, h = h, info = info, capped = capped, minH = minH, maxH = maxH }
end

-- Steepness in degrees at a column, from its neighbours
local function slopeAt(grid, i: number, k: number): number
	local h = grid.h
	local il, ir = math.max(1, i - 1), math.min(grid.nx, i + 1)
	local kl, kr = math.max(1, k - 1), math.min(grid.nz, k + 1)
	local gx = (h[ir][k] - h[il][k]) / ((ir - il) * VOXEL)
	local gz = (h[i][kr] - h[i][kl]) / ((kr - kl) * VOXEL)
	if ir == il then
		gx = 0
	end
	if kr == kl then
		gz = 0
	end
	return math.deg(math.atan(math.sqrt(gx * gx + gz * gz)))
end

--[[
	Decor shifting. Every decor item that stands in the road or verge is moved sideways (or along the
	road if it must) to the nearest free spot inside path.decor.interior. An item is a Model that sits
	directly in a decor folder, or a cluster of loose parts in one folder that lie within clusterGap of
	each other (a flower, a fence run, a picnic). Nothing is deleted; build() records the old positions.
]]
local function boxOf(item): (Vector3, Vector3)
	if item.model then
		local cf, size = item.model:GetBoundingBox()
		return cf.Position - size / 2, cf.Position + size / 2
	end
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in item.parts do
		local plo, phi = partAABB(part)
		lo, hi = lo:Min(plo), hi:Max(phi)
	end
	return lo, hi
end

-- Smallest distance from a footprint rectangle to the road centreline (sampled every 2 studs)
local function rectRoadDistance(path, x1: number, z1: number, x2: number, z2: number): number
	local nx = math.max(1, math.ceil((x2 - x1) / 2))
	local nz = math.max(1, math.ceil((z2 - z1) / 2))
	local best = math.huge
	for a = 0, nx do
		local x = x1 + (x2 - x1) * a / nx
		for c = 0, nz do
			local d = RegionPaths.nearest(path, x, z1 + (z2 - z1) * c / nz)
			if d < best then
				best = d
			end
		end
	end
	return best
end

local function overlaps(a1, a2, b1, b2): boolean
	return a1.X < b2.X and a2.X > b1.X and a1.Z < b2.Z and a2.Z > b1.Z
end

local function shrink(lo: Vector3, hi: Vector3, f: number): (Vector3, Vector3)
	local c, half = (lo + hi) / 2, (hi - lo) / 2 * f
	return c - half, c + half
end

local function decorItems(path)
	local cfg = path.decor
	local root = cfg and resolve(cfg.root)
	if not root then
		return {}
	end
	local skip = {}
	for _, name in cfg.skipFolders or {} do
		skip[name] = true
	end
	if path.dressing then
		skip[path.dressing.folder] = true -- placed on purpose by RegionDecorator
	end
	local function skipped(folder: Instance): boolean
		local f: Instance? = folder
		while f and f ~= root do
			if skip[f.Name] then
				return true
			end
			f = f.Parent
		end
		return false
	end
	local folders = { root }
	for _, d in root:GetDescendants() do
		if d:IsA("Folder") then
			table.insert(folders, d)
		end
	end
	local items = {}
	local gap = cfg.clusterGap or 4
	for _, folder in folders do
		if skipped(folder) then
			continue
		end
		local loose = {}
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				table.insert(items, { model = child, name = folder.Name .. "/" .. child.Name })
			elseif child:IsA("BasePart") then
				local plo, phi = partAABB(child)
				table.insert(loose, { part = child, lo = plo, hi = phi })
			end
		end
		-- cluster loose parts (union-find on padded boxes)
		local parent = {}
		for i = 1, #loose do
			parent[i] = i
		end
		local function find(i)
			while parent[i] ~= i do
				parent[i] = parent[parent[i]]
				i = parent[i]
			end
			return i
		end
		local pad = Vector3.new(gap, 0, gap) / 2
		for i = 1, #loose do
			for j = i + 1, #loose do
				if overlaps(loose[i].lo - pad, loose[i].hi + pad, loose[j].lo - pad, loose[j].hi + pad) then
					parent[find(i)] = find(j)
				end
			end
		end
		local groups = {}
		for i, e in loose do
			local r = find(i)
			groups[r] = groups[r] or { parts = {}, name = folder.Name .. "/" .. e.part.Name }
			table.insert(groups[r].parts, e.part)
		end
		for _, g in groups do
			table.insert(items, g)
		end
	end
	for _, item in items do
		item.lo, item.hi = boxOf(item)
	end
	return items
end

local function itemWhere(item): string
	local c = (item.lo + item.hi) / 2
	return ("(%.0f, %.0f)"):format(c.X, c.Z)
end

-- Works out where each blocking decor item goes. Returns moves { item, offset } and blocked { item }.
local function planDecor(path)
	local cfg = path.decor
	if not cfg then
		return {}, {}, 0
	end
	local inner = path.corridorWidth / 2 + path.buffer
	local clear = inner + (cfg.margin or 0)
	local b, box = path.bounds, cfg.interior
	local items = decorItems(path)
	local inRegion = {}
	for _, item in items do
		local c = (item.lo + item.hi) / 2
		if c.X >= b.minX and c.X <= b.maxX and c.Z >= b.minZ and c.Z <= b.maxZ then
			table.insert(inRegion, item)
		end
	end
	-- footprints others must not land on (shrunk, so canopies may overlap)
	local f = cfg.overlapShrink or 0.4
	for _, item in inRegion do
		item.slo, item.shi = shrink(item.lo, item.hi, f)
	end
	local blocking = {}
	for _, item in inRegion do
		if rectRoadDistance(path, item.lo.X, item.lo.Z, item.hi.X, item.hi.Z) < clear then
			table.insert(blocking, item)
		end
	end
	table.sort(blocking, function(a, c)
		return (a.hi.X - a.lo.X) * (a.hi.Z - a.lo.Z) > (c.hi.X - c.lo.X) * (c.hi.Z - c.lo.Z)
	end)
	local offsets = {}
	local maxShift = cfg.maxShift or 80
	local maxAlong = cfg.maxShiftAlong or 48
	for dx = -maxShift, maxShift, 4 do
		for dz = -maxAlong, maxAlong, 4 do
			if dx ~= 0 or dz ~= 0 then
				table.insert(offsets, Vector3.new(dx, 0, dz))
			end
		end
	end
	table.sort(offsets, function(a, c)
		return a.X * a.X + (a.Z * 1.5) ^ 2 < c.X * c.X + (c.Z * 1.5) ^ 2
	end)
	local moves, blocked = {}, {}
	for _, item in blocking do
		local found
		for _, off in offsets do
			local lo, hi = item.lo + off, item.hi + off
			if lo.X < box.minX or hi.X > box.maxX or lo.Z < box.minZ or hi.Z > box.maxZ then
				continue
			end
			local ok = true
			for _, k in path.keepClear do
				local m = (k.margin or 0) + (cfg.margin or 0)
				if overlaps(lo, hi, Vector3.new(k.minX - m, 0, k.minZ - m), Vector3.new(k.maxX + m, 0, k.maxZ + m)) then
					ok = false
					break
				end
			end
			if ok then
				local slo, shi = item.slo + off, item.shi + off
				for _, other in inRegion do
					if other ~= item and overlaps(slo, shi, other.slo, other.shi) then
						ok = false
						break
					end
				end
			end
			if ok and rectRoadDistance(path, lo.X, lo.Z, hi.X, hi.Z) >= clear then
				found = off
				break
			end
		end
		if found then
			table.insert(moves, { item = item, offset = found, from = itemWhere(item) })
			-- later items must avoid where this one lands
			item.lo, item.hi = item.lo + found, item.hi + found
			item.slo, item.shi = item.slo + found, item.shi + found
		else
			table.insert(blocked, item)
		end
	end
	return moves, blocked, #inRegion
end

local function logDecorPlan(moves, blocked, total)
	log("decor: %d item(s) in the region, %d in the road or verge: %d get moved, %d have no free spot", total, #moves + #blocked, #moves, #blocked)
	for n = 1, math.min(25, #moves) do
		local m = moves[n]
		log("  move %s from %s by (%d, %d)", m.item.name, m.from, m.offset.X, m.offset.Z)
	end
	if #moves > 25 then
		log("  ...and %d more moves", #moves - 25)
	end
	for _, item in blocked do
		warn(("[RegionTerrain]   NO SPOT for %s at %s; move it by hand or the validator will flag it"):format(item.name, ("(%.0f, %.0f)"):format((item.lo.X + item.hi.X) / 2, (item.lo.Z + item.hi.Z) / 2)))
	end
end

-- Moves the planned items, recording each old position under `record` (a Folder in the snapshot)
local function applyDecor(moves, record: Instance)
	for _, m in moves do
		local insts = if m.item.model then { m.item.model } else m.item.parts
		for _, inst in insts do
			local tag = Instance.new("ObjectValue")
			tag.Name = "Moved"
			tag.Value = inst
			if inst:IsA("Model") then
				tag:SetAttribute("Orig", inst:GetPivot())
				inst:PivotTo(inst:GetPivot() + m.offset)
			else
				tag:SetAttribute("Orig", inst.CFrame)
				inst.CFrame += m.offset
			end
			tag.Parent = record
		end
	end
end

local function backupFolder(create: boolean): Folder?
	local folder = ServerStorage:FindFirstChild(BACKUP_FOLDER)
	if not folder and create then
		folder = Instance.new("Folder")
		folder.Name = BACKUP_FOLDER
		folder.Parent = ServerStorage
	end
	return folder
end

local function snapshotList(laneKey: string)
	local list = {}
	local folder = backupFolder(false)
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Folder") and child:GetAttribute("Lane") == laneKey then
				table.insert(list, child)
			end
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Seq") or 0) < (b:GetAttribute("Seq") or 0)
	end)
	return list
end

-- Dry run. Returns a summary table.
function Builder.preview(laneKey: string)
	local path = getPath(laneKey)
	local lo, hi = writeBox(path)
	local protected, slabs = scanParts(path, lo, hi)
	local grid = computeGrid(path, lo, hi, protected)
	local cells = grid.nx * grid.nz * ((hi.Y - lo.Y) / VOXEL)
	log("%s (%s) preview. Nothing changed.", laneKey, path.name)
	log("write box %s to %s: %d x %d columns, %d voxels", tostring(lo), tostring(hi), grid.nx, grid.nz, cells)
	log("ground height %.1f to %.1f; %d columns held down under existing parts", grid.minH, grid.maxH, grid.capped)
	log("%d protected part(s), %d flat ground slab(s) in the bounds (counted before decor moves)", #protected, #slabs)
	local moves, blocked, total = planDecor(path)
	logDecorPlan(moves, blocked, total)

	-- the protected parts that hold the ground down the most (they'd have been buried)
	local held = {}
	for _, p in protected do
		local cx, cz = (p.lo.X + p.hi.X) / 2, (p.lo.Z + p.hi.Z) / 2
		local designed = RegionPaths.heightAt(path, cx, cz)
		if designed > p.lo.Y + 1 then
			table.insert(held, { p = p, by = designed - p.lo.Y })
		end
	end
	table.sort(held, function(a, b)
		return a.by > b.by
	end)
	for n = 1, math.min(15, #held) do
		local e = held[n]
		log("  holds ground %.0f studs lower: %s", e.by, fullName(e.p.part))
	end
	if #held > 15 then
		log("  ...and %d more", #held - 15)
	end
	local inside = 0
	for _, s in slabs do
		local b = path.bounds
		if s.lo.X >= b.minX and s.hi.X <= b.maxX and s.lo.Z >= b.minZ and s.hi.Z <= b.maxZ then
			inside += 1
			if inside <= 10 then
				log("  ground slab (stashGround would move it): %s", fullName(s.part))
			end
		else
			log("  ground slab crossing the bounds edge (left alone): %s", fullName(s.part))
		end
	end
	return {
		lo = lo,
		hi = hi,
		protected = #protected,
		slabs = #slabs,
		held = #held,
		minH = grid.minH,
		maxH = grid.maxH,
		decorMoves = #moves,
		decorBlocked = #blocked,
	}
end

-- Writes the terrain. opts.stashGround moves the flat ground parts inside the bounds into the backup.
function Builder.build(laneKey: string, opts: { stashGround: boolean? }?)
	opts = opts or {}
	local path = getPath(laneKey)
	local terrain = workspace.Terrain
	local lo, hi = writeBox(path)

	-- 1. snapshot
	local folder = backupFolder(true)
	local list = snapshotList(laneKey)
	local seq = if #list > 0 then (list[#list]:GetAttribute("Seq") or 0) + 1 else 1
	local snapFolder = Instance.new("Folder")
	snapFolder.Name = ("%s #%d"):format(laneKey, seq)
	snapFolder:SetAttribute("Lane", laneKey)
	snapFolder:SetAttribute("Seq", seq)
	snapFolder:SetAttribute("Made", os.date("!%Y-%m-%d %H:%M UTC"))
	local corner = Vector3int16.new(lo.X / VOXEL, lo.Y / VOXEL, lo.Z / VOXEL)
	local far = Vector3int16.new(hi.X / VOXEL - 1, hi.Y / VOXEL - 1, hi.Z / VOXEL - 1)
	local region = terrain:CopyRegion(Region3int16.new(corner, far))
	region.Name = "Terrain"
	region.Parent = snapFolder
	snapFolder:SetAttribute("CornerX", corner.X)
	snapFolder:SetAttribute("CornerY", corner.Y)
	snapFolder:SetAttribute("CornerZ", corner.Z)
	snapFolder.Parent = folder
	log("snapshot saved: %s", fullName(snapFolder))

	-- 2. shift decor out of the road and verge (old positions go in the snapshot)
	local moves, blocked, total = planDecor(path)
	logDecorPlan(moves, blocked, total)
	local record = Instance.new("Folder")
	record.Name = "MovedDecor"
	record.Parent = snapFolder
	applyDecor(moves, record)

	-- 3. heights, protecting parts where they now stand
	local protected, slabs = scanParts(path, lo, hi)
	local grid = computeGrid(path, lo, hi, protected)

	-- 4. write the voxels, in slices along z
	local ny = (hi.Y - lo.Y) / VOXEL
	local air = Enum.Material.Air
	local SLICE = 32
	for kStart = 1, grid.nz, SLICE do
		local kEnd = math.min(grid.nz, kStart + SLICE - 1)
		local count = kEnd - kStart + 1
		local mats, occs = table.create(grid.nx), table.create(grid.nx)
		for i = 1, grid.nx do
			local mi, oi = table.create(ny), table.create(ny)
			for j = 1, ny do
				mi[j], oi[j] = table.create(count, air), table.create(count, 0)
			end
			for kk = 1, count do
				local k = kStart + kk - 1
				local height = grid.h[i][k]
				local cell = grid.info[i][k]
				local x, z = grid.x0 + (i - 1) * VOXEL, grid.z0 + (k - 1) * VOXEL
				local top = RegionPaths.materialAt(path, x, z, height, cell.kind, cell.roadY, cell.zone, slopeAt(grid, i, k))
				for j = 1, ny do
					local yb = lo.Y + (j - 1) * VOXEL
					local occ = math.clamp((height - SURFACE_OFFSET - yb) / VOXEL, 0, 1)
					if occ > 0 then
						oi[j][kk] = occ
						mi[j][kk] = if height - SURFACE_OFFSET - (yb + VOXEL) < VOXEL then top else cell.zone.under
					end
				end
			end
			mats[i], occs[i] = mi, oi
		end
		local zLo = lo.Z + (kStart - 1) * VOXEL
		local sliceRegion = Region3.new(Vector3.new(lo.X, lo.Y, zLo), Vector3.new(hi.X, hi.Y, zLo + count * VOXEL))
		terrain:WriteVoxels(sliceRegion, VOXEL, mats, occs)
	end
	log("%s terrain written: %d x %d columns, ground %.1f to %.1f, %d columns held under parts", laneKey, grid.nx, grid.nz, grid.minH, grid.maxH, grid.capped)

	-- 5. optionally move the old flat ground out of the way
	if opts.stashGround then
		local stash = Instance.new("Folder")
		stash.Name = "StashedGround"
		stash.Parent = snapFolder
		local b, moved = path.bounds, 0
		local function namedStash(part: BasePart): boolean
			for _, pattern in path.stashNames or {} do
				if part.Name:find(pattern) then
					return true
				end
			end
			return false
		end
		for _, s in slabs do
			local inside = s.lo.X >= b.minX and s.hi.X <= b.maxX and s.lo.Z >= b.minZ and s.hi.Z <= b.maxZ
			-- old floor stripes that poke a little past the bounds still go, if their middle is inside
			local mid = (s.lo + s.hi) / 2
			if not inside and namedStash(s.part) and mid.Z >= b.minZ and mid.Z <= b.maxZ and s.hi.Y - s.lo.Y <= 6 then
				inside = true
			end
			if inside then
				local home = Instance.new("ObjectValue")
				home.Name = "Home"
				home.Value = s.part.Parent
				home.Parent = s.part
				s.part.Parent = stash
				moved += 1
			end
		end
		log("moved %d flat ground part(s) into the snapshot", moved)
	end
	log("done. Next: require(game.ServerStorage.RegionPathValidator).validate(%q)", laneKey)
	return snapFolder
end

-- Puts back the newest snapshot for the region and removes it from the backups
function Builder.restore(laneKey: string)
	local list = snapshotList(laneKey)
	local snapFolder = list[#list]
	if not snapFolder then
		warn("[RegionTerrain] no snapshot for " .. laneKey)
		return false
	end
	local seq = snapFolder:GetAttribute("Seq") or 0
	local region = snapFolder:FindFirstChild("Terrain")
	assert(region and region:IsA("TerrainRegion"), "snapshot has no TerrainRegion")
	local corner = Vector3int16.new(snapFolder:GetAttribute("CornerX"), snapFolder:GetAttribute("CornerY"), snapFolder:GetAttribute("CornerZ"))
	workspace.Terrain:PasteRegion(region, corner, true)
	local movedBack = 0
	local record = snapFolder:FindFirstChild("MovedDecor")
	if record then
		for _, tag in record:GetChildren() do
			local inst = tag:IsA("ObjectValue") and tag.Value
			local orig = tag:GetAttribute("Orig")
			if inst and typeof(orig) == "CFrame" then
				if inst:IsA("Model") then
					inst:PivotTo(orig)
				elseif inst:IsA("BasePart") then
					inst.CFrame = orig
				end
				movedBack += 1
			end
		end
	end
	local stash = snapFolder:FindFirstChild("StashedGround")
	local returned = 0
	if stash then
		for _, part in stash:GetChildren() do
			local home = part:FindFirstChild("Home")
			if home and home:IsA("ObjectValue") and home.Value then
				part.Parent = home.Value
				home:Destroy()
				returned += 1
			else
				warn("[RegionTerrain] no home for stashed part " .. part.Name .. "; left in the snapshot")
			end
		end
	end
	if not stash or #stash:GetChildren() == 0 then
		snapFolder:Destroy()
	else
		snapFolder.Name ..= " (leftover parts)"
		snapFolder:SetAttribute("Lane", nil)
	end
	log("%s restored from snapshot #%d (%d decor instance(s) and %d ground part(s) put back)", laneKey, seq, movedBack, returned)
	return true
end

function Builder.snapshots(laneKey: string)
	local list = snapshotList(laneKey)
	for _, s in list do
		log("%s  made %s  stashed parts: %d", s.Name, tostring(s:GetAttribute("Made")), if s:FindFirstChild("StashedGround") then #s.StashedGround:GetChildren() else 0)
	end
	if #list == 0 then
		log("no snapshots for %s", laneKey)
	end
	return list
end

-- for the validator
Builder.writeBox = writeBox
Builder.scanParts = scanParts

return Builder
