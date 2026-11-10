-- Run the returned function in the Studio command bar in EDIT mode (not Play).
-- Builds a disposable fake Meadow Gym far from the real map, runs MeadowGymFix on it, and checks:
--   a dry run changes nothing; floating rocks are archived and resting rocks / his belt are kept;
--   Slate ends up standing on the gym floor; the path now reaches the door; restore() undoes all of it.
-- It uses its own map folder and its own archive folder, so the real map and archive are never touched.
return function()
	local RunService = game:GetService("RunService")
	local ServerStorage = game:GetService("ServerStorage")
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Run this in Studio edit mode")
	local Fix = require(ServerStorage.MeadowGymFix)

	local ARCHIVE = "MeadowGymFixTestArchive"
	local X = 6000
	local created, checks = {}, 0
	local function check(value, label)
		assert(value, label)
		checks += 1
	end
	local function near(a, b, tolerance)
		return math.abs(a - b) <= (tolerance or 0.05)
	end
	local function part(parent, name, size, position, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = position
		p.Anchored = true
		p.Material = material or Enum.Material.SmoothPlastic
		p.Parent = parent
		return p
	end
	local function bottom(p)
		return p.Position.Y - p.Size.Y / 2
	end

	assert(not ServerStorage:FindFirstChild(ARCHIVE), "Delete ServerStorage." .. ARCHIVE .. " from an earlier failed run first")

	local root = Instance.new("Folder")
	root.Name = "MeadowGymFixTestMap"
	root.Parent = workspace
	table.insert(created, root)

	local ok, err = xpcall(function()
		-- ground (top at y = 0) and the Meadow lane with its last path piece ending at z = 48
		part(root, "TestGround", Vector3.new(200, 4, 400), Vector3.new(X, -2, 200))
		local lanes = Instance.new("Folder")
		lanes.Name = "Lanes"
		lanes.Parent = root
		local lane = part(lanes, "Lane1", Vector3.new(60, 1, 100), Vector3.new(X, -0.5, 0))
		lane.CanCollide = false
		local old = part(root, "WindingPath", Vector3.new(12, 0.16, 96), Vector3.new(X, 0.1, 0))
		old.CanCollide = false

		-- gym: raised floor (top y = 1) with its door on the side facing the path (z = 90)
		local gym = Instance.new("Model")
		gym.Name = "MeadowGym"
		gym.Parent = root
		part(gym, "GymFloor", Vector3.new(60, 1, 60), Vector3.new(X, 0.5, 120))
		part(gym, "GymDoor", Vector3.new(8, 10, 1), Vector3.new(X, 6, 90)).CanCollide = false
		local resting = part(gym, "RestingRock", Vector3.new(3, 3, 3), Vector3.new(X + 9, 2.5, 120), Enum.Material.Rock)
		local floating = part(gym, "LooseRock", Vector3.new(3, 3, 3), Vector3.new(X - 8, 8, 122), Enum.Material.Rock)

		-- Slate, R6 style, feet 6 studs above the floor; one rock inside his model, and a belt that must stay
		local slate = Instance.new("Model")
		slate.Name = "Slate"
		slate.Parent = gym
		part(slate, "Left Leg", Vector3.new(1, 2, 1), Vector3.new(X - 0.5, 8, 120))
		part(slate, "Right Leg", Vector3.new(1, 2, 1), Vector3.new(X + 0.5, 8, 120))
		local torso = part(slate, "Torso", Vector3.new(2, 2, 1), Vector3.new(X, 10, 120))
		part(slate, "Head", Vector3.new(1, 1, 1), Vector3.new(X, 11.5, 120))
		part(slate, "Belt", Vector3.new(2.2, 0.4, 1.2), Vector3.new(X, 9.2, 120), Enum.Material.Slate)
		part(slate, "OrbitRock1", Vector3.new(2, 2, 2), Vector3.new(X + 5, 11, 120), Enum.Material.Rock)
		slate.PrimaryPart = torso

		local opts = { map = root, archive = ARCHIVE }
		local before = slate:GetPivot()

		-- dry run changes nothing
		local report = Fix.run(true, opts)
		check(slate:GetPivot() == before, "dry run keeps Slate where he was")
		check(slate:FindFirstChild("OrbitRock1") ~= nil and floating.Parent == gym, "dry run keeps the rocks")
		check(not ServerStorage:FindFirstChild(ARCHIVE), "dry run creates no archive")
		check(report.rocks == 2, "dry run finds the two floating rocks (found " .. tostring(report.rocks) .. ")")
		check(report.slateMove ~= nil and near(report.slateMove, -6), "dry run plans to drop Slate 6 studs")
		check(report.pathPieces == 2, "dry run plans two path pieces (planned " .. tostring(report.pathPieces) .. ")")

		-- apply
		Fix.run(false, opts)
		check(slate:FindFirstChild("OrbitRock1") == nil, "rock inside Slate archived")
		check(floating.Parent ~= gym, "loose floating rock archived")
		check(resting.Parent == gym, "rock resting on the floor kept")
		check(slate:FindFirstChild("Belt") ~= nil, "belt kept")
		check(ServerStorage:FindFirstChild(ARCHIVE) and #ServerStorage[ARCHIVE]:GetChildren() == 2, "both rocks are in the archive")
		check(near(bottom(slate["Left Leg"]), 1) and near(bottom(slate["Right Leg"]), 1), "feet rest on the gym floor")
		check(slate:GetAttribute("HomePos") == slate:GetPivot().Position, "HomePos re-stamped")
		local pieces = {}
		for _, d in root:GetDescendants() do
			if d:GetAttribute("MeadowGymFix") == "path" and d:IsA("BasePart") then
				table.insert(pieces, d)
			end
		end
		check(#pieces == 2, "two path pieces added (added " .. #pieces .. ")")
		local reach = -math.huge
		for _, p in pieces do
			reach = math.max(reach, p.Position.Z + p.Size.Z / 2)
		end
		check(reach >= 89 - 8, "path reaches the door (ends at z " .. reach .. ")")

		-- running again does not stack another path or move anything
		local again = Fix.run(false, opts)
		check(again.pathPieces == 0 and again.rocks == 0, "second run adds nothing")

		-- restore puts it all back
		Fix.restore(opts)
		check(slate:FindFirstChild("OrbitRock1") ~= nil and floating.Parent == gym, "restore brings the rocks back")
		check(slate:GetPivot() == before or near((slate:GetPivot().Position - before.Position).Magnitude, 0), "restore moves Slate back")
		local left = 0
		for _, d in root:GetDescendants() do
			if d:GetAttribute("MeadowGymFix") == "path" then
				left += 1
			end
		end
		check(left == 0, "restore removes the path pieces")
	end, debug.traceback)

	for _, inst in created do
		inst:Destroy()
	end
	local leftover = ServerStorage:FindFirstChild(ARCHIVE)
	if leftover then
		leftover:Destroy()
	end
	assert(ok, err)
	print(("MeadowGymFixTests: %d checks passed"):format(checks))
	return checks
end
