--!nocheck
-- RouteWalker: read-only road audit and validation gate for every route in Region 1 and Region 2.
-- Studio tool (Edit mode). Command bar:
--   local W = require(game.ServerStorage.RouteWalker)
--   print(W.report(W.walk("Lane9")))       -- one route
--   print(W.summary(W.walkAll()))           -- every route, one line each
-- From MCP execute_luau (which can't require): loadstring(game.ServerStorage.RouteWalker.Source)()
--
-- What it does for one route: walks the road centreline (RegionPaths waypoints when the lane has them,
-- otherwise the straight lane line, detouring around the gym) in STEP-stud steps with downward rays and reports
--   GAP       no ground under the road, or ground far below it (void)
--   JUMP      ground height changes more than MAX_JUMP between steps
--   BLOCKED   something solid at chest height in the walking direction, or no head room
--   MOUNTAIN  terrain over the road (ROOF: a part over the road, e.g. a cave or arch)
--   COVER     cross-section ground inside the corridor more than COVER_ABOVE over the road (hills filling the lane)
--   VOID      an eye-level sightline to the side or ahead escapes 600 studs without hitting anything
--   LAYER     a ground part with terrain poking up through it, or a part floating over a different terrain material
--   FLOAT / BURIED  route trainers and gym leaders whose feet are off the ground
--   DEADEND   the walk can't reach the far end of the lane (first BLOCKED/GAP run that never clears)
-- Everything is a plain table, so the same walk is the phase-2 validation gate (W.gate(result) -> pass, reasons).

local RouteWalker = {}

local STEP = 4
local MAX_JUMP = 2.5 -- studs per 4-stud step (~32 degrees)
local COVER_ABOVE = 15
local CLEAR_HEAD = 7
local CORRIDOR_HALF = 55 -- cross-section samples stay inside the 130-wide lane

-- Lane order and geometry, from GameData.Arms / RoadOffsets (520-stud lanes).
local R1 = { "Lane1", "Lane1B", "Lane3", "Lane4", "Lane2", "Lane5", "Lane6", "Lane7" }
local R2 = { "Lane9", "Lane10", "Lane11", "Lane12", "Lane13", "Lane14", "Lane15", "Lane16" }
local NAMES = {
	Lane1 = "Meadow Route", Lane1B = "Boulder Pass", Lane3 = "Tide Coast", Lane4 = "Volt Plains", Lane2 = "Ember Ridge",
	Lane5 = "Frost Peak", Lane6 = "Shadow Woods", Lane7 = "Sky Spire",
	Lane9 = "Sunpetal Fields", Lane10 = "Mirage Desert", Lane11 = "Coral Reef", Lane12 = "Thunder Mesa",
	Lane13 = "Toxic Bog", Lane14 = "Crystal Caverns", Lane15 = "Phantom Manor", Lane16 = "Dragon Peaks",
}
local GYMS = {
	Lane1 = "MeadowGym", Lane1B = "BrookGym", Lane3 = "TideGym", Lane4 = "VoltGym", Lane2 = "EmberGym",
	Lane5 = "FrostGym", Lane6 = "ShadowGym", Lane7 = "SkyGym",
	Lane9 = "BloomGym", Lane10 = "MirageGym", Lane11 = "ReefGym", Lane12 = "MesaGym", Lane13 = "BogGym",
	Lane14 = "CrystalGym", Lane15 = "ManorGym", Lane16 = "PeakGym",
}

RouteWalker.ROUTES = {}
for i, lane in R1 do
	RouteWalker.ROUTES[lane] = { lane = lane, name = NAMES[lane], region = 1, x = 0, z0 = 250 + (i - 1) * 520, z1 = 250 + i * 520, gym = GYMS[lane] }
end
for i, lane in R2 do
	RouteWalker.ROUTES[lane] = { lane = lane, name = NAMES[lane], region = 2, x = 460, z0 = 300 + (i - 1) * 520, z1 = 300 + i * 520, gym = GYMS[lane] }
end
RouteWalker.ORDER = table.clone(R1)
for _, l in R2 do
	table.insert(RouteWalker.ORDER, l)
end

local function regionPaths()
	local mod = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
	mod = mod and mod:FindFirstChild("RegionPaths")
	if not mod then
		return nil
	end
	local ok, rp = pcall(function()
		return loadstring(mod.Source)()
	end)
	return ok and rp or nil
end

local function exclusions()
	local map = workspace:FindFirstChild("Map")
	local list = {}
	for _, n in { "Bounds", "Gates", "RouteTrainers", "MountainHints" } do
		local f = map and map:FindFirstChild(n)
		if f then
			table.insert(list, f)
		end
	end
	for _, p in game:GetService("Players"):GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	-- NPC rigs inside gyms (they stand on the floor; they aren't floor)
	if map then
		for _, m in map:GetChildren() do
			if m:IsA("Model") and m.Name:match("Gym$") then
				for _, c in m:GetChildren() do
					if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then
						table.insert(list, c)
					end
				end
			end
		end
	end
	return list
end

local function params(extra)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local ex = exclusions()
	for _, e in extra or {} do
		table.insert(ex, e)
	end
	p.FilterDescendantsInstances = ex
	p.RespectCanCollide = true
	return p
end

local function matName(r)
	if not r then
		return "none"
	end
	if r.Instance:IsA("Terrain") then
		return "T:" .. r.Material.Name
	end
	return "P:" .. r.Material.Name
end

-- Road centreline points for a route.
function RouteWalker.path(lane, sideOverride)
	local route = RouteWalker.ROUTES[lane]
	local rp = regionPaths()
	local entry = rp and rp[lane]
	local pts = {}
	if entry and entry.waypoints then
		local wps = entry.waypoints
		for i = 1, #wps - 1 do
			local a, b = wps[i], wps[i + 1]
			local A, B = Vector3.new(a.x or a[1], 0, a.z or a[3]), Vector3.new(b.x or b[1], 0, b.z or b[3])
			local n = math.max(1, math.floor((B - A).Magnitude / STEP))
			for k = 0, n - 1 do
				local p = A:Lerp(B, k / n)
				if p.Z >= route.z0 - 2 and p.Z <= route.z1 + 2 then
					table.insert(pts, p)
				end
			end
		end
		return pts, "RegionPaths"
	end
	-- straight lane line, swinging round the gym (side = 1 east, -1 west)
	local gym = workspace.Map:FindFirstChild(route.gym or "")
	local gcf, gsz
	if gym then
		gcf, gsz = gym:GetBoundingBox()
	end
	local side = sideOverride or 1
	for z = route.z0 + 2, route.z1 - 2, STEP do
		local x = route.x
		if gcf then
			local half = gsz.Z / 2 + 8
			local dz = math.abs(z - gcf.Z)
			if dz < half + 16 then
				local off = gsz.X / 2 + 8
				local t = dz < half and 1 or (1 - (dz - half) / 16)
				x = route.x + side * off * math.clamp(t, 0, 1)
			end
		end
		table.insert(pts, Vector3.new(x, 0, z))
	end
	return pts, side > 0 and "straight, east of gym" or "straight, west of gym"
end

function RouteWalker.gymBox(lane)
	local route = RouteWalker.ROUTES[lane]
	local gym = workspace.Map:FindFirstChild(route.gym or "")
	if not gym then
		return nil
	end
	local cf, sz = gym:GetBoundingBox()
	return cf.Position, sz
end

local function median(t)
	local c = table.clone(t)
	table.sort(c)
	return c[math.max(1, math.floor(#c / 2))] or 0
end

local function npcFeet(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local lowest = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
			local cf, s = d.CFrame, d.Size
			-- lowest corner of the oriented box
			local h = math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
			lowest = math.min(lowest, cf.Y - h)
		end
	end
	local rigFeet = (hum and hrp) and (hrp.Position.Y - hrp.Size.Y / 2 - hum.HipHeight) or lowest
	return lowest, rigFeet
end

local function checkNpc(model, issues)
	local pos = model:GetPivot().Position
	local r = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params({ model }))
	if not r then
		table.insert(issues, { kind = "FLOAT", z = pos.Z, x = pos.X, detail = model:GetFullName() .. " has no ground within 60 studs" })
		return
	end
	local lowest = npcFeet(model)
	local gap = lowest - r.Position.Y
	if gap > 0.6 then
		table.insert(issues, { kind = "FLOAT", z = pos.Z, x = pos.X, detail = ("%s feet %.1f studs above %s"):format(model:GetFullName(), gap, matName(r)) })
	elseif gap < -1.5 then
		table.insert(issues, { kind = "BURIED", z = pos.Z, x = pos.X, detail = ("%s feet %.1f studs under %s"):format(model:GetFullName(), -gap, matName(r)) })
	end
end

-- Ray that skips see-through parts (glass dividers, invisible zones), up to 6 of them.
local function solidRay(origin, dir, p)
	local extra = {}
	for _ = 1, 6 do
		local r = workspace:Raycast(origin, dir, p)
		if not r or r.Instance:IsA("Terrain") or r.Instance.Transparency < 0.3 then
			return r
		end
		table.insert(extra, r.Instance)
		p = params(extra)
	end
	return nil
end

local function inBox(x, z, c, s, pad)
	return c and math.abs(x - c.X) < s.X / 2 + pad and math.abs(z - c.Z) < s.Z / 2 + pad
end

-- One walk along a list of points. Returns samples, issues.
local function walkPoints(route, pts, p)
	local issues, samples = {}, {}
	local first = solidRay(Vector3.new(pts[1].X, 40, pts[1].Z), Vector3.new(0, -80, 0), p)
	local prevY = first and first.Position.Y or 0
	local blockedRun, lastGood = 0, nil
	for i, pt in pts do
		-- the foothold a walker would find: down from just above where they last stood
		local r = solidRay(Vector3.new(pt.X, prevY + 6, pt.Z), Vector3.new(0, -40, 0), p)
		local s = { x = pt.X, z = pt.Z, y = r and r.Position.Y or nil, mat = matName(r) }
		table.insert(samples, s)
		local bad = false
		if not r or r.Position.Y < prevY - 12 then
			table.insert(issues, { kind = "GAP", z = s.z, x = s.x, detail = r and ("drop of %.0f to %s"):format(prevY - r.Position.Y, s.mat) or "no ground within 40 studs (void)" })
			bad = true
		else
			if r.Position.Y - prevY > MAX_JUMP then
				table.insert(issues, { kind = "JUMP", z = s.z, x = s.x, detail = ("up %.1f -> %.1f (%s)"):format(prevY, s.y, s.mat) })
				bad = r.Position.Y - prevY > 5
			elseif prevY - r.Position.Y > MAX_JUMP then
				table.insert(issues, { kind = "JUMP", z = s.z, x = s.x, detail = ("down %.1f -> %.1f (%s)"):format(prevY, s.y, s.mat) })
			end
			-- head room
			local up = solidRay(Vector3.new(s.x, s.y + 0.3, s.z), Vector3.new(0, CLEAR_HEAD, 0), p)
			if up then
				table.insert(issues, { kind = "BLOCKED", z = s.z, x = s.x, detail = "no head room: " .. (up.Instance:IsA("Terrain") and ("terrain " .. up.Material.Name) or up.Instance:GetFullName()) })
				bad = true
			end
			-- anything over the road at all (mountain, cave roof, overhang)
			local sky = solidRay(Vector3.new(s.x, 300, s.z), Vector3.new(0, -(300 - s.y - CLEAR_HEAD), 0), p)
			if sky and sky.Position.Y > s.y + CLEAR_HEAD then
				local what = sky.Instance:IsA("Terrain") and ("terrain " .. sky.Material.Name) or sky.Instance:GetFullName()
				local isTree = not sky.Instance:IsA("Terrain") and (sky.Instance:GetFullName():lower():find("tree") or sky.Instance:GetFullName():lower():find("oak"))
				if not isTree then
					table.insert(issues, { kind = sky.Instance:IsA("Terrain") and "MOUNTAIN" or "ROOF", z = s.z, x = s.x, detail = ("%s %.0f studs over the road"):format(what, sky.Position.Y - s.y) })
				end
			end
			-- chest-height step from the last foothold
			local prev = samples[i - 1]
			if prev and prev.y then
				local from = Vector3.new(prev.x, prev.y + 2.5, prev.z)
				local to = Vector3.new(s.x, s.y + 2.5, s.z)
				local hit = solidRay(from, to - from, p)
				if hit then
					table.insert(issues, { kind = "BLOCKED", z = s.z, x = s.x, detail = "step blocked by " .. (hit.Instance:IsA("Terrain") and ("terrain " .. hit.Material.Name) or hit.Instance:GetFullName()) })
					bad = true
				end
			end
			prevY = r.Position.Y
		end
		if bad then
			blockedRun += 1
		else
			blockedRun = 0
			lastGood = s
		end
	end
	if blockedRun > 0 then
		table.insert(issues, { kind = "DEADEND", z = lastGood and lastGood.z or route.z0, x = lastGood and lastGood.x or route.x, detail = ("last %d steps to the lane end are blocked or missing"):format(blockedRun) })
	end
	return samples, issues
end

-- Walk one route. Returns { lane, name, base, samples, issues, materials, layers }
function RouteWalker.walk(lane)
	local route = assert(RouteWalker.ROUTES[lane], "unknown lane " .. tostring(lane))
	local p = params()
	-- try both sides of the gym; keep the cleaner walk
	local best
	for _, side in { 1, -1 } do
		local pts, source = RouteWalker.path(lane, side)
		local samples, issues = walkPoints(route, pts, p)
		local score = 0
		for _, i in issues do
			if i.kind ~= "MOUNTAIN" and i.kind ~= "ROOF" then
				score += 1
			end
		end
		if not best or score < best.score then
			best = { samples = samples, issues = issues, source = source, score = score }
		end
		if source == "RegionPaths" then
			break
		end
	end
	local samples, issues, source = best.samples, best.issues, best.source
	local heights, materials = {}, {}
	for _, s in samples do
		if s.y then
			table.insert(heights, s.y)
		end
		materials[s.mat] = (materials[s.mat] or 0) + 1
	end
	local base = median(heights)

	-- cross-sections every 40 studs: hills covering the lane, sightlines, ground layering
	local gc, gs = RouteWalker.gymBox(lane)
	local layers = {}
	local seen = {}
	for z = route.z0 + 20, route.z1 - 20, 40 do
		local cover = {}
		for dx = -CORRIDOR_HALF, CORRIDOR_HALF, 11 do
			local x = route.x + dx
			if not inBox(x, z, gc, gs, 4) then
				local r = solidRay(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), p)
				if r and r.Position.Y > base + COVER_ABOVE and (r.Instance:IsA("Terrain") or r.Instance.Size.Magnitude > 60) then
					table.insert(cover, ("%+d:%.0f"):format(dx, r.Position.Y - base))
				end
				-- layering: what is under a ground part?
				if r and not r.Instance:IsA("Terrain") then
					local under = workspace:Raycast(r.Position + Vector3.new(0, 0.05, 0), Vector3.new(0, -12, 0), params({ r.Instance }))
					if under and under.Instance:IsA("Terrain") then
						local key = ("P:%s over T:%s"):format(r.Material.Name, under.Material.Name)
						if r.Position.Y - under.Position.Y < 0.35 then
							key ..= " (flicker)"
						end
						layers[key] = (layers[key] or 0) + 1
					end
				elseif r then
					local above = workspace:Raycast(r.Position + Vector3.new(0, 3, 0), Vector3.new(0, -3.2, 0), params())
					if above and not above.Instance:IsA("Terrain") then
						local key = "T:" .. r.Material.Name .. " flush with " .. above.Instance.Name
						layers[key] = (layers[key] or 0) + 1
					end
				end
			end
		end
		if #cover > 0 then
			table.insert(issues, { kind = "COVER", z = z, x = route.x, detail = "hills over the lane at dx " .. table.concat(cover, " ") })
		end
		-- sightlines from eye height: world edge (VOID) and the other region (OTHER)
		local eye = Vector3.new(route.x, base + 6, z)
		for _, dir in { Vector3.new(1, -0.012, 0), Vector3.new(-1, -0.012, 0), Vector3.new(1, 0.02, 0), Vector3.new(-1, 0.02, 0), Vector3.new(0, -0.012, 1) } do
			local r = solidRay(eye, dir.Unit * 1200, p)
			local name = (dir.Z > 0 and "north") or (dir.X > 0 and "east" or "west")
			if not r and dir.Y < 0 then
				table.insert(issues, { kind = "VOID", z = z, x = route.x, detail = ("eye-level sightline %s escapes 1200 studs"):format(name) })
			elseif r then
				local hx = r.Position.X
				local other = (route.region == 1 and hx > 384) or (route.region == 2 and hx < 76)
				if other and not seen[name] then
					seen[name] = true
					table.insert(issues, { kind = "OTHER", z = z, x = route.x, detail = ("looking %s you see the other region (hit %s at x %.0f)"):format(name, r.Instance:IsA("Terrain") and ("terrain " .. r.Material.Name) or r.Instance:GetFullName(), hx) })
				end
			end
		end
	end

	-- NPCs: the three route trainers and the gym leader
	local map = workspace.Map
	local rt = map:FindFirstChild("RouteTrainers")
	local npcs = {}
	if rt then
		for _, m in rt:GetChildren() do
			local pos = m:GetPivot().Position
			if math.abs(pos.X - route.x) < 70 and pos.Z >= route.z0 and pos.Z < route.z1 then
				table.insert(npcs, m)
				checkNpc(m, issues)
			end
		end
	end
	local gym = map:FindFirstChild(route.gym or "")
	if gym then
		for _, c in gym:GetChildren() do
			if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then
				checkNpc(c, issues)
			end
		end
	end

	return {
		lane = lane, name = route.name, region = route.region, source = source, base = base,
		samples = samples, issues = issues, materials = materials, layers = layers, npcCount = #npcs,
	}
end

function RouteWalker.walkAll(lanes)
	local res = {}
	for _, lane in lanes or RouteWalker.ORDER do
		table.insert(res, RouteWalker.walk(lane))
		task.wait()
	end
	return res
end

local function counts(issues)
	local c = {}
	for _, i in issues do
		c[i.kind] = (c[i.kind] or 0) + 1
	end
	return c
end

-- Collapse consecutive issues of the same kind into z ranges, so a report stays short.
local function ranges(issues)
	local byKind = {}
	for _, i in issues do
		if i.kind == "FLOAT" or i.kind == "BURIED" then continue end
		byKind[i.kind] = byKind[i.kind] or {}
		table.insert(byKind[i.kind], i)
	end
	local lines = {}
	for kind, list in byKind do
		table.sort(list, function(a, b)
			return a.z < b.z
		end)
		local start, last, first = nil, nil, nil
		local function flush()
			if start then
				table.insert(lines, ("  %-8s z %d-%d  e.g. %s"):format(kind, start, last, first.detail))
			end
		end
		for _, i in list do
			if start and i.z - last <= 45 then
				last = i.z
			else
				flush()
				start, last, first = i.z, i.z, i
			end
		end
		flush()
	end
	table.sort(lines)
	return lines
end

function RouteWalker.report(res)
	local out = {}
	table.insert(out, ("%s (%s) via %s, %d samples, road base y %.1f"):format(res.name, res.lane, res.source, #res.samples, res.base))
	local mats = {}
	for m, n in res.materials do
		table.insert(mats, m .. " " .. n)
	end
	table.sort(mats)
	table.insert(out, "  road surface: " .. table.concat(mats, ", "))
	local lay = {}
	for m, n in res.layers do
		table.insert(lay, m .. " x" .. n)
	end
	table.sort(lay)
	if #lay > 0 then
		table.insert(out, "  layering: " .. table.concat(lay, "; "))
	end
	for _, l in ranges(res.issues) do
		table.insert(out, l)
	end
	-- NPC lines are individual
	for _, i in res.issues do
		if i.kind == "FLOAT" or i.kind == "BURIED" then
			table.insert(out, "  " .. i.kind .. " " .. i.detail)
		end
	end
	return table.concat(out, "\n")
end

function RouteWalker.summary(all)
	local out = {}
	for _, res in all do
		local c = counts(res.issues)
		local parts = {}
		for k, n in c do
			table.insert(parts, k .. "=" .. n)
		end
		table.sort(parts)
		table.insert(out, ("%-16s %-7s base %6.1f  %s"):format(res.name, res.lane, res.base, #parts > 0 and table.concat(parts, " ") or "clean"))
	end
	return table.concat(out, "\n")
end

-- Validation gate: road walkable end to end, no jumps, NPCs grounded, nothing covering the lane, no void.
function RouteWalker.gate(res)
	local c = counts(res.issues)
	local reasons = {}
	for _, k in { "GAP", "JUMP", "BLOCKED", "MOUNTAIN", "DEADEND", "FLOAT", "BURIED", "COVER", "VOID", "OTHER" } do
		if (c[k] or 0) > 0 then
			table.insert(reasons, k .. "=" .. c[k])
		end
	end
	return #reasons == 0, reasons
end

return RouteWalker
