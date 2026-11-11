-- Edit-only builder for part-built mountains (Workspace.Map.Mountains.<Group>.<Name>).
-- It only creates a mountain Model that is missing, so manual Studio edits are never
-- overwritten. Nothing here runs in a live server. See vault/Systems/MountainLookouts.md.
local Builder = {}

local TIER = 36 -- height of one cliff band
local LEDGE = 30 -- depth of one terrace in the trail zone
local RAMP_W = 12
local RAMP_HALF = 40 -- each ramp runs from -40 to +40 along the range
local PAD = 12
local TRAIL_ZONE = 90 -- |a| inside this stays exact so ramps, ledges and decks line up
local CAP = 1.2
local WOOD, RAIL = Color3.fromRGB(139, 115, 80), Color3.fromRGB(73, 96, 85)

local PALETTES = {
	Meadow = {
		Rock = { Color3.fromRGB(92, 98, 112), Color3.fromRGB(104, 110, 122), Color3.fromRGB(82, 88, 101) },
		RockMaterial = Enum.Material.Rock,
		Cap = Color3.fromRGB(98, 160, 72),
		CapMaterial = Enum.Material.Grass,
		Peak = Color3.fromRGB(150, 156, 166),
		Foliage = { Color3.fromRGB(58, 118, 62), Color3.fromRGB(46, 101, 56) },
		Trunk = Color3.fromRGB(96, 72, 50),
	},
	Desert = {
		Rock = { Color3.fromRGB(196, 158, 108), Color3.fromRGB(184, 144, 96), Color3.fromRGB(208, 172, 122) },
		RockMaterial = Enum.Material.Sandstone,
		Cap = Color3.fromRGB(222, 204, 160),
		CapMaterial = Enum.Material.Sand,
		Peak = Color3.fromRGB(230, 214, 178),
		Tree = "Cactus",
		Foliage = { Color3.fromRGB(92, 138, 74), Color3.fromRGB(80, 124, 66) },
		Trunk = Color3.fromRGB(120, 96, 66),
	},
	Reef = {
		Rock = { Color3.fromRGB(214, 194, 150), Color3.fromRGB(200, 180, 138), Color3.fromRGB(188, 168, 128) },
		RockMaterial = Enum.Material.Sandstone,
		Cap = Color3.fromRGB(228, 214, 172),
		CapMaterial = Enum.Material.Sand,
		Peak = Color3.fromRGB(238, 226, 192),
		Tree = "Coral",
		Foliage = { Color3.fromRGB(240, 120, 128), Color3.fromRGB(250, 160, 84), Color3.fromRGB(84, 196, 190), Color3.fromRGB(196, 110, 200) },
		Trunk = Color3.fromRGB(230, 220, 200),
	},
	Mesa = {
		Rock = { Color3.fromRGB(172, 98, 66), Color3.fromRGB(186, 114, 76), Color3.fromRGB(156, 86, 58) },
		RockMaterial = Enum.Material.Sandstone,
		Cap = Color3.fromRGB(190, 150, 98),
		CapMaterial = Enum.Material.Ground,
		Peak = Color3.fromRGB(206, 140, 96),
		Tree = "DeadTree",
		Foliage = { Color3.fromRGB(150, 140, 80) },
		Trunk = Color3.fromRGB(110, 84, 62),
	},
	Bog = {
		Rock = { Color3.fromRGB(78, 86, 70), Color3.fromRGB(66, 74, 62), Color3.fromRGB(90, 94, 78) },
		RockMaterial = Enum.Material.Rock,
		Cap = Color3.fromRGB(88, 112, 58),
		CapMaterial = Enum.Material.LeafyGrass,
		Peak = Color3.fromRGB(112, 118, 100),
		Tree = "Mushroom",
		Foliage = { Color3.fromRGB(150, 92, 190), Color3.fromRGB(120, 196, 72) },
		Trunk = Color3.fromRGB(200, 196, 170),
	},
	Crystal = {
		Rock = { Color3.fromRGB(150, 172, 192), Color3.fromRGB(134, 156, 180), Color3.fromRGB(168, 188, 206) },
		RockMaterial = Enum.Material.Glacier,
		Cap = Color3.fromRGB(226, 236, 242),
		CapMaterial = Enum.Material.Snow,
		Peak = Color3.fromRGB(236, 244, 250),
		Tree = "Crystal",
		Foliage = { Color3.fromRGB(110, 210, 240), Color3.fromRGB(170, 130, 240), Color3.fromRGB(140, 236, 220) },
		Trunk = Color3.fromRGB(120, 130, 150),
	},
	Manor = {
		Rock = { Color3.fromRGB(78, 80, 92), Color3.fromRGB(68, 70, 82), Color3.fromRGB(90, 90, 100) },
		RockMaterial = Enum.Material.Slate,
		Cap = Color3.fromRGB(86, 94, 78),
		CapMaterial = Enum.Material.LeafyGrass,
		Peak = Color3.fromRGB(124, 126, 136),
		Tree = "DeadTree",
		Foliage = { Color3.fromRGB(70, 66, 74) },
		Trunk = Color3.fromRGB(64, 56, 54),
	},
	Dragon = {
		Rock = { Color3.fromRGB(66, 62, 62), Color3.fromRGB(78, 72, 70), Color3.fromRGB(56, 52, 54) },
		RockMaterial = Enum.Material.Basalt,
		Cap = Color3.fromRGB(236, 242, 248),
		CapMaterial = Enum.Material.Snow,
		Peak = Color3.fromRGB(244, 248, 252),
		Foliage = { Color3.fromRGB(44, 74, 60), Color3.fromRGB(38, 64, 54) },
		Trunk = Color3.fromRGB(70, 54, 44),
	},
}

