--[[
	RegionStyle: the look of every route, as data. Overhaul Phase 2 (2026-11-10).

	`spec` is the StyleSpec measured from Meadow Route (see claude/audit.md): road and verge widths, decor
	density per 100 studs, spacing off the road, and where the three route trainers stand. `lanes` holds one
	theme per route (palette, terrain materials, decor set). RegionPaths.fromStyle turns a theme into the full
	road and land entry that RegionTerrainBuilder, RegionDecorator and RegionPathValidator read, so a route
	only needs a theme here. Meadow (Lane1) keeps its hand-written entry in RegionPaths and is the reference.

	Change a route's look: edit its theme below, then in the command bar (Edit mode)
	  require(game.ServerStorage.RegionRollout).run("Lane9")
	Lighting is one global set (NPCAnimator); per-route mood comes from materials, palette and decor.
]]

local RegionStyle = {}

-- Measured from Meadow Route. Depths run 0 (route entrance) to 1 (gym).
RegionStyle.spec = {
	laneLength = 520,
	laneWidth = 130, -- walls at +-65 from the lane centre
	road = { width = 16, verge = 12, shoulder = 20, maxSlopeDeg = 10 },
	-- route trainers: depth along the lane and side of the road (+1 east of the road, -1 west)
	trainers = {
		{ depth = 120 / 520, side = 1 }, -- open ground near the entrance
		{ depth = 290 / 520, side = -1 }, -- at the change into the middle zone
		{ depth = 420 / 520, side = 1 }, -- deep in the last zone, before the gym
	},
	trainerOffset = 14, -- studs from the road centre (on the verge)
	trainerClear = 9, -- no decor within this many studs of a trainer
	-- decor bands, studs from the road centre, and how often each role repeats along the road
	-- (Meadow per 100 studs: ~14 trees, ~14 bushes, ~95 flowers, ~6.5 rocks, ~5 mushrooms, ~5 fence runs)
	roles = {
		cover = { scatter = true, perHundred = 70, minOffset = 13, maxOffset = 58 }, -- loose flowers, tufts, shells
		cover2 = { scatter = true, perHundred = 30, minOffset = 13, maxOffset = 58 },
		verge = { offset = 10.5, every = 12, sides = "alternate", jitter = 1 }, -- low things at the road edge
		bush = { offset = 22, every = 14, sides = "alternate", jitter = 2 },
		mid = { offset = 29, every = 30, sides = "alternate", jitter = 4 },
		tree = { offset = 37, every = 16, sides = "both", jitter = 4 },
		far = { offset = 52, every = 44, sides = "alternate", jitter = 5 }, -- landmarks near the walls
		fence = { kind = "fence", offset = 9.5, every = 28, length = 12, sides = "both" },
	},
	zoneNames = { "entrance", "middle", "approach" }, -- depth 0-0.35, 0.35-0.65, 0.65-1
	hills = { 7, 13, 19 }, -- rolling land height over the road per zone (Meadow)
	boundary = { height = 64, width = 72, minWall = 30 },
}

-- Where each region's lanes are (GameData.Arms): centre x, first lane start z, road surface y,
-- the gym floor height (terrain stays under it), and old floor tops terrain must not sit level with.
RegionStyle.regions = {
	[1] = { x = 0, start = 250, roadY = 0.4, gymFloorY = -0.4, avoidY = { 0 } },
	[2] = { x = 460, start = 300, roadY = 1.0, gymFloorY = 0.6, avoidY = { 0 } },
}

-- Gym boxes (centre z; every gym is 38 x 30 studs at the lane centre x). From the audit, 2026-11-10.
-- Old parts that are features, not floor: kept and protected (terrain held under them), never stashed.
RegionStyle.keepParts = { "Sea", "Surf", "Foam", "Lagoon", "LavaRiver", "LavaPool", "Pool", "Lake", "Oasis", "TidePool", "ToxicPool", "FrozenPond", "Pier", "Deck" }
-- Old floor stripes and lane ground: stashed even when they poke a little past the bounds.
RegionStyle.stashNames = { "^Path$", "^PathDirt$", "^Ground_", "Blend_", "^TownPath$", "^PassFloor$" }

local M = Enum.Material

