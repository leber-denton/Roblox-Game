-- Edit-time builder. Original bases are retained in ServerStorage.Backups.RidgeBase_PreBuild.
local Builder = {}

local function part(parent, floor, name, size, x, y, z, color, material, solid)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Anchored = name, size, true
	local side = floor.Position.X < 0 and 1 or -1
	p.Position = floor.Position + Vector3.new(x * side, y + 0.3, z)
	p.Color, p.Material = color, material or Enum.Material.WoodPlanks
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide = solid ~= false
	p:SetAttribute("Solid", p.CanCollide)
	p.Parent = parent
	return p
end

local function board(parent, floor, name, x, y, z, text)
	local p = part(parent, floor, name, Vector3.new(0.5, 5, 12), x, y, z, Color3.fromRGB(57, 83, 72), nil, false)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.CanvasSize = face, Vector2.new(640, 280)
		gui.Parent = p
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Font, label.TextSize = Enum.Font.FredokaOne, 30
		label.TextColor3, label.TextWrapped, label.Text = Color3.fromRGB(255, 239, 200), true, text
		label.Parent = gui
	end
	return p
end

function Builder.build(base)
	assert(game:GetService("RunService"):IsStudio(), "Edit tool only")
	assert(game.PlaceId == 94034385545160, "Cloud test place only")
	if base:FindFirstChild("Homestead") then return false end
	local floor = base.Floor
	local root = Instance.new("Folder")
	root.Name = "Homestead"
	local zones = {}
	for stage, name in { "StarterYard", "HabitatGarden", "XPBalcony", "ChampionTerrace" } do
		local zone = Instance.new("Model")
		zone.Name = name
		zone:SetAttribute("Stage", stage)
		zone.Parent = root
		zones[stage] = zone
	end
	local cream, timber = Color3.fromRGB(235, 223, 187), Color3.fromRGB(127, 91, 61)
	local green, blue = Color3.fromRGB(99, 147, 92), Color3.fromRGB(54, 116, 137)
	board(zones[1], floor, "ProgressBoard", 35, 8, -13, "Starter Yard\nNext: Habitat Garden\n1 badge + 500 coins")
	part(zones[1], floor, "MailboxPost", Vector3.new(0.7, 3, 0.7), 35, 1.5, 12, timber)
	part(zones[1], floor, "Mailbox", Vector3.new(2.5, 1.6, 1.8), 35, 3.5, 12, blue)
	for _, z in { -21, 21 } do
		part(zones[2], floor, "GardenBorder", Vector3.new(21, 0.5, 1), -61, 0.3, z, cream)
		for x = -69, -51, 6 do
			part(zones[2], floor, "GardenPlanter", Vector3.new(3, 0.6, 2), x, 0.5, z, timber)
			part(zones[2], floor, "Herbs", Vector3.new(2.5, 1, 1.5), x, 1.2, z, green, Enum.Material.Grass, false)
		end
	end
	local deck = zones[3]
	part(deck, floor, "BalconyDeck", Vector3.new(30, 1, 28), -96, 6, 0, cream)
	for _, x in { -109, -83 } do
		for _, z in { -12, 12 } do
			part(deck, floor, "LodgePillar", Vector3.new(1, 13, 1), x, 6.5, z, timber)
		end
	end
	for _, z in { -14, 14 } do
		part(deck, floor, "BalconyRail", Vector3.new(30, 2.8, 0.6), -96, 8, z, blue)
	end
	for _, z in { -9, 9 } do
		part(deck, floor, "BackRail", Vector3.new(0.6, 2.8, 10), -111, 8, z, blue)
	end
	local backGate = part(deck, floor, "TerraceGate", Vector3.new(0.6, 2.8, 8), -111, 8, 0, blue)
	backGate:SetAttribute("OpenAtStage", 4)
	for _, z in { -9, 9 } do
		part(deck, floor, "EntryRail", Vector3.new(0.6, 2.8, 10), -81, 8, z, blue)
	end
	for i = 1, 12 do
		part(deck, floor, "SafeStair", Vector3.new(1.6, i * 0.5, 7), -63 - i * 1.5, i * 0.25, 0, timber)
	end
	local side = floor.Position.X < 0 and 1 or -1
	for _, z in { -4, 4 } do
		local rail = part(deck, floor, "StairRail", Vector3.new(20, 0.6, 0.6), -72, 5.5, z, blue)
		rail.CFrame *= CFrame.Angles(0, 0, -side * math.atan(1 / 3))
	end
	board(deck, floor, "TrainingBoard", -108, 10, 0, "XP BALCONY\nBattle XP for your bench\nTraining stays below your badge cap")
	local canopy = base:FindFirstChild("Canopy")
	if canopy then
		local original = canopy:GetPivot()
		base:SetAttribute("HomeCanopyPivot", original)
		base:SetAttribute("BalconyCanopyPivot", original + Vector3.new(-120 * side, 6, -3))
	end
	local expFence = base.Expansion:FindFirstChild("ExpFence")
	if expFence then
		for _, p in expFence:GetDescendants() do
			if p:IsA("BasePart") and math.abs(p.Position.Z - floor.Position.Z) <= 4 then
				p:SetAttribute("Stage3Passage", true)
				p:SetAttribute("PassageSolid", p.CanCollide)
			end
		end
	end
	local terrace = zones[4]
	for i = 1, 12 do
		part(terrace, floor, "TerraceStair", Vector3.new(1.6, 6 - i * 0.45, 7), -110 - i * 1.5, (6 - i * 0.45) / 2, 0, timber)
	end
	for _, z in { -4, 4 } do
		local rail = part(terrace, floor, "TerraceStairRail", Vector3.new(20, 0.6, 0.6), -119, 5.5, z, blue)
		rail.CFrame *= CFrame.Angles(0, 0, side * math.atan(0.3))
	end
	part(terrace, floor, "TerraceGround", Vector3.new(40, 0.6, 38), -131, 0, 0, green, Enum.Material.Grass)
	part(terrace, floor, "TerraceWalk", Vector3.new(40, 0.12, 6), -131, 0.38, 0, cream, Enum.Material.Pavement)
	for _, z in { -19, 19 } do
		part(terrace, floor, "TerraceFence", Vector3.new(40, 3, 0.7), -131, 1.5, z, timber)
	end
	part(terrace, floor, "TerraceBackFence", Vector3.new(0.7, 3, 38), -151, 1.5, 0, timber)
	for _, z in { -10, 10 } do
		part(terrace, floor, "TrophyPlinth", Vector3.new(4, 1.5, 4), -146, 0.75, z, cream, Enum.Material.Marble)
		part(terrace, floor, "ChampionTrophy", Vector3.new(2, 3, 2), -146, 3, z, Color3.fromRGB(225, 180, 65), Enum.Material.Metal, false)
	end
	board(terrace, floor, "ChampionBoard", -150, 6, 0, "CHAMPION TERRACE\nRegion 1 collection mastered\nA home for your achievements")
	-- Closed stages have no collision or visual footprint until the owner's state opens them.
	for _, zone in zones do
		if zone:GetAttribute("Stage") > 1 then
			for _, p in zone:GetDescendants() do
				if p:IsA("BasePart") then p.Transparency, p.CanCollide = 1, false end
				if p:IsA("SurfaceGui") then p.Enabled = false end
			end
		end
	end
	root.Parent = base
	return true
end

function Builder.buildAll()
	-- The old tree belt crosses the new deck footprints. Move only intersecting models
	-- into the phase backup, retaining originals for recovery instead of deleting them.
	local surroundings = workspace.Map.Decor:FindFirstChild("BaseSurroundings")
	local backup = game.ServerStorage.Backups.RidgeBase_PreBuild
	local cleared = backup:FindFirstChild("ClearedBaseSurroundings") or Instance.new("Folder")
	cleared.Name, cleared.Parent = "ClearedBaseSurroundings", backup
	if surroundings then
		for _, model in surroundings:GetChildren() do
			if model:IsA("Model") then
				local cf, size = model:GetBoundingBox()
				for _, base in workspace.Map.Bases:GetChildren() do
					if math.abs(cf.Position.X) + size.X / 2 >= 153 and math.abs(cf.Position.X) - size.X / 2 <= 232
						and math.abs(cf.Position.Z - base.Floor.Position.Z) < 21 + size.Z / 2 then
						model.Parent = cleared
						break
					end
				end
			end
		end
	end
	local count = 0
	for _, base in workspace.Map.Bases:GetChildren() do
		if Builder.build(base) then count += 1 end
		task.wait()
	end
	return count
end

return Builder
