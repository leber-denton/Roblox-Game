--[[
	RegionDecorator: puts a region's route trainers on the ground at their GameData spots, and dresses the
	route with themed decor from ReplicatedStorage.Shared.RegionPaths (path.dressing). Theming Overhaul A1.
	Studio only, command bar in Edit mode, after RegionTerrainBuilder.build:

	  local D = require(game.ServerStorage.RegionDecorator)
	  D.preview("Lane1")         -- dry run: where trainers go, how many dressing items each rule places
	  D.placeTrainers("Lane1")   -- moves r1a/r1b/r1c to GameData's x/z, feet on the terrain, HomePos updated
	  D.dress("Lane1")           -- clears and re-places Map.Decor.<dressing.folder>
	  D.undo("Lane1")            -- trainers back to where they were, dressing folder removed

	Trainers: the model keeps its rotation; its lowest part is set on the ground under GameData's x/z.
	HomePos (NpcGuard) is stamped to the new spot so the guard doesn't snap it back on server start.
	The old pivots and HomePos are kept in ServerStorage.RegionTerrainBackups."<lane> trainers".

	Dressing: clones of existing decor (OakTree, FlowerBush, Boulder, GlowMushrooms) keep their names, so
	ModelSync still finds them. Fences are built from clones of the Fence folder's Post and Rail parts.
	Everything placed lives in one folder, so dress() can be re-run and undo() removes it cleanly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RegionPaths = require(Shared:WaitForChild("RegionPaths"))
local GameData = require(Shared:WaitForChild("GameData"))

local Decorator = {}

-- Studio's command bar keeps modules it has required, so after GameData changes (Rojo sync) hand in a
-- fresh copy:  D.useGameData(require(game.ReplicatedStorage.Shared.GameData:Clone()))
function Decorator.useGameData(gd)
	GameData = gd
end

local BACKUP_FOLDER = "RegionTerrainBackups"

local function log(fmt, ...)
	print("[RegionDecor] " .. (fmt):format(...))
end

local function resolve(dotted: string): Instance?
	local inst: Instance? = workspace
	for name in dotted:gmatch("[^%.]+") do
		inst = inst and inst:FindFirstChild(name)
	end
	return inst
end

local function getPath(laneKey: string)
	local path = RegionPaths.get(laneKey)
	assert(path, ("RegionPaths has no data for %s"):format(tostring(laneKey)))
	return path
end

local function terrainParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	return params
end

-- Ground height under (x, z): terrain first, else whatever solid is there
local function groundAt(x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), terrainParams())
	return hit and hit.Position.Y or nil
end

local function bottomOffset(inst: Instance): number
	-- how far the pivot sits above the lowest point
	if inst:IsA("Model") then
		local cf, size = inst:GetBoundingBox()
		return inst:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
	end
	local part = inst :: BasePart
	return part.Size.Y / 2
end

local function backup(name: string): Folder
	local root = ServerStorage:FindFirstChild(BACKUP_FOLDER)
	if not root then
		root = Instance.new("Folder")
		root.Name = BACKUP_FOLDER
		root.Parent = ServerStorage
	end
	local f = root:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
	end
	return f :: Folder
end

local rigBottom -- defined below, used by planTrainers and groundGymLeader

local function trainerData(id: string)
	for _, t in GameData.RouteTrainers do
		if t.id == id then
			return t
		end
	end
	return nil
end

-- Where each trainer would go: { id, model, from = CFrame, to = CFrame }
local function planTrainers(path)
	local plan = {}
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("RouteTrainers")
	for _, id in path.trainerIds or {} do
		local t = trainerData(id)
		local model = folder and folder:FindFirstChild(id)
		if not t or not model or not model:IsA("Model") then
			warn(("[RegionDecor] trainer %s: %s"):format(id, if not t then "not in GameData.RouteTrainers" else "no model in Map.RouteTrainers"))
			continue
		end
		-- solid ground of any kind (terrain, or a cave floor part), cast from just above the road so a
		-- roof overhead doesn't count; spawn zones, walls, gates and other trainers are ignored
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = {}
		for _, n in { "Lanes", "Bounds", "Gates", "RouteTrainers", "MountainHints" } do
			local f = workspace.Map:FindFirstChild(n)
			if f then
				table.insert(ignore, f)
			end
		end
		params.FilterDescendantsInstances = ignore
		params.RespectCanCollide = true
		local top = path.waypoints[1].y + 8
		local hit = workspace:Raycast(Vector3.new(t.x, top, t.z), Vector3.new(0, -40, 0), params)
		local y = if hit then hit.Position.Y else groundAt(t.x, t.z)
		if not y then
			warn(("[RegionDecor] trainer %s: no ground at (%d, %d)"):format(id, t.x, t.z))
			continue
		end
		local from = model:GetPivot()
		-- the rig's lowest visible part (not its bounding box, which the invisible root part can stretch)
		local to = CFrame.new(t.x, y + (from.Position.Y - rigBottom(model)), t.z) * from.Rotation
		table.insert(plan, { id = id, model = model, from = from, to = to })
	end
	return plan
end

function Decorator.placeTrainers(laneKey: string)
	local path = getPath(laneKey)
	local store = backup(laneKey .. " trainers")
	for _, p in planTrainers(path) do
		-- keep the very first original, so undo always returns to the pre-theming spot
		if not store:FindFirstChild(p.id) then
			local tag = Instance.new("ObjectValue")
			tag.Name = p.id
			tag.Value = p.model
			tag:SetAttribute("Orig", p.from)
			tag:SetAttribute("OrigHome", p.model:GetAttribute("HomePos"))
			tag.Parent = store
		end
		p.model:PivotTo(p.to)
		p.model:SetAttribute("HomePos", p.to.Position)
		log("trainer %s -> (%.0f, %.1f, %.0f)", p.id, p.to.X, p.to.Y, p.to.Z)
	end
end

-- Lowest visible point of a rig (the HumanoidRootPart is invisible and hangs below the hips on some rigs)
function rigBottom(model: Model): number
	local lowest = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
			local cf, s = d.CFrame, d.Size
			local h = math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
			lowest = math.min(lowest, cf.Y - h)
		end
	end
	return lowest
end

-- Puts the gym leader's feet on the gym floor (a part, so any solid counts). Idempotent; the first
-- original pivot is kept in RegionTerrainBackups."<lane> trainers" under the leader's name.
function Decorator.groundGymLeader(laneKey: string)
	local path = getPath(laneKey)
	local gym = workspace.Map:FindFirstChild(path.gym or "")
	if not gym then
		warn("[RegionDecor] no gym model " .. tostring(path.gym))
		return
	end
	for _, npc in gym:GetChildren() do
		if npc:IsA("Model") and npc:FindFirstChildOfClass("Humanoid") then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { npc }
			params.RespectCanCollide = true
			local pivot = npc:GetPivot()
			local hit = workspace:Raycast(pivot.Position + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), params)
			if not hit then
				warn("[RegionDecor] no floor under " .. npc:GetFullName())
				continue
			end
			local gap = rigBottom(npc) - hit.Position.Y
			if math.abs(gap) < 0.1 then
				log("gym leader %s already on the floor", npc.Name)
				continue
			end
			local store = backup(laneKey .. " trainers")
			if not store:FindFirstChild(npc.Name) then
				local tag = Instance.new("ObjectValue")
				tag.Name = npc.Name
				tag.Value = npc
				tag:SetAttribute("Orig", pivot)
				tag:SetAttribute("OrigHome", npc:GetAttribute("HomePos"))
				tag.Parent = store
			end
			local to = pivot - Vector3.new(0, gap, 0)
			npc:PivotTo(to)
			if npc:GetAttribute("HomePos") then
				npc:SetAttribute("HomePos", to.Position)
			end
			log("gym leader %s lowered %.2f studs onto %s", npc.Name, gap, hit.Instance.Name)
		end
	end
