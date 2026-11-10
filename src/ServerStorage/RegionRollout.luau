--!nocheck
--[[
	RegionRollout: themes one route end to end from its RegionStyle entry. Overhaul Phase 2 (2026-11-10).
	Studio tool, Edit mode. Command bar or MCP:
	  local R = require(game.ServerStorage.RegionRollout)
	  R.run("Lane9")          -- prep, terrain, trainers, gym leader, dressing (idempotent: re-running rebuilds)
	  R.validate("Lane9")     -- RouteWalker gate + RegionPathValidator, in a later frame
	  R.undo("Lane9")         -- dressing, trainers, terrain and the lane floor back as they were

	Studio caches a module after its first require, so every call loads fresh copies of GameData,
	RegionStyle, RegionPaths and the three region tools (R.load). Their `Shared` lookups are pointed at a
	temporary folder of clones, which is removed again.

	What run() changes, all undoable:
	  * Map.Lanes.<lane>: hidden and non-collide, like Meadow's (WildSpawner still reads its size). The old
	    values are kept as attributes OrigTransparency / OrigCanCollide.
	  * Terrain inside the route's bounds, plus old flat floor parts stashed (RegionTerrainBuilder snapshot).
	  * Route trainers moved to GameData's spots (Meadow spacing), the gym leader's feet put on the floor.
	  * Map.Decor.<lane>Dressing filled from the theme's decor list.
]]

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rollout = {}

local SHARED = { "GameData", "RegionStyle", "RegionPaths" }
local TOOLS = { "RegionTerrainBuilder", "RegionDecorator", "RegionPathValidator", "RouteWalker" }

-- Fresh, uncached copies of everything. Returns a table: GameData, RegionStyle, RegionPaths, Builder,
-- Decorator, Validator, Walker.
function Rollout.load()
	local tmp = Instance.new("Folder")
	tmp.Name = "__RegionFresh"
	local shared = ReplicatedStorage:WaitForChild("Shared")
	for _, name in SHARED do
		shared:WaitForChild(name):Clone().Parent = tmp
	end
	for _, name in TOOLS do
		local m = ServerStorage:FindFirstChild(name)
		if m then
			local c = m:Clone()
			-- point the tool at the clones next to it
			c.Source = c.Source
				:gsub('ReplicatedStorage:WaitForChild%("Shared"%)', "script.Parent")
			c.Parent = tmp
		end
	end
	tmp.Parent = ServerStorage
	local out = {}
	local ok, err = pcall(function()
		out.GameData = require(tmp.GameData)
		out.RegionStyle = require(tmp.RegionStyle)
		out.RegionPaths = require(tmp.RegionPaths)
		out.Builder = require(tmp.RegionTerrainBuilder)
		out.Decorator = require(tmp.RegionDecorator)
		out.Validator = tmp:FindFirstChild("RegionPathValidator") and require(tmp.RegionPathValidator)
		out.Walker = tmp:FindFirstChild("RouteWalker") and require(tmp.RouteWalker)
		if out.Walker then
			out.Walker.useRegionPaths(out.RegionPaths)
		end
	end)
	tmp:Destroy()
	assert(ok, err)
	return out
end

local function laneFloor(laneKey: string): BasePart?
	local lanes = workspace.Map:FindFirstChild("Lanes")
	return lanes and lanes:FindFirstChild(laneKey)
end

local function hideFloor(laneKey: string)
	local p = laneFloor(laneKey)
	if not p then
		return
	end
	if p:GetAttribute("OrigTransparency") == nil then
		p:SetAttribute("OrigTransparency", p.Transparency)
		p:SetAttribute("OrigCanCollide", p.CanCollide)
	end
	p.Transparency = 1
	p.CanCollide = false
end

local function showFloor(laneKey: string)
	local p = laneFloor(laneKey)
	if p and p:GetAttribute("OrigTransparency") ~= nil then
		p.Transparency = p:GetAttribute("OrigTransparency")
		p.CanCollide = p:GetAttribute("OrigCanCollide")
		p:SetAttribute("OrigTransparency", nil)
		p:SetAttribute("OrigCanCollide", nil)
	end
end

local function decorItems(folder: Instance, acc)
	for _, d in folder:GetChildren() do
		if d:IsA("Folder") then
			decorItems(d, acc)
		elseif d:IsA("Model") or d:IsA("BasePart") then
			table.insert(acc, d)
		end
	end
	return acc
end

local function stashFolder(laneKey: string, create: boolean): Folder?
	local root = ServerStorage:FindFirstChild("RegionTerrainBackups")
	if not root and create then
		root = Instance.new("Folder")
		root.Name = "RegionTerrainBackups"
		root.Parent = ServerStorage
	end
	local f = root and root:FindFirstChild(laneKey .. " buried")
	if not f and create then
		f = Instance.new("Folder")
		f.Name = laneKey .. " buried"
		f.Parent = root
	end
	return f
end