-- Region 1 faces of the divider, the hub corner and the coast.
PALETTES.Boulder = {
	Rock = { Color3.fromRGB(118, 112, 104), Color3.fromRGB(104, 100, 94), Color3.fromRGB(130, 124, 114) },
	RockMaterial = Enum.Material.Rock,
	Cap = Color3.fromRGB(104, 142, 70),
	CapMaterial = Enum.Material.LeafyGrass,
	Peak = Color3.fromRGB(160, 156, 150),
	Foliage = { Color3.fromRGB(62, 112, 60), Color3.fromRGB(52, 98, 54) },
	Trunk = Color3.fromRGB(96, 72, 50),
}
PALETTES.Volt = {
	Rock = { Color3.fromRGB(122, 118, 102), Color3.fromRGB(110, 106, 92), Color3.fromRGB(134, 128, 110) },
	RockMaterial = Enum.Material.Rock,
	Cap = Color3.fromRGB(146, 148, 92),
	CapMaterial = Enum.Material.Grass,
	Peak = Color3.fromRGB(170, 166, 150),
	Tree = "DeadTree",
	Foliage = { Color3.fromRGB(150, 140, 80) },
	Trunk = Color3.fromRGB(104, 86, 64),
}
PALETTES.Ember = {
	Rock = { Color3.fromRGB(70, 62, 60), Color3.fromRGB(82, 70, 64), Color3.fromRGB(60, 54, 54) },
	RockMaterial = Enum.Material.Basalt,
	Cap = Color3.fromRGB(150, 70, 40),
	CapMaterial = Enum.Material.CrackedLava,
	Peak = Color3.fromRGB(96, 86, 82),
	Tree = "DeadTree",
	Foliage = { Color3.fromRGB(60, 50, 46) },
	Trunk = Color3.fromRGB(52, 44, 40),
}
PALETTES.Alpine = {
	Rock = { Color3.fromRGB(100, 104, 112), Color3.fromRGB(88, 92, 100), Color3.fromRGB(112, 116, 124) },
	RockMaterial = Enum.Material.Rock,
	Cap = Color3.fromRGB(236, 242, 248),
	CapMaterial = Enum.Material.Snow,
	Peak = Color3.fromRGB(244, 248, 252),
	Foliage = { Color3.fromRGB(44, 82, 62), Color3.fromRGB(38, 70, 56) },
	Trunk = Color3.fromRGB(80, 60, 44),
}
PALETTES.Sky = {
	Rock = { Color3.fromRGB(206, 200, 184), Color3.fromRGB(192, 186, 170), Color3.fromRGB(218, 212, 198) },
	RockMaterial = Enum.Material.Limestone,
	Cap = Color3.fromRGB(112, 176, 84),
	CapMaterial = Enum.Material.Grass,
	Peak = Color3.fromRGB(236, 240, 244),
	Foliage = { Color3.fromRGB(70, 140, 74), Color3.fromRGB(58, 124, 66) },
	Trunk = Color3.fromRGB(110, 84, 60),
}
PALETTES.Coast = {
	Rock = { Color3.fromRGB(176, 146, 108), Color3.fromRGB(160, 130, 96), Color3.fromRGB(190, 160, 120) },
	RockMaterial = Enum.Material.Sandstone,
	Cap = Color3.fromRGB(98, 160, 72),
	CapMaterial = Enum.Material.Grass,
	Peak = Color3.fromRGB(236, 242, 248),
	Foliage = { Color3.fromRGB(58, 118, 62), Color3.fromRGB(46, 101, 56) },
	Trunk = Color3.fromRGB(96, 72, 50),
}

-- Scenery ridge with no trail. Faces at least 32 studs inside the nearest lane wall: band fronts
-- and their sloped faces reach up to ~32 studs in front of Origin.
local function ridgeSpec(name, group, t)
	t.Name, t.Group = name, group
	t.Saddle = t.Saddle or 150
	t.Trail = false
	t.Attributes = t.Attributes or {}
	t.Attributes.MountainName = t.Attributes.MountainName or name:gsub("^Mountain_", "")
	return t
end

-- Divider between Region 1 (west, x < 76) and Region 2 (east, x > 384): one segment per lane pair.
local DIVIDER = {
	{ "Boulder", "Desert", "Boulder Pass", "Mirage Desert" },
	{ "Reef", "Reef", "Tide Coast", "Coral Reef" },
	{ "Volt", "Mesa", "Volt Plains", "Thunder Mesa" },
	{ "Ember", "Bog", "Ember Ridge", "Toxic Bog" },
	{ "Alpine", "Crystal", "Frost Peak", "Crystal Caverns" },
	{ "Manor", "Manor", "Shadow Woods", "Phantom Manor" },
	{ "Sky", "Dragon", "Sky Spire", "Dragon Peaks" },
}
local function dividerSpecs(list)
	for i, d in DIVIDER do
		local c = 560 + 520 * i
		table.insert(list, ridgeSpec("Mountain_Divider" .. i, "Divider", {
			Palette = d[1],
			Back = { Palette = d[2] },
			Seed = 100 + i,
			Origin = Vector3.new(108, 2, c),
			Facing = Vector3.new(1, 0, 0),
			Length = 520,
			Depth = 122,
			Advance = { 0.34, 0.56 },
			Saddle = 150,
			Peaks = { { A = (i % 2 == 0 and 1 or -1) * 120, H = 215, W = 160 }, { A = (i % 2 == 0 and -1 or 1) * 150, H = 190, W = 90 } },
			JoinEnds = { Low = i > 1, High = true },
			ClearTerrain = { Min = Vector3.new(80, 4, c - 260), Max = Vector3.new(380, 440, c + 260) },
			Attributes = { MountainName = d[3] .. " / " .. d[4] .. " Divide" },
		}))
	end
	table.insert(list, ridgeSpec("Mountain_Divider8", "Divider", {
		Palette = "Alpine",
		Back = { Palette = "Dragon" },
		Seed = 108,
		Origin = Vector3.new(108, 2, 4580),
		Facing = Vector3.new(1, 0, 0),
		Length = 240,
		Depth = 122,
		Advance = { 0.34, 0.56 },
		Saddle = 150,
		Peaks = { { A = 0, H = 205, W = 120 } },
		JoinEnds = { Low = true },
		ClearTerrain = { Min = Vector3.new(80, 4, 4460), Max = Vector3.new(380, 440, 4700) },
		Attributes = { MountainName = "Victory Road Divide" },
	}))
end

