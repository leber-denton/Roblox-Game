--[[
	RegionPathValidator: checks a built region against ReplicatedStorage.Shared.RegionPaths, and reads
	the place for the numbers RegionPaths needs. Theming Overhaul Phase A1. Studio command bar, Edit mode:

	  local V = require(game.ServerStorage.RegionPathValidator)
	  V.recon("Lane1")      -- read-only: prints what is in the place where the region goes (run this first)
	  V.validate("Lane1")   -- after RegionTerrainBuilder.build: PASS / WARN / FAIL lines and a RESULT line

	Copy the Output and paste it back to Claude. Neither function changes anything.

	validate() checks:
	  data       RegionPaths.check (slopes, trainer spots, zones)
	  road       ground under the full corridor width is at road height, nothing blocks the 10 studs above
	  slope      along the road and across it, no steeper than maxSlopeDeg
	  verge      the buffer beside the road is flat (route trainers stand there)
	  trainers   each trainer model stands on the ground, not buried and not floating
	  keepClear  no terrain inside the gym box
	  boundary   the ridge line all round is at least boundary.minWall over the road, except where the road
	             passes (and boundary.openings / keep-clear buildings, which are reported as WARN)
	  connect    the road meets the ground just past the south and north edges at the same height
	  spawns     wild spawn points (as WildSpawner picks them) find ground, the way Wander.groundAt does
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RegionPaths = require(Shared:WaitForChild("RegionPaths"))
local GameData = require(Shared:WaitForChild("GameData"))

local Validator = {}

local VOXEL = 4
local TOL_ROAD = 1.5
local TOL_VERGE = 2
local MAX_EXAMPLES = 5

local function fmtV(v: Vector3): string
	return ("(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z)
end

local function characters()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return list
end

-- What a player can stand on: terrain plus collidable parts
local function walkParams(extra: { Instance }?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = characters()
	for _, name in { "WildCreatures", "TutorialCreatures", "BattleAllies" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	-- route gates are force fields that open per player; they aren't ground (Overhaul Phase 2)
	local gates = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Gates")
	if gates then
		table.insert(ignore, gates)
	end
	for _, inst in extra or {} do
		table.insert(ignore, inst)
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	return params
end

local function terrainParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	return params
end

-- Same rules as Wander.groundAt: skips creatures, Map.Decor, Map.Bounds and base creatures
local function wanderParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = characters()
	for _, name in { "WildCreatures", "TutorialCreatures", "BattleAllies" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, name in { "Decor", "Bounds" } do
			if map:FindFirstChild(name) then
				table.insert(list, map[name])
			end
		end
		local bases = map:FindFirstChild("Bases")
		if bases then
			for _, base in bases:GetChildren() do
				if base:FindFirstChild("Creatures") then
					table.insert(list, base.Creatures)
				end
			end
		end
	end
	params.FilterDescendantsInstances = list
	return params
end

local function groundY(x: number, z: number, fromY: number, params: RaycastParams)
	local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -(fromY + 200), 0), params)
	if hit then
		return hit.Position.Y, hit.Instance, hit.Material
	end
	return nil, nil, nil
end

local function shortName(inst: Instance?): string
	if not inst then
		return "nothing"
	end
	if inst == workspace.Terrain then
		return "Terrain"
	end
	return (inst:GetFullName():gsub("^Workspace%.", ""))
end

local function inBox(box, x: number, z: number, pad: number?): boolean
	pad = pad or 0
	return x >= box.minX - pad and x <= box.maxX + pad and z >= box.minZ - pad and z <= box.maxZ + pad
end

local function inKeepClear(path, x: number, z: number, pad: number?)
	for _, box in path.keepClear do
		if inBox(box, x, z, pad) then
			return box
		end
	end
	return nil
end

-- One check's tally: status is the worst of its lines
local function newCheck(name: string)
	return { name = name, fails = 0, warns = 0, examples = {}, notes = {} }
end

local function fail(c, fmt, ...)
	c.fails += 1
	if #c.examples < MAX_EXAMPLES then
		table.insert(c.examples, "FAIL " .. (fmt):format(...))
	end
end

local function warnLine(c, fmt, ...)
	c.warns += 1
	if #c.examples < MAX_EXAMPLES * 2 then
		table.insert(c.examples, "WARN " .. (fmt):format(...))
	end
end

local function note(c, fmt, ...)
	table.insert(c.notes, (fmt):format(...))
end

local function report(laneKey: string, checks)
	local fails, warns = 0, 0
	print(("[RegionValidate] %s"):format(laneKey))
	for _, c in checks do
		local status = if c.fails > 0 then "FAIL" elseif c.warns > 0 then "WARN" else "PASS"
		print(("[RegionValidate] %-4s %-9s %s"):format(status, c.name, table.concat(c.notes, "; ")))
		for _, line in c.examples do
			print("[RegionValidate]        " .. line)
		end
		if c.fails > MAX_EXAMPLES then
			print(("[RegionValidate]        ...%d fails in all"):format(c.fails))
		end
		fails += c.fails
		warns += c.warns
	end
	local result = if fails > 0 then "FAIL" else "PASS"
	print(("[RegionValidate] RESULT %s: %d fail(s), %d warning(s)"):format(result, fails, warns))
	return fails == 0, fails, warns
end

function Validator.validate(laneKey: string)
	local path = RegionPaths.get(laneKey)
	assert(path, ("RegionPaths has no data for %s"):format(tostring(laneKey)))
	local checks = {}
	local half = path.corridorWidth / 2
	local inner = half + path.buffer
	local walk = walkParams()
	local trainerFolder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("RouteTrainers")
	local decorRoot = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
	local vergeIgnore = {}
	for _, inst in { trainerFolder, decorRoot } do
		if inst then
			table.insert(vergeIgnore, inst)
		end
	end
	local vergeRay = walkParams(vergeIgnore) -- trainers, fences and mushrooms stand on the verge; it's the ground that counts
	local terr = terrainParams()
	local b = path.bounds
	local length = RegionPaths.length(path)

	-- data
	local data = newCheck("data")
	for _, p in RegionPaths.check(path) do
		fail(data, "%s", p)
	end
	note(data, "%d waypoints, %.0f studs of road", #path.waypoints, length)
	table.insert(checks, data)

	-- road, slope, verge: walk the road every 4 studs, inside the bounds only
	local road, slope, verge = newCheck("road"), newCheck("slope"), newCheck("verge")
	local maxSlope = path.maxSlopeDeg
	local prevY, prevAlong
	local worstAlong, worstCross, samples = 0, 0, 0
	for along = 0, length, VOXEL do
		local x, y, z, ux, uz = RegionPaths.pointAt(path, along)
		if z < b.minZ or z > b.maxZ - 2 or inKeepClear(path, x, z) then
			prevY = nil
			continue
		end
		samples += 1
		local px, pz = uz, -ux -- sideways
		local edgeYs = {}
		for _, off in { -(half - 0.5), -half / 2, 0, half / 2, half - 0.5 } do
			local sx, sz = x + px * off, z + pz * off
			local gy, inst = groundY(sx, sz, y + 40, walk)
			if not gy then
				fail(road, "no ground at %s", fmtV(Vector3.new(sx, y, sz)))
			elseif math.abs(gy - y) > TOL_ROAD then
				fail(road, "ground %.1f studs off the road height at (%.0f, %.0f) [%s]", gy - y, sx, sz, shortName(inst))
			else
				local up = workspace:Raycast(Vector3.new(sx, gy + 0.5, sz), Vector3.new(0, 10, 0), walk)
				if up then
					fail(road, "blocked %.1f studs above the road at (%.0f, %.0f) by %s", up.Position.Y - gy, sx, sz, shortName(up.Instance))
				end
			end
			if gy then
				table.insert(edgeYs, gy)
			end
			if off == 0 and gy then
				if prevY and along > prevAlong then
					local deg = math.deg(math.atan(math.abs(gy - prevY) / (along - prevAlong)))
					worstAlong = math.max(worstAlong, deg)
					if deg > maxSlope + 0.5 then
						fail(slope, "%.1f deg along the road at z %.0f", deg, z)
					end
				end
				prevY, prevAlong = gy, along
			end
		end
		if #edgeYs >= 2 then
			local cross = math.deg(math.atan((math.max(table.unpack(edgeYs)) - math.min(table.unpack(edgeYs))) / path.corridorWidth))
			worstCross = math.max(worstCross, cross)
			if cross > maxSlope + 0.5 then
				fail(slope, "%.1f deg across the road at z %.0f", cross, z)
			end
		end
		for _, side in { -1, 1 } do
			for off = half + 2, inner, VOXEL do
				local sx, sz = x + px * off * side, z + pz * off * side
				-- verge spots outside the bounds belong to the neighbouring lane (the shared junction road
				-- runs diagonally round the previous gym)
				local bb = path.bounds
				if inKeepClear(path, sx, sz) or sz < bb.minZ or sz > bb.maxZ then
					continue
				end
				local gy, inst = groundY(sx, sz, y + 40, vergeRay)
				if not gy or math.abs(gy - y) > TOL_VERGE then
					fail(verge, "verge at (%.0f, %.0f) is %s [%s]", sx, sz, if gy then ("%.1f off"):format(gy - y) else "missing", shortName(inst))
				end
			end
		end
	end
	note(road, "%d samples across %d studs", samples, path.corridorWidth)
	note(slope, "worst %.1f deg along, %.1f deg across (max %d)", worstAlong, worstCross, maxSlope)
	note(verge, "%d studs each side", path.buffer)
	table.insert(checks, road)
	table.insert(checks, slope)
	table.insert(checks, verge)

	-- trainers
	local trainers = newCheck("trainers")
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("RouteTrainers")
	for _, spot in RegionPaths.trainerSpots(path) do
		local model = folder and folder:FindFirstChild(spot.id)
		if not model then
			fail(trainers, "%s: no model Map.RouteTrainers.%s", spot.id, spot.id)
			continue
		end
		local cf, size = model:GetBoundingBox()
		local bottom = cf.Position.Y - size.Y / 2
		local p = model:GetPivot().Position
		if math.abs(p.X - spot.x) > 2 or math.abs(p.Z - spot.z) > 2 then
			warnLine(trainers, "%s model is at (%.0f, %.0f) but data says (%.0f, %.0f)", spot.id, p.X, p.Z, spot.x, spot.z)
		end
		-- from head height, not the sky: a trainer inside a cave stands under its roof (Boulder Pass)
		local gy, inst = groundY(p.X, p.Z, bottom + 6, walkParams({ model }))
		if not gy then
			fail(trainers, "%s: no ground under the model", spot.id)
		elseif bottom < gy - 1.5 then
			fail(trainers, "%s: feet %.1f studs below the ground [%s]", spot.id, gy - bottom, shortName(inst))
		elseif bottom > gy + 1.5 then
			-- recon found the models' lowest part 2.8 above the old ground already; not the terrain's doing
			warnLine(trainers, "%s: lowest part %.1f studs above the ground [%s]", spot.id, bottom - gy, shortName(inst))
		end
		local buried = workspace:Raycast(Vector3.new(p.X, bottom + 0.5, p.Z), Vector3.new(0, 6, 0), terr)
		if buried then
			fail(trainers, "%s: terrain inside the model at %.1f", spot.id, buried.Position.Y)
		end
		note(trainers, "%s ok at (%.0f, %.0f)", spot.id, p.X, p.Z)
	end
	table.insert(checks, trainers)

	-- keep-clear boxes: no terrain inside
	local clear = newCheck("keepClear")
	for _, box in path.keepClear do
		local lo = Vector3.new(math.floor(box.minX / VOXEL) * VOXEL, math.floor((box.floorY + 1) / VOXEL) * VOXEL + VOXEL, math.floor(box.minZ / VOXEL) * VOXEL)
		local hi = Vector3.new(math.ceil(box.maxX / VOXEL) * VOXEL, lo.Y + 24, math.ceil(box.maxZ / VOXEL) * VOXEL)
		local _, occs = workspace.Terrain:ReadVoxels(Region3.new(lo, hi), VOXEL)
		local filled = 0
		local size = occs.Size
		for i = 1, size.X do
			for j = 1, size.Y do
				for k = 1, size.Z do
					if occs[i][j][k] > 0.1 then
						filled += 1
					end
				end
			end
		end
		if filled > 0 then
			fail(clear, "%s: %d terrain voxels above its floor", box.name, filled)
		end
		local model = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild(box.name)
		if model and model:IsA("Model") then
			local cf, sz = model:GetBoundingBox()
			local mlo, mhi = cf.Position - sz / 2, cf.Position + sz / 2
			if mlo.X < box.minX - 1 or mhi.X > box.maxX + 1 or mlo.Z < box.minZ - 1 or mhi.Z > box.maxZ + 1 then
				warnLine(clear, "%s model %s..%s sticks out of its keep-clear box", box.name, fmtV(mlo), fmtV(mhi))
			end
		elseif not model then
			warnLine(clear, "no Map.%s model found", box.name)
		end
		note(clear, "%s checked", box.name)
	end
	table.insert(checks, clear)

	-- boundary: ridge line just inside the bounds on each ridge side (away from the tapered ends),
	-- then a sideways ray from the road each way that must hit a wall before leaving the bounds
	local boundary = newCheck("boundary")
	local ridge = path.boundary
	local sides = ridge.sides or { west = true, east = true, south = true, north = true }
	local inset = ridge.width * 0.2
	local taper = ridge.endTaper or 0
	local z1, z2 = b.minZ + (if sides.south then inset else taper), b.maxZ - (if sides.north then inset else taper)
	local x1, x2 = b.minX + (if sides.west then inset else taper), b.maxX - (if sides.east then inset else taper)
	local ring = {}
	if sides.south or sides.north then
		for x = x1, x2, 8 do
			if sides.south then
				table.insert(ring, { x, b.minZ + inset })
			end
			if sides.north then
				table.insert(ring, { x, b.maxZ - inset })
			end
		end
	end
	for z = z1, z2, 8 do
		if sides.west then
			table.insert(ring, { b.minX + inset, z })
		end
		if sides.east then
			table.insert(ring, { b.maxX - inset, z })
		end
	end
	local open = 0
	local decorFolder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
	local wallRay = walkParams(if decorFolder then { decorFolder } else nil) -- trees don't count as a wall
	for along = 0, length, 16 do
		local x, y, z = RegionPaths.pointAt(path, along)
		if z < b.minZ + 4 or z > b.maxZ - 4 then
			continue
		end
		for _, dir in { -1, 1 } do
			local reach = (if dir < 0 then x - b.minX else b.maxX - x)
			local hit = workspace:Raycast(Vector3.new(x, y + 5, z), Vector3.new(dir * reach, 0, 0), wallRay)
			if not hit then
				open += 1
				fail(boundary, "nothing stops a walker going %s from the road at z %.0f", if dir < 0 then "west" else "east", z)
			end
		end
	end
	note(boundary, "sideways from the road: %d open", open)
	local roadGaps, lowest = 0, math.huge
	for _, pt in ring do
		local x, z = pt[1], pt[2]
		local d, _, roadY = RegionPaths.nearest(path, x, z)
		if d <= inner + path.shoulder then
			roadGaps += 1
			continue
		end
		local gy = groundY(x, z, roadY + ridge.height + 100, terr)
		local over = if gy then gy - roadY else -math.huge
		lowest = math.min(lowest, over)
		if over >= ridge.minWall then
			continue
		end
		local box = inKeepClear(path, x, z, 4)
		if box then
			warnLine(boundary, "gap at (%.0f, %.0f) is covered by %s, check the building closes it", x, z, box.name)
		elseif RegionPaths.inOpening(path, x, z) then
			warnLine(boundary, "allowed opening at (%.0f, %.0f)", x, z)
		else
			fail(boundary, "ridge only %.1f studs over the road at (%.0f, %.0f) (want %d)", over, x, z, ridge.minWall)
		end
	end
	note(boundary, "%d ring samples, %d at the road cut, lowest ridge %.1f over the road", #ring, roadGaps, lowest)
	table.insert(checks, boundary)

	-- connect: road meets the ground past both ends
	local connect = newCheck("connect")
	local firstWp, lastWp = path.waypoints[1], path.waypoints[#path.waypoints]
	for _, endZ in { b.minZ - 12, b.maxZ + 12 } do
		local x = if endZ < b.minZ then firstWp.x else lastWp.x
		local _, _, roadY = RegionPaths.nearest(path, x, endZ)
		local gy, inst = groundY(x, endZ, roadY + 40, walk)
		if not gy then
			fail(connect, "no ground just past the edge at (%.0f, %.0f)", x, endZ)
		elseif math.abs(gy - roadY) > TOL_VERGE then
			fail(connect, "ground at (%.0f, %.0f) is %.1f off the road end [%s]", x, endZ, gy - roadY, shortName(inst))
		else
			note(connect, "z %.0f meets %s", endZ, shortName(inst))
		end
	end
	table.insert(checks, connect)

	-- spawns: same maths as WildSpawner.spawnInLane, ground like Wander.groundAt
	local spawns = newCheck("spawns")
	local lane = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Lanes") and workspace.Map.Lanes:FindFirstChild(path.lane)
	if not lane or not lane:IsA("BasePart") then
		fail(spawns, "no spawn zone part Map.Lanes.%s", path.lane)
	else
		local halfX = lane.Size.X / 2 - 10
		local startZ = lane.Position.Z - lane.Size.Z / 2 + 20
		local len = lane.Size.Z - 60
		local y = lane.Position.Y + lane.Size.Y / 2
		local wp = wanderParams()
		for _, depth in { 0, 0.35, 0.65, 1 } do
			for _, side in { -1, 0, 1 } do
				local pos = Vector3.new(lane.Position.X + side * halfX, y, startZ + depth * len)
				local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), wp)
				if not hit then
					fail(spawns, "depth %.2f x %.0f: Wander.groundAt finds nothing", depth, pos.X)
				elseif hit.Position.Y - y > 30 then
					warnLine(spawns, "depth %.2f x %.0f: ground %.0f studs over the zone top (inside a hill?)", depth, pos.X, hit.Position.Y - y)
				end
			end
		end
		note(spawns, "zone %s size %s, %d config entries", fmtV(lane.Position), fmtV(lane.Size), #(GameData.Lanes[path.lane] and GameData.Lanes[path.lane].spawns or {}))
	end
	table.insert(checks, spawns)

	return report(laneKey, checks)
end

-- Read-only survey of the place where the region goes. Paste the output back to Claude.
function Validator.recon(laneKey: string)
	local path = RegionPaths.get(laneKey)
	assert(path, ("RegionPaths has no data for %s"):format(tostring(laneKey)))
	local function out(fmt, ...)
		print("[RegionRecon] " .. (fmt):format(...))
	end
	local b = path.bounds
	local map = workspace:FindFirstChild("Map")
	out("%s (%s) bounds x %d..%d z %d..%d", laneKey, path.name, b.minX, b.maxX, b.minZ, b.maxZ)
	if not map then
		out("no Workspace.Map!")
		return
	end
	local names = {}
	for _, c in map:GetChildren() do
		table.insert(names, c.Name)
	end
	table.sort(names)
	out("Map children: %s", table.concat(names, ", "))

	-- spawn zones
	local lanes = map:FindFirstChild("Lanes")
	for _, key in { path.lane, "Lane1B" } do
		local lane = lanes and lanes:FindFirstChild(key)
		if lane and lane:IsA("BasePart") then
			out("Lanes.%s pos %s size %s transp %.2f collide %s query %s unlocked %s", key, fmtV(lane.Position), fmtV(lane.Size), lane.Transparency, tostring(lane.CanCollide), tostring(lane.CanQuery), tostring(lane:GetAttribute("Unlocked")))
		else
			out("Lanes.%s: %s", key, if lane then lane.ClassName else "missing")
		end
	end

	-- gym and other keep-clear models
	for _, box in path.keepClear do
		local model = map:FindFirstChild(box.name)
		if model and model:IsA("Model") then
			local cf, size = model:GetBoundingBox()
			out("%s box %s .. %s (pivot %s)", box.name, fmtV(cf.Position - size / 2), fmtV(cf.Position + size / 2), fmtV(model:GetPivot().Position))
		else
			out("%s: %s", box.name, if model then model.ClassName else "missing")
		end
	end

	-- trainers
	local rt = map:FindFirstChild("RouteTrainers")
	for _, spot in RegionPaths.trainerSpots(path) do
		local model = rt and rt:FindFirstChild(spot.id)
		if model then
			local cf, size = model:GetBoundingBox()
			out("trainer %s data (%.0f, %.0f) model pivot %s feet %.1f HomePos %s", spot.id, spot.x, spot.z, fmtV(model:GetPivot().Position), cf.Position.Y - size.Y / 2, tostring(model:GetAttribute("HomePos")))
		else
			out("trainer %s data (%.0f, %.0f): no model", spot.id, spot.x, spot.z)
		end
	end

	-- ground along the centre line, past both ends
	local walk = walkParams()
	local line = {}
	for z = b.minZ - 60, b.maxZ + 60, 26 do
		local gy, inst, mat = groundY(0, z, 300, walk)
		table.insert(line, ("z%d=%s %s/%s"):format(z, if gy then ("%.1f"):format(gy) else "-", shortName(inst), if mat then mat.Name else "-"))
		if #line == 4 then
			out("centre %s", table.concat(line, " | "))
			line = {}
		end
	end
	if #line > 0 then
		out("centre %s", table.concat(line, " | "))
	end

	-- ground across the region at three depths
	for _, depth in { 0.1, 0.5, 0.9 } do
		local z = b.minZ + depth * (b.maxZ - b.minZ)
		local row = {}
		for x = b.minX, b.maxX, 20 do
			local gy, inst = groundY(x, z, 300, walk)
			table.insert(row, ("%d:%s%s"):format(x, if gy then ("%.0f"):format(gy) else "-", if inst == workspace.Terrain then "T" elseif inst then "P" else ""))
		end
		out("across z %.0f (T terrain, P part): %s", z, table.concat(row, " "))
	end

	-- existing terrain in the box the builder would write
	local okBuilder, Builder = pcall(require, ServerStorage:FindFirstChild("RegionTerrainBuilder"))
	if okBuilder then
		local lo, hi = Builder.writeBox(path)
		local _, occs = workspace.Terrain:ReadVoxels(Region3.new(lo, hi), VOXEL)
		local size = occs.Size
		local filled, topY = 0, -math.huge
		for i = 1, size.X do
			for j = 1, size.Y do
				for k = 1, size.Z do
					if occs[i][j][k] > 0.1 then
						filled += 1
						topY = math.max(topY, lo.Y + (j - 1) * VOXEL)
					end
				end
			end
		end
		out("terrain in write box %s..%s: %d filled voxels, highest at %s", fmtV(lo), fmtV(hi), filled, if filled > 0 then tostring(topY) else "-")

		-- parts in the bounds, grouped by their first two folders
		local protected, slabs = Builder.scanParts(path, lo, hi)
		local groups = {}
		for _, list in { { "protected", protected }, { "slab", slabs } } do
			for _, e in list[2] do
				local key = list[1] .. " " .. (shortName(e.part):match("^([^%.]+%.?[^%.]*)") or "?")
				groups[key] = (groups[key] or 0) + 1
			end
		end
		local keys = {}
		for k in groups do
			table.insert(keys, k)
		end
		table.sort(keys)
		for _, k in keys do
			out("parts %s: %d", k, groups[k])
		end
		table.sort(slabs, function(a, c)
			return (a.hi.X - a.lo.X) * (a.hi.Z - a.lo.Z) > (c.hi.X - c.lo.X) * (c.hi.Z - c.lo.Z)
		end)
		for n = 1, math.min(12, #slabs) do
			local s = slabs[n]
			out("slab %s x %.0f..%.0f z %.0f..%.0f top %.1f %s", shortName(s.part), s.lo.X, s.hi.X, s.lo.Z, s.hi.Z, s.hi.Y, s.part.Material.Name)
		end
	else
		out("RegionTerrainBuilder not found in ServerStorage (is Rojo synced?)")
	end
	out("data check: %s", if #RegionPaths.check(path) == 0 then "ok" else table.concat(RegionPaths.check(path), "; "))
	out("done")
end

return Validator