-- Decor that sits entirely inside the old terrain (Region 2 had 261 such items in its cliffs) was never
-- visible. Left in place it would be protected by the builder and punch holes in the new ridge, so it is
-- moved into RegionTerrainBackups."<lane> buried" (each with a Home ObjectValue) before the build.
local function stashBuried(path, keep: { [Instance]: boolean }): number
	local b = path.bounds
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local decor = workspace.Map:FindFirstChild("Decor")
	if not decor then
		return 0
	end
	local moved = 0
	local store
	for _, d in decorItems(decor, {}) do
		local cf, size
		if d:IsA("Model") then
			cf, size = d:GetBoundingBox()
		else
			cf, size = d.CFrame, d.Size
		end
		local p = cf.Position
		if keep[d] or p.X < b.minX or p.X > b.maxX or p.Z < b.minZ or p.Z > b.maxZ then
			continue
		end
		local hit = workspace:Raycast(Vector3.new(p.X, 400, p.Z), Vector3.new(0, -500, 0), params)
		local laneX = (b.minX + b.maxX) / 2
		local fully = hit and hit.Position.Y > p.Y + size.Y / 2 + 0.5
		-- outside the walls, half sunk into the old cliff (the Lane9 windmill): it would sit in the new ridge
		local sunkOutside = hit and math.abs(p.X - laneX) > 66 and hit.Position.Y > p.Y
		if fully or sunkOutside then
			store = store or stashFolder(path.lane, true)
			local home = Instance.new("ObjectValue")
			home.Name = "Home"
			home.Value = d.Parent
			home.Parent = d
			d.Parent = store
			moved += 1
		end
	end
	return moved
end

local function unstashBuried(laneKey: string): number
	local f = stashFolder(laneKey, false)
	if not f then
		return 0
	end
	local n = 0
	for _, d in f:GetChildren() do
		local home = d:FindFirstChild("Home")
		if home and home.Value then
			d.Parent = home.Value
			home:Destroy()
			n += 1
		end
	end
	f:Destroy()
	return n
end

--[[
	The old mountains just outside a route's bounds (snowy rock 200-300 studs high) are kept in shape but
	repainted in the theme's materials, so a desert or manor route isn't walled in by snow. Bands: Region 1
	west of the bounds and east up to x 232; Region 2 from x 232 to its bounds and 320 studs east of them.
	The first original of each band is kept in RegionTerrainBackups."<lane> outer" for undo.
]]
local OUTER_SPLIT_X = 232 -- between the regions: Region 1 paints west of this, Region 2 east of it

local function outerBands(path, region: number)
	local b = path.bounds
	if region == 1 then
		return { { b.minX - 300, b.minX }, { b.maxX, OUTER_SPLIT_X } }
	end
	return { { OUTER_SPLIT_X, b.minX }, { b.maxX, b.maxX + 320 } }
end

local function bandRegion(path, band): Region3
	local b = path.bounds
	local lo = Vector3.new(math.floor(band[1] / 4) * 4, -24, b.minZ)
	local hi = Vector3.new(math.ceil(band[2] / 4) * 4, 340, b.maxZ)
	return Region3.new(lo, hi)
end

function Rollout.paintOuter(laneKey: string, env)
	env = env or Rollout.load()
	local theme = env.RegionStyle.lanes[laneKey]
	local path = env.RegionPaths.get(laneKey)
	if not theme or not path then
		return 0
	end
	local terrain = workspace.Terrain
	local root = ServerStorage:FindFirstChild("RegionTerrainBackups") or Instance.new("Folder")
	root.Name = "RegionTerrainBackups"
	root.Parent = ServerStorage
	local store = root:FindFirstChild(laneKey .. " outer")
	local first = store == nil
	if first then
		store = Instance.new("Folder")
		store.Name = laneKey .. " outer"
		store.Parent = root
	end
	local rock = theme.boundaryRock or theme.cliff
	local map = {
		[Enum.Material.Snow] = theme.peak,
		[Enum.Material.Glacier] = theme.peak,
		[Enum.Material.Rock] = rock,
		[Enum.Material.Slate] = rock,
		-- the old dirt band at the foot of the cliffs read as flat tan: it takes the route's ground
		[Enum.Material.Ground] = theme.ground,
		[Enum.Material.Mud] = theme.ground,
		[Enum.Material.Sand] = theme.ground,
		[Enum.Material.Sandstone] = rock, -- old tan stripes along the cliffs
		[Enum.Material.Grass] = theme.ground,
		[Enum.Material.LeafyGrass] = theme.ground,
	}
	if not first then
		-- repaint from the original, so changing a theme and re-running gives the same result
		for _, copy in store:GetChildren() do
			if copy:IsA("TerrainRegion") then
				terrain:PasteRegion(copy, Vector3int16.new(copy:GetAttribute("CornerX"), copy:GetAttribute("CornerY"), copy:GetAttribute("CornerZ")), true)
			end
		end
		task.wait(0.3)
	end
	local painted = 0
	for i, band in outerBands(path, theme.region) do
		if band[2] - band[1] < 8 then
			continue
		end
		local region = bandRegion(path, band)
		if first then
			local lo, hi = region.CFrame.Position - region.Size / 2, region.CFrame.Position + region.Size / 2
			local corner = Vector3int16.new(lo.X / 4, lo.Y / 4, lo.Z / 4)
			local copy = terrain:CopyRegion(Region3int16.new(corner, Vector3int16.new(hi.X / 4 - 1, hi.Y / 4 - 1, hi.Z / 4 - 1)))
			copy.Name = "Band" .. i
			copy:SetAttribute("CornerX", corner.X)
			copy:SetAttribute("CornerY", corner.Y)
			copy:SetAttribute("CornerZ", corner.Z)
			copy.Parent = store
		end
		for from, to in map do
			if to and to ~= from then
				terrain:ReplaceMaterial(region, 4, from, to)
				painted += 1
			end
		end
		task.wait()
	end
	print(("[RegionRollout] %s: outer mountains repainted (%d material swaps)"):format(laneKey, painted))
	return painted
