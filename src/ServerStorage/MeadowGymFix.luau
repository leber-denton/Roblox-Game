--[[
	MeadowGymFix: one-off Studio fix for Gym 1 (Meadow Gym, Gym Leader Slate).
	  1. Slate stands on the ground instead of floating, and the loose rocks hovering around him are archived.
	  2. The Meadow Route path is extended so it ends at the gym building's base.
	The map lives in the place file, so this runs in Studio (command bar, edit mode). It is a dry run unless you
	pass false, and a dry run prints exactly what it found so you can check it before anything moves:
	  local Fix = require(game.ServerStorage.MeadowGymFix)
	  Fix.run()        -- prints what it would do, changes nothing
	  Fix.run(false)   -- applies it (one undo step in Studio)
	  Fix.restore()    -- puts archived rocks back, drops the path pieces it added and moves Slate back
	Archived rocks are kept in ServerStorage.MeadowGymFixArchive, never destroyed. Slate's HomePos is re-stamped
	so NpcGuard does not snap him back. Save the place afterwards.
	The showcase reference copy and the NPCBackup copy of Slate get the same rock cleanup, otherwise the next
	ModelSync.apply would bring the floating rocks back.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local MeadowGymFix = {}

local GYM = "MeadowGym"
local LEADER = "Slate"
local LANE = "Lane1"
local COPY_NAME = "Workspace_Map_MeadowGym_Slate" -- ModelSync name of Slate's reference and backup copies
local TAG = "MeadowGymFix"
local ARCHIVE = "MeadowGymFixArchive"
local PATH_COLOR = Color3.fromRGB(166, 148, 111) -- same as the Meadow Route paint in NPCAnimator
local PATH_WIDTH = 12
local PATH_STEP = 24
local CONNECTED_WITHIN = 8 -- a path ending this close to the gym already counts as connected
local NEAR_RADIUS = 24 -- loose rocks within this many studs of Slate are candidates
local ROCK_MAX_SIZE = 14
local MIN_BODY_GAP = 3 -- rock-like parts closer than this to his body are his props, not rocks around him
local MAX_MOVE = 60 -- refuse to move Slate further than this; the ray probably hit the wrong surface

local RIG = {}
for _, name in {
	"Head",
	"Torso",
	"UpperTorso",
	"LowerTorso",
	"HumanoidRootPart",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
} do
	RIG[name] = true
end

local ROCK_WORDS = { "rock", "boulder", "stone", "pebble", "rubble", "debris", "crag", "orbit" }
local ROCK_MATERIALS = {
	[Enum.Material.Slate] = true,
	[Enum.Material.Rock] = true,
	[Enum.Material.Granite] = true,
	[Enum.Material.Basalt] = true,
	[Enum.Material.Cobblestone] = true,
	[Enum.Material.Pebble] = true,
}
local ENTRANCE_WORDS = { "door", "entrance", "entry", "step", "stair", "porch", "threshold" }
local FOOT_NAMES = { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }

local function say(...)
	print("[MeadowGymFix]", ...)
end

local function waypoint(label: string)
	pcall(function()
		ChangeHistoryService:SetWaypoint(label)
	end)
end

local function nameHas(name: string, words: { string }): boolean
	local lower = name:lower()
	for _, word in words do
		if lower:find(word, 1, true) then
			return true
		end
	end
	return false
end

-- Lowest world Y of a part, rotation included
local function bottomY(part: BasePart): number
	local cf, s = part.CFrame, part.Size
	local half = (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
	return cf.Position.Y - half
end

-- Nearest point of an oriented box (cf, size) to a world point
local function closestInBox(cf: CFrame, size: Vector3, point: Vector3): Vector3
	local rel = cf:PointToObjectSpace(point)
	local h = size / 2
	return cf:PointToWorldSpace(Vector3.new(math.clamp(rel.X, -h.X, h.X), math.clamp(rel.Y, -h.Y, h.Y), math.clamp(rel.Z, -h.Z, h.Z)))
end

local function inAccessory(inst: Instance): boolean
	return inst:FindFirstAncestorWhichIsA("Accessory") ~= nil or inst:FindFirstAncestorWhichIsA("Tool") ~= nil
end

local function bodyCenter(model: Model): Vector3
	local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or model.PrimaryPart
	return if root and root:IsA("BasePart") then root.Position else model:GetPivot().Position
end

local function looksLikeRock(part: BasePart, body: Vector3): boolean
	if RIG[part.Name] or inAccessory(part) then
		return false
	end
	if not (nameHas(part.Name, ROCK_WORDS) or ROCK_MATERIALS[part.Material]) then
		return false
	end
	return (part.Position - body).Magnitude > MIN_BODY_GAP
end

local function ground(from: Vector3, ignore: { Instance }, depth: number?): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	return workspace:Raycast(from, Vector3.new(0, -(depth or 300), 0), params)
end

-- Rock-like parts that belong to a leader model (floating chunks welded or placed inside it)
local function modelRocks(model: Model): { BasePart }
	local body = bodyCenter(model)
	local found = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and looksLikeRock(d, body) then
			table.insert(found, d)
		end
	end
	return found
end

-- Loose rocks near the leader that sit inside the gym but outside his model and have nothing under them
local function nearbyRocks(gym: Instance, slate: Model, skip: { [Instance]: boolean }): { BasePart }
	local center = slate:GetPivot().Position
	local body = bodyCenter(slate)
	local found = {}
	for _, d in gym:GetDescendants() do
		if d:IsA("BasePart") and not d:IsDescendantOf(slate) and not skip[d] and looksLikeRock(d, body) then
			local offset = d.Position - center
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			local s = d.Size
			if flat <= NEAR_RADIUS and offset.Y >= -12 and offset.Y <= 20 and math.max(s.X, s.Y, s.Z) < ROCK_MAX_SIZE then
				local under = Vector3.new(d.Position.X, bottomY(d) + 0.05, d.Position.Z)
				if not ground(under, { d, slate }, 1.2) then
					table.insert(found, d)
				end
			end
		end
	end
	return found
end

-- If every part of a rock's model is itself a rock, archive the whole model instead of one piece of it
local function archiveTargets(parts: { BasePart }): { Instance }
	local set = {}
	for _, p in parts do
		set[p] = true
	end
	local function allRocks(model: Instance): boolean
		local count = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				count += 1
				if not set[d] then
					return false
				end
			end
		end
		return count > 0
	end
	local seen, targets = {}, {}
	for _, p in parts do
		local target: Instance = p
		while target.Parent and target.Parent:IsA("Model") and allRocks(target.Parent) do
			target = target.Parent
		end
		if not seen[target] then
			seen[target] = true
			table.insert(targets, target)
		end
	end
	return targets
end

local function archiveFolder(name: string): Folder
	local folder = ServerStorage:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = ServerStorage
	end
	return folder
end

local function archive(target: Instance, archiveName: string)
	local entry = Instance.new("Folder")
	entry.Name = target.Name
	entry:SetAttribute("OriginalPath", target:GetFullName())
	local original = Instance.new("ObjectValue")
	original.Name = "OriginalParent"
	original.Value = target.Parent
	original.Parent = entry
	target.Parent = entry
	entry.Parent = archiveFolder(archiveName)
end

-- How far Slate has to move up (+) or down (-) so his feet rest on the surface under him
local function slateMove(slate: Model, ignore: { Instance }): (number?, string?)
	local low
	for _, name in FOOT_NAMES do
		local p = slate:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			local b = bottomY(p)
			low = if low then math.min(low, b) else b
		end
	end
	if not low then
		for _, p in slate:GetChildren() do
			if p:IsA("BasePart") and RIG[p.Name] and p.Name ~= "HumanoidRootPart" then
				local b = bottomY(p)
				low = if low then math.min(low, b) else b
			end
		end
	end
	if not low then
		return nil, "no body parts found on Slate"
	end
	local pivot = slate:GetPivot().Position
	local hit = ground(Vector3.new(pivot.X, low + 6, pivot.Z), ignore)
	if not hit then
		return nil, "nothing solid under Slate to stand on"
	end
	local move = hit.Position.Y - low
	if math.abs(move) > MAX_MOVE then
		return nil, ("ground found %.0f studs away (%s), not trusting it"):format(move, hit.Instance:GetFullName())
	end
	return move, hit.Instance:GetFullName()
end

-- Where the Meadow path currently stops: the furthest end of the Lane1 winding path, else the end of the lane
local function pathEnd(map: Instance, lane: BasePart): (Vector3, string)
	local best
	local zMin, zMax = lane.Position.Z - lane.Size.Z / 2 - 10, lane.Position.Z + lane.Size.Z / 2 + 10
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "WindingPath" and d:GetAttribute(TAG) == nil then
			if math.abs(d.Position.X - lane.Position.X) < 40 and d.Position.Z > zMin and d.Position.Z < zMax then
				local half = d.CFrame.LookVector * (d.Size.Z / 2)
				for _, e in { d.Position + half, d.Position - half } do
					if not best or e.Z > best.Z then
						best = e
					end
				end
			end
		end
	end
	if best then
		return best, "end of the Lane1 winding path"
	end
	return Vector3.new(lane.Position.X, lane.Position.Y + lane.Size.Y / 2 + 0.1, lane.Position.Z + lane.Size.Z / 2 - 2), "end of the lane (no winding path found)"
end

-- The spot on the gym the path should reach: its door or steps if it has them, else the edge of its footprint
local function gymTarget(gym: Model, from: Vector3): (Vector3, string)
	local bestPoint, bestPart, bestDist
	for _, d in gym:GetDescendants() do
		if d:IsA("BasePart") and nameHas(d.Name, ENTRANCE_WORDS) and not nameHas(d.Name, { "window" }) then
			local point = closestInBox(d.CFrame, d.Size, from)
			local dist = (point - from).Magnitude
			if not bestDist or dist < bestDist then
				bestPoint, bestPart, bestDist = point, d, dist
			end
		end
	end
	if bestPoint and bestPart then
		return bestPoint, "gym entrance part " .. bestPart:GetFullName()
	end
	local cf, size = gym:GetBoundingBox()
	return closestInBox(cf, size, from), "edge of the gym footprint"
end

local function pathNodes(from: Vector3, target: Vector3, ignore: { Instance }): ({ Vector3 }, number)
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	local count = math.max(1, math.ceil(flat.Magnitude / PATH_STEP))
	-- the existing path pieces sit 0.1 above the ground (buildPath lifts new ones by the same amount)
	local y = from.Y - 0.1
	local nodes, blocked = { Vector3.new(from.X, y, from.Z) }, 0
	for i = 1, count do
		local xz = from + flat * (i / count)
		local hit = ground(Vector3.new(xz.X, y + 8, xz.Z), ignore, 24)
		if hit and math.abs(hit.Position.Y - y) <= 6 then
			y = hit.Position.Y
		else
			blocked += 1 -- no sensible ground here (an obstacle or a drop); keep the last height
		end
		table.insert(nodes, Vector3.new(xz.X, y, xz.Z))
	end
	return nodes, blocked
end

local function buildPath(map: Instance, nodes: { Vector3 })
	local passages = map:FindFirstChild("WorldPolish") and map.WorldPolish:FindFirstChild("RoutePassages")
	local parent = passages
	if not parent then
		parent = Instance.new("Folder")
		parent.Name = "MeadowGymFixPath"
		parent:SetAttribute(TAG, "path")
		parent.Parent = map
	end
	local lift = Vector3.new(0, 0.1, 0)
	for n = 2, #nodes do
		local a, b = nodes[n - 1] + lift, nodes[n] + lift
		local piece = Instance.new("Part")
		piece.Name = "WindingPath"
		piece.Anchored = true
		piece.CanCollide = false
		piece.Size = Vector3.new(PATH_WIDTH, 0.16, (b - a).Magnitude + 0.8)
		piece.Color = PATH_COLOR
		piece.Material = Enum.Material.Ground
		piece.TopSurface = Enum.SurfaceType.Smooth
		piece.BottomSurface = Enum.SurfaceType.Smooth
		piece.CFrame = CFrame.lookAt((a + b) / 2, b)
		piece:SetAttribute(TAG, "path")
		piece.Parent = parent
	end
end

-- Reference and backup copies of Slate (so ModelSync.apply cannot bring the rocks back)
local function copies(): { Model }
	local found = {}
	local showcase = workspace:FindFirstChild("ShowcaseArea")
	if showcase then
		for _, d in showcase:GetDescendants() do
			if d:IsA("Model") and d.Name == COPY_NAME then
				table.insert(found, d)
			end
		end
	end
	local backup = ServerStorage:FindFirstChild("NPCBackup")
	local stored = backup and backup:FindFirstChild(COPY_NAME)
	if stored and stored:IsA("Model") then
		table.insert(found, stored)
	end
	return found
end

-- opts.map: use this folder instead of workspace.Map (the tests build a disposable one); copies are then skipped
-- opts.archive: name of the ServerStorage folder archived rocks go to (the tests use their own)
function MeadowGymFix.run(dryRun: boolean?, opts: { map: Instance?, archive: string? }?)
	dryRun = dryRun ~= false
	local archiveName = (opts and opts.archive) or ARCHIVE
	local map = (opts and opts.map) or workspace:FindFirstChild("Map")
	local gym = map and map:FindFirstChild(GYM)
	local slate = gym and gym:FindFirstChild(LEADER)
	assert(map and gym and gym:IsA("Model") and slate and slate:IsA("Model"), "MeadowGymFix: Map." .. GYM .. "." .. LEADER .. " not found")
	local lanes = map:FindFirstChild("Lanes")
	local lane = lanes and lanes:FindFirstChild(LANE)
	assert(lane and lane:IsA("BasePart"), "MeadowGymFix: Map.Lanes." .. LANE .. " not found")

	-- 1. rocks
	local inside = modelRocks(slate)
	local skip = {}
	for _, p in inside do
		skip[p] = true
	end
	local loose = nearbyRocks(gym, slate, skip)
	local worldRocks = table.clone(inside)
	table.move(loose, 1, #loose, #worldRocks + 1, worldRocks)
	local worldTargets = archiveTargets(worldRocks)
	local copyTargets = {}
	if not (opts and opts.map) then
		for _, copy in copies() do
			for _, target in archiveTargets(modelRocks(copy)) do
				table.insert(copyTargets, target)
			end
		end
	end
	say(("%d rock piece(s) on or around Slate (%d inside his model, %d loose in the gym), %d on reference/backup copies"):format(
		#worldRocks,
		#inside,
		#loose,
		#copyTargets
	))
	for _, p in worldRocks do
		say(("  rock: %s  size %s  material %s  %.1f studs from his body"):format(
			p:GetFullName(),
			tostring(p.Size),
			p.Material.Name,
			(p.Position - bodyCenter(slate)).Magnitude
		))
	end

	-- 2. Slate's feet
	local ignore: { Instance } = { slate }
	for _, t in worldTargets do
		table.insert(ignore, t)
	end
	local move, why = slateMove(slate, ignore)
	if move then
		say(("Slate: move %+.2f studs to stand on %s"):format(move, why or "?"))
	else
		say("Slate: left where he is (" .. tostring(why) .. ")")
	end

	-- 3. path
	local from, fromWhy = pathEnd(map, lane)
	local target, targetWhy = gymTarget(gym, from)
	local gap = Vector3.new(target.X - from.X, 0, target.Z - from.Z).Magnitude
	local alreadyBuilt = false
	for _, d in map:GetDescendants() do
		if d:GetAttribute(TAG) == "path" then
			alreadyBuilt = true
			break
		end
	end
	local nodes, blocked = nil, 0
	if alreadyBuilt then
		say("Path: pieces from an earlier run exist; run restore() first to rebuild")
	elseif gap <= CONNECTED_WITHIN then
		say(("Path: already reaches the gym (%.1f studs from %s)"):format(gap, targetWhy))
	else
		nodes, blocked = pathNodes(from, target, { slate })
		say(("Path: %s ends %.1f studs short of the %s; adding %d piece(s)%s"):format(
			fromWhy,
			gap,
			targetWhy,
			#nodes - 1,
			if blocked > 0 then (", %d node(s) had no clear ground, check them"):format(blocked) else ""
		))
	end

	local report = { rocks = #worldTargets + #copyTargets, slateMove = move, pathPieces = nodes and (#nodes - 1) or 0 }
	if dryRun then
		say("Dry run: nothing changed. Run Fix.run(false) to apply.")
		return report
	end

	waypoint("MeadowGymFix: before")
	for _, t in worldTargets do
		archive(t, archiveName)
	end
	for _, t in copyTargets do
		archive(t, archiveName)
	end
	if move and math.abs(move) > 0.01 then
		slate:PivotTo(slate:GetPivot() + Vector3.new(0, move, 0))
		slate:SetAttribute("MeadowGymFixDY", (slate:GetAttribute("MeadowGymFixDY") or 0) + move)
	end
	slate:SetAttribute("HomePos", slate:GetPivot().Position)
	if nodes then
		buildPath(map, nodes)
	end
	waypoint("MeadowGymFix: after")
	say(("Done: %d archived, Slate moved %s, %d path piece(s) added. Save the place."):format(report.rocks, move and ("%+.2f"):format(move) or "0", report.pathPieces))
	return report
end

function MeadowGymFix.restore(opts: { map: Instance?, archive: string? }?)
	local map = (opts and opts.map) or workspace:FindFirstChild("Map")
	waypoint("MeadowGymFix: before restore")
	local restored = 0
	local folder = ServerStorage:FindFirstChild((opts and opts.archive) or ARCHIVE)
	if folder then
		for _, entry in folder:GetChildren() do
			local original = entry:FindFirstChild("OriginalParent")
			local parent = original and original:IsA("ObjectValue") and original.Value
			if parent then
				for _, child in entry:GetChildren() do
					if child ~= original then
						child.Parent = parent
						restored += 1
					end
				end
				entry:Destroy()
			else
				warn("[MeadowGymFix] " .. entry.Name .. ": original parent is gone; left in the archive")
			end
		end
	end
	local removed = 0
	if map then
		for _, d in map:GetDescendants() do
			if d:GetAttribute(TAG) == "path" then
				d:Destroy()
				removed += 1
			end
		end
		local gym = map:FindFirstChild(GYM)
		local slate = gym and gym:FindFirstChild(LEADER)
		local dy = slate and slate:GetAttribute("MeadowGymFixDY")
		if slate and slate:IsA("Model") and type(dy) == "number" then
			slate:PivotTo(slate:GetPivot() + Vector3.new(0, -dy, 0))
			slate:SetAttribute("MeadowGymFixDY", nil)
			slate:SetAttribute("HomePos", slate:GetPivot().Position)
		end
	end
	waypoint("MeadowGymFix: after restore")
	say(("Restored %d part(s)/model(s), removed %d path piece(s)"):format(restored, removed))
end

return MeadowGymFix