end

-- Spots each dressing rule would use: { rule, pos = Vector3 (x, z; y unused), yaw, dir = Vector3 }
local function planDressing(path)
	local cfg = path.dressing
	local spots = {}
	if not cfg then
		return spots
	end
	local b = path.bounds
	local length = RegionPaths.length(path)
	local trainers = {}
	for _, id in path.trainerIds or {} do
		local t = trainerData(id)
		if t then
			table.insert(trainers, Vector3.new(t.x, 0, t.z))
		end
	end
	local interior = path.decor and path.decor.interior or b
	for r, rule in cfg.rules do
		local rng = Random.new(path.seed * 1000 + r)
		local n = 0
		if rule.scatter then
			-- ground cover: perHundred items per 100 studs of road, at random spots minOffset..maxOffset
			-- studs out on either side (Meadow's loose flowers and grass tufts)
			for _ = 1, math.floor(length / 100 * rule.perHundred + 0.5) do
				local along = rng:NextNumber(0, length)
				local x, _, z, ux, uz = RegionPaths.pointAt(path, along)
				local depth = RegionPaths.depthAt(path, z)
				if z < b.minZ + 4 or z > b.maxZ - 4 or depth < rule.from or depth > rule.to then
					continue
				end
				local side = if rng:NextNumber() < 0.5 then -1 else 1
				local off = rng:NextNumber(rule.minOffset, rule.maxOffset)
				table.insert(spots, {
					rule = rule,
					pos = Vector3.new(x + uz * off * side, 0, z - ux * off * side),
					dir = Vector3.new(ux, 0, uz),
					yaw = rng:NextNumber(0, math.pi * 2),
					interior = interior,
					trainers = trainers,
				})
			end
			continue
		end
		for along = rule.start or 0, length, rule.every do
			local x, _, z, ux, uz = RegionPaths.pointAt(path, along)
			local depth = RegionPaths.depthAt(path, z)
			if z < b.minZ + 4 or z > b.maxZ - 4 or depth < rule.from or depth > rule.to then
				continue
			end
			n += 1
			local sides = if rule.sides == "both" then { -1, 1 } else { if n % 2 == 0 then 1 else -1 }
			for _, side in sides do
				local j = rule.jitter or 0
				local off = rule.offset + rng:NextNumber(-j, j)
				local slide = rng:NextNumber(-j, j)
				local px = x + uz * off * side + ux * slide
				local pz = z - ux * off * side + uz * slide
				table.insert(spots, {
					rule = rule,
					pos = Vector3.new(px, 0, pz),
					dir = Vector3.new(ux, 0, uz),
					yaw = rng:NextNumber(0, math.pi * 2),
					interior = interior,
					trainers = trainers,
				})
			end
		end
	end
	return spots
end

-- Is a footprint free: inside the walls, clear of trainers, keep-clear boxes and other decor?
local function spotFree(path, spot, halfX: number, halfZ: number, placed, across: number?): boolean
	local p, box = spot.pos, spot.interior
	if p.X - halfX < box.minX or p.X + halfX > box.maxX or p.Z - halfZ < box.minZ or p.Z + halfZ > box.maxZ then
		return false
	end
	for _, t in spot.trainers do
		if (Vector3.new(p.X, 0, p.Z) - t).Magnitude < (path.dressing.trainerClear or 8) + math.max(halfX, halfZ) then
			return false
		end
	end
	for _, k in path.keepClear do
		if p.X + halfX > k.minX - 4 and p.X - halfX < k.maxX + 4 and p.Z + halfZ > k.minZ - 4 and p.Z - halfZ < k.maxZ + 4 then
			return false
		end
	end
	-- the road itself stays clear
	if RegionPaths.nearest(path, p.X, p.Z) - (across or math.max(halfX, halfZ)) < path.corridorWidth / 2 + 0.5 then
		return false
	end
	-- other decor (existing, and what this pass already placed): compare trunk-sized footprints
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local decor = workspace.Map:FindFirstChild("Decor")
	params.FilterDescendantsInstances = { decor }
	local hits = workspace:GetPartBoundsInBox(CFrame.new(p.X, 10, p.Z), Vector3.new(halfX * 1.2, 30, halfZ * 1.2), params)
	for _, h in hits do
		if h.Transparency < 0.95 then
			return false
		end
	end
	for _, q in placed do
		if math.abs(q.X - p.X) < halfX + q.hx and math.abs(q.Z - p.Z) < halfZ + q.hz then
			return false
		end
	end
	return true
end

local function placeModel(template: Instance, folder: Instance, spot, sink: number)
	local y = groundAt(spot.pos.X, spot.pos.Z)
	if not y then
		return nil
	end
	local clone = template:Clone()
	local off = bottomOffset(template)
	local cf = CFrame.new(spot.pos.X, y - sink + off, spot.pos.Z) * CFrame.Angles(0, spot.yaw, 0)
	if clone:IsA("Model") then
		clone:PivotTo(cf)
	elseif clone:IsA("BasePart") then
		clone.CFrame = cf
	end
	clone.Parent = folder
	return clone
end

-- A short split-rail fence run centred on the spot, along the road
local function placeFence(fence: Instance, folder: Instance, spot, sink: number, length: number)
	local post = fence:FindFirstChild("Post")
	local rail = fence:FindFirstChild("Rail")
	if not (post and post:IsA("BasePart") and rail and rail:IsA("BasePart")) then
		return 0
	end
	local run = Instance.new("Model")
	run.Name = "FenceRun"
	local dir = spot.dir
	local posts = math.max(2, math.floor(length / 6) + 1)
	local step = length / (posts - 1)
	local start = spot.pos - dir * (length / 2)
	local tops = {}
	for i = 0, posts - 1 do
		local at = start + dir * (step * i)
		local y = groundAt(at.X, at.Z)
		if not y then
			run:Destroy()
			return 0
		end
		local p = post:Clone()
		p.CFrame = CFrame.new(at.X, y - sink + p.Size.Y / 2, at.Z)
		p.Parent = run
		tops[i] = Vector3.new(at.X, y - sink, at.Z)
	end
	for i = 0, posts - 2 do
		local a, c = tops[i], tops[i + 1]
		for _, h in { 0.45, 0.8 } do
			local r = rail:Clone()
			local ya, yc = a.Y + post.Size.Y * h, c.Y + post.Size.Y * h
			local m1, m2 = Vector3.new(a.X, ya, a.Z), Vector3.new(c.X, yc, c.Z)
			r.Size = Vector3.new(r.Size.X, r.Size.Y, (m2 - m1).Magnitude)
			r.CFrame = CFrame.lookAt((m1 + m2) / 2, m2)
			r.Parent = run
		end
	end
	run.Parent = folder
	return 1
end

local function sizeOf(template: Instance): Vector3
	if template:IsA("Model") then
		local _, size = template:GetBoundingBox()
		return size
	end
	return (template :: BasePart).Size
end

local function runDressing(path, apply: boolean)
	local cfg = path.dressing
	local decor = workspace.Map:FindFirstChild("Decor")
	assert(decor, "no Workspace.Map.Decor")
	local folder = decor:FindFirstChild(cfg.folder)
	if apply then
		if folder then
			folder:Destroy() -- re-running replaces the previous pass
		end
		folder = Instance.new("Folder")
		folder.Name = cfg.folder
		folder.Parent = decor
	end
	local counts, missing = {}, {}
	local placed = {}
	for _, spot in planDressing(path) do
		local rule = spot.rule
		counts[rule.name] = counts[rule.name] or 0
		local halfX, halfZ, across
		local template
		if rule.kind == "fence" then
			halfX, halfZ, across = rule.length / 2, rule.length / 2, 0.5 -- a thin run along the road
		else
			template = resolve(rule.template)
			if not template then
				missing[rule.template] = true
				continue
			end
			local size = sizeOf(template)
			-- trunk-ish footprint for trees, full footprint for small things
			local f = if size.Y > 10 then 0.35 else 0.5
			halfX, halfZ = size.X * f, size.Z * f
		end
		if not spotFree(path, spot, halfX, halfZ, placed, across) then
			continue
		end
		table.insert(placed, { X = spot.pos.X, Z = spot.pos.Z, hx = halfX, hz = halfZ })
		counts[rule.name] += 1
		if apply then
			if rule.kind == "fence" then
				placeFence(resolve(path.decor.root .. ".Fence") or decor, folder, spot, cfg.sink, rule.length)
			else
				placeModel(template, folder, spot, cfg.sink)
			end
		end
	end
	local total = 0
	for _, rule in cfg.rules do
		log("  %-18s %d placed", rule.name, counts[rule.name] or 0)
		total += counts[rule.name] or 0
	end
	for name in missing do
		warn("[RegionDecor] template not found: " .. name)
	end
	return total
end

function Decorator.preview(laneKey: string)
	local path = getPath(laneKey)
	log("%s preview. Nothing changed.", laneKey)
	for _, p in planTrainers(path) do
		log("trainer %s: (%.0f, %.1f, %.0f) -> (%.0f, %.1f, %.0f)", p.id, p.from.X, p.from.Y, p.from.Z, p.to.X, p.to.Y, p.to.Z)
	end
	local total = runDressing(path, false)
	log("dressing: %d item(s) would be placed in Map.Decor.%s", total, path.dressing.folder)
end

function Decorator.dress(laneKey: string)
	local path = getPath(laneKey)
	local total = runDressing(path, true)
	log("dressing: %d item(s) placed in Map.Decor.%s", total, path.dressing.folder)
end

function Decorator.undo(laneKey: string)
	local path = getPath(laneKey)
	local decor = workspace.Map:FindFirstChild("Decor")
	local folder = decor and decor:FindFirstChild(path.dressing.folder)
	if folder then
		folder:Destroy()
	end
	local root = ServerStorage:FindFirstChild(BACKUP_FOLDER)
	local store = root and root:FindFirstChild(laneKey .. " trainers")
	local n = 0
	if store then
		for _, tag in store:GetChildren() do
			local model = tag:IsA("ObjectValue") and tag.Value
			local orig = tag:GetAttribute("Orig")
			if model and typeof(orig) == "CFrame" then
				model:PivotTo(orig)
				model:SetAttribute("HomePos", tag:GetAttribute("OrigHome"))
				n += 1
			end
		end
		store:Destroy()
	end
	log("%s: dressing removed, %d trainer(s) put back", laneKey, n)
end

return Decorator