end

local function unpaintOuter(laneKey: string)
	local root = ServerStorage:FindFirstChild("RegionTerrainBackups")
	local store = root and root:FindFirstChild(laneKey .. " outer")
	if not store then
		return
	end
	for _, copy in store:GetChildren() do
		if copy:IsA("TerrainRegion") then
			local corner = Vector3int16.new(copy:GetAttribute("CornerX"), copy:GetAttribute("CornerY"), copy:GetAttribute("CornerZ"))
			workspace.Terrain:PasteRegion(copy, corner, true)
		end
	end
	store:Destroy()
end

-- Problems RegionPaths.check finds in the data (empty when fine)
function Rollout.check(laneKey: string)
	local env = Rollout.load()
	local path = env.RegionPaths.get(laneKey)
	assert(path, "no RegionPaths entry for " .. tostring(laneKey))
	return env.RegionPaths.check and env.RegionPaths.check(path) or {}
end

function Rollout.preview(laneKey: string)
	local env = Rollout.load()
	env.Builder.preview(laneKey)
	env.Decorator.preview(laneKey)
end

function Rollout.run(laneKey: string)
	local env = Rollout.load()
	local path = env.RegionPaths.get(laneKey)
	assert(path, "no RegionPaths entry for " .. tostring(laneKey))
	local problems = env.RegionPaths.check and env.RegionPaths.check(path) or {}
	if #problems > 0 then
		error(("[RegionRollout] %s data problems: %s"):format(laneKey, table.concat(problems, " | ")))
	end
	-- re-running: undo the earlier build completely, so every build starts from the original land
	local floorPart = laneFloor(laneKey)
	if floorPart and floorPart:GetAttribute("Themed") then
		Rollout.undo(laneKey)
		-- rays cast right after PasteRegion still see the old voxels; give the terrain a moment
		task.wait(0.5)
	else
		env.Decorator.undo(laneKey)
	end
	hideFloor(laneKey)
	-- never stash an item some route's dressing clones from (Lane11's TidePool template was buried)
	local keep = {}
	for _, key in env.RegionPaths.list() do
		local p = env.RegionPaths.get(key)
		for _, rule in p.dressing and p.dressing.rules or {} do
			if rule.template then
				local inst = workspace
				for name in rule.template:gmatch("[^%.]+") do
					inst = inst and inst:FindFirstChild(name)
				end
				if inst then
					keep[inst] = true
				end
			end
		end
	end
	local buried = stashBuried(path, keep)
	print(("[RegionRollout] %s: %d buried decor item(s) stashed"):format(laneKey, buried))
	task.wait()
	env.Builder.build(laneKey, { stashGround = true })
	task.wait()
	env.Decorator.placeTrainers(laneKey)
	env.Decorator.groundGymLeader(laneKey)
	task.wait()
	Rollout.paintOuter(laneKey, env)
	env.Decorator.dress(laneKey)
	local floor = laneFloor(laneKey)
	if floor then
		floor:SetAttribute("Themed", os.date("!%Y-%m-%d %H:%M UTC"))
	end
	print(("[RegionRollout] %s themed. Run R.validate(%q) next (a later frame)."):format(laneKey, laneKey))
end

-- RouteWalker gate (walk, NPCs, cover, sightlines) plus the RegionPathValidator checks.
-- Returns pass, report text.
function Rollout.validate(laneKey: string)
	local env = Rollout.load()
	local res = env.Walker.walk(laneKey)
	local pass, reasons = env.Walker.gate(res)
	local lines = { env.Walker.report(res) }
	table.insert(lines, ("RouteWalker gate: %s %s"):format(pass and "PASS" or "FAIL", table.concat(reasons, " ")))
	if env.Validator and env.Validator.validate then
		local ok, err = pcall(env.Validator.validate, laneKey)
		if not ok then
			table.insert(lines, "RegionPathValidator error: " .. tostring(err))
		end
	end
	return pass, table.concat(lines, "\n")
end

function Rollout.undo(laneKey: string)
	local env = Rollout.load()
	env.Decorator.undo(laneKey)
	env.Builder.restore(laneKey)
	unpaintOuter(laneKey)
	task.wait()
	unstashBuried(laneKey)
	showFloor(laneKey)
	local floor = laneFloor(laneKey)
	if floor then
		floor:SetAttribute("Themed", nil)
	end
end

return Rollout