-- One east-side trail mountain per Region 2 route (lane centre z = 560 + 520 * (k - 9)).
local function eastSpec(lane, name, palette, seed, y, peaks, ground, attrs)
	local c = 560 + 520 * (lane - 9)
	attrs.Lane = "Lane" .. lane
	attrs.LookoutPrompt = attrs.LookoutPrompt or "Look out"
	attrs.SummitPrompt = attrs.SummitPrompt or "Survey Norven"
	return {
		Name = name,
		Group = "Region2",
		Palette = palette,
		Seed = seed,
		Origin = Vector3.new(562, y, c),
		Facing = Vector3.new(1, 0, 0),
		Length = 520,
		Depth = 334,
		Tiers = 8,
		Saddle = 110,
		Peaks = peaks,
		Trail = true,
		Lookouts = { 3, 6 },
		ClearTerrain = { Min = Vector3.new(524, y, c - 260), Max = Vector3.new(1000, 440, c + 260), Ground = 566, GroundMaterial = ground },
		Attributes = attrs,
	}
end

-- Origin is the base of the lane-facing cliff at the middle of the mountain; Facing points
-- into the mountain. Local coordinates: a = along the range, y = up, d = depth into the mountain.
Builder.Specs = {
	{
		Name = "Mountain_SunpetalFields",
		Group = "Region2",
		Palette = "Meadow",
		Seed = 9,
		Origin = Vector3.new(562, 2, 560),
		Facing = Vector3.new(1, 0, 0),
		Length = 520,
		Depth = 334,
		Tiers = 8,
		Saddle = 110,
		Peaks = { { A = 0, H = 290, W = 250 }, { A = -150, H = 225, W = 60 } },
		Trail = true,
		Lookouts = { 3, 6 },
		ClearTerrain = { Min = Vector3.new(524, 2, 300), Max = Vector3.new(1000, 440, 820), Ground = 566 },
		Attributes = {
			MountainName = "Sunpetal Crag",
			Lane = "Lane9",
			RouteName = "Sunpetal Fields",
			SummitName = "Sunpetal Crag Summit",
			SummitPrompt = "Survey Norven",
			SummitMessage = "You reached the top of Sunpetal Crag! Follow the trail back down to Sunpetal Fields.",
			LookoutPrompt = "Look out",
			Lookout1Name = "Windmill Ledge",
			Lookout1Message = "Windmill Ledge · The sunflower fields roll out below you.",
			Lookout2Name = "Falcon Rest",
			Lookout2Message = "Falcon Rest · Summit Town and the hub are in view to the north.",
		},
	},
	eastSpec(10, "Mountain_MirageDesert", "Desert", 10, 2, { { A = 0, H = 290, W = 230 }, { A = 170, H = 210, W = 70 } }, Enum.Material.Sand, {
		MountainName = "Mirage Butte",
		RouteName = "Mirage Desert",
		SummitName = "Mirage Butte Summit",
		SummitMessage = "You reached the top of Mirage Butte! The dunes shimmer all the way to the coast.",
		Lookout1Name = "Dune Watch",
		Lookout1Message = "Dune Watch · Heat haze ripples over the desert road.",
		Lookout2Name = "Vulture Perch",
		Lookout2Message = "Vulture Perch · The route winds between the dunes below.",
	}),
	eastSpec(11, "Mountain_CoralReef", "Reef", 11, 5, { { A = 0, H = 285, W = 240 }, { A = -165, H = 200, W = 60 } }, Enum.Material.Sand, {
		MountainName = "Shellback Bluff",
		RouteName = "Coral Reef",
		SummitName = "Shellback Bluff Summit",
		SummitMessage = "You reached the top of Shellback Bluff! The reef glitters in the shallows.",
		Lookout1Name = "Tidepool Ledge",
		Lookout1Message = "Tidepool Ledge · Coral blooms line the shore below.",
		Lookout2Name = "Gull Point",
		Lookout2Message = "Gull Point · Sea breeze and gulls overhead.",
	}),
	eastSpec(12, "Mountain_ThunderMesa", "Mesa", 12, 5, { { A = 0, H = 300, W = 260 }, { A = 160, H = 230, W = 80 }, { A = -175, H = 190, W = 50 } }, Enum.Material.Sandstone, {
		MountainName = "Stormcap Mesa",
		RouteName = "Thunder Mesa",
		SummitName = "Stormcap Mesa Summit",
		SummitMessage = "You reached the top of Stormcap Mesa! Thunderheads roll across the red rock.",
		Lookout1Name = "Red Rock Shelf",
		Lookout1Message = "Red Rock Shelf · The mesa road cuts through the canyon below.",
		Lookout2Name = "Lightning Ledge",
		Lookout2Message = "Lightning Ledge · Storm clouds gather over the mesas.",
	}),
	eastSpec(13, "Mountain_ToxicBog", "Bog", 13, 2, { { A = 0, H = 280, W = 220 }, { A = -150, H = 215, W = 70 } }, Enum.Material.Mud, {
		MountainName = "Mirebrow Hill",
		RouteName = "Toxic Bog",
		SummitName = "Mirebrow Hill Summit",
		SummitMessage = "You reached the top of Mirebrow Hill! Mist drifts over the bog below.",
		Lookout1Name = "Spore Shelf",
		Lookout1Message = "Spore Shelf · Glowing mushrooms dot the marsh.",
		Lookout2Name = "Fogwatch",
		Lookout2Message = "Fogwatch · The bog road vanishes into the haze.",
	}),
	eastSpec(14, "Mountain_CrystalCaverns", "Crystal", 14, 2, { { A = 0, H = 295, W = 240 }, { A = 165, H = 225, W = 60 } }, Enum.Material.Slate, {
		MountainName = "Glimmerspire",
		RouteName = "Crystal Caverns",
		SummitName = "Glimmerspire Summit",
		SummitMessage = "You reached the top of Glimmerspire! Crystals catch the light all around you.",
		Lookout1Name = "Frost Ledge",
		Lookout1Message = "Frost Ledge · Ice and crystal glint along the cavern route.",
		Lookout2Name = "Prism Point",
		Lookout2Message = "Prism Point · The whole valley sparkles below.",
	}),
	eastSpec(15, "Mountain_PhantomManor", "Manor", 15, 2, { { A = 0, H = 285, W = 230 }, { A = -160, H = 220, W = 70 }, { A = 175, H = 180, W = 45 } }, Enum.Material.Slate, {
		MountainName = "Gloomcrest",
		RouteName = "Phantom Manor",
		SummitName = "Gloomcrest Summit",
		SummitMessage = "You reached the top of Gloomcrest! The manor's towers loom through the gloom.",
		Lookout1Name = "Raven Ledge",
		Lookout1Message = "Raven Ledge · Crows circle over the old grounds.",
		Lookout2Name = "Lantern Watch",
		Lookout2Message = "Lantern Watch · Ghostly lights flicker on the road below.",
	}),
	eastSpec(16, "Mountain_DragonPeaks", "Dragon", 16, 2, { { A = 0, H = 305, W = 250 }, { A = 160, H = 240, W = 70 }, { A = -165, H = 230, W = 65 } }, Enum.Material.Basalt, {
		MountainName = "Wyrmspine",
		RouteName = "Dragon Peaks",
		SummitName = "Wyrmspine Summit",
		SummitMessage = "You reached the top of Wyrmspine! Snow and smoke drift across the dragon's peaks.",
		Lookout1Name = "Ember Ledge",
		Lookout1Message = "Ember Ledge · Dark basalt cliffs drop to the route below.",
		Lookout2Name = "Wyrm's Rest",
		Lookout2Message = "Wyrm's Rest · The peaks march off toward the champion's road.",
	}),
}

