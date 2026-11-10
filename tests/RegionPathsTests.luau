--[[
	RegionPathsTests: checks the RegionPaths data and geometry. Run by hand in Studio's command bar
	(Edit mode); needs no map, changes nothing.
	  local ok, lines = require(game.ServerStorage.RegionPathsTests).run(require(game.ReplicatedStorage.Shared.RegionPaths))
	Put this file in ServerStorage as a ModuleScript named RegionPathsTests (temporarily copy it into
	src/ServerStorage so Rojo syncs it, then remove it again), then call run(RegionPaths).

	Covers: every region's data passes RegionPaths.check, the road and verge are flat at road height,
	trainer spots sit on flat verge, the designed ridge clears boundary.minWall all round (except the road
	cut and keep-clear boxes), hills have no seams at zone borders, nearest() on a known line, and that
	check() catches a too-steep road and a trainer off the verge.
]]

local Tests = {}

function Tests.run(RegionPaths)
	local results, failed = {}, 0
	local function test(name, fn)
		local ok, err = pcall(fn)
		if ok then
			table.insert(results, "PASS " .. name)
		else
			failed += 1
			table.insert(results, "FAIL " .. name .. ": " .. tostring(err))
		end
	end
	local function near(a, b, eps, what)
		assert(math.abs(a - b) <= eps, ("%s: %.3f vs %.3f"):format(what or "value", a, b))
	end
	local function copy(t)
		if type(t) ~= "table" then
			return t
		end
		local c = {}
		for k, v in t do
			c[k] = copy(v)
		end
		return c
	end

	for _, key in RegionPaths.list() do
		local path = RegionPaths.get(key)
		local half = path.corridorWidth / 2
		local inner = half + path.buffer
		local b = path.bounds

		test(key .. " data check", function()
			local problems = RegionPaths.check(path)
			assert(#problems == 0, table.concat(problems, "; "))
		end)

		test(key .. " road and verge are flat at road height", function()
			local length = RegionPaths.length(path)
			for along = 0, length, 8 do
				local x, y, z, ux, uz = RegionPaths.pointAt(path, along)
				if z < b.minZ or z > b.maxZ then
					continue
				end
				for off = -inner + 0.5, inner - 0.5, 2 do
					local sx, sz = x + uz * off, z - ux * off
					local inBox = false
					for _, box in path.keepClear do
						if sx >= box.minX - box.margin and sx <= box.maxX + box.margin and sz >= box.minZ - box.margin and sz <= box.maxZ + box.margin then
							inBox = true
						end
					end
					if not inBox then
						local h, kind = RegionPaths.heightAt(path, sx, sz)
						assert(kind == "road" or kind == "verge", ("kind %s at (%.0f, %.0f)"):format(kind, sx, sz))
						near(h, y - (path.surfaceSink or 0), 0.01, ("height at (%.0f, %.0f)"):format(sx, sz))
					end
				end
			end
		end)

		test(key .. " trainer spots are on flat verge", function()
			for _, s in RegionPaths.trainerSpots(path) do
				local h, kind, roadY = RegionPaths.heightAt(path, s.x, s.z)
				assert(kind == "verge", s.id .. " is on " .. kind)
				near(h, roadY - (path.surfaceSink or 0), 0.01, s.id)
			end
		end)

		test(key .. " designed ridge closes the boundary", function()
			local ridge = path.boundary
			local inset = ridge.width * 0.2
			local lowest = math.huge
			local function at(x, z)
				local d = RegionPaths.nearest(path, x, z)
				if d <= inner + path.shoulder or RegionPaths.inOpening(path, x, z) then
					return
				end
				for _, box in path.keepClear do
					if x >= box.minX - box.margin - 4 and x <= box.maxX + box.margin + 4 and z >= box.minZ - box.margin - 4 and z <= box.maxZ + box.margin + 4 then
						return
					end
				end
				local h, _, roadY = RegionPaths.heightAt(path, x, z)
				lowest = math.min(lowest, h - roadY)
				assert(h - roadY >= ridge.minWall, ("ridge %.1f over the road at (%.0f, %.0f)"):format(h - roadY, x, z))
			end
			local sides = ridge.sides or { west = true, east = true, south = true, north = true }
			local taper = ridge.endTaper or 0
			local z1, z2 = b.minZ + (if sides.south then inset else taper), b.maxZ - (if sides.north then inset else taper)
			local x1, x2 = b.minX + (if sides.west then inset else taper), b.maxX - (if sides.east then inset else taper)
			for x = x1, x2, 4 do
				if sides.south then
					at(x, b.minZ + inset)
				end
				if sides.north then
					at(x, b.maxZ - inset)
				end
			end
			for z = z1, z2, 4 do
				if sides.west then
					at(b.minX + inset, z)
				end
				if sides.east then
					at(b.maxX - inset, z)
				end
			end
			assert(lowest < math.huge, "no ring samples at all")
		end)

		test(key .. " no seams at zone borders", function()
			-- walk north through the wild land; neighbouring 1-stud samples must not jump
			local x = (b.minX + b.maxX) / 2 + inner + path.shoulder + 30
			local prev
			for z = b.minZ + path.boundary.width + 4, b.maxZ - path.boundary.width - 4 do
				local h, kind = RegionPaths.heightAt(path, x, z)
				if kind == "wild" and prev then
					assert(math.abs(h - prev) < 2, ("jump of %.1f at z %d"):format(h - prev, z))
				end
				prev = if kind == "wild" then h else nil
			end
		end)
	end

	test("nearest on a straight north road", function()
		local path = {
			waypoints = { { x = 0, y = 0, z = 0 }, { x = 0, y = 10, z = 100 } },
		}
		local d, along, y = RegionPaths.nearest(path, 6, 50)
		near(d, 6, 1e-6, "distance")
		near(along, 50, 1e-6, "along")
		near(y, 5, 1e-6, "road y")
		local px, py, pz = RegionPaths.pointAt(path, 25)
		near(px, 0, 1e-6, "x")
		near(py, 2.5, 1e-6, "y")
		near(pz, 25, 1e-6, "z")
	end)

	test("check catches a steep road", function()
		local path = copy(RegionPaths.Lane1)
		path.waypoints[3].y = path.waypoints[2].y + 60
		local problems = RegionPaths.check(path)
		local found = false
		for _, p in problems do
			if p:find("slope") then
				found = true
			end
		end
		assert(found, "no slope problem reported")
	end)

	test("check catches a trainer off the verge", function()
		local path = copy(RegionPaths.Lane1)
		path.buffer = 2 -- r1a stands 14 studs out, now past the verge
		local problems = RegionPaths.check(path)
		local found = false
		for _, p in problems do
			if p:find("outside the verge") then
				found = true
			end
		end
		assert(found, "no trainer problem reported")
	end)

	for _, line in results do
		print("[RegionPathsTests] " .. line)
	end
	print(("[RegionPathsTests] %d passed, %d failed"):format(#results - failed, failed))
	return failed == 0, results
end

return Tests