-- One theme per route. order = position along its region's road (0 = first lane).
-- palette colours tint the route's gate (NPCAnimator) and are the reference for future props.
-- decor: { role, template (dotted path under Workspace), from, to (depth band, optional) }
RegionStyle.lanes = {
	Lane1B = {
		name = "Boulder Pass", region = 1, order = 1, seed = 21, gymZ = 1264,
		palette = { primary = Color3.fromRGB(122, 112, 98), accent = Color3.fromRGB(152, 138, 112), trim = Color3.fromRGB(88, 102, 84) },
		ground = M.Ground, accent = M.Rock, under = M.Ground, cliff = M.Rock, peak = M.Slate, road = M.Cobblestone,
		-- Glimmer Cavern: the cave plateau (parts) over the road, z ~915-1195, stays as built
		keepClear = { { name = "GlimmerCavern", minX = -78, maxX = 78, minZ = 912, maxZ = 1196, floorY = 0.0, margin = 6 } },
		decor = {
			{ "cover", "Map.Decor.BoulderPass.Flower" },
			{ "verge", "Map.Decor.ShadowWoods.GlowMushrooms" },
			{ "bush", "Map.Decor.Bushes.FlowerBush", 0, 0.3 },
			{ "mid", "Map.Decor.Rocks.Boulder" },
			{ "tree", "Map.Decor.Trees.OakTree", 0, 0.3 },
			{ "far", "Map.Decor.BoulderPass.Spire" },
		},
	},
	Lane3 = {
		name = "Tide Coast", region = 1, order = 2, seed = 31, gymZ = 1787,
		palette = { primary = Color3.fromRGB(226, 205, 150), accent = Color3.fromRGB(64, 160, 196), trim = Color3.fromRGB(240, 240, 228) },
		ground = M.Sand, accent = M.LeafyGrass, accentAt = 0.78, under = M.Sandstone, cliff = M.Sandstone, peak = M.LeafyGrass, road = M.WoodPlanks,
		boundaryRock = M.Sandstone,
		decor = {
			{ "cover", "Map.Decor.Fresh_TideCoast.Starfish" },
			{ "cover2", "Map.Decor.TideCoast.Shell" },
			{ "verge", "Map.Decor.Fresh_TideCoast.Sandcastle" },
			{ "bush", "Map.Decor.Fresh_TideCoast.Dune" },
			{ "mid", "Map.Decor.TideCoast.Rock" },
			{ "tree", "Map.Decor.Fresh_TideCoast.Palm" },
			{ "far", "Map.Decor.Fresh_TideCoast.BeachHut" },
			{ "far", "Map.Decor.Fresh_TideCoast.LifeguardTower", 0.3, 0.7 },
		},
	},
	Lane4 = {
		name = "Volt Plains", region = 1, order = 3, seed = 41, gymZ = 2307,
		palette = { primary = Color3.fromRGB(150, 170, 92), accent = Color3.fromRGB(255, 214, 64), trim = Color3.fromRGB(70, 74, 86) },
		ground = M.Grass, accent = M.Ground, under = M.Ground, cliff = M.Rock, peak = M.Slate, road = M.Asphalt,
		decor = {
			{ "cover", "Map.Decor.Fresh_VoltPlains.Flowers" },
			{ "cover2", "Map.Decor.VoltPlains.TallGrass" },
			{ "verge", "Map.Decor.Fresh_VoltPlains.VoltCrystal" },
			{ "bush", "Map.Decor.VoltPlains.TallGrass" },
			{ "mid", "Map.Decor.Fresh_VoltPlains.TeslaCoil" },
			{ "tree", "Map.Decor.Fresh_VoltPlains.SolarArray" },
			{ "far", "Map.Decor.Fresh_VoltPlains.WindTurbine" },
			{ "far", "Map.Decor.Fresh_VoltPlains.Generator", 0.2, 0.8 },
		},
	},
	Lane2 = {
		name = "Ember Ridge", region = 1, order = 4, seed = 51, gymZ = 2827,
		palette = { primary = Color3.fromRGB(58, 50, 50), accent = Color3.fromRGB(255, 120, 40), trim = Color3.fromRGB(196, 52, 34) },
		ground = M.Basalt, accent = M.CrackedLava, accentAt = 0.72, under = M.Basalt, cliff = M.Basalt, peak = M.CrackedLava, road = M.Slate,
		boundaryRock = M.Basalt,
		decor = {
			{ "cover", "Map.Decor.Fresh_EmberRidge.GlowRock" },
			{ "verge", "Map.Decor.EmberRidge.VolcanicRock" },
			{ "bush", "Map.Decor.Fresh_EmberRidge.Spires" },
			{ "mid", "Map.Decor.Fresh_EmberRidge.LavaPool" },
			{ "tree", "Map.Decor.Fresh_EmberRidge.DeadTree" },
			{ "far", "Map.Decor.EmberRidge.Volcano" },
		},
	},
	Lane5 = {
		name = "Frost Peak", region = 1, order = 5, seed = 61, gymZ = 3347,
		palette = { primary = Color3.fromRGB(232, 240, 248), accent = Color3.fromRGB(140, 196, 232), trim = Color3.fromRGB(90, 110, 140) },
		ground = M.Snow, accent = M.Glacier, accentAt = 0.74, under = M.Ice, cliff = M.Rock, peak = M.Snow, road = M.Slate,
		decor = {
			{ "cover", "Map.Decor.FrostPeak.Snowball" },
			{ "verge", "Map.Decor.Fresh_FrostPeak.IceCrystals" },
			{ "bush", "Map.Decor.Fresh_FrostPeak.SnowMound" },
			{ "mid", "Map.Decor.Fresh_FrostPeak.Snowman" },
			{ "tree", "Map.Decor.Fresh_FrostPeak.Pine" },
			{ "far", "Map.Decor.Fresh_FrostPeak.Igloo" },
		},
	},
	Lane6 = {
		name = "Shadow Woods", region = 1, order = 6, seed = 71, gymZ = 3868,
		palette = { primary = Color3.fromRGB(46, 58, 52), accent = Color3.fromRGB(120, 220, 170), trim = Color3.fromRGB(30, 34, 40) },
		ground = M.LeafyGrass, accent = M.Mud, under = M.Ground, cliff = M.Rock, peak = M.Slate, road = M.Ground,
		decor = {
			{ "cover", "Map.Decor.Fresh_ShadowWoods.GlowShrooms" },
			{ "verge", "Map.Decor.ShadowWoods.GlowMushrooms" },
			{ "bush", "Map.Decor.Fresh_ShadowWoods.Lantern" },
			{ "mid", "Map.Decor.ShadowWoods.Standing Stone" },
			{ "tree", "Map.Decor.Fresh_ShadowWoods.TwistedTree" },
			{ "far", "Map.Decor.Fresh_ShadowWoods.Graveyard" },
		},
	},
	Lane7 = {
		name = "Sky Spire", region = 1, order = 7, seed = 81, gymZ = 4387,
		palette = { primary = Color3.fromRGB(236, 236, 244), accent = Color3.fromRGB(150, 200, 255), trim = Color3.fromRGB(255, 220, 120) },
		ground = M.Grass, accent = M.Limestone, accentAt = 0.7, under = M.Limestone, cliff = M.Limestone, peak = M.Marble, road = M.Marble,
		boundaryRock = M.Limestone,
		decor = {
			{ "cover", "Map.Decor.Fresh_TideCoast.Starfish" },
			{ "verge", "Map.Decor.SkySpire.FloatStone" },
			{ "bush", "Map.Decor.Fresh_SkySpire.RainbowCloud" },
			{ "mid", "Map.Decor.SkySpire.PillarCap" },
			{ "tree", "Map.Decor.SkySpire.Pillar" },
			{ "far", "Map.Decor.Fresh_SkySpire.FloatingIsland" },
		},
	},
	Lane9 = {
		name = "Sunpetal Fields", region = 2, order = 0, seed = 91, gymZ = 793,
		palette = { primary = Color3.fromRGB(120, 176, 84), accent = Color3.fromRGB(255, 206, 60), trim = Color3.fromRGB(150, 110, 70) },
		ground = M.Grass, accent = M.LeafyGrass, accentAt = 0.62, under = M.Ground, cliff = M.Rock, peak = M.Grass, road = M.Ground,
		decor = {
			{ "cover", "Map.Decor.Region2Fill.Lane9.FlowerPatch" },
			{ "cover2", "Map.Decor.Region2Fill.Lane9.Sunflower" },
			{ "fence", "", 0.02, 0.6 },
			{ "bush", "Map.Decor.Region2.Lane9.Hedge" },
			{ "mid", "Map.Decor.Region2Fill.Lane9.HayBale" },
			{ "tree", "Map.Decor.Region2Fill.Lane9.Birch" },
			{ "far", "Map.Decor.Region2Fill.Lane9.Windmill" },
			{ "far", "Map.Decor.Region2.Lane9.GiantFlower", 0.5, 1 },
		},
	},
	Lane10 = {
		name = "Mirage Desert", region = 2, order = 1, seed = 101, gymZ = 1313,
		palette = { primary = Color3.fromRGB(230, 200, 140), accent = Color3.fromRGB(196, 120, 70), trim = Color3.fromRGB(80, 150, 110) },
		ground = M.Sand, accent = M.Sandstone, accentAt = 0.7, under = M.Sandstone, cliff = M.Sandstone, peak = M.Sandstone, road = M.Sandstone,
		boundaryRock = M.Sandstone,
		decor = {
			{ "cover", "Map.Decor.Region2Fill.Lane10.Bones" },
			{ "verge", "Map.Decor.Region2Fill.Lane10.SandRock" },
			{ "bush", "Map.Decor.Region2Fill.Lane10.Cactus" },
			{ "mid", "Map.Decor.Region2Fill.Lane10.Dune" },
			{ "tree", "Map.Decor.Region2Fill.Lane10.Palm" },
			{ "far", "Map.Decor.Region2.Lane10.Mesa" },
			{ "far", "Map.Decor.Region2Fill.Lane10.Oasis", 0.4, 0.6 },
		},
	},
	Lane11 = {
		name = "Coral Reef", region = 2, order = 2, seed = 111, gymZ = 1833,
		palette = { primary = Color3.fromRGB(240, 222, 180), accent = Color3.fromRGB(255, 120, 130), trim = Color3.fromRGB(40, 170, 190) },
		ground = M.Sand, accent = M.Salt, accentAt = 0.74, under = M.Sandstone, cliff = M.Rock, peak = M.LeafyGrass, road = M.WoodPlanks,
		decor = {
			{ "cover", "Map.Decor.Region2Fill.Lane11.Shells" },
			{ "verge", "Map.Decor.Region2Fill.Lane11.Coral" },
			{ "bush", "Map.Decor.Region2.Lane11.Coral" },
			{ "mid", "Map.Decor.Region2Fill.Lane11.TidePool" },
			{ "tree", "Map.Decor.Region2Fill.Lane11.Palm" },
			{ "far", "Map.Decor.Region2Fill.Lane11.Umbrella" },
			{ "far", "Map.Decor.Region2.Lane11.Shipwreck", 0.45, 0.55 },
		},
	},
	Lane12 = {
		name = "Thunder Mesa", region = 2, order = 3, seed = 121, gymZ = 2353,
		palette = { primary = Color3.fromRGB(196, 140, 96), accent = Color3.fromRGB(255, 224, 70), trim = Color3.fromRGB(60, 64, 90) },
		ground = M.Sandstone, accent = M.Rock, accentAt = 0.68, under = M.Sandstone, cliff = M.Sandstone, peak = M.Rock, road = M.Ground,
		boundaryRock = M.Sandstone,
		decor = {
			{ "cover", "Map.Decor.Region2Fill.Lane12.DryBush" },
			{ "verge", "Map.Decor.Region2.Lane12.VoltCrystal" },
			{ "bush", "Map.Decor.Region2Fill.Lane12.Boulder" },
			{ "mid", "Map.Decor.Region2Fill.Lane12.LightningRod" },
			{ "tree", "Map.Decor.Region2Fill.Lane12.MesaPillar" },
			{ "far", "Map.Decor.Region2.Lane12.RockTower" },
		},
	},
	Lane13 = {
		name = "Toxic Bog", region = 2, order = 4, seed = 131, gymZ = 2873,
		palette = { primary = Color3.fromRGB(70, 82, 52), accent = Color3.fromRGB(150, 230, 60), trim = Color3.fromRGB(96, 70, 120) },
		ground = M.Mud, accent = M.LeafyGrass, accentAt = 0.6, under = M.Ground, cliff = M.Rock, peak = M.Ground, road = M.WoodPlanks,
		decor = {
			{ "cover", "Map.Decor.Region2Fill.Lane13.Reeds" },
			{ "verge", "Map.Decor.Region2Fill.Lane13.Mushroom" },
			{ "bush", "Map.Decor.Region2.Lane13.ToxicShroom" },
			{ "mid", "Map.Decor.Region2Fill.Lane13.ToxicPool" },
			{ "tree", "Map.Decor.Region2Fill.Lane13.DeadTree" },
			{ "far", "Map.Decor.Region2.Lane13.DeadTree" },
		},
	},
	Lane14 = {
		name = "Crystal Caverns", region = 2, order = 5, seed = 141, gymZ = 3393,
		palette = { primary = Color3.fromRGB(90, 96, 112), accent = Color3.fromRGB(150, 220, 255), trim = Color3.fromRGB(230, 140, 255) },
		ground = M.Slate, accent = M.Rock, accentAt = 0.66, under = M.Rock, cliff = M.Rock, peak = M.Slate, road = M.Cobblestone,
		decor = {
			{ "cover", "Map.Decor.Region2Fill.Lane14.Crystal" },
			{ "verge", "Map.Decor.Region2.Lane14.CrystalCluster" },
			{ "bush", "Map.Decor.Region2Fill.Lane14.Stalagmite" },
			{ "mid", "Map.Decor.Region2.Lane14.Stalagmite" },
			{ "tree", "Map.Decor.Region2Fill.Lane14.Crystal" },
			{ "far", "Map.Decor.Region2Fill.Lane14.CaveArch" },
		},
	},
	Lane15 = {
		name = "Phantom Manor", region = 2, order = 6, seed = 151, gymZ = 3913,
		palette = { primary = Color3.fromRGB(64, 60, 70), accent = Color3.fromRGB(255, 170, 60), trim = Color3.fromRGB(40, 40, 46) },
		ground = M.Ground, accent = M.LeafyGrass, accentAt = 0.64, under = M.Ground, cliff = M.Rock, peak = M.Slate, road = M.Cobblestone,
		decor = {
			{ "cover", "Map.Decor.Region2Fill.Lane15.Pumpkin" },
			{ "verge", "Map.Decor.Region2Fill.Lane15.Lantern" },
			{ "bush", "Map.Decor.Region2Fill.Lane15.Grave" },
			{ "mid", "Map.Decor.Region2Fill.Lane15.RuinWall" },
			{ "tree", "Map.Decor.Region2Fill.Lane15.DeadTree" },
			{ "far", "Map.Decor.Region2Fill.Lane15.IronFence" },
		},
	},
	Lane16 = {
		name = "Dragon Peaks", region = 2, order = 7, seed = 161, gymZ = 4433,
		palette = { primary = Color3.fromRGB(52, 48, 54), accent = Color3.fromRGB(255, 96, 40), trim = Color3.fromRGB(200, 170, 90) },
		ground = M.Basalt, accent = M.Rock, accentAt = 0.66, under = M.Basalt, cliff = M.Basalt, peak = M.Snow, road = M.Slate,
		boundaryRock = M.Basalt,
		decor = {
			{ "cover", "Map.Decor.Region2Fill.Lane16.Crag" },
			{ "verge", "Map.Decor.Region2Fill.Lane16.BasaltCols" },
			{ "bush", "Map.Decor.Region2Fill.Lane16.Crag" },
			{ "mid", "Map.Decor.Region2Fill.Lane16.LavaPool" },
			{ "tree", "Map.Decor.Region2.Lane16.Spire" },
			{ "far", "Map.Decor.Region2Fill.Lane16.DragonRibs" },
			{ "far", "Map.Decor.Region2.Lane16.BannerPole", 0.8, 1 },
		},
	},
}

-- Lane start z and centre x
function RegionStyle.laneBox(laneKey: string)
	local t = RegionStyle.lanes[laneKey]
	if not t then
		return nil
	end
	local r = RegionStyle.regions[t.region]
	local z0 = r.start + t.order * RegionStyle.spec.laneLength
	return { x = r.x, z0 = z0, z1 = z0 + RegionStyle.spec.laneLength, roadY = r.roadY }
end

-- Route trainer spot by Meadow's logic: index 1..3 -> x, z (world)
function RegionStyle.trainerSpot(laneKey: string, index: number): (number, number)
	local box = assert(RegionStyle.laneBox(laneKey), "no theme for " .. tostring(laneKey))
	local t = RegionStyle.spec.trainers[index]
	return box.x + t.side * RegionStyle.spec.trainerOffset, box.z0 + math.floor(t.depth * RegionStyle.spec.laneLength + 0.5)
end

return RegionStyle