dividerSpecs(Builder.Specs)
-- Ridge east of the hub and Summit Town (hub wall ArmBound at x = 746), from the coast to Sunpetal Crag.
table.insert(Builder.Specs, ridgeSpec("Mountain_HubEastRidge", "Hub", {
	Palette = "Alpine",
	Seed = 31,
	Origin = Vector3.new(780, 0, 5),
	Facing = Vector3.new(1, 0, 0),
	Length = 590,
	Depth = 200,
	Advance = { 0.4, 0.62 },
	Saddle = 200,
	Peaks = { { A = -20, H = 300, W = 200 }, { A = 220, H = 250, W = 80 } },
	JoinEnds = { Low = true },
	ClearTerrain = { Min = Vector3.new(752, 0, -290), Max = Vector3.new(1000, 440, 300) },
	Attributes = { MountainName = "Hub East Ridge" },
}))
-- Coastal escarpment south of the hub: hub face (north, Alpine) and sea face (south, sandstone).
for i, x in { -270, 230, 730 } do
	table.insert(Builder.Specs, ridgeSpec("Mountain_Coast" .. ({ "West", "Centre", "East" })[i], "Coast", {
		Palette = "Alpine",
		Back = { Palette = "Coast", Drop = -6 },
		Seed = 40 + i,
		Origin = Vector3.new(x, 0, -285),
		Facing = Vector3.new(0, 0, -1),
		Length = 500,
		Depth = 165,
		Advance = { 0.4, 0.6 },
		Saddle = 220,
		Peaks = { { A = (i - 2) * 60, H = 300, W = 170 }, { A = 180 - i * 80, H = 260, W = 70 } },
		JoinEnds = { Low = true, High = i < 3 },
		ClearTerrain = { Min = Vector3.new(x - 250, -12, -650), Max = Vector3.new(x + 250, 440, -276) },
		Attributes = { MountainName = "Coastal Escarpment " .. ({ "West", "Centre", "East" })[i] },
	}))
end

local function checkEdit()
	local RunService = game:GetService("RunService")
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Edit tool only")
	assert(game.PlaceId == 94034385545160, "Cloud test place only")
end

local function specFor(name)
	for _, spec in Builder.Specs do
		if spec.Name == name then return spec end
	end
	error("No mountain spec named " .. tostring(name))
end

