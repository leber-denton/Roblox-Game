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
	  route      (ROUTE DECOR SETS only) the route whose RegionStyle theme uses this template

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
	"ROUTE DECOR SETS",
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

-- Dark Tower trainers: rooms 1-10 (Bone Crypt) and 11-20 (Ember Forge). Room 21 is the rest room, no trainer.
-- Rooms 11-20 were built by ServerStorage.TowerBuilder and have no NPCBackup copy (softTemplate).
for room = 1, 20 do
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

-- Route decoration sets (Overhaul Phase 2). Every route's dressing (Workspace.Map.Decor.<Lane>Dressing) is
-- cloned by RegionDecorator from the templates its RegionStyle theme lists, so the sets are read from
-- RegionStyle here instead of being typed twice: one entry per route per template, named
-- "<Route name>: <Template>". They are reference-only. To change a prop everywhere, edit its own entry
-- (DECORATIONS / MAP PROPS) or the template in Map.Decor, then re-run RegionRollout for the route; a name
-- match across the dressing would flatten the variants (Cactus, Coral, Grave, ...).
Lookup.ROUTE_SETS = {} -- route name -> sorted list of showcase names
Lookup.ROUTE_ORDER = {} -- route names in walking order (Region 1 then Region 2)
local function regionStyle()
	local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
	local mod = shared and shared:FindFirstChild("RegionStyle")
	if not mod then
		return nil
	end
	local function valid(value)
		return type(value) == "table" and type(value.lanes) == "table"
	end
	-- In Edit, require() keeps returning the table from the first require of the session, even after Rojo
	-- syncs a new RegionStyle, so the sets would be built from stale themes. RegionStyle is plain data with
	-- no requires of its own, so compile its current Source instead. In Play loadstring is off and the
	-- module cannot have changed since the server started, so require() is right there.
	if not game:GetService("RunService"):IsRunning() then
		local ok, fresh = pcall(function()
			return loadstring(mod.Source)()
		end)
		if ok and valid(fresh) then
			return fresh
		end
	end
	local ok, style = pcall(require, mod)
	return (ok and valid(style)) and style or nil
end
local style = regionStyle()
if style then
	local themes, laneOf = {}, {}
	for lane, theme in pairs(style.lanes) do
		table.insert(themes, theme)
		laneOf[theme] = lane
	end
	table.sort(themes, function(a, b)
		if a.region ~= b.region then
			return a.region < b.region
		end
		return a.order < b.order
	end)
	for _, theme in ipairs(themes) do
		table.insert(Lookup.ROUTE_ORDER, theme.name)
		local seen, names = {}, {}
		for _, rule in ipairs(theme.decor or {}) do
			local path = rule[2]
			if rule[1] == "fence" and path == "" then
				-- fence runs are built in place, not cloned: show the first one in the route's dressing
				path = "Map.Decor." .. laneOf[theme] .. "Dressing.FenceRun"
			end
			if type(path) == "string" and path ~= "" and not seen[path] then
				seen[path] = true
				local parent, leaf = path:match("([^%.]+)%.([^%.]+)$")
				local name = theme.name .. ": " .. (leaf or path)
				if entries[name] then -- two folders with a prop of the same name in one set
					name = theme.name .. ": " .. parent .. " " .. leaf
				end
				entries[name] = {
					category = "ROUTE DECOR SETS",
					map = {},
					source = "Workspace." .. path,
					reference = true,
					route = theme.name,
				}
				table.insert(names, name)
			end
		end
		table.sort(names)
		Lookup.ROUTE_SETS[theme.name] = names
	end
else
	warn("ModelSyncLookup: ReplicatedStorage.Shared.RegionStyle could not be loaded; route decor sets left out")
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
