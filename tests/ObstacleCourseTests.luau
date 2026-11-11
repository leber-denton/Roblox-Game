--!nocheck
-- Obstacle course checks. Run in Edit (command bar, or MCP execute_luau with the Edit datamodel) after
-- ObstacleCourseBuilder has built the courses. Read-only: it changes nothing.
--
-- Config: every route in GameData.Regions has exactly one course, ids are unique, rewards grow along the
-- road, difficulties and themes exist. Built courses: each folder has a start pad, chest, prompt and bounds,
-- stays out of the wild-spawn area and every trainer's sight box, and its jumps fit a default character.

local function load(module)
	return loadstring(module.Source)()
end
local CourseConfig = load(game.ReplicatedStorage.Shared.CourseConfig)
local Builder = load(game.ServerStorage.ObstacleCourseBuilder)
local GameData = load(game.ReplicatedStorage.Shared.GameData)

local results = {}
local function check(name, ok, detail)
	table.insert(results, ("%s  %s%s"):format(ok and "PASS" or "FAIL", name, detail and ("  [" .. detail .. "]") or ""))
end

-- Config ---------------------------------------------------------------------------------------
local seen, lanes = {}, {}
local lastReward = 0
for _, c in CourseConfig.Courses do
	check(c.Id .. " id unique", not seen[c.Id])
	seen[c.Id] = true
	lanes[c.Lane] = true
	check(c.Id .. " difficulty known", CourseConfig.Difficulties[c.Difficulty] ~= nil, c.Difficulty)
	check(c.Id .. " theme known", Builder.THEMES[c.Theme] ~= nil, c.Theme)
	check(c.Id .. " reward positive and not below the previous route", c.CoinReward > 0 and c.CoinReward >= lastReward, tostring(c.CoinReward))
	check(c.Id .. " cooldown at least a minute", CourseConfig.cooldown(c) >= 60)
	lastReward = c.CoinReward
end
for _, r in GameData.Regions do
	check(r.lane .. " (" .. r.name .. ") has a course", lanes[r.lane] == true)
end
for name, t in CourseConfig.Difficulties do
	check(name .. " gaps jumpable", t.GapMax <= 6.5 and t.GapMin <= t.GapMax, ("%.1f-%.1f"):format(t.GapMin, t.GapMax))
end

-- Built courses --------------------------------------------------------------------------------
local obstacles = workspace:FindFirstChild("Obstacles")
check("Workspace.Obstacles exists", obstacles ~= nil)
for _, c in CourseConfig.Courses do
	local folder
	for _, f in obstacles and obstacles:GetChildren() or {} do
		if f:GetAttribute("CourseId") == c.Id then folder = f end
	end
	check(c.Id .. " built", folder ~= nil)
	if not folder then continue end
	local pad = folder:FindFirstChild("Start") and folder.Start:FindFirstChild("StartPad")
	local chest = folder:FindFirstChild("Chest")
	local prompt = chest and chest:FindFirstChild("ChestPrompt", true)
	local bounds = folder:FindFirstChild("CourseBounds")
	check(c.Id .. " has start pad, chest, prompt and bounds", pad and chest and prompt and bounds and true or false)
	if not (pad and chest and bounds) then continue end
	check(c.Id .. " prompt is hold-E", prompt.KeyboardKeyCode == Enum.KeyCode.E and prompt.HoldDuration > 0)

	-- Wild spawns use x within the lane part's half-width minus 10 (WildSpawner.spawnInLane).
	local lane = workspace.Map.Lanes[c.Lane]
	local spawnHalf = lane.Size.X / 2 - 10
	local bx0, bx1 = bounds.Position.X - bounds.Size.X / 2, bounds.Position.X + bounds.Size.X / 2
	local inSpawn = bx1 > lane.Position.X - spawnHalf and bx0 < lane.Position.X + spawnHalf
	check(c.Id .. " outside the wild-spawn area", not inSpawn, ("x %.1f..%.1f, spawns %.1f..%.1f"):format(bx0, bx1, lane.Position.X - spawnHalf, lane.Position.X + spawnHalf))

	-- Trainer sight: 26 studs toward the hub (-Z), whole lane width, within 12 studs of height.
	local bz0, bz1 = bounds.Position.Z - bounds.Size.Z / 2, bounds.Position.Z + bounds.Size.Z / 2
	local clash
	for _, m in workspace.Map.RouteTrainers:GetChildren() do
		local p = m:GetPivot().Position
		if math.abs(p.X - lane.Position.X) < 70 and bz1 > p.Z - 26 and bz0 < p.Z + 4 then clash = m.Name end
	end
	check(c.Id .. " clear of trainer sight boxes", clash == nil, clash)

	-- Jumps along the recorded route: horizontal gap between landing centres and climb.
	local pts = {}
	for x, y, z in folder:GetAttribute("Route"):gmatch("([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
		table.insert(pts, Vector3.new(tonumber(x), tonumber(y), tonumber(z)))
	end
	local worstRise, worstSpan = 0, 0
	for i = 2, #pts do
		worstRise = math.max(worstRise, pts[i].Y - pts[i - 1].Y)
		worstSpan = math.max(worstSpan, Vector3.new(pts[i].X - pts[i - 1].X, 0, pts[i].Z - pts[i - 1].Z).Magnitude)
	end
	check(c.Id .. " climbs at most 3 studs per jump", worstRise <= 3, ("%.1f"):format(worstRise))
	-- landing centre to centre: platform halves (up to 4) + gap + mover travel; beams and movers are the long ones
	check(c.Id .. " no landing more than 17 studs from the last", worstSpan <= 17, ("%.1f"):format(worstSpan))
end

local failed = 0
for _, line in results do
	if line:sub(1, 4) == "FAIL" then failed += 1 end
end
print(("ObstacleCourseTests: %d checks, %d failed"):format(#results, failed))
for _, line in results do
	if line:sub(1, 4) == "FAIL" then print(line) end
end
return ("%d checks, %d failed"):format(#results, failed)