local function newPart(parent, name, size, cf, color, material, class)
	local p = Instance.new(class or "Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Anchored, p.Color, p.Material = true, color, material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function decor(p)
	p.CanCollide, p.CanTouch, p.CastShadow = false, false, true
	return p
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name, f.Parent = name, parent
	return f
end

local function sign(parent, name, cf, text)
	local p = decor(newPart(parent, name, Vector3.new(14, 5, 0.6), cf, Color3.fromRGB(55, 91, 82)))
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.CanvasSize, gui.Parent = face, Vector2.new(840, 300), p
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Font, label.TextSize = Enum.Font.FredokaOne, 34
		label.TextColor3 = Color3.fromRGB(255, 240, 204)
		label.TextWrapped, label.Text = true, text
		label.Parent = gui
	end
	return p
end

local function pine(parent, cf, scale, palette, rng)
	local tree = Instance.new("Model")
	tree.Name = "Pine"
	decor(newPart(tree, "Trunk", Vector3.new(1.6, 7, 1.6) * scale, cf * CFrame.new(0, 3.5 * scale, 0), palette.Trunk, Enum.Material.Wood))
	local green = palette.Foliage[rng:NextInteger(1, #palette.Foliage)]
	local y = 6 * scale
	for i, w in { 10, 7.5, 4.5 } do
		local h = (i == 3 and 4 or 5) * scale
		local yaw = CFrame.Angles(0, math.rad(45 + i * 12), 0)
		decor(newPart(tree, "Foliage", Vector3.new(w, h, w) * scale, cf * CFrame.new(0, y + h / 2, 0) * yaw, green, Enum.Material.Grass))
		y += h * 0.8
	end
	tree.Parent = parent
	return tree
end

-- Themed ledge decor. palette.Tree picks the kind; Pine is the default.
local DECOR = {}
function DECOR.Cactus(model, cf, scale, palette, rng)
	local green = palette.Foliage[rng:NextInteger(1, #palette.Foliage)]
	local h = rng:NextNumber(7, 11) * scale
	decor(newPart(model, "Stem", Vector3.new(1.8, h, 1.8) * Vector3.new(scale, 1, scale), cf * CFrame.new(0, h / 2, 0), green, Enum.Material.Grass))
	for _, side in { -1, 1 } do
		if rng:NextNumber() < 0.8 then
			local y, len = h * rng:NextNumber(0.35, 0.6), rng:NextNumber(3, 5) * scale
			decor(newPart(model, "Arm", Vector3.new(2.4 * scale, 1.2 * scale, 1.2 * scale), cf * CFrame.new(side * 1.6 * scale, y, 0), green, Enum.Material.Grass))
			decor(newPart(model, "Arm", Vector3.new(1.2, len, 1.2) * scale, cf * CFrame.new(side * 2.6 * scale, y + len / 2, 0), green, Enum.Material.Grass))
		end
	end
end
function DECOR.Coral(model, cf, scale, palette, rng)
	for _ = 1, rng:NextInteger(3, 5) do
		local color = palette.Foliage[rng:NextInteger(1, #palette.Foliage)]
		local h = rng:NextNumber(3, 7) * scale
		local tilt = CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), 0, math.rad(rng:NextNumber(-25, 25)))
		local base = cf * CFrame.new(rng:NextNumber(-2, 2) * scale, 0, rng:NextNumber(-2, 2) * scale) * tilt
		decor(newPart(model, "Branch", Vector3.new(1, h, 1) * Vector3.new(scale, 1, scale), base * CFrame.new(0, h / 2, 0), color, Enum.Material.Pebble))
		decor(newPart(model, "Tip", Vector3.new(1.6, 1.6, 1.6) * scale, base * CFrame.new(0, h, 0), color, Enum.Material.Pebble, "Part")).Shape = Enum.PartType.Ball
	end
end
function DECOR.Crystal(model, cf, scale, palette, rng)
	for i = 1, rng:NextInteger(3, 5) do
		local color = palette.Foliage[rng:NextInteger(1, #palette.Foliage)]
		local h = (i == 1 and rng:NextNumber(8, 12) or rng:NextNumber(3, 7)) * scale
		local w = (i == 1 and 2.4 or 1.4) * scale
		local tilt = CFrame.Angles(math.rad(rng:NextNumber(-22, 22)), math.rad(rng:NextNumber(0, 90)), math.rad(rng:NextNumber(-22, 22)))
		local base = cf * CFrame.new(rng:NextNumber(-2, 2) * scale, 0, rng:NextNumber(-2, 2) * scale) * tilt
		local shard = decor(newPart(model, "Shard", Vector3.new(w, h, w), base * CFrame.new(0, h / 2, 0), color, Enum.Material.Glass))
		shard.Transparency = 0.15
	end
end
function DECOR.Mushroom(model, cf, scale, palette, rng)
	for i = 1, rng:NextInteger(1, 3) do
		local s = scale * (i == 1 and 1 or rng:NextNumber(0.45, 0.7))
		local off = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
		local h = 5 * s
		decor(newPart(model, "Stalk", Vector3.new(1.4, h, 1.4) * Vector3.new(s, 1, s), cf * CFrame.new(off + Vector3.new(0, h / 2, 0)), palette.Trunk, Enum.Material.SmoothPlastic))
		local cap = decor(newPart(model, "Cap", Vector3.new(1.6, 6, 6) * s, cf * CFrame.new(off + Vector3.new(0, h, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			palette.Foliage[rng:NextInteger(1, #palette.Foliage)], Enum.Material.SmoothPlastic))
		cap.Shape = Enum.PartType.Cylinder
	end
end
function DECOR.DeadTree(model, cf, scale, palette, rng)
	local h = rng:NextNumber(8, 12) * scale
	decor(newPart(model, "Trunk", Vector3.new(1.4, h, 1.4) * Vector3.new(scale, 1, scale), cf * CFrame.new(0, h / 2, 0), palette.Trunk, Enum.Material.Wood))
	for _ = 1, rng:NextInteger(2, 3) do
		local y, len = h * rng:NextNumber(0.5, 0.9), rng:NextNumber(3, 5) * scale
		local branch = cf * CFrame.new(0, y, 0) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(35, 60)))
		decor(newPart(model, "Branch", Vector3.new(0.7, len, 0.7) * Vector3.new(scale, 1, scale), branch * CFrame.new(0, len / 2, 0), palette.Trunk, Enum.Material.Wood))
	end
end

local function ledgeDecor(parent, cf, scale, palette, rng)
	local build = palette.Tree and DECOR[palette.Tree]
	if not build then return pine(parent, cf, scale, palette, rng) end
	local model = Instance.new("Model")
	model.Name = palette.Tree
	build(model, cf, scale, palette, rng)
	model.Parent = parent
	return model
end

-- Builds one cliff block plus its grass cap. Returns the block so callers can seat decor on it.
local function rockBlock(ctx, name, a0, a1, top, front, yaw, bottom)
	bottom = bottom or -4
	local depth = ctx.depth - front
	local height = top - CAP - bottom
	local cf = ctx.frame * CFrame.new((a0 + a1) / 2, (top - CAP + bottom) / 2, -(front + depth / 2)) * CFrame.Angles(0, yaw, 0)
	local color = ctx.palette.Rock[ctx.rng:NextInteger(1, #ctx.palette.Rock)]
	local block = newPart(ctx.cliff, name, Vector3.new(a1 - a0, height, depth), cf, color, ctx.palette.RockMaterial)
	local capCf = cf * CFrame.new(0, height / 2 + CAP / 2, 0.6)
	newPart(ctx.cliff, name .. "Cap", Vector3.new(a1 - a0 + 1.2, CAP, depth + 1.2), capCf, ctx.palette.Cap, ctx.palette.CapMaterial)
	return block
end

-- Ridge height along the range: smooth peaks over a saddle, so neighbours read as separate peaks.
local function profile(spec, a)
	local h = spec.Saddle
	for _, p in spec.Peaks do
		local t = math.clamp(1 - math.abs(a - p.A) / p.W, 0, 1)
		h = math.max(h, spec.Saddle + (p.H - spec.Saddle) * t * t * (3 - 2 * t))
	end
	return h
end

-- One irregular column of stacked cliff bands. Each band gets a sloped face (a WedgePart)
-- and a grass ledge; band heights differ per column so no ledge line runs the whole range.
-- Band ends that stand above the neighbouring column (lowH / highH) get sloped sides too.
local function slope(ctx, name, size, cf, grassy)
	local palette = ctx.palette
	local p = newPart(ctx.cliff, name, size, cf, palette.Rock[ctx.rng:NextInteger(1, #palette.Rock)], palette.RockMaterial, "WedgePart")
	if grassy then p.Color, p.Material = palette.Cap, palette.CapMaterial end
	return p
end

local function column(ctx, a0, a1, height, lowH, highH)
	local rng = ctx.rng
	local y, front, room = 0, rng:NextNumber(-10, 6), 24
	local yaw = math.rad(rng:NextNumber(-6, 6))
	local run = rng:NextNumber(12, 22)
	while y < height - 10 and front < ctx.depth - 40 do
		local h = math.min(rng:NextNumber(28, 44), height - y)
		if height - (y + h) < 14 then h = height - y end
		local top = y + h
		-- Mountain ends (neighbour height 0) get longer slopes so neighbours meet in a saddle.
		local function sideRun(neighbour)
			if top <= neighbour + 6 then return 0 end
			return math.min(neighbour == 0 and rng:NextNumber(20, 32) or rng:NextNumber(10, 20), (a1 - a0) / 2.5)
		end
		local runLow, runHigh = sideRun(lowH), sideRun(highH)
		local block = rockBlock(ctx, "Band", a0 + runLow, a1 - runHigh, top, front, yaw + math.rad(rng:NextNumber(-3, 3)), y - 6)
		local faceH = h - CAP
		-- WedgeParts slope down toward their local -Z, so turn each one to face out of the cliff.
		slope(ctx, "Face", Vector3.new(block.Size.X * 0.98, faceH, run),
			block.CFrame * CFrame.new(0, 3, block.Size.Z / 2 + run / 2) * CFrame.Angles(0, math.pi, 0), y > 0 and rng:NextNumber() < 0.3)
		for _, e in { { -1, runLow }, { 1, runHigh } } do
			local sgn, r = e[1], e[2]
			if r > 0 then
				slope(ctx, "Side", Vector3.new(block.Size.Z, faceH, r),
					block.CFrame * CFrame.new(sgn * (block.Size.X / 2 + r / 2), 3, 0) * CFrame.Angles(0, sgn > 0 and -math.pi / 2 or math.pi / 2, 0))
			end
		end
		local advance = h * rng:NextNumber(ctx.advance[1], ctx.advance[2])
		room = advance - 4
		run = math.min(room, room * rng:NextNumber(0.45, 0.8))
		local ledge = advance - run
		if top < height - 10 and ledge > 8 and rng:NextNumber() < 0.7 then
			for _ = 1, rng:NextInteger(1, 2) do
				local x = rng:NextNumber(-block.Size.X / 2 + 6, block.Size.X / 2 - 6)
				local seat = block.CFrame * CFrame.new(x, block.Size.Y / 2 + CAP, block.Size.Z / 2 - rng:NextNumber(3, ledge - 4))
				ledgeDecor(ctx.decor, CFrame.new(seat.Position) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.8, 1.3), ctx.palette, rng)
			end
		end
		y, front = top, front + advance
	end
	table.insert(ctx.tops, { a0 = a0, a1 = a1, top = y })
end

-- Lowest column top at a: columns can stop short of the profile on a narrow ridge, and seating a crag on the lower of two overlapping columns keeps it from floating.
local function builtTop(ctx, a)
	local best
	for _, t in ctx.tops do
		if a >= t.a0 and a <= t.a1 then best = math.min(best or math.huge, t.top) end
	end
	return best
end

local function buildCliff(ctx, spec)
	local rng, n = ctx.rng, spec.Tiers
	if spec.Trail then
		-- The trail climbs cut terraces: exact bands so ramps, ledges and decks line up.
		for k = 1, n do
			local block = rockBlock(ctx, "Tier" .. k, -TRAIL_ZONE, TRAIL_ZONE, TIER * k, LEDGE * (k - 1), 0)
			-- Sloped faces only outside the ramps (|a| > 52), which lean on the vertical face.
			for _, sgn in { -1, 1 } do
				local len = TRAIL_ZONE - 54
				slope(ctx, "Face", Vector3.new(len, TIER - CAP, 14),
					block.CFrame * CFrame.new(sgn * (54 + len / 2), block.Size.Y / 2 - (TIER - CAP) / 2, block.Size.Z / 2 + 7) * CFrame.Angles(0, math.pi, 0))
			end
			if k < n then
				-- Boulders on the unused half of each ledge break up the terrace line.
				local dir = k % 2 == 1 and 1 or -1
				for _ = 1, 2 do
					local size = Vector3.new(rng:NextNumber(9, 15), rng:NextNumber(6, 11), rng:NextNumber(8, 12))
					local cf = ctx.frame * CFrame.new(-dir * rng:NextNumber(62, 84), TIER * k + size.Y / 2 - 2, -(LEDGE * (k - 1) + rng:NextNumber(3, 6)))
						* CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), math.rad(rng:NextNumber(0, 90)), math.rad(rng:NextNumber(-12, 12)))
					newPart(ctx.cliff, "Boulder", size, cf, ctx.palette.Rock[rng:NextInteger(1, #ctx.palette.Rock)], ctx.palette.RockMaterial)
				end
			end
		end
	end
	local half = spec.Length / 2
	for _, side in { -1, 1 } do
		-- Lay out the columns first so each one knows how tall its neighbours are.
		local cols, a = {}, spec.Trail and TRAIL_ZONE - 6 or 0
		while a < half do
			local len = math.min(rng:NextNumber(38, 72), half - a)
			if half - (a + len) < 24 then len = half - a end
			local mid = side * (a + len / 2)
			table.insert(cols, { a = a, b = math.min(a + len + 4, half), h = profile(spec, mid) + rng:NextNumber(-14, 10) })
			a += len
		end
		for i, c in cols do
			local inner = i == 1 and (spec.Trail and math.huge or c.h) or cols[i - 1].h
			-- A joined end runs flat into the next mountain instead of sloping down to a saddle.
			local joined = ctx.join[side > 0 and "High" or "Low"]
			local outer = cols[i + 1] and cols[i + 1].h or (joined and c.h or 0)
			if side > 0 then
				column(ctx, c.a, c.b, c.h, inner, outer)
			else
				column(ctx, -c.b, -c.a, c.h, outer, inner)
			end
			task.wait()
		end
	end
	-- Summit crags behind the summit ledge.
	local summitTop = spec.Trail and TIER * n or profile(spec, 0)
	for i = 1, 4 do
		local w, d = rng:NextNumber(26, 44), rng:NextNumber(30, 50)
		local h = rng:NextNumber(22, 50)
		local a = (i - 2.5) * 34 + rng:NextNumber(-8, 8)
		local base = spec.Trail and summitTop or (builtTop(ctx, a) or summitTop)
		local cf = ctx.frame * CFrame.new(a, base + h / 2 - 6, -(ctx.depth - d / 2 - rng:NextNumber(0, 16)))
			* CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), math.rad(rng:NextNumber(-20, 20)), math.rad(rng:NextNumber(-6, 6)))
		local crag = newPart(ctx.summit, "Crag", Vector3.new(w, h, d), cf, ctx.palette.Rock[rng:NextInteger(1, #ctx.palette.Rock)], ctx.palette.RockMaterial)
		newPart(ctx.summit, "CragCap", Vector3.new(w + 1, 1.4, d + 1), crag.CFrame * CFrame.new(0, h / 2 + 0.7, 0), ctx.palette.Peak, ctx.palette.RockMaterial)
	end
end

local function fence(parent, cf, length)
	return newPart(parent, "Fence", Vector3.new(0.6, 3, length), cf, RAIL, Enum.Material.WoodPlanks)
end

local function post(parent, frame, a, d, y0, y1)
	if y1 - y0 < 1 then return end
	newPart(parent, "Support", Vector3.new(1.2, y1 - y0, 1.2), frame * CFrame.new(a, (y0 + y1) / 2, -d), WOOD, Enum.Material.Wood)
end

local function buildTrail(ctx, spec)
	local frame, paths = ctx.frame, ctx.paths
	local outward = frame.ZVector -- local +Z points out of the mountain, toward the lane
	for k = 1, spec.Tiers do
		local dir = k % 2 == 1 and 1 or -1
		local y0, y1, front = TIER * (k - 1), TIER * k, LEDGE * (k - 1)
		local bottom = (frame * CFrame.new(-dir * RAMP_HALF, y0, -(front - RAMP_W / 2))).Position
		local top = (frame * CFrame.new(dir * RAMP_HALF, y1, -(front - RAMP_W / 2))).Position
		local length = (top - bottom).Magnitude
		local rampCf = CFrame.lookAt((bottom + top) / 2, top) * CFrame.new(0, -0.5, 0)
		local ramp = newPart(paths, "Ramp" .. k, Vector3.new(RAMP_W, 1, length + 1), rampCf, WOOD, Enum.Material.WoodPlanks)
		ramp:SetAttribute("Order", k)
		fence(paths, rampCf.Rotation + rampCf.Position + outward * (RAMP_W / 2 - 0.3) + rampCf.UpVector * 2, length + 1)
		local padA = dir * (RAMP_HALF + PAD / 2)
		local pad = newPart(paths, "Landing" .. k, Vector3.new(PAD, 1, RAMP_W), frame * CFrame.new(padA, y1 - 0.5, -(front - RAMP_W / 2)), WOOD, Enum.Material.WoodPlanks)
		pad:SetAttribute("Order", k)
		fence(paths, frame * CFrame.new(padA, y1 + 1.5, -(front - RAMP_W + 0.3)) * CFrame.Angles(0, math.pi / 2, 0), PAD)
		fence(paths, frame * CFrame.new(dir * (RAMP_HALF + PAD - 0.3), y1 + 1.5, -(front - RAMP_W / 2)), RAMP_W)
		-- Timber supports from the ledge below up to the ramp and landing.
		for _, t in { 0.4, 0.75 } do
			post(paths, frame, dir * RAMP_HALF * (2 * t - 1), front - RAMP_W + 1, y0, y0 + (y1 - y0) * t - 1)
		end
		post(paths, frame, dir * (RAMP_HALF + PAD - 1), front - RAMP_W + 1, y0, y1 - 1)
		post(paths, frame, dir * (RAMP_HALF + 1), front - RAMP_W + 1, y0, y1 - 1)
	end
	local attrs = spec.Attributes
	local entrance = sign(paths, "EntranceSign", frame * CFrame.new(16, 6, 18), attrs.MountainName .. " · Summit Trail\nFollow the switchbacks · return the same way")
	for _, x in { -6.5, 6.5 } do
		newPart(paths, "SignPost", Vector3.new(0.8, 6, 0.8), entrance.CFrame * CFrame.new(x, -3, 0), WOOD, Enum.Material.Wood)
	end
end

local function marker(parent, name, kind, cf, size)
	local p = newPart(parent, name, size, cf, Color3.fromRGB(196, 160, 82), Enum.Material.Metal)
	p.CanCollide, p.CanTouch = false, false
	p:SetAttribute("MountainMarker", kind)
	return p
end

local function buildLookouts(ctx, spec)
	local frame = ctx.frame
	for i, k in spec.Lookouts or {} do
		local dir = k % 2 == 1 and 1 or -1
		local y, front = TIER * k, LEDGE * (k - 1)
		local deck = Instance.new("Model")
		deck.Name = "Lookout" .. i .. "Deck"
		local a = dir * 75
		newPart(deck, "Deck", Vector3.new(22, 1, 14), frame * CFrame.new(a, y - 0.3, -(front - 1)), WOOD, Enum.Material.WoodPlanks)
		fence(deck, frame * CFrame.new(a, y + 1.7, -(front - 7.7)) * CFrame.Angles(0, math.pi / 2, 0), 22)
		for _, side in { -1, 1 } do
			fence(deck, frame * CFrame.new(a + side * 10.7, y + 1.7, -(front - 4)), 8)
			post(deck, frame, a + side * 10, front - 7, y - TIER, y - 0.8)
		end
		local stand = marker(deck, "Lookout" .. i, "Lookout", frame * CFrame.new(a, y + 2.2, -(front - 5)), Vector3.new(1, 4.5, 1))
		decor(newPart(deck, "Scope", Vector3.new(1.1, 1.1, 3.2), stand.CFrame * CFrame.new(0, 2.6, 0.6) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(70, 74, 84), Enum.Material.Metal))
		deck.Parent = ctx.lookouts
	end
end

local function buildSummit(ctx, spec)
	local frame, n = ctx.frame, spec.Tiers
	local y, front = TIER * n, LEDGE * (n - 1)
	newPart(ctx.summit, "SummitDeck", Vector3.new(28, 1, 22), frame * CFrame.new(0, y - 0.3, -(front + 15)), WOOD, Enum.Material.WoodPlanks)
	fence(ctx.summit, frame * CFrame.new(0, y + 1.7, -(front + 4.3)) * CFrame.Angles(0, math.pi / 2, 0), 28)
	local cairn = newPart(ctx.summit, "Cairn", Vector3.new(4, 3, 4), frame * CFrame.new(0, y + 1.5, -(front + 20)), ctx.palette.Peak, ctx.palette.RockMaterial)
	marker(ctx.summit, "SummitMarker", "Summit", cairn.CFrame * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, math.rad(30), 0), Vector3.new(2.6, 2, 2.6)).Color = ctx.palette.Peak
	local pole = decor(newPart(ctx.summit, "FlagPole", Vector3.new(0.4, 12, 0.4), cairn.CFrame * CFrame.new(1.4, 7.5, 1.4), Color3.fromRGB(230, 230, 230), Enum.Material.Metal))
	decor(newPart(ctx.summit, "Flag", Vector3.new(0.2, 3, 5), pole.CFrame * CFrame.new(0, 4.4, -2.6), Color3.fromRGB(232, 179, 60), Enum.Material.Fabric))
end

function Builder.clearTerrain(name)
	checkEdit()
	local spec = specFor(name)
	local c = assert(spec.ClearTerrain, "Spec has no terrain clearing box")
	local terrain = workspace.Terrain
	-- Clear in 104-stud slices along the longer side so each FillBlock stays small.
	local alongX = c.Max.X - c.Min.X > c.Max.Z - c.Min.Z
	local from, to = alongX and c.Min.X or c.Min.Z, alongX and c.Max.X or c.Max.Z
	for s0 = from, to - 1, 104 do
		local s1 = math.min(s0 + 104, to)
		local min = alongX and Vector3.new(s0, c.Min.Y, c.Min.Z) or Vector3.new(c.Min.X, c.Min.Y, s0)
		local max = alongX and Vector3.new(s1, c.Max.Y, c.Max.Z) or Vector3.new(c.Max.X, c.Max.Y, s1)
		terrain:FillBlock(CFrame.new((min + max) / 2), max - min, Enum.Material.Air)
		if c.Ground then
			-- Flat floor (the lane's own ground material) in front of an east cliff so the trail entrance has no step.
			local strip = Vector3.new(c.Ground - c.Min.X, 6, max.Z - min.Z)
			terrain:FillBlock(CFrame.new(c.Min.X + strip.X / 2, c.Min.Y - 3, (min.Z + max.Z) / 2), strip, c.GroundMaterial or Enum.Material.Grass)
		end
		task.wait()
	end
	return true
end

-- Builds the named mountain if it is missing. Returns the model and whether it was created.
function Builder.build(name)
	checkEdit()
	local spec = specFor(name)
	local map = workspace.Map
	local root = map:FindFirstChild("Mountains") or folder(map, "Mountains")
	local group = root:FindFirstChild(spec.Group) or folder(root, spec.Group)
	local existing = group:FindFirstChild(spec.Name)
	if existing then return existing, false end
	local model = Instance.new("Model")
	model.Name = spec.Name
	local into = spec.Facing.Unit
	local along = into:Cross(Vector3.yAxis)
	local frame = CFrame.fromMatrix(spec.Origin, along, Vector3.yAxis, -into)
	local ctx = {
		frame = frame,
		depth = spec.Depth,
		rng = Random.new(spec.Seed),
		palette = PALETTES[spec.Palette],
		cliff = folder(model, "Cliff"),
		paths = folder(model, "Paths"),
		lookouts = folder(model, "Lookouts"),
		summit = folder(model, "Summit"),
		decor = folder(model, "Decor"),
		advance = spec.Advance or { 0.62, 0.95 },
		join = spec.JoinEnds or {},
		tops = {},
	}
	local pivot = newPart(model, "MountainPivot", Vector3.new(4, 1, 4), frame * CFrame.new(0, -0.5, 0), Color3.new(1, 1, 1))
	pivot.Transparency, pivot.CanCollide, pivot.CanQuery, pivot.CanTouch = 1, false, false, false
	model.PrimaryPart = pivot
	for key, value in spec.Attributes do model:SetAttribute(key, value) end
	model:SetAttribute("BuiltBy", "MountainPartBuilder")
	model:SetAttribute("BuildVersion", 1)
	buildCliff(ctx, spec)
	if spec.Back then
		-- Two-faced ridge: the far face mirrors the near one, Depth * 2 further in, with its own palette.
		ctx.frame = frame * CFrame.new(0, spec.Back.Drop or 0, -2 * spec.Depth) * CFrame.Angles(0, math.pi, 0)
		ctx.palette = PALETTES[spec.Back.Palette]
		ctx.tops = {}
		ctx.join = { Low = ctx.join.High, High = ctx.join.Low }
		local back = table.clone(spec)
		back.Peaks = {}
		for _, p in spec.Peaks do table.insert(back.Peaks, { A = -p.A, H = p.H, W = p.W }) end
		buildCliff(ctx, back)
	end
	if spec.Trail then
		buildTrail(ctx, spec)
		buildLookouts(ctx, spec)
		buildSummit(ctx, spec)
	end
	model.Parent = group
	game:GetService("ChangeHistoryService"):SetWaypoint("Built " .. spec.Name)
	return model, true
end

return Builder
