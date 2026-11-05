--[[
	ModelSyncLookup: tells ModelSync where the real copies of every showcase model live.
	Same idea as ServerStorage.NPCBackup (one entry per model, found by exact path), but kept in git
	so changes are reviewed and Graphify can search them.

	Each entry is keyed by the model's name in Workspace.ShowcaseArea:
	  category   which showcase section it sits in
	  map        exact paths of live copies to replace on apply (can be empty or several)
	  byName     a root path: every Model/part with the showcase name under it is also replaced
	             (used for decorations, where there are hundreds of identical copies)
	  template   the stored original that spawners clone (ReplicatedStorage.CreatureMeshes.Blazefox, ...)
	  softTemplate  the template may be missing (NPCBackup only has some NPCs); that is not an error
	  source     what ShowcaseBuilder clones into the showcase (defaults to map[1], then template)
	  reference  true = design reference only, apply/restore refuse to touch anything

	Creatures and balls have no copies placed in the map: they are spawned from their template at
	runtime, so their entry is just a template path. Updating the template updates every future spawn.

	Adding a model: add its name below (or to the right list), run ModelSync.audit(), then
	ShowcaseBuilder.build(). Models not listed here fall back to the old behaviour (match by name in
	Workspace.Map, template taken from the showcase model's ShowcaseSource attribute).
]]

local Lookup = {}

Lookup.CATEGORY_ORDER = {
	"TRAINERS",
	"GYM LEADERS",
	"ROUTE TRAINERS",
	"DUNGEON TRAINERS",
	"NPCS",
	"BALLS",
	"CREATURES",
	"DECORATIONS",
	"MAP PROPS",
}

local entries = {}
Lookup.entries = entries

-- Map NPCs: showcase name is "Workspace_Map_" .. path with dots as underscores (the NPCBackup naming).
local function npcName(rel)
	return "Workspace_Map_" .. (rel:gsub("%.", "_"))
end

local function addNpc(category, rel)
	local name = npcName(rel)
	entries[name] = {
		category = category,
		map = { "Workspace.Map." .. rel },
		template = "ServerStorage.NPCBackup." .. name,
		softTemplate = true,
	}
end

-- Gym leaders (Gym 1 is Meadow: Workspace_Map_MeadowGym_Slate). Paths are relative to Workspace.Map.
for _, rel in ipairs({
	"MeadowGym.Slate",
	"BrookGym.Coralie",
	"TideGym.Duna",
	"VoltGym.Jolt",
	"EmberGym.Ignatia",
	"FrostGym.Hale",
	"ShadowGym.Morrow",
	"SkyGym.Aero",
	"BloomGym.Fern",
	"MirageGym.Sahra",
	"ReefGym.Marin",
	"MesaGym.Volta",
	"BogGym.Hemlock",
	"CrystalGym.Gemma",
	"ManorGym.Silas",
	"PeakGym.Drakon",
}) do
	addNpc("GYM LEADERS", rel)
end

-- Route trainers: r1a..r8c (region 1) and s9a..s16c (region 2).
for r = 1, 16 do
	for _, letter in ipairs({ "a", "b", "c" }) do
		addNpc("ROUTE TRAINERS", "RouteTrainers." .. (r <= 8 and "r" or "s") .. r .. letter)
	end
end

for room = 1, 10 do
	addNpc("DUNGEON TRAINERS", "DungeonTower.Room" .. room .. ".Trainer")
end

-- Everyone else with a Humanoid in the map: hub staff, league members, Coliseum, Summit Town.
for _, rel in ipairs({
	"Hub.HealingCenter.Nurse",
	"Hub.Lab.Professor",
	"Hub.Lab.Rival",
	"Hub.Shop.Clerk",
	"SummitTown.HealingCenter.Nurse",
	"SummitTown.Shop.Clerk",
	"Coliseum.ArenaMaster",
	"League.Members.Champion",
	"League.Members.Elite1",
	"League.Members.Elite2",
	"League.Members.Elite3",
	"League.Members.Elite4",
	"League2.Members.Champion",
	"League2.Members.Elite1",
	"League2.Members.Elite2",
	"League2.Members.Elite3",
	"League2.Members.Elite4",
}) do
	addNpc("NPCS", rel)
end

-- Companion trainers live only as templates (cloned onto players), so no map copies.
for _, n in ipairs({ "Juniper", "Trainer" }) do
	entries["Companion " .. n] = { category = "TRAINERS", map = {}, template = "ReplicatedStorage.Companion." .. n }
end
-- Workspace.ModelGallery trainers (Trainer v1, Juniper v1, ...) are version comparisons, not game assets.
-- ModelSync treats any showcase model whose source is under Workspace.ModelGallery as reference-only.

local function addTemplates(category, root, names)
	for _, n in ipairs(names) do
		entries[n] = { category = category, map = {}, template = root .. "." .. n }
	end
end

addTemplates("BALLS", "ReplicatedStorage.Shared.BallModels", {
	"ApexBall",
	"AquaBall",
	"BlazeBall",
	"Default",
	"FrostBall",
	"HeavyBall",
	"Hemi",
	"HiveBall",
	"LeafBall",
	"LevelBall",
	"LoopBall",
	"MindBall",
	"QuickBall",
	"ShadeBall",
	"SkyBall",
	"StoneBall",
	"SwiftBall",
	"TideBall",
	"UltraBall",
	"VoltBall",
})

addTemplates("CREATURES", "ReplicatedStorage.CreatureMeshes", {
	"Blazefox",
	"Bramblet",
	"Brawlet",
	"Buzzbolt",
	"Cinderock",
	"Cindrake",
	"Cragmaul",
	"Drizzlet",
	"Dunehorn",
	"Echoling",
	"Embercub",
	"Fluttle",
	"Frostpaw",
	"Galewing",
	"Glaciorn",
	"Glintle",
	"Gloomwisp",
	"Icicrest",
	"Infernyx",
	"Kindlit",
	"Lumifawn",
	"Lunaryx",
	"Nibbit",
	"Nightfang",
	"Nimbuff",
	"Pebblit",
	"Phantorb",
	"Pinchard",
	"Puddlepup",
	"Rimeling",
	"Ripplefin",
	"Sandsnip",
	"Scorchling",
	"Shadeshroom",
	"Shellum",
	"Skydrake",
	"Sporelet",
	"Sproutle",
	"Squawkit",
	"Stingle",
	"Stormane",
	"Thornip",
	"Thornwarden",
	"Tidalgon",
	"Tidecrest",
	"Torrentail",
	"Voltmole",
	"Wigglet",
	"Zapkit",
	"Zephlet",
})

-- Decorations with a stored template: every copy anywhere in the map is replaced.
for _, n in ipairs({
	"Boulder",
	"CrystalCluster",
	"FlowerBush",
	"GlowMushrooms",
	"IceCrystal",
	"OakTree",
	"PalmTree",
	"ShadowTree",
	"SnowPine",
	"VolcanicRock",
}) do
	entries[n] = {
		category = "DECORATIONS",
		map = {},
		byName = "Workspace.Map",
		template = "ServerStorage.DecorMeshes." .. n,
	}
end

-- Props that exist only as placed copies (no template). Only types whose copies are all identical in
-- structure and sit directly in a Workspace.Map.Decor folder are listed; the showcase clones the first
-- copy it finds. Types with several structural variants under one name (Cactus, Coral, Grave, ...) and
-- building pieces (Cottage, Shop, ...) are deliberately left out: a name match would flatten them.
for _, n in ipairs({
	"Birch",
	"Bones",
	"CloudBank",
	"DryBush",
	"Fence",
	"FlowerPatch",
	"Flowers",
	"Generator",
	"GiantFlower",
	"GlowRock",
	"HayBale",
	"Hedge",
	"Igloo",
	"IronFence",
	"LightningRod",
	"Mesa",
	"Mushroom",
	"Oasis",
	"Pine",
	"Pumpkin",
	"RainbowCloud",
	"Reeds",
	"RockTower",
	"RuinWall",
	"Sailboat",
	"SandRock",
	"Sandcastle",
	"Shells",
	"SkyRing",
	"Snowman",
	"SolarArray",
	"Spire",
	"Stalagmite",
	"Starfish",
	"Sunflower",
	"TeslaCoil",
	"ToxicPool",
	"ToxicShroom",
	"Tree",
	"TwistedTree",
	"Umbrella",
	"WindTurbine",
	"Windmill",
}) do
	entries[n] = { category = "MAP PROPS", map = {}, byName = "Workspace.Map.Decor", propsFolderOnly = true }
end

-- Template folders the audit compares against the entries above, so a new creature/ball/decor/companion
-- added in Studio but missing here gets reported instead of silently skipped.
Lookup.TEMPLATE_FOLDERS = {
	"ReplicatedStorage.CreatureMeshes",
	"ReplicatedStorage.Shared.BallModels",
	"ServerStorage.DecorMeshes",
	"ReplicatedStorage.Companion",
}

return Lookup
