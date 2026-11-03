--[[
	GameData: tunable numbers and creature definitions for Creature Quest: Catch & Battle.
	Battle numbers (stats, moves, type chart) live in BattleData.
]]

local GameData = {}

-- General settings
GameData.ResetSeconds = 600          -- safe Wild Shift every 10 minutes
GameData.RefillSeconds = 15          -- between resets, a missing wild creature respawns this often (per lane)
GameData.WildPerLane = 20            -- wild creatures per unlocked lane each reset
GameData.StartingBaseCapacity = 6    -- creatures a base holds before upgrades (12 later)
GameData.TutorialCreature = "Fluttle" -- with an empty team, pressing E on this catches it instantly

-- Variants rolled for every wild creature
GameData.ShinyChance = 1 / 100        -- shiny: different colours and a sparkle
GameData.SizeClasses = {               -- size variants; bigger = slightly better stats (all stats x statMult)
	{ name = "Tiny",   scale = 0.6,  weight = 5,  statMult = 0.90 },
	{ name = "Small",  scale = 0.8,  weight = 20, statMult = 0.95 },
	{ name = "Normal", scale = 1,    weight = 50, statMult = 1.00 },
	{ name = "Large",  scale = 1.25, weight = 20, statMult = 1.05 },
	{ name = "Huge",   scale = 1.6,  weight = 5,  statMult = 1.10 },
}

-- Creature Index order (everything you can currently catch)
GameData.IndexOrder = {
	-- Starters
	"Sproutle", "Bramblet", "Thornwarden", "Kindlit", "Blazefox", "Infernyx", "Drizzlet", "Torrentail", "Tidalgon",
	-- Meadow Route
	"Fluttle", "Nibbit", "Squawkit", "Thornip", "Brawlet", "Wigglet", "Stingle", "Shellum", "Voltmole", "Lunaryx",
	-- Boulder Pass, Glimmer Cavern, Brook Town
	"Pebblit", "Cragmaul", "Sporelet", "Echoling", "Glintle", "Puddlepup",
	-- Tide Coast
	"Ripplefin", "Tidecrest", "Sandsnip", "Dunehorn", "Pinchard",
	-- Volt Plains
	"Zapkit", "Stormane", "Buzzbolt",
	-- Ember Ridge
	"Embercub", "Cindrake", "Scorchling", "Cinderock",
	-- Frost Peak
	"Frostpaw", "Rimeling", "Glaciorn", "Icicrest",
	-- Shadow Woods
	"Gloomwisp", "Phantorb", "Shadeshroom", "Nightfang",
	-- Sky Spire
	"Zephlet", "Galewing", "Nimbuff", "Skydrake",
}

-- Movement
GameData.WalkSpeed = 16
GameData.SprintSpeed = 24            -- holding Shift
GameData.SprintPerBadge = 2          -- extra sprint speed per gym leader beaten

-- Status conditions (shared by battles, items and the UI)
GameData.StatusInfo = {
	brn = { name = "Burn",      short = "BRN", color = Color3.fromRGB(235, 110, 50) },
	psn = { name = "Poison",    short = "PSN", color = Color3.fromRGB(165, 70, 175) },
	par = { name = "Paralysis", short = "PAR", color = Color3.fromRGB(225, 195, 40) },
	slp = { name = "Sleep",     short = "SLP", color = Color3.fromRGB(130, 130, 150) },
	frz = { name = "Freeze",    short = "FRZ", color = Color3.fromRGB(110, 200, 235) },
}

-- Balls. multiplier scales the catch chance; the Loop Ball is the free, unlimited baseline.
-- Shop balls (below) cost coins and are used up when thrown.
-- kind = nil (flat multiplier) | "quick" | "heavy" | "type" (see GameData.ballMultiplier)
GameData.Balls = {
	LoopBall = {
		name = "Loop Ball", multiplier = 1, unlimited = true, rareMult = 0.5, color = Color3.fromRGB(225, 45, 45), order = 1,
		description = "A free, reusable ball marked with an infinity sign. Throw as many as you like, but it has the lowest catch rate (x1, and only x0.5 on Rare and Legendary creatures), so weaken creatures first or bring a shop ball for the rare ones!",
	},
	-- the three standard tiers
	-- (ids stay the same as before so saved bags keep working; only the names shown to players changed)
	SwiftBall = {
		name = "Spark Ball", multiplier = 1.5, color = Color3.fromRGB(60, 130, 230), band = Color3.fromRGB(230, 60, 60), order = 2,
		description = "A better ball with a blue shell. Catch rate x1.5 on every creature. Used up when thrown.",
	},
	UltraBall = {
		name = "Nova Ball", multiplier = 2.2, color = Color3.fromRGB(40, 40, 45), band = Color3.fromRGB(250, 205, 50), order = 3,
		description = "A high-performance ball. Catch rate x2.2 on every creature. Used up when thrown.",
	},
	ApexBall = {
		name = "Apex Ball", multiplier = 3, color = Color3.fromRGB(245, 245, 250), band = Color3.fromRGB(150, 70, 230), order = 4,
		description = "The best standard ball money can buy. Catch rate x3 on every creature. Used up when thrown.",
	},
	-- situational balls
	QuickBall = {
		name = "Dawn Ball", kind = "quick", multiplier = 1, firstTurn = 4, color = Color3.fromRGB(70, 190, 230), band = Color3.fromRGB(250, 220, 60), order = 10,
		description = "Strikes first: catch rate x4 if you throw it on the very first turn of a battle (before doing anything else). After that it's only x1.",
	},
	HeavyBall = {
		name = "Titan Ball", kind = "heavy", multiplier = 1, color = Color3.fromRGB(110, 115, 125), band = Color3.fromRGB(60, 120, 200), order = 12,
		description = "Made for big creatures: catch rate x1.5 on medium ones, x2.5 on big ones and x4 on huge ones (Large and Huge size variants count). x1 on small creatures.",
	},
}
-- type balls: x3.5 against their types, x1 otherwise
for id, d in {
	AquaBall  = { name = "Aqua Ball",  types = { "Water", "Ice" },      color = Color3.fromRGB(60, 140, 230),  band = Color3.fromRGB(200, 235, 255), order = 20 },
	BlazeBall = { name = "Blaze Ball", types = { "Fire" },              color = Color3.fromRGB(235, 95, 40),   band = Color3.fromRGB(255, 210, 80),  order = 21 },
	LeafBall  = { name = "Leaf Ball",  types = { "Grass", "Bug", "Poison" }, color = Color3.fromRGB(90, 185, 80),   band = Color3.fromRGB(230, 240, 150), order = 22 },
	VoltBall  = { name = "Volt Ball",  types = { "Electric" },          color = Color3.fromRGB(240, 205, 40),  band = Color3.fromRGB(60, 60, 70),    order = 23 },
	StoneBall = { name = "Stone Ball", types = { "Rock", "Ground" },    color = Color3.fromRGB(165, 140, 100), band = Color3.fromRGB(90, 75, 55),    order = 25 },
	ShadeBall = { name = "Shade Ball", types = { "Ghost", "Dark", "Psychic", "Fairy" }, color = Color3.fromRGB(70, 50, 100),   band = Color3.fromRGB(180, 120, 255), order = 26 },
	SkyBall   = { name = "Sky Ball",   types = { "Flying", "Dragon" }, color = Color3.fromRGB(150, 190, 245), band = Color3.fromRGB(250, 250, 255), order = 27 },
} do
	d.kind = "type"
	d.multiplier = 1
	d.typeBonus = 3.5
	d.description = ("Catch rate x3.5 on %s-type creatures (either of a creature's types counts), x1 on everything else."):format(table.concat(d.types, " and "))
	GameData.Balls[id] = d
end
GameData.DefaultBall = "LoopBall"

-- Size of a creature for the Heavy Ball (species size x size-variant scale)
function GameData.creatureBulk(name: string, sizeClass: string?): number
	local c = GameData.Creatures[name]
	local scale = 1
	for _, s in GameData.SizeClasses do
		if s.name == sizeClass then
			scale = s.scale
		end
	end
	return (c and c.size or 4) * scale
end

--[[ The multiplier a ball gets in this situation. ctx (all optional) =
	{ turn = turns already taken (0 = first turn), allyLevel, wildLevel, wildName, wildSize (sizeClass) }
	Returns multiplier, shortNote ]]
function GameData.ballMultiplier(ballId: string, ctx): (number, string)
	local ball = GameData.Balls[ballId]
	if not ball then
		return 1, ""
	end
	ctx = ctx or {}
	if ball.kind == "quick" then
		if (ctx.turn or 0) == 0 then
			return ball.firstTurn, "first turn"
		end
		return ball.multiplier, "too late"
	elseif ball.kind == "heavy" then
		local bulk = ctx.wildName and GameData.creatureBulk(ctx.wildName, ctx.wildSize) or 4
		if bulk >= 7 then
			return 4, "huge"
		elseif bulk >= 5 then
			return 2.5, "big"
		elseif bulk >= 4 then
			return 1.5, "medium"
		end
		return 1, "small"
	elseif ball.kind == "type" then
		local c = ctx.wildName and GameData.Creatures[ctx.wildName]
		if c and (table.find(ball.types, c.type) or (c.type2 and table.find(ball.types, c.type2))) then
			return ball.typeBonus, "type match"
		end
		return ball.multiplier, "wrong type"
	end
	return ball.multiplier, ""
end

-- Rarity tiers. Catch chance = catchRate x ball multiplier x (3*maxHP - 2*HP) / (3*maxHP),
-- so a full-HP creature is a third as easy to catch as one at 1 HP.
GameData.Rarities = {
	Common    = { order = 1, color = Color3.fromRGB(225, 225, 225), catchRate = 0.90, announce = false },
	Uncommon  = { order = 2, color = Color3.fromRGB(110, 225, 120), catchRate = 0.70, announce = false },
	Rare      = { order = 3, color = Color3.fromRGB(90, 165, 255),  catchRate = 0.45, announce = false },
	Legendary = { order = 4, color = Color3.fromRGB(255, 200, 60),  catchRate = 0.20, announce = true },
}

-- Original creatures. shape picks the body plan in CreatureBuilder:
-- bird, rodent, spiky, fighter, larva, cocoon, blob, quad. accent colours beaks, ears, spines, gloves, etc.
GameData.Creatures = {
	-- Meadow start
	Fluttle  = { type = "Normal", type2 = "Flying", rarity = "Common",   shape = "bird",    size = 3.5, color = Color3.fromRGB(245, 205, 95) },
	Nibbit   = { type = "Normal",   rarity = "Common",   shape = "rodent",  size = 3.2, color = Color3.fromRGB(170, 145, 125), accent = Color3.fromRGB(245, 160, 170) },
	-- Middle stretch
	Squawkit = { type = "Normal", type2 = "Flying", rarity = "Common",   shape = "bird",    size = 3.6, color = Color3.fromRGB(95, 110, 140), accent = Color3.fromRGB(250, 200, 60) },
	Thornip  = { type = "Poison",   rarity = "Uncommon", shape = "spiky",   size = 3.6, color = Color3.fromRGB(120, 175, 110), accent = Color3.fromRGB(150, 80, 190) },
	Brawlet  = { type = "Fighting", rarity = "Uncommon", shape = "fighter", size = 3.8, color = Color3.fromRGB(230, 195, 155), accent = Color3.fromRGB(220, 50, 50) },
	-- Whisperwood forest
	Wigglet  = { type = "Bug",      rarity = "Common",   shape = "larva",   size = 3.0, color = Color3.fromRGB(250, 195, 165), accent = Color3.fromRGB(110, 180, 240) },
	Stingle  = { type = "Bug", type2 = "Poison", rarity = "Common",   shape = "larva",   size = 3.0, color = Color3.fromRGB(60, 130, 140),  accent = Color3.fromRGB(250, 210, 60), stinger = true },
	Shellum  = { type = "Bug",      rarity = "Uncommon", shape = "cocoon",  size = 3.2, color = Color3.fromRGB(175, 125, 75),  accent = Color3.fromRGB(120, 85, 50) },
	Voltmole = { type = "Electric", rarity = "Rare",     shape = "blob",    size = 4.4, color = Color3.fromRGB(55, 85, 155),   accent = Color3.fromRGB(255, 230, 70) },
	-- Legendary
	Lunaryx  = { type = "Psychic", type2 = "Flying", rarity = "Legendary", shape = "bird",   size = 7,   color = Color3.fromRGB(200, 180, 255), accent = Color3.fromRGB(255, 240, 200), floats = true },
	-- Rock creatures (used by Gym Leader Slate for now)
	Pebblit  = { type = "Rock", rarity = "Uncommon", shape = "rock", size = 3.6, color = Color3.fromRGB(150, 140, 125), accent = Color3.fromRGB(105, 95, 85) },
	Cragmaul = { type = "Rock", type2 = "Ground", rarity = "Rare", shape = "rock", size = 5, color = Color3.fromRGB(125, 112, 100), accent = Color3.fromRGB(215, 160, 85), arms = true },
	-- Starters (Professor Maple gives one; they don't spawn in the wild). Evolve at 16 and 32.
	Sproutle    = { type = "Grass", rarity = "Uncommon", shape = "quad", size = 3.6, color = Color3.fromRGB(120, 200, 130), accent = Color3.fromRGB(70, 150, 80), features = { "leafBud", "blush" }, starter = true },
	Bramblet    = { type = "Grass", rarity = "Uncommon", shape = "quad", size = 4.6, color = Color3.fromRGB(90, 175, 115), accent = Color3.fromRGB(230, 110, 150), features = { "bud", "spines" }, starter = true },
	Thornwarden = { type = "Grass", type2 = "Poison", rarity = "Uncommon", shape = "quad", size = 6, color = Color3.fromRGB(70, 150, 100), accent = Color3.fromRGB(240, 90, 120), features = { "flower", "spines", "horns" }, starter = true },
	Kindlit     = { type = "Fire", rarity = "Uncommon", shape = "fox", size = 3.5, color = Color3.fromRGB(250, 150, 70), accent = Color3.fromRGB(255, 220, 90), features = { "flameTail", "blush" }, starter = true },
	Blazefox    = { type = "Fire", rarity = "Uncommon", shape = "fox", size = 4.6, color = Color3.fromRGB(235, 100, 50), accent = Color3.fromRGB(255, 200, 70), features = { "flameTail", "flameMane" }, starter = true },
	Infernyx    = { type = "Fire", type2 = "Flying", rarity = "Uncommon", shape = "fox", size = 6, color = Color3.fromRGB(215, 70, 40), accent = Color3.fromRGB(255, 190, 60), features = { "flameTail", "flameMane", "wings", "horns" }, starter = true },
	Drizzlet    = { type = "Water", rarity = "Uncommon", shape = "turtle", size = 3.5, color = Color3.fromRGB(110, 190, 240), accent = Color3.fromRGB(190, 140, 90), features = { "blush" }, starter = true },
	Torrentail  = { type = "Water", rarity = "Uncommon", shape = "turtle", size = 4.6, color = Color3.fromRGB(80, 150, 225), accent = Color3.fromRGB(170, 115, 70), features = { "finEars", "swirlTail" }, starter = true },
	Tidalgon    = { type = "Water", rarity = "Uncommon", shape = "turtle", size = 6, color = Color3.fromRGB(55, 110, 200), accent = Color3.fromRGB(150, 100, 60), features = { "cannons", "swirlTail", "horns" }, starter = true },
	-- Boulder Pass, Glimmer Cavern, Brook Town
	Puddlepup = { type = "Water", rarity = "Uncommon", shape = "quad", size = 4.1, color = Color3.fromRGB(80, 150, 230) },
	Sporelet  = { type = "Bug", type2 = "Grass", rarity = "Common", shape = "spiky", size = 3.2, color = Color3.fromRGB(230, 120, 90), accent = Color3.fromRGB(250, 240, 220) },
	Echoling  = { type = "Poison", type2 = "Flying", rarity = "Common", shape = "bird", size = 3.3, color = Color3.fromRGB(105, 80, 150), accent = Color3.fromRGB(200, 120, 220) },
	Glintle   = { type = "Fairy", rarity = "Uncommon", shape = "crystal", size = 3.4, color = Color3.fromRGB(245, 190, 225), accent = Color3.fromRGB(190, 240, 255) },
	-- Tide Coast
	Ripplefin    = { type = "Water", rarity = "Common", shape = "fish", size = 3.3, color = Color3.fromRGB(80, 170, 235), accent = Color3.fromRGB(250, 220, 90) },
	Tidecrest = { type = "Water", type2 = "Dragon", rarity = "Rare", shape = "fish", size = 5.4, color = Color3.fromRGB(40, 95, 190), accent = Color3.fromRGB(120, 230, 230) },
	Sandsnip  = { type = "Ground", rarity = "Common", shape = "rodent", size = 3.3, color = Color3.fromRGB(225, 195, 135), accent = Color3.fromRGB(180, 120, 70) },
	Dunehorn  = { type = "Ground", rarity = "Uncommon", shape = "quad", size = 4.8, color = Color3.fromRGB(190, 145, 90), accent = Color3.fromRGB(245, 235, 210) },
	Pinchard   = { type = "Water", type2 = "Rock", rarity = "Uncommon", shape = "rock", size = 3.9, color = Color3.fromRGB(230, 95, 70), accent = Color3.fromRGB(255, 190, 150), arms = true },
	-- Volt Plains
	Zapkit    = { type = "Electric", rarity = "Common", shape = "rodent", size = 3.2, color = Color3.fromRGB(250, 220, 70), accent = Color3.fromRGB(70, 60, 40) },
	Stormane  = { type = "Electric", rarity = "Rare", shape = "quad", size = 5.2, color = Color3.fromRGB(70, 80, 120), accent = Color3.fromRGB(255, 240, 90) },
	Buzzbolt  = { type = "Bug", type2 = "Electric", rarity = "Uncommon", shape = "larva", size = 3.2, color = Color3.fromRGB(60, 200, 120), accent = Color3.fromRGB(255, 240, 80), stinger = true },
	-- Ember Ridge
	Embercub  = { type = "Fire",  rarity = "Uncommon", shape = "quad", size = 4.1, color = Color3.fromRGB(235, 110, 60) },
	Cindrake  = { type = "Fire", type2 = "Dragon", rarity = "Rare", shape = "dragon", size = 5.4, color = Color3.fromRGB(200, 60, 40), accent = Color3.fromRGB(255, 190, 60) },
	Scorchling = { type = "Fire", type2 = "Flying", rarity = "Common", shape = "bird", size = 3.4, color = Color3.fromRGB(245, 140, 50), accent = Color3.fromRGB(255, 230, 100) },
	Cinderock   = { type = "Fire", type2 = "Rock", rarity = "Common", shape = "rock", size = 3.8, color = Color3.fromRGB(70, 55, 55), accent = Color3.fromRGB(255, 120, 40) },
	-- Frost Peak
	Frostpaw  = { type = "Ice", rarity = "Common", shape = "quad", size = 3.7, color = Color3.fromRGB(225, 240, 255), accent = Color3.fromRGB(120, 190, 240) },
	Rimeling = { type = "Ice", rarity = "Common", shape = "crystal", size = 3.2, color = Color3.fromRGB(160, 215, 245), accent = Color3.fromRGB(240, 250, 255) },
	Glaciorn  = { type = "Ice", type2 = "Rock", rarity = "Rare", shape = "crystal", size = 5.4, color = Color3.fromRGB(110, 170, 220), accent = Color3.fromRGB(230, 250, 255) },
	Icicrest  = { type = "Ice", type2 = "Flying", rarity = "Uncommon", shape = "bird", size = 3.8, color = Color3.fromRGB(190, 225, 250), accent = Color3.fromRGB(90, 150, 220) },
	-- Shadow Woods
	Gloomwisp     = { type = "Ghost", rarity = "Common", shape = "ghost", size = 3.2, color = Color3.fromRGB(150, 120, 210), accent = Color3.fromRGB(230, 200, 255), floats = true },
	Phantorb  = { type = "Ghost", type2 = "Dark", rarity = "Rare", shape = "ghost", size = 5, color = Color3.fromRGB(60, 40, 90), accent = Color3.fromRGB(255, 90, 140), floats = true },
	Shadeshroom = { type = "Grass", type2 = "Poison", rarity = "Common", shape = "spiky", size = 3.4, color = Color3.fromRGB(90, 70, 120), accent = Color3.fromRGB(170, 240, 120) },
	Nightfang = { type = "Dark", rarity = "Uncommon", shape = "quad", size = 4.3, color = Color3.fromRGB(45, 45, 60), accent = Color3.fromRGB(230, 60, 60) },
	-- Sky Spire
	Zephlet  = { type = "Normal", type2 = "Flying", rarity = "Common", shape = "bird", size = 3.2, color = Color3.fromRGB(240, 245, 255), accent = Color3.fromRGB(130, 190, 255) },
	Galewing  = { type = "Normal", type2 = "Flying", rarity = "Uncommon", shape = "bird", size = 4.6, color = Color3.fromRGB(130, 170, 230), accent = Color3.fromRGB(255, 255, 255) },
	Nimbuff     = { type = "Flying", type2 = "Fairy", rarity = "Uncommon", shape = "ghost", size = 3.8, color = Color3.fromRGB(250, 250, 255), accent = Color3.fromRGB(255, 200, 230), floats = true },
	Skydrake  = { type = "Dragon", type2 = "Flying", rarity = "Rare", shape = "dragon", size = 5.8, color = Color3.fromRGB(70, 150, 140), accent = Color3.fromRGB(240, 220, 120) },
}

-- Extra model details per creature (CreatureBuilder Features)
for name, feats in {
	Fluttle = { "blush" }, Nibbit = { "blush" }, Wigglet = { "blush" }, Puddlepup = { "finEars", "blush" },
	Zapkit = { "boltTail", "blush" }, Stormane = { "mane", "boltTail", "horns" }, Voltmole = { "fangs" },
	Embercub = { "flameTail", "blush" }, Cindrake = { "flameMane" }, Scorchling = { "flameMane" },
	Frostpaw = { "horns", "blush" }, Nightfang = { "fangs", "mane" }, Dunehorn = { "horns", "mane" },
	Sandsnip = { "fangs" }, Tidecrest = { "horns" }, Skydrake = { "mane" }, Lunaryx = { "antennae" },
	Buzzbolt = { "antennae" }, Brawlet = { "fangs" }, Glintle = { "blush" }, Sporelet = { "leafBud" },
	Shadeshroom = { "leafBud" }, Gloomwisp = { "blush" }, Nimbuff = { "blush" }, Zephlet = { "blush" },
} do
	if GameData.Creatures[name] then
		GameData.Creatures[name].features = feats
	end
end

-- What spawns where. depth = how far up the lane (0 = start, 1 = gym end).
-- Wild levels scale from minLevel at the start to maxLevel at the end unless an entry sets level.
GameData.Lanes = {
	Lane1 = {
		minLevel = 2,
		maxLevel = 8,
		spawns = {
			-- Meadow start
			{ name = "Fluttle",  weight = 55, minDepth = 0,    maxDepth = 0.35 },
			{ name = "Nibbit",   weight = 45, minDepth = 0,    maxDepth = 0.35 },
			-- Middle stretch
			{ name = "Nibbit",   weight = 30, minDepth = 0.35, maxDepth = 0.65 },
			{ name = "Squawkit", weight = 25, minDepth = 0.35, maxDepth = 0.65 },
			{ name = "Fluttle",  weight = 20, minDepth = 0.35, maxDepth = 0.65 },
			{ name = "Thornip",  weight = 17, minDepth = 0.35, maxDepth = 0.65 },
			{ name = "Brawlet",  weight = 8,  minDepth = 0.35, maxDepth = 0.65 },
			-- Whisperwood forest (Voltmole is 5% here)
			{ name = "Wigglet",  weight = 38, minDepth = 0.65, maxDepth = 1 },
			{ name = "Stingle",  weight = 38, minDepth = 0.65, maxDepth = 1 },
			{ name = "Shellum",  weight = 19, minDepth = 0.65, maxDepth = 1 },
			{ name = "Voltmole", weight = 5,  minDepth = 0.65, maxDepth = 1 },
			{ name = "Lunaryx",  weight = 0.5, minDepth = 0.9, maxDepth = 1, level = 15 },
		},
	},
	-- Behind the Meadow Gym: Boulder Pass (rocky), Glimmer Cavern (cave), Brook Town
	Lane1B = {
		minLevel = 10,
		maxLevel = 15,
		spawns = {
			{ name = "Sporelet",  weight = 35, minDepth = 0,    maxDepth = 0.37 },
			{ name = "Pebblit",   weight = 30, minDepth = 0,    maxDepth = 0.37 },
			{ name = "Puddlepup", weight = 20, minDepth = 0,    maxDepth = 0.37 },
			{ name = "Nibbit",    weight = 15, minDepth = 0,    maxDepth = 0.37 },
			{ name = "Echoling",  weight = 45, minDepth = 0.37, maxDepth = 0.75 },
			{ name = "Glintle",   weight = 25, minDepth = 0.37, maxDepth = 0.75 },
			{ name = "Pebblit",   weight = 20, minDepth = 0.37, maxDepth = 0.75 },
			{ name = "Sporelet",  weight = 10, minDepth = 0.37, maxDepth = 0.75 },
			{ name = "Puddlepup", weight = 50, minDepth = 0.75, maxDepth = 1 },
			{ name = "Sporelet",  weight = 30, minDepth = 0.75, maxDepth = 1 },
			{ name = "Glintle",   weight = 20, minDepth = 0.75, maxDepth = 1 },
		},
	},
	Lane3 = { -- Tide Coast
		minLevel = 16,
		maxLevel = 21,
		spawns = {
			{ name = "Ripplefin",    weight = 35, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Sandsnip",  weight = 35, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Pinchard",   weight = 20, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Puddlepup", weight = 10, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Ripplefin",    weight = 30, minDepth = 0.6, maxDepth = 1 },
			{ name = "Pinchard",   weight = 30, minDepth = 0.6, maxDepth = 1 },
			{ name = "Sandsnip",  weight = 25, minDepth = 0.6, maxDepth = 1 },
			{ name = "Dunehorn",  weight = 10, minDepth = 0.6, maxDepth = 1 },
			{ name = "Tidecrest", weight = 5,  minDepth = 0.6, maxDepth = 1 },
		},
	},
	Lane4 = { -- Volt Plains
		minLevel = 22,
		maxLevel = 27,
		spawns = {
			{ name = "Zapkit",   weight = 40, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Buzzbolt", weight = 35, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Squawkit", weight = 15, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Voltmole", weight = 10, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Zapkit",   weight = 30, minDepth = 0.6, maxDepth = 1 },
			{ name = "Buzzbolt", weight = 30, minDepth = 0.6, maxDepth = 1 },
			{ name = "Voltmole", weight = 25, minDepth = 0.6, maxDepth = 1 },
			{ name = "Stormane", weight = 5,  minDepth = 0.6, maxDepth = 1 },
		},
	},
	Lane2 = { -- Ember Ridge
		minLevel = 28,
		maxLevel = 33,
		spawns = {
			{ name = "Scorchling", weight = 40, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Cinderock",    weight = 35, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Embercub",   weight = 20, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Pebblit",    weight = 5,  minDepth = 0,   maxDepth = 0.6 },
			{ name = "Cinderock",    weight = 35, minDepth = 0.6, maxDepth = 1 },
			{ name = "Scorchling", weight = 30, minDepth = 0.6, maxDepth = 1 },
			{ name = "Embercub",   weight = 25, minDepth = 0.6, maxDepth = 1 },
			{ name = "Cindrake",   weight = 5,  minDepth = 0.6, maxDepth = 1 },
		},
	},
	Lane5 = { -- Frost Peak
		minLevel = 34,
		maxLevel = 39,
		spawns = {
			{ name = "Frostpaw",  weight = 40, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Rimeling", weight = 35, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Icicrest",  weight = 25, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Rimeling", weight = 30, minDepth = 0.6, maxDepth = 1 },
			{ name = "Icicrest",  weight = 30, minDepth = 0.6, maxDepth = 1 },
			{ name = "Frostpaw",  weight = 25, minDepth = 0.6, maxDepth = 1 },
			{ name = "Glaciorn",  weight = 5,  minDepth = 0.6, maxDepth = 1 },
		},
	},
	Lane6 = { -- Shadow Woods
		minLevel = 40,
		maxLevel = 45,
		spawns = {
			{ name = "Gloomwisp",       weight = 40, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Shadeshroom", weight = 35, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Nightfang",   weight = 25, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Nightfang",   weight = 35, minDepth = 0.6, maxDepth = 1 },
			{ name = "Gloomwisp",       weight = 30, minDepth = 0.6, maxDepth = 1 },
			{ name = "Shadeshroom", weight = 25, minDepth = 0.6, maxDepth = 1 },
			{ name = "Phantorb",    weight = 5,  minDepth = 0.6, maxDepth = 1 },
		},
	},
	Lane7 = { -- Sky Spire
		minLevel = 46,
		maxLevel = 51,
		spawns = {
			{ name = "Zephlet", weight = 40, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Nimbuff",    weight = 35, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Galewing", weight = 20, minDepth = 0,   maxDepth = 0.6 },
			{ name = "Squawkit", weight = 5,  minDepth = 0,   maxDepth = 0.6 },
			{ name = "Galewing", weight = 35, minDepth = 0.6, maxDepth = 1 },
			{ name = "Nimbuff",    weight = 30, minDepth = 0.6, maxDepth = 1 },
			{ name = "Zephlet", weight = 25, minDepth = 0.6, maxDepth = 1 },
			{ name = "Skydrake", weight = 5,  minDepth = 0.6, maxDepth = 1 },
		},
	},
}

-- Regions in journey order. badges = gym badges needed to get in (the gate at the start).
GameData.Regions = {
	{ lane = "Lane1",  name = "Meadow Route",  badges = 0, gym = "Meadow" },
	{ lane = "Lane1B", name = "Boulder Pass",  badges = 1, gym = "Brook" },
	{ lane = "Lane3",  name = "Tide Coast",    badges = 2, gym = "Tide" },
	{ lane = "Lane4",  name = "Volt Plains",   badges = 3, gym = "Volt" },
	{ lane = "Lane2",  name = "Ember Ridge",   badges = 4, gym = "Ember" },
	{ lane = "Lane5",  name = "Frost Peak",    badges = 5, gym = "Frost" },
	{ lane = "Lane6",  name = "Shadow Woods",  badges = 6, gym = "Shadow" },
	{ lane = "Lane7",  name = "Sky Spire",     badges = 7, gym = "Sky" },
	-- Region 2 (past Victory Road, through Summit Town). Opens once you're the Champion.
	{ lane = "Lane9",  name = "Sunpetal Fields", badges = 8,  gym = "Bloom",   region = 2, champion = true },
	{ lane = "Lane10", name = "Mirage Desert",   badges = 9,  gym = "Mirage",  region = 2, champion = true },
	{ lane = "Lane11", name = "Coral Reef",      badges = 10, gym = "Reef",    region = 2, champion = true },
	{ lane = "Lane12", name = "Thunder Mesa",    badges = 11, gym = "Mesa",    region = 2, champion = true },
	{ lane = "Lane13", name = "Toxic Bog",       badges = 12, gym = "Bog",     region = 2, champion = true },
	{ lane = "Lane14", name = "Crystal Caverns", badges = 13, gym = "Crystal", region = 2, champion = true },
	{ lane = "Lane15", name = "Phantom Manor",   badges = 14, gym = "Manor",   region = 2, champion = true },
	{ lane = "Lane16", name = "Dragon Peaks",    badges = 15, gym = "Peak",    region = 2, champion = true },
}
-- Region names. Each region's Victory Road carries its region's name (signs, arch over the road, HUD).
GameData.Region1 = { name = "Soraku" }
-- Region 2's town (between the League and the Region 2 lanes)
GameData.Region2 = { name = "Summit Town", region = "Norven", firstLane = "Lane9" }
GameData.VictoryRoads = {
	League = GameData.Region1.name .. " Victory Road",  -- Region 1 (LaneVR / VictoryRoad, gate Gate_League)
	League2 = GameData.Region2.region .. " Victory Road", -- Region 2 (VictoryRoad2, gate Gate_League2)
}
-- The map is a star: the Hub is the centre and each region is its own arm (a straight road along +Z).
-- Region 1 runs north from the bases at x = 0: 8 regions (Lane1, Lane1B, Lane2..Lane7, 520 studs each), then Maple Victory Road
-- (LaneVR / VictoryRoad, z ~4410-4700) and the League (Map.League, z ~4600-4680).
-- Region 2 branches east from the Hub to x = 460: Summit Town (z 220-300), then Lane9..Lane16
-- (520 studs each) from z 300, then Summit Victory Road (VictoryRoad2, z ~4460-4745) and the
-- Summit League (Map.League2, z ~4650-4725). An arm opens once you've beaten the previous region's Champion.
-- Region 1 and 2 are split by a mountain range (Terrain, x ~170-345).
GameData.Arms = {
	{ region = 1, x = 0, start = 250 },
	{ region = 2, x = 460, start = 300, laneLength = 520, town = Vector3.new(460, 5, 250), league = "League2" },
}

-- Can this player enter a region? (badge count + Champion title for Region 2)
function GameData.regionFor(lane: string)
	for _, r in GameData.Regions do
		if r.lane == lane then
			return r
		end
	end
	return nil
end
-- Wild areas that aren't regions (no gym, no TRAVEL entry): badges needed to battle there
GameData.ExtraLanes = {
	LaneVR = { badges = 8, name = GameData.VictoryRoads.League },
	LaneVR2 = { badges = 16, name = GameData.VictoryRoads.League2 },
}

function GameData.canEnter(lane: string, badges: number, isChampion: boolean): boolean
	local extra = GameData.ExtraLanes[lane]
	if extra then
		return badges >= extra.badges
	end
	local r = GameData.regionFor(lane)
	if not r then
		return true
	end
	return badges >= r.badges and (not r.champion or isChampion)
end
function GameData.badgesForLane(lane: string): number
	if GameData.ExtraLanes[lane] then
		
-- Story rewards cannot be bought or rolled by any wild/paid spawn pool.
GameData.Items.JuniperJournal = { name = "Juniper's Journal", category = "Story", storyOnly = true,
    color = Color3.fromRGB(170, 120, 230), description = "Recovered from the Havoc lab. Open Journey > Story to read Juniper's notes." }
GameData.Items.HavocLens = { name = "Havoc Lens", category = "Held Items", storyOnly = true,
    held = { superBoost = 1.15 }, color = Color3.fromRGB(180, 90, 230), description = "Recovered from a Norven Havoc base. Super-effective hits deal 15% more damage." }
GameData.Items.CrystalAnchor = { name = "Crystal Anchor", category = "Held Items", storyOnly = true,
    held = { guard = 0.9 }, color = Color3.fromRGB(90, 190, 230), description = "Recovered from a Norven Havoc base. Takes 10% less damage." }
GameData.Items.TimeClover = { name = "Time Clover", category = "Held Items", storyOnly = true,
    held = { xpMult = 1.15 }, color = Color3.fromRGB(110, 220, 170), description = "Recovered from a Norven Havoc base. Earns 15% more battle XP." }
GameData.Creatures.Chronowisp = { type = "Ghost", type2 = "Steel", rarity = "Legendary", shape = "ghost", size = 4.2,
    color = Color3.fromRGB(180, 155, 230), accent = Color3.fromRGB(80, 240, 220), floats = true, storyOnly = true }
table.insert(GameData.IndexOrder, "Chronowisp")

return GameData.ExtraLanes[lane].badges
	end
	for _, r in GameData.Regions do
		if r.lane == lane then
			return r.badges
		end
	end
	return 0
end

-- Items that aren't balls (shown in the Bag). Skill Discs teach a move to one creature.
GameData.Items = {
	DiscRockfall = {
		name = "Skill Disc: Rockfall", category = "Skill Discs", move = "Rockfall", color = Color3.fromRGB(185, 160, 60),
		description = "Teaches Rockfall (Rock, power 75) to one of your creatures. If it already knows 4 moves, it forgets its oldest one. Single use.",
	},
}
-- Medicine: use from the Bag outside battle, or from Bag in battle (uses your turn).
-- heal = HP restored ("max" = full), revive = brings a fainted creature back at that fraction of its HP,
-- cure = status cured: a status key ("brn"...) or "all". order sorts the Bag.
local function med(id, def)
	def.category = "Medicine"
	GameData.Items[id] = def
end
-- potions: five strengths
-- (ids stay the same as before so saved bags keep working; only the names shown to players changed)
-- tonics: five strengths
med("Potion",      { name = "Mini Tonic",   heal = 20,    order = 1, color = Color3.fromRGB(170, 90, 220),  description = "A little herbal tonic that restores 20 HP to one creature." })
med("SuperPotion", { name = "Tonic",        heal = 60,    order = 2, color = Color3.fromRGB(235, 140, 50),  description = "An herbal tonic that restores 60 HP to one creature." })
med("HyperPotion", { name = "Strong Tonic", heal = 200,   order = 3, color = Color3.fromRGB(230, 80, 140),  description = "A strong herbal tonic that restores 200 HP to one creature." })
med("MaxPotion",   { name = "Grand Tonic",  heal = "max", order = 5, color = Color3.fromRGB(80, 200, 140),  description = "Restores all of one creature's HP." })
med("FullRestore", { name = "Miracle Tonic", heal = "max", cure = "all", order = 6, color = Color3.fromRGB(240, 210, 70), description = "Restores all of one creature's HP and cures any status condition." })
-- revival seeds
med("Revive",       { name = "Revival Seed",  revive = 0.5, order = 10, color = Color3.fromRGB(250, 220, 90),  description = "A glowing seed that brings a fainted creature back with half its HP." })
med("MaxRevive",    { name = "Revival Bloom", revive = 1, cure = "all", order = 11, color = Color3.fromRGB(255, 185, 60),  description = "Brings a fainted creature back with all of its HP and clears any status condition." })
-- status cures
med("FullHeal",     { name = "Cure-All Drops", cure = "all", order = 25, color = Color3.fromRGB(240, 120, 160), description = "Cures every status condition: burn, poison, paralysis, sleep and freeze." })

-- Battle draughts: used in battle on your active creature (uses your turn). boost = { stat, stages }.
for id, d in {
	PowerDraught = { name = "Power Draught", stat = "atk", color = Color3.fromRGB(225, 80, 60) },
} do
	local statName = ({ atk = "Attack", def = "Defense", spd = "Speed" })[d.stat]
	GameData.Items[id] = {
		name = d.name, category = "Battle Items", boost = { stat = d.stat, stages = 2 }, color = d.color,
		order = ({ atk = 1, def = 2, spd = 3 })[d.stat],
		description = ("Drink it in battle: your active creature's %s rises by 2 stages until it switches out or the battle ends. Uses your turn."):format(statName),
	}
end

-- Evolution crystals: use one from the Bag on the right creature and it evolves on the spot.
-- StoneEvolutions[creature][crystalId] = what it becomes. (These are extra paths next to level-up evolutions.)
GameData.StoneEvolutions = {
	Pebblit  = { EmberCrystal = "Cinderock" }, -- normally evolves into Cragmaul at Lv 14
	Stingle  = { VoltCrystal = "Buzzbolt" },
	Squawkit = { FrostCrystal = "Icicrest" },
	Puddlepup = { FrostCrystal = "Frostpaw" },
	Nibbit   = { GloomCrystal = "Nightfang" },
	Sporelet = { GloomCrystal = "Shadeshroom" },
	Glintle  = { GaleCrystal = "Nimbuff" },
}
for id, d in {
	EmberCrystal = { name = "Ember Crystal", color = Color3.fromRGB(240, 110, 50) },
	VoltCrystal  = { name = "Volt Crystal",  color = Color3.fromRGB(245, 210, 50) },
	FrostCrystal = { name = "Frost Crystal", color = Color3.fromRGB(140, 210, 240) },
	GloomCrystal = { name = "Gloom Crystal", color = Color3.fromRGB(110, 70, 160) },
	GaleCrystal  = { name = "Gale Crystal",  color = Color3.fromRGB(170, 215, 250) },
} do
	local list = {}
	for from, map in GameData.StoneEvolutions do
		if map[id] then
			table.insert(list, from .. " \u{2192} " .. map[id])
		end
	end
	table.sort(list)
	GameData.Items[id] = {
		name = d.name, category = "Evolution", evolve = true, color = d.color,
		description = ("A glowing crystal. Use it on the right creature to make it evolve right away: %s. Used up."):format(table.concat(list, ", ")),
	}
end

-- Held items: give one to a creature from the Bag. It works automatically in every battle.
--   held = { boostType = "Fire", mult = 1.2 } powers up moves of that type
--   held = { berry = true, below = 0.5, healFrac / healHP } eaten once when HP drops under half
--   held = { berry = true, cureStatus = true } eaten once to cure a status condition
--   held = { xpMult = 1.5 } more battle XP
for _, t in { "Normal", "Fire", "Water", "Grass", "Electric", "Ice", "Fighting", "Poison", "Ground",
	"Flying", "Psychic", "Bug", "Rock", "Ghost", "Dragon", "Dark", "Steel", "Fairy" } do
	GameData.Items[t .. "Charm"] = {
		name = t .. " Charm", category = "Held Items", held = { boostType = t, mult = 1.2 }, order = 10,
		color = Color3.fromRGB(200, 190, 160),
		description = ("Give it to a creature to hold: its %s-type moves do 20%% more damage. Never used up."):format(t),
	}
end
GameData.Items.SunrootBerry = { name = "Sunroot Berry", category = "Held Items", order = 2, color = Color3.fromRGB(245, 190, 60),
	held = { berry = true, below = 0.5, healFrac = 0.25 },
	description = "Give it to a creature to hold. When its HP drops below half in battle, it eats the berry and restores a quarter of its HP. Eaten once." }
GameData.Items.MintleafBerry = { name = "Mintleaf Berry", category = "Held Items", order = 3, color = Color3.fromRGB(120, 210, 160),
	held = { berry = true, cureStatus = true },
	description = "Give it to a creature to hold. The moment it gets a status condition (burn, poison, paralysis, sleep, freeze) it eats the berry and is cured. Eaten once." }
GameData.Items.GrowthClover = { name = "Growth Clover", category = "Held Items", order = 5, color = Color3.fromRGB(110, 190, 80),
	held = { xpMult = 1.5 },
	description = "Give it to a creature to hold: it earns 50% more XP from battles. Never used up." }

----------------------------------------------------------------------------------------------
-- Battle Coliseum: PvP area behind the portal in the hub. Win battles against players to earn
-- Battle Points (BP); BP buys items you can't get anywhere else. BP can't be bought with Robux
-- (only the 2x BP pass and cosmetics are), so the Coliseum stays fair.
----------------------------------------------------------------------------------------------
GameData.Coliseum = {
	badges = 1,          -- gym badges needed to enter (and to send battle requests)
	winBP = 25,          -- BP for beating a player
	loseBP = 5,          -- BP for a close fight you lose (still worth showing up)
	bpCooldown = 300,    -- seconds before the same two players earn BP from each other again
	shop = {
		{ id = "DiscTorrentBlast", bp = 250 }, { id = "DiscBloomBurst", bp = 250 }, { id = "DiscAstralGale", bp = 300 },
		{ id = "DiscSkyDive", bp = 200 },
		{ id = "ArenaBand", bp = 400 }, { id = "ExpertCrest", bp = 450 }, { id = "GuardPlate", bp = 400 }, { id = "ArenaBerry", bp = 60 },
	},
}
-- Coliseum-only Skill Discs
for id, d in {
	DiscTorrentBlast = { move = "Torrent Blast", type = "Water", power = 90, color = Color3.fromRGB(60, 140, 240) },
	DiscBloomBurst = { move = "Bloom Burst", type = "Grass", power = 90, color = Color3.fromRGB(90, 200, 90) },
	DiscAstralGale = { move = "Astral Gale", type = "Psychic", power = 90, color = Color3.fromRGB(230, 110, 200) },
	DiscSkyDive = { move = "Sky Dive", type = "Flying", power = 80, color = Color3.fromRGB(150, 180, 255) },
	DiscMoonbeam = { move = "Moonbeam", type = "Psychic", power = 70, color = Color3.fromRGB(200, 190, 255) },
} do
	GameData.Items[id] = {
		name = "Skill Disc: " .. d.move, category = "Skill Discs", move = d.move, color = d.color, coliseum = true,
		description = ("Coliseum exclusive. Teaches %s (%s, power %d) to one of your creatures. If it already knows 4 moves, it forgets its oldest one. Single use."):format(d.move, d.type, d.power),
	}
end
-- Coliseum-only held items
GameData.Items.ArenaBand = { name = "Arena Band", category = "Held Items", order = 20, color = Color3.fromRGB(230, 70, 70), coliseum = true,
	held = { allBoost = 1.1 },
	description = "Coliseum exclusive. Give it to a creature to hold: every one of its attacks does 10% more damage. Never used up." }
GameData.Items.ExpertCrest = { name = "Expert Crest", category = "Held Items", order = 21, color = Color3.fromRGB(255, 200, 60), coliseum = true,
	held = { superBoost = 1.25 },
	description = "Coliseum exclusive. Give it to a creature to hold: its super-effective hits do 25% more damage. Never used up." }
GameData.Items.GuardPlate = { name = "Guard Plate", category = "Held Items", order = 22, color = Color3.fromRGB(150, 160, 180), coliseum = true,
	held = { guard = 0.9 },
	description = "Coliseum exclusive. Give it to a creature to hold: it takes 10% less damage from every attack. Never used up." }
GameData.Items.ArenaBerry = { name = "Arena Berry", category = "Held Items", order = 4, color = Color3.fromRGB(255, 120, 80), coliseum = true,
	held = { berry = true, below = 0.5, healFrac = 0.4 },
	description = "Coliseum exclusive. Give it to a creature to hold. When its HP drops below half in battle, it eats the berry and restores 40% of its HP. Eaten once." }

-- One line about what an item does (shop rows, the Bag, battle buttons)
function GameData.itemSummary(id: string): string
	local ball = GameData.Balls[id]
	if ball then
		if ball.kind == "quick" then
			return "Catch x4 on turn 1"
		elseif ball.kind == "heavy" then
			return "Up to x4 on big creatures"
		elseif ball.kind == "type" then
			return ("x%s vs %s"):format(tostring(ball.typeBonus), table.concat(ball.types, "/"))
		end
		return "Catch x" .. tostring(ball.multiplier)
	end
	local item = GameData.Items[id]
	if not item then
		return ""
	end
	local function cureText(c)
		if c == "all" then
			return "cures all status"
		end
		local s = GameData.StatusInfo[c]
		return "cures " .. (s and s.name:lower() or c)
	end
	local parts = {}
	if item.revive then
		table.insert(parts, item.revive >= 1 and "Revives at full HP" or ("Revives at %d%% HP"):format(math.floor(item.revive * 100)))
	elseif item.heal == "max" then
		table.insert(parts, "Restores all HP")
	elseif item.heal then
		table.insert(parts, ("Restores %d HP"):format(item.heal))
	end
	if item.cure then
		local t = cureText(item.cure)
		table.insert(parts, #parts == 0 and (t:sub(1, 1):upper() .. t:sub(2)) or t)
	end
	if item.move then
		table.insert(parts, "Teaches " .. item.move)
	end
	if item.boost then
		table.insert(parts, ("%s +2 in battle"):format(({ atk = "Attack", def = "Defense", spd = "Speed" })[item.boost.stat]))
	end
	if item.evolve then
		table.insert(parts, "Makes certain creatures evolve")
	end
	local h = item.held
	if h then
		if h.boostType then
			table.insert(parts, ("Held: %s moves +20%%"):format(h.boostType))
		elseif h.cureStatus then
			table.insert(parts, "Held: cures a status once")
		elseif h.healHP then
			table.insert(parts, ("Held: +%d HP below half, once"):format(h.healHP))
		elseif h.healFrac then
			table.insert(parts, ("Held: +%d%% HP below half, once"):format(math.floor(h.healFrac * 100)))
		elseif h.xpMult then
			table.insert(parts, ("Held: +%d%% battle XP"):format(math.floor((h.xpMult - 1) * 100)))
		elseif h.allBoost then
			table.insert(parts, ("Held: all attacks +%d%%"):format(math.floor((h.allBoost - 1) * 100 + 0.5)))
		elseif h.superBoost then
			table.insert(parts, ("Held: super-effective hits +%d%%"):format(math.floor((h.superBoost - 1) * 100 + 0.5)))
		elseif h.guard then
			table.insert(parts, ("Held: takes %d%% less damage"):format(math.floor((1 - h.guard) * 100 + 0.5)))
		end
	end
	return table.concat(parts, ", ")
end

-- Battle draught ids in Bag order
function GameData.battleItemOrder(): { string }
	local list = {}
	for id, item in GameData.Items do
		if item.boost then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		return (GameData.Items[a].order or 99) < (GameData.Items[b].order or 99)
	end)
	return list
end

-- Medicine ids in Bag order
function GameData.medicineOrder(): { string }
	local list = {}
	for id, item in GameData.Items do
		if item.category == "Medicine" then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		return (GameData.Items[a].order or 99) < (GameData.Items[b].order or 99)
	end)
	return list
end

-- Ball ids in Bag order
function GameData.ballOrder(): { string }
	local list = {}
	for id in GameData.Balls do
		table.insert(list, id)
	end
	table.sort(list, function(a, b)
		return (GameData.Balls[a].order or 99) < (GameData.Balls[b].order or 99)
	end)
	return list
end

-- Clerk Milo's shop. badges = gym badges needed before it's sold (like stocking better items later on).
GameData.Shop = {
	-- from the start
	{ id = "Potion", price = 30, badges = 0 },
	{ id = "SwiftBall", price = 50, badges = 0 },
	{ id = "FullHeal", price = 60, badges = 0 },
	-- 1 badge
	{ id = "SuperPotion", price = 90, badges = 1 },
	{ id = "QuickBall", price = 90, badges = 1 },
	-- 2 badges
	{ id = "Revive", price = 250, badges = 2 },
	{ id = "HeavyBall", price = 120, badges = 2 },
	{ id = "AquaBall", price = 120, badges = 2 },
	{ id = "BlazeBall", price = 120, badges = 2 },
	{ id = "LeafBall", price = 120, badges = 2 },
	{ id = "VoltBall", price = 120, badges = 2 },
	{ id = "StoneBall", price = 120, badges = 2 },
	-- 3+ badges
	{ id = "UltraBall", price = 150, badges = 3 },
	{ id = "SkyBall", price = 120, badges = 3 },
	{ id = "ShadeBall", price = 120, badges = 4 },
	{ id = "HyperPotion", price = 280, badges = 4 },
	{ id = "ApexBall", price = 300, badges = 5 },
	{ id = "MaxPotion", price = 450, badges = 6 },
	{ id = "MaxRevive", price = 600, badges = 6 },
	{ id = "FullRestore", price = 650, badges = 7 },
	-- battle draughts
	{ id = "PowerDraught", price = 100, badges = 1 },
	-- held items
	{ id = "MintleafBerry", price = 120, badges = 1 },
	{ id = "SunrootBerry", price = 90, badges = 0 },
	{ id = "GrowthClover", price = 1500, badges = 3 },
}
-- evolution crystals (3 badges)
for _, id in { "EmberCrystal", "VoltCrystal", "FrostCrystal", "GloomCrystal", "GaleCrystal" } do
	table.insert(GameData.Shop, { id = id, price = 1200, badges = 3 })
end

-- Items that were cut from the game, and what old saves get instead (1:1)
GameData.RetiredItems = {
	LevelBall = "QuickBall", FrostBall = "AquaBall", HiveBall = "LeafBall", MindBall = "ShadeBall",
	MegaPotion = "HyperPotion", PhoenixPlume = "MaxRevive",
	Antidote = "FullHeal", BurnSalve = "FullHeal", ThawSpray = "FullHeal", WakeBell = "FullHeal", ParalyzeBalm = "FullHeal",
	GuardDraught = "PowerDraught", SwiftDraught = "PowerDraught",
	SweetrootBerry = "SunrootBerry",
}

-- One Skill Disc per gym (same rules as Rockfall)
for id, d in {
	DiscTidePulse = { move = "Tide Pulse", type = "Water", power = 65, color = Color3.fromRGB(80, 140, 235) },
	DiscQuakeStomp = { move = "Quake Stomp", type = "Ground", power = 75, color = Color3.fromRGB(200, 165, 90) },
	DiscThunderLash = { move = "Thunder Lash", type = "Electric", power = 80, color = Color3.fromRGB(240, 200, 40) },
	DiscInfernoDive = { move = "Inferno Dive", type = "Fire", power = 85, color = Color3.fromRGB(235, 100, 45) },
	DiscHailLance = { move = "Hail Lance", type = "Ice", power = 75, color = Color3.fromRGB(120, 200, 230) },
	DiscPhantomWail = { move = "Phantom Wail", type = "Ghost", power = 80, color = Color3.fromRGB(120, 90, 170) },
	DiscDragonRush = { move = "Dragon Rush", type = "Dragon", power = 90, color = Color3.fromRGB(110, 60, 240) },
} do
	GameData.Items[id] = {
		name = "Skill Disc: " .. d.move, category = "Skill Discs", move = d.move, color = d.color,
		description = ("Teaches %s (%s, power %d) to one of your creatures. If it already knows 4 moves, it forgets its oldest one. Single use."):format(d.move, d.type, d.power),
	}
end

-- Economy and trainer progression
-- Coins come from playing: battles, catches, trainers, gyms, quests and the Dungeon.
-- Creature XP comes from battles, plus slow "base training" while they sit in your base (see BaseTraining).
GameData.Economy = {
	wildWinCoins = 6,       -- + wildCoinsPerLevel x the wild creature's level
	wildCoinsPerLevel = 1.5,
	trainerCoinMult = 1.5,  -- route trainers, gyms, Dungeon floors and the League pay this much more than their listed coins
	wildWinXP = 4,          -- x the wild creature's level (trainer XP)
	catchCoins = 12,
	catchXP = 6,            -- x the caught creature's level
	expansionCost = 500,    -- unlock the area behind your base (team cap 6 -> 12)
	benchXPShare = 0.50,    -- XP Canopy's top tier (the real share is per player: DecorData.CanopyTiers, upgraded with coins)
}
-- Base training: every minute you're online, creatures in your base (not while you battle) gain a
-- slice of the XP they need for their next level. Passive XP never trains past `levelCap(badges)`,
-- so the last levels and every star have to be earned in battle.
GameData.BaseTraining = {
	rate = 0.015,           -- share of the current level's XP per minute
	dummyRate = 0.015,      -- + per Training Dummy (up to 3)
	habitatRate = 0.02,     -- + for a creature whose type matches a habitat you placed (up to 2 habitats)
	maxDummies = 3,
	maxHabitats = 2,
	offlineRate = 0.5,      -- training keeps going at half speed while you're away, up to offlineHours
	offlineHours = 8,
}
-- Level cap: creatures stop growing at the cap for your badge count (XP past it is lost),
-- so you can't out-level a gym by grinding. Each cap sits 2 above the next leader's ace.
-- index = badges + 1. Region 1 champion run: 8 badges -> 70 (the Champion's ace is 70).
-- Beating the Champion lifts it to 75; Region 2 badges (9..16) keep raising it.
-- At 16 badges the cap is gone and stars (XP past Lv 100) unlock.
GameData.LevelCaps = { 14, 20, 27, 33, 39, 45, 51, 57, 70, 79, 83, 87, 91, 95, 99, 100, 100 }
GameData.ChampionCap = 75
function GameData.levelCap(badges: number, champion: boolean?): (number, boolean)
	badges = math.clamp(badges or 0, 0, #GameData.LevelCaps - 1)
	local cap = GameData.LevelCaps[badges + 1]
	if badges == 8 and champion then
		cap = GameData.ChampionCap
	end
	return cap, badges >= 16
end
-- passive base training stops 3 levels under the battle cap
function GameData.BaseTraining.levelCap(badges: number, champion: boolean?): number
	return math.max(5, GameData.levelCap(badges, champion) - 3)
end

function GameData.trainerXPToNext(level: number): number
	return 100 + (level - 1) * 50
end

-- The Dungeon tower: one trainer per floor, 1.10 is the boss, 2.1 is the end for now
GameData.Dungeon = {
	floors = {
		{ label = "1.1",  trainer = "Tower Trainee Pip",  team = { { "Nibbit", 2 } },                          coins = 20,  xp = 30 },
		{ label = "1.2",  trainer = "Tower Trainee Rue",  team = { { "Fluttle", 4 }, { "Wigglet", 3 } },       coins = 25,  xp = 35 },
		{ label = "1.3",  trainer = "Tower Trainee Bo",   team = { { "Squawkit", 5 } },                        coins = 30,  xp = 40 },
		{ label = "1.4",  trainer = "Tower Adept Lin",    team = { { "Thornip", 5 }, { "Nibbit", 5 } },        coins = 35,  xp = 45 },
		{ label = "1.5",  trainer = "Tower Adept Kade",   team = { { "Stingle", 6 }, { "Wigglet", 6 } },       coins = 40,  xp = 50 },
		{ label = "1.6",  trainer = "Tower Adept Juno",   team = { { "Brawlet", 7 } },                         coins = 45,  xp = 55 },
		{ label = "1.7",  trainer = "Tower Veteran Moss", team = { { "Shellum", 7 }, { "Squawkit", 7 } },      coins = 50,  xp = 60 },
		{ label = "1.8",  trainer = "Tower Veteran Ash",  team = { { "Thornip", 8 }, { "Stingle", 8 } },       coins = 55,  xp = 70 },
		{ label = "1.9",  trainer = "Tower Veteran Quill", team = { { "Brawlet", 9 }, { "Squawkit", 9 } },     coins = 60,  xp = 80 },
		{ label = "1.10", trainer = "Tower Warden Nyx",   team = { { "Squawkit", 10 }, { "Voltmole", 10 }, { "Brawlet", 11 } }, coins = 250, xp = 220, boss = true },
		{ label = "2.1",  rest = true },
	},
}

-- Route trainers: three in the later part of every area, before its gym. They spot you when you
-- walk into their line of sight (straight ahead of them) and battle you; no running.
-- x, z = where they stand (they face the hub, toward players walking up the route). Beaten once = beaten for good.
GameData.RouteTrainers = {
	-- Meadow Route
	{ id = "r1a", lane = "Lane1", name = "Rookie Theo", x = 14, z = 470, team = { { "Nibbit", 6 }, { "Fluttle", 6 } }, intro = "Hey! I just got my first creatures. Battle me!", after = "You're good! I need more practice." },
	{ id = "r1b", lane = "Lane1", name = "Explorer Mae", x = -14, z = 530, team = { { "Wigglet", 7 }, { "Stingle", 7 } }, intro = "The woods are full of bugs. Want to meet mine?", after = "My bugs need a nap after that." },
	{ id = "r1c", lane = "Lane1", name = "Scout Bram", x = 14, z = 585, team = { { "Thornip", 8 }, { "Brawlet", 8 } }, intro = "Nobody gets to Slate without getting past me!", after = "Fine, go on. Slate's tougher than me, though." },
	-- Boulder Pass, Glimmer Cavern, Brook Town
	{ id = "r2a", lane = "Lane1B", name = "Caver Ollie", x = 196, z = 459, team = { { "Echoling", 12 }, { "Pebblit", 12 } }, intro = "Shh! You'll wake the Echolings... too late. Battle!", after = "The cave's all yours." },
	{ id = "r2b", lane = "Lane1B", name = "Crystal Seeker Lena", x = 224, z = 519, team = { { "Glintle", 13 }, { "Echoling", 13 } }, intro = "These crystals are mine! Well... let's battle for them!", after = "Okay, you can look at the crystals." },
	{ id = "r2c", lane = "Lane1B", name = "Angler Ross", x = 201, z = 584, team = { { "Puddlepup", 14 }, { "Sporelet", 14 } }, intro = "Caught a challenger! Let's see how you swim.", after = "That one got away from me." },
	-- Tide Coast
	{ id = "r3a", lane = "Lane3", name = "Swimmer Nia", x = -84, z = 470, team = { { "Ripplefin", 19 }, { "Ripplefin", 19 } }, intro = "The water's perfect today! Ready to battle?", after = "Time to dry off..." },
	{ id = "r3b", lane = "Lane3", name = "Beachcomber Dex", x = -56, z = 530, team = { { "Sandsnip", 20 }, { "Pinchard", 20 } }, intro = "Look what I dug up on the beach! Battle!", after = "Back to digging, I guess." },
	{ id = "r3c", lane = "Lane3", name = "Diver Kael", x = -84, z = 585, team = { { "Ripplefin", 21 }, { "Pinchard", 21 }, { "Sandsnip", 21 } }, intro = "Duna trained me herself. Show me what you've got!", after = "You might actually beat Duna." },
	-- Volt Plains
	{ id = "r4a", lane = "Lane4", name = "Engineer Pax", x = 126, z = 470, team = { { "Zapkit", 25 }, { "Voltmole", 25 } }, intro = "These pylons hum all day. So does my team. Battle!", after = "Short circuit..." },
	{ id = "r4b", lane = "Lane4", name = "Stormchaser Rin", x = 154, z = 530, team = { { "Buzzbolt", 26 }, { "Zapkit", 26 } }, intro = "I chase storms. You look like a storm. Battle!", after = "Okay, you're a big storm." },
	{ id = "r4c", lane = "Lane4", name = "Lineworker Gus", x = 126, z = 585, team = { { "Voltmole", 27 }, { "Buzzbolt", 27 }, { "Zapkit", 27 } }, intro = "Nobody reaches Jolt without passing my inspection!", after = "Inspection passed. Go see Jolt." },
	-- Ember Ridge
	{ id = "r5a", lane = "Lane2", name = "Firewalker Vex", x = 84, z = 470, team = { { "Scorchling", 31 }, { "Cinderock", 31 } }, intro = "I walk on lava for fun. Battling you is easy!", after = "Ouch. That burned." },
	{ id = "r5b", lane = "Lane2", name = "Smith Hollis", x = 56, z = 530, team = { { "Cinderock", 32 }, { "Embercub", 32 } }, intro = "I forge my team in volcano heat. Let's test yours!", after = "Back to the forge for me." },
	{ id = "r5c", lane = "Lane2", name = "Ash Ranger Kit", x = 84, z = 585, team = { { "Scorchling", 33 }, { "Embercub", 33 }, { "Cinderock", 33 } }, intro = "I guard the ridge for Ignatia. You won't pass!", after = "Go on. Ignatia's waiting." },
	-- Frost Peak
	{ id = "r6a", lane = "Lane5", name = "Mountaineer Bo", x = -126, z = 470, team = { { "Frostpaw", 37 }, { "Rimeling", 37 } }, intro = "Climbed this peak a hundred times. Battle me at the top!", after = "Brr. You're tough." },
	{ id = "r6b", lane = "Lane5", name = "Skier Tova", x = -154, z = 530, team = { { "Icicrest", 38 }, { "Frostpaw", 38 } }, intro = "Whoosh! Out of my way... unless you want to battle!", after = "Wiped out!" },
	{ id = "r6c", lane = "Lane5", name = "Ice Sculptor Nils", x = -126, z = 585, team = { { "Rimeling", 39 }, { "Icicrest", 39 }, { "Frostpaw", 39 } }, intro = "My creatures are works of art. Let me show you!", after = "Art takes time. And losses." },
	-- Shadow Woods
	{ id = "r7a", lane = "Lane6", name = "Mystic Wren", x = 14, z = 871, team = { { "Gloomwisp", 43 }, { "Shadeshroom", 43 } }, intro = "The spirits told me you'd come. Battle!", after = "The spirits... were wrong." },
	{ id = "r7b", lane = "Lane6", name = "Night Owl Cass", x = -14, z = 931, team = { { "Nightfang", 44 }, { "Gloomwisp", 44 } }, intro = "I only come out at night. Lucky you!", after = "Back to the shadows." },
	{ id = "r7c", lane = "Lane6", name = "Medium Odile", x = 14, z = 986, team = { { "Shadeshroom", 45 }, { "Nightfang", 45 }, { "Gloomwisp", 45 } }, intro = "Morrow sees all through me. Prove yourself!", after = "Morrow will be impressed." },
	-- Sky Spire
	{ id = "r8a", lane = "Lane7", name = "Skydiver Remy", x = -224, z = 470, team = { { "Zephlet", 49 }, { "Nimbuff", 49 } }, intro = "Ever jumped off a cloud? Battle me first!", after = "Freefall... of my pride." },
	{ id = "r8b", lane = "Lane7", name = "Glider Pilot Ana", x = -196, z = 530, team = { { "Galewing", 50 }, { "Zephlet", 50 } }, intro = "The wind is on my side today!", after = "The wind changed." },
	{ id = "r8c", lane = "Lane7", name = "Cloud Watcher Sol", x = -224, z = 585, team = { { "Nimbuff", 51 }, { "Galewing", 51 }, { "Zephlet", 51 } }, intro = "Only the strongest reach Aero. Are you one of them?", after = "You are. Go meet Aero." },
}

-- Gym leaders (original characters). npc = the leader's model inside workspace.Map[model].
-- intro / win = what they say before and after a battle.
-- Region 1 is one continuous road of 520-stud regions: Meadow (z 250) -> Boulder Pass (770) -> Tide Coast (1290)
-- -> Volt Plains (1810) -> Ember Ridge (2330) -> Frost Peak (2850) -> Shadow Woods (3371) -> Sky Spire (3890)
-- -> Victory Road (4413). The trainer spots above were written for the old side-by-side layout; this moves
-- them onto the road. (z offsets updated 2026-11-02 for the 520-stud lanes; they must match the trainer models.)
GameData.RoadOffsets = {
	Lane1 = { 0, 120 }, Lane1B = { -210, 640 }, Lane3 = { 70, 1160 }, Lane4 = { -140, 1680 }, Lane2 = { -70, 2200 },
	Lane5 = { 140, 2720 }, Lane6 = { 0, 2840 }, Lane7 = { 210, 3760 },
}
for _, t in GameData.RouteTrainers do
	local off = GameData.RoadOffsets[t.lane]
	if off then
		t.x += off[1]
		t.z += off[2]
	end
end

GameData.GymLeaders = {
	Meadow = {
		name = "Gym Leader Slate", specialty = "Rock", model = "MeadowGym", npc = "Slate", lane = "Lane1",
		team = { { "Pebblit", 9 }, { "Cragmaul", 12 } },
		badge = "Quarry Badge", item = "DiscRockfall", charm = "RockCharm",
		coins = 300, xp = 300, rematchCoins = 60, rematchXP = 60,
		intro = "I'm Slate! My Rock creatures are tough as bedrock. Show me what you've got!",
		rematch = "Back for more? My rocks never crumble!",
		win = "Solid work! You've got a heart of stone... in a good way.",
	},
	Brook = {
		name = "Gym Leader Duna", specialty = "Ground", model = "BrookGym", npc = "Duna", lane = "Lane1B",
		team = { { "Sandsnip", 15 }, { "Pinchard", 16 }, { "Dunehorn", 18 } },
		badge = "Dune Badge", item = "DiscQuakeStomp", charm = "GroundCharm",
		coins = 400, xp = 400, rematchCoins = 80, rematchXP = 80,
		intro = "Welcome to Boulder Pass! My Ground creatures stand firm. Can you move a mountain?",
		rematch = "Solid ground, fresh battle!",
		win = "You shook the mountain! The Dune Badge is yours.",
	},
	Tide = {
		name = "Gym Leader Coralie", specialty = "Water", model = "TideGym", npc = "Coralie", lane = "Lane3",
		team = { { "Puddlepup", 21 }, { "Ripplefin", 22 }, { "Tidecrest", 25 } },
		badge = "Ripple Badge", item = "DiscTidePulse", charm = "WaterCharm",
		coins = 500, xp = 500, rematchCoins = 100, rematchXP = 100,
		intro = "Welcome to Tide Coast! My Water creatures go with the flow. Can you keep up?",
		rematch = "The tide is back in. Ready for another splash?",
		win = "You washed right over me! The Ripple Badge is yours.",
	},
	Volt = {
		name = "Gym Leader Jolt", specialty = "Electric", model = "VoltGym", npc = "Jolt", lane = "Lane4",
		team = { { "Zapkit", 27 }, { "Buzzbolt", 28 }, { "Stormane", 31 } },
		badge = "Spark Badge", item = "DiscThunderLash", charm = "ElectricCharm",
		coins = 600, xp = 600, rematchCoins = 120, rematchXP = 120,
		intro = "Bzzt! I'm Jolt, and my team runs at a million volts. Try not to get shocked!",
		rematch = "Recharged and ready!",
		win = "Whoa, what a surge! The Spark Badge is all yours.",
	},
	Ember = {
		name = "Gym Leader Ignatia", specialty = "Fire", model = "EmberGym", npc = "Ignatia", lane = "Lane2",
		team = { { "Cinderock", 33 }, { "Scorchling", 34 }, { "Cindrake", 37 } },
		badge = "Cinder Badge", item = "DiscInfernoDive", charm = "FireCharm",
		coins = 700, xp = 700, rematchCoins = 140, rematchXP = 140,
		intro = "The ridge is burning hot, and so is my team. Step into the fire!",
		rematch = "Still warm from last time? Let's turn up the heat!",
		win = "You put out my flames! Take the Cinder Badge.",
	},
	Frost = {
		name = "Gym Leader Hale", specialty = "Ice", model = "FrostGym", npc = "Hale", lane = "Lane5",
		team = { { "Frostpaw", 39 }, { "Icicrest", 40 }, { "Glaciorn", 43 } },
		badge = "Glacier Badge", item = "DiscHailLance", charm = "IceCharm",
		coins = 800, xp = 800, rematchCoins = 160, rematchXP = 160,
		intro = "Cold hands, colder creatures. Only the steady survive the peak!",
		rematch = "The blizzard never really stops.",
		win = "Ice cold. The Glacier Badge is yours.",
	},
	Shadow = {
		name = "Gym Leader Morrow", specialty = "Ghost", model = "ShadowGym", npc = "Morrow", lane = "Lane6",
		team = { { "Gloomwisp", 45 }, { "Nightfang", 46 }, { "Phantorb", 49 } },
		badge = "Eclipse Badge", item = "DiscPhantomWail", charm = "GhostCharm",
		coins = 900, xp = 900, rematchCoins = 180, rematchXP = 180,
		intro = "Shh... the woods are listening. My creatures live in the dark between the trees.",
		rematch = "The shadows remember you...",
		win = "You found the light. Take the Eclipse Badge.",
	},
	Sky = {
		name = "Gym Leader Aero", specialty = "Dragon", model = "SkyGym", npc = "Aero", lane = "Lane7",
		team = { { "Galewing", 50 }, { "Nimbuff", 51 }, { "Skydrake", 55 } },
		badge = "Zenith Badge", item = "DiscDragonRush", charm = "DragonCharm",
		coins = 1200, xp = 1200, rematchCoins = 240, rematchXP = 240,
		intro = "You climbed all the way to the top of the spire. Now face the dragons who live here!",
		rematch = "The sky is wide. Let's fly again!",
		win = "You've reached the Zenith! All eight badges... incredible.",
	},
}

-- Professor Maple's three starters (level 5). counter = the one the rival takes against it.
GameData.Starters = {
	{ name = "Sproutle", counter = "Kindlit", blurb = "A calm Grass creature with a leaf bud on its back. Tough and patient." },
	{ name = "Kindlit", counter = "Drizzlet", blurb = "A playful Fire fox whose tail flickers when it's excited. Fast and fierce." },
	{ name = "Drizzlet", counter = "Sproutle", blurb = "A cheerful Water turtle that loves to splash. Sturdy and dependable." },
}
GameData.StarterLevel = 5
GameData.RivalName = "Rival Kai"
GameData.ProfessorName = "Professor Maple"

-- Old names from earlier versions, so old saves still load
GameData.Renamed = {
	Finnly = "Ripplefin", Clawdle = "Pinchard", Magmite = "Cinderock", Glacikit = "Frostpaw", Frostling = "Rimeling",
	Wispy = "Gloomwisp", Breezlet = "Zephlet", Aerowing = "Galewing", Nimbo = "Nimbuff",
}

-- Evolutions: a creature that reaches `level` evolves into `into` after the battle
GameData.Evolutions = {
	Sproutle = { into = "Bramblet", level = 16 },
	Bramblet = { into = "Thornwarden", level = 32 },
	Kindlit = { into = "Blazefox", level = 16 },
	Blazefox = { into = "Infernyx", level = 32 },
	Drizzlet = { into = "Torrentail", level = 16 },
	Torrentail = { into = "Tidalgon", level = 32 },
	Wigglet = { into = "Shellum", level = 7 },
	Fluttle = { into = "Squawkit", level = 10 },
	Pebblit = { into = "Cragmaul", level = 14 },
	Ripplefin = { into = "Tidecrest", level = 20 },
	Sandsnip = { into = "Dunehorn", level = 22 },
	Zapkit = { into = "Stormane", level = 26 },
	Embercub = { into = "Cindrake", level = 28 },
	Rimeling = { into = "Glaciorn", level = 32 },
	Gloomwisp = { into = "Phantorb", level = 34 },
	Zephlet = { into = "Galewing", level = 36 },
}

-- Creature Index regions: catch every creature listed to earn the reward once
GameData.IndexRegions = {
	{ id = "Meadow", name = "Meadow Route", creatures = { "Fluttle", "Nibbit", "Squawkit", "Thornip", "Brawlet" }, coins = 250 },
	{ id = "Whisperwood", name = "Whisperwood", creatures = { "Wigglet", "Stingle", "Shellum", "Voltmole" }, coins = 400 },
	{ id = "Boulder", name = "Boulder Pass & Glimmer Cavern", creatures = { "Pebblit", "Cragmaul", "Sporelet", "Echoling", "Glintle", "Puddlepup" }, coins = 500 },
	{ id = "TideCoast", name = "Tide Coast", creatures = { "Ripplefin", "Tidecrest", "Sandsnip", "Dunehorn", "Pinchard" }, coins = 600 },
	{ id = "VoltPlains", name = "Volt Plains", creatures = { "Zapkit", "Stormane", "Buzzbolt" }, coins = 700 },
	{ id = "EmberRidge", name = "Ember Ridge", creatures = { "Embercub", "Cindrake", "Scorchling", "Cinderock" }, coins = 800 },
	{ id = "FrostPeak", name = "Frost Peak", creatures = { "Frostpaw", "Rimeling", "Glaciorn", "Icicrest" }, coins = 900 },
	{ id = "ShadowWoods", name = "Shadow Woods", creatures = { "Gloomwisp", "Phantorb", "Shadeshroom", "Nightfang" }, coins = 1000 },
	{ id = "SkySpire", name = "Sky Spire", creatures = { "Zephlet", "Galewing", "Nimbuff", "Skydrake" }, coins = 1200 },
	{ id = "All", name = "Full Index", creatures = GameData.IndexOrder, coins = 5000 },
}

-- Daily login streak: day 1..7 rewards, then it loops at day 7's reward. Miss a day and it resets.
GameData.DailyRewards = { 50, 80, 120, 160, 220, 300, 500 }

-- Daily quests: 3 are picked each day (same for everyone). kind: catch, catchType, winWild, towerFloor, heal, pvpWin
GameData.QuestPool = {
	{ id = "catch5", kind = "catch", goal = 5, coins = 60, xp = 60, text = "Catch 5 creatures" },
	{ id = "catch10", kind = "catch", goal = 10, coins = 120, xp = 120, text = "Catch 10 creatures" },
	{ id = "bug3", kind = "catchType", type = "Bug", goal = 3, coins = 80, xp = 70, text = "Catch 3 Bug types" },
	{ id = "flying3", kind = "catchType", type = "Flying", goal = 3, coins = 80, xp = 70, text = "Catch 3 Flying types" },
	{ id = "normal4", kind = "catchType", type = "Normal", goal = 4, coins = 70, xp = 60, text = "Catch 4 Normal types" },
	{ id = "win5", kind = "winWild", goal = 5, coins = 70, xp = 80, text = "Win 5 wild battles" },
	{ id = "win10", kind = "winWild", goal = 10, coins = 130, xp = 150, text = "Win 10 wild battles" },
	{ id = "tower2", kind = "towerFloor", goal = 2, coins = 90, xp = 100, text = "Clear 2 tower floors" },
	{ id = "heal2", kind = "heal", goal = 2, coins = 40, xp = 30, text = "Heal at the Healing Center twice" },
	-- (no PvP quest: it can't be finished on an empty server)
	{ id = "win15", kind = "winWild", goal = 15, coins = 180, xp = 200, text = "Win 15 wild battles" },
}
GameData.QuestsPerDay = 4
for _, q in GameData.QuestPool do
	q.coins = math.floor(q.coins * 1.5) -- quests are a main coin source
end

-- Rare spawn event: every `everySeconds` a boosted creature appears in an open lane for `lastsSeconds`
GameData.RareEvent = {
	everySeconds = 3600,
	lastsSeconds = 300,
	shinyChance = 0.25,
	pool = { { "Voltmole", 12 }, { "Brawlet", 12 }, { "Thornip", 12 }, { "Lunaryx", 15 } },
}

-- PvP: battles use full-HP copies of each team; nothing faints for real. Rewards once per opponent per cooldown.
GameData.PvP = { winCoins = 40, winXP = 60, loseCoins = 10, loseXP = 15, rewardCooldown = 300, turnSeconds = 30 }

-- Trading: up to this many creatures per side; you always keep at least one
GameData.TradeMax = 3

-- REGION 2 ------------------------------------------------------------------------------
-- (creatures are stronger versions of existing species for now; new species can replace them)
local function spawnsFrom(early, late)
	local list = {}
	for _, s in early do
		table.insert(list, { name = s[1], weight = s[2], minDepth = 0, maxDepth = 0.6 })
	end
	for _, s in late do
		table.insert(list, { name = s[1], weight = s[2], minDepth = 0.6, maxDepth = 1 })
	end
	return list
end
GameData.Lanes.Lane9 = { minLevel = 70, maxLevel = 74, spawns = spawnsFrom(
	{ { "Bramblet", 30 }, { "Sporelet", 25 }, { "Glintle", 25 }, { "Buzzbolt", 20 } },
	{ { "Nimbuff", 30 }, { "Galewing", 25 }, { "Bramblet", 25 }, { "Thornwarden", 6 } }) }
GameData.Lanes.Lane10 = { minLevel = 74, maxLevel = 78, spawns = spawnsFrom(
	{ { "Sandsnip", 35 }, { "Scorchling", 25 }, { "Zephlet", 20 }, { "Cinderock", 20 } },
	{ { "Dunehorn", 35 }, { "Cinderock", 25 }, { "Scorchling", 25 }, { "Cragmaul", 6 } }) }
GameData.Lanes.Lane11 = { minLevel = 78, maxLevel = 82, spawns = spawnsFrom(
	{ { "Ripplefin", 35 }, { "Puddlepup", 25 }, { "Pinchard", 20 }, { "Glintle", 20 } },
	{ { "Torrentail", 30 }, { "Pinchard", 30 }, { "Ripplefin", 25 }, { "Tidecrest", 6 } }) }
GameData.Lanes.Lane12 = { minLevel = 82, maxLevel = 86, spawns = spawnsFrom(
	{ { "Zapkit", 35 }, { "Pebblit", 25 }, { "Buzzbolt", 25 }, { "Voltmole", 15 } },
	{ { "Buzzbolt", 30 }, { "Cragmaul", 25 }, { "Zapkit", 25 }, { "Stormane", 6 } }) }
GameData.Lanes.Lane13 = { minLevel = 86, maxLevel = 90, spawns = spawnsFrom(
	{ { "Stingle", 30 }, { "Thornip", 30 }, { "Wigglet", 20 }, { "Echoling", 20 } },
	{ { "Shadeshroom", 35 }, { "Echoling", 25 }, { "Stingle", 25 }, { "Thornwarden", 6 } }) }
GameData.Lanes.Lane14 = { minLevel = 90, maxLevel = 94, spawns = spawnsFrom(
	{ { "Glintle", 35 }, { "Pebblit", 25 }, { "Rimeling", 20 }, { "Echoling", 20 } },
	{ { "Nimbuff", 30 }, { "Cragmaul", 30 }, { "Glintle", 25 }, { "Glaciorn", 6 } }) }
GameData.Lanes.Lane15 = { minLevel = 94, maxLevel = 97, spawns = spawnsFrom(
	{ { "Gloomwisp", 40 }, { "Shadeshroom", 30 }, { "Echoling", 30 } },
	{ { "Nightfang", 35 }, { "Gloomwisp", 35 }, { "Shadeshroom", 20 }, { "Phantorb", 6 } }) }
GameData.Lanes.Lane16 = { minLevel = 96, maxLevel = 100, spawns = spawnsFrom(
	{ { "Zephlet", 30 }, { "Galewing", 30 }, { "Icicrest", 25 }, { "Scorchling", 15 } },
	{ { "Galewing", 30 }, { "Cindrake", 25 }, { "Tidecrest", 25 }, { "Skydrake", 5 } }) }

-- Victory Road: a training ground between the 8th badge and the League (not a region; no gym)
GameData.Lanes.LaneVR = { minLevel = 52, maxLevel = 60, spawns = spawnsFrom(
	{ { "Galewing", 25 }, { "Nightfang", 25 }, { "Cragmaul", 20 }, { "Icicrest", 15 }, { "Dunehorn", 15 } },
	{ { "Glaciorn", 25 }, { "Stormane", 25 }, { "Cindrake", 20 }, { "Tidecrest", 20 }, { "Phantorb", 8 }, { "Skydrake", 4 } }) }
-- Summit Victory Road (Region 2): training ground before the Summit League. Wild creatures spawn in the
-- invisible Lanes.LaneVR2 zone (like LaneVR in Region 1), which stops 10 studs short of the League hall.
GameData.Lanes.LaneVR2 = { minLevel = 97, maxLevel = 100, spawns = spawnsFrom(
	{ { "Galewing", 25 }, { "Nightfang", 25 }, { "Cragmaul", 20 }, { "Glaciorn", 15 }, { "Thornwarden", 15 } },
	{ { "Stormane", 25 }, { "Cindrake", 25 }, { "Tidecrest", 20 }, { "Phantorb", 15 }, { "Skydrake", 6 } }) }

local function leader(t)
	t.region = 2
	t.rematchCoins = math.floor(t.coins / 5)
	t.rematchXP = math.floor(t.xp / 5)
	return t
end
GameData.GymLeaders.Bloom = leader({ name = "Gym Leader Fern", specialty = "Grass", model = "BloomGym", npc = "Fern", lane = "Lane9",
	team = { { "Bramblet", 69 }, { "Sporelet", 69 }, { "Nimbuff", 70 }, { "Thornwarden", 73 } }, badge = "Petal Badge", item = "GrowthClover", charm = "GrassCharm",
	coins = 1600, xp = 1600, intro = "Welcome to Summit's first gym! My garden grows stronger every season. Ready?",
	rematch = "The flowers bloomed again. Let's battle!", win = "Your team blossomed beautifully. The Petal Badge is yours!" })
GameData.GymLeaders.Mirage = leader({ name = "Gym Leader Sahra", specialty = "Ground", model = "MirageGym", npc = "Sahra", lane = "Lane10",
	team = { { "Dunehorn", 74 }, { "Cinderock", 74 }, { "Cragmaul", 75 }, { "Dunehorn", 77 } }, badge = "Mirage Badge", item = "ApexBall", -- was "Dune Badge" (same as Tide), which blocked Region 2 at 9 badges
	coins = 1800, xp = 1800, intro = "The desert tests everyone who crosses it. Let's see if you're a mirage or the real deal!",
	rematch = "Back in the heat? Let's go!", win = "You're the real deal. Take the Mirage Badge." })
GameData.GymLeaders.Reef = leader({ name = "Gym Leader Marin", specialty = "Water", model = "ReefGym", npc = "Marin", lane = "Lane11",
	team = { { "Torrentail", 78 }, { "Pinchard", 78 }, { "Tidecrest", 80 }, { "Tidalgon", 81 } }, badge = "Coral Badge", item = "MaxRevive",
	coins = 2000, xp = 2000, intro = "Dive in! The reef is beautiful, but its creatures bite.",
	rematch = "The tide's in. Battle me!", win = "You swam circles around me. The Coral Badge is yours." })
GameData.GymLeaders.Mesa = leader({ name = "Gym Leader Volta", specialty = "Electric", model = "MesaGym", npc = "Volta", lane = "Lane12",
	team = { { "Buzzbolt", 82 }, { "Voltmole", 82 }, { "Stormane", 84 }, { "Stormane", 85 } }, badge = "Thunder Badge", item = "FullRestore",
	coins = 2200, xp = 2200, intro = "Thunder rolls across the mesa every day. Today it rolls over you!",
	rematch = "Feel that static? Rematch!", win = "Shocking! The Thunder Badge is yours." })
GameData.GymLeaders.Bog = leader({ name = "Gym Leader Hemlock", specialty = "Poison", model = "BogGym", npc = "Hemlock", lane = "Lane13",
	team = { { "Echoling", 86 }, { "Shadeshroom", 86 }, { "Thornwarden", 88 }, { "Thornwarden", 89 } }, badge = "Venom Badge", item = "FullHeal", charm = "PoisonCharm",
	coins = 2400, xp = 2400, intro = "Careful where you step. Everything in this bog is poisonous, including me.",
	rematch = "Back for another dose?", win = "You've got an iron stomach. Take the Venom Badge." })
GameData.GymLeaders.Crystal = leader({ name = "Gym Leader Gemma", specialty = "Fairy", model = "CrystalGym", npc = "Gemma", lane = "Lane14",
	team = { { "Glintle", 90 }, { "Nimbuff", 90 }, { "Glaciorn", 92 }, { "Lunaryx", 93 } }, badge = "Prism Badge", item = "MaxRevive", charm = "FairyCharm",
	coins = 2600, xp = 2600, intro = "The crystals here sing when a strong trainer walks in. They're singing for you.",
	rematch = "The crystals are humming again!", win = "Dazzling! The Prism Badge is yours." })
GameData.GymLeaders.Manor = leader({ name = "Gym Leader Silas", specialty = "Ghost", model = "ManorGym", npc = "Silas", lane = "Lane15",
	team = { { "Gloomwisp", 94 }, { "Nightfang", 95 }, { "Phantorb", 96 }, { "Phantorb", 97 } }, badge = "Spectre Badge", item = "ApexBall",
	coins = 2800, xp = 2800, intro = "Welcome to my manor. Most guests never leave... shall we find out why?",
	rematch = "The ghosts missed you.", win = "You've escaped the manor. Take the Spectre Badge." })
GameData.GymLeaders.Peak = leader({ name = "Gym Leader Drakon", specialty = "Dragon", model = "PeakGym", npc = "Drakon", lane = "Lane16",
	team = { { "Galewing", 95 }, { "Cindrake", 96 }, { "Tidecrest", 97 }, { "Skydrake", 100 } }, badge = "Summit Badge", item = "MaxRevive",
	coins = 3200, xp = 3200, intro = "Only the strongest reach Dragon Peaks. I'm the final gym of Summit. Show me everything!",
	rematch = "The dragons are restless. Again!", win = "Sixteen badges... You're a true legend." })

-- route trainers: three per Region 2 lane, like Region 1
do
	local arm = GameData.Arms[2]
	local laneOrder = { Lane9 = 0, Lane10 = 1, Lane11 = 2, Lane12 = 3, Lane13 = 4, Lane14 = 5, Lane15 = 6, Lane16 = 7 }
	local crews = {
		Lane9 = { { "Gardener Ivy", { { "Bramblet", 69 }, { "Sporelet", 69 } } }, { "Beekeeper Hal", { { "Buzzbolt", 70 }, { "Stingle", 70 } } }, { "Florist Rosa", { { "Nimbuff", 71 }, { "Glintle", 71 }, { "Bramblet", 71 } } } },
		Lane10 = { { "Nomad Zeke", { { "Sandsnip", 73 }, { "Dunehorn", 73 } } }, { "Explorer Dara", { { "Cinderock", 74 }, { "Scorchling", 74 } } }, { "Sand Ranger Omar", { { "Dunehorn", 75 }, { "Cragmaul", 75 }, { "Sandsnip", 75 } } } },
		Lane11 = { { "Diver Coral", { { "Ripplefin", 77 }, { "Pinchard", 77 } } }, { "Sailor Finn", { { "Torrentail", 78 }, { "Puddlepup", 78 } } }, { "Reef Guard Mo", { { "Pinchard", 79 }, { "Tidecrest", 79 }, { "Ripplefin", 79 } } } },
		Lane12 = { { "Storm Kid Rex", { { "Zapkit", 81 }, { "Voltmole", 81 } } }, { "Miner Tess", { { "Pebblit", 82 }, { "Cragmaul", 82 } } }, { "Lightning Lou", { { "Buzzbolt", 83 }, { "Stormane", 83 }, { "Zapkit", 83 } } } },
		Lane13 = { { "Swamp Rat Gil", { { "Thornip", 85 }, { "Stingle", 85 } } }, { "Herbalist Nell", { { "Shadeshroom", 86 }, { "Echoling", 86 } } }, { "Bog Witch Vex", { { "Shadeshroom", 87 }, { "Thornwarden", 87 }, { "Echoling", 87 } } } },
		Lane14 = { { "Spelunker Jo", { { "Pebblit", 89 }, { "Glintle", 89 } } }, { "Gem Hunter Ari", { { "Cragmaul", 90 }, { "Rimeling", 90 } } }, { "Crystal Sage Lu", { { "Nimbuff", 91 }, { "Glaciorn", 91 }, { "Glintle", 91 } } } },
		Lane15 = { { "Butler Grimm", { { "Gloomwisp", 93 }, { "Echoling", 93 } } }, { "Maid Elsie", { { "Shadeshroom", 94 }, { "Nightfang", 94 } } }, { "Ghost Hunter Rook", { { "Nightfang", 95 }, { "Phantorb", 95 }, { "Gloomwisp", 95 } } } },
		Lane16 = { { "Climber Kai", { { "Zephlet", 96 }, { "Galewing", 96 } } }, { "Dragon Tamer Mira", { { "Cindrake", 97 }, { "Icicrest", 97 } } }, { "Ace Trainer Bram", { { "Galewing", 98 }, { "Tidecrest", 98 }, { "Cindrake", 98 } } } },
	}
	local lines = {
		{ "Summit trainers don't go easy. Battle!", "Okay, you belong up here." },
		{ "I've been waiting for a real challenge!", "That was a real challenge. For me." },
		{ "Only the strongest reach the gym. Prove it!", "Go on. The gym leader is waiting." },
	}
	local n = 0
	for lane, crew in crews do
		for i, c in crew do
			n += 1
			local z = arm.start + laneOrder[lane] * arm.laneLength + ({ 340, 400, 455 })[i]
			local x = arm.x + (i == 2 and -14 or 14)
			table.insert(GameData.RouteTrainers, {
				id = ("s%s%s"):format(lane:sub(5), string.char(96 + i)), lane = lane, name = c[1], x = x, z = z, team = c[2],
				intro = lines[i][1], after = lines[i][2],
			})
		end
	end
end

-- The Creature League: Maple Victory Road opens at the end of Sky Spire (the last Region 1 lane) once you
-- have all 8 badges. The Elites stand on Map.League.Hall EliteNPad pads, the Champion on ChampionDais.
-- Beat the Elite Four in order, then the Champion. No Healing Center in between: healing
-- (Nurse Ivy or Instant Heal) or losing sends you back to the first Elite. Items are allowed.
-- npc = the model in workspace.Map.League.Members. team = { { species, level } }.
-- The Champion's last creature is the final form of the starter that beats yours (added in LeagueService).
GameData.League = {
	badges = 8,
	name = GameData.VictoryRoads.League,
	members = {
		{
			npc = "Elite1", name = "Elite Mara", specialty = "Poison & Bug",
			team = { { "Echoling", 56 }, { "Buzzbolt", 57 }, { "Shadeshroom", 58 }, { "Thornwarden", 60 } },
			coins = 900, xp = 900, rematchCoins = 250, rematchXP = 250,
			intro = "Welcome to the League. I'm Mara. My creatures sting, and the poison lingers. Shall we?",
			win = "Your team shrugged off my toxins... impressive. Go on, the next Elite awaits.",
		},
		{
			npc = "Elite2", name = "Elite Brutus", specialty = "Rock & Fighting",
			team = { { "Brawlet", 59 }, { "Pinchard", 59 }, { "Dunehorn", 60 }, { "Cragmaul", 61 }, { "Glaciorn", 62 } },
			coins = 1000, xp = 1000, rematchCoins = 280, rematchXP = 280,
			intro = "Brutus is the name, strength is the game. Let's see if your team can take a hit!",
			win = "HA! You hit harder than a rockslide. Respect.",
		},
		{
			npc = "Elite3", name = "Elite Vesper", specialty = "Ghost & Dark",
			team = { { "Gloomwisp", 60 }, { "Nightfang", 61 }, { "Gloomwisp", 61 }, { "Phantorb", 64 } },
			coins = 1100, xp = 1100, rematchCoins = 310, rematchXP = 310,
			intro = "Shhh... the shadows told me you were coming. I am Vesper. Do you fear the dark?",
			win = "You walked through the dark and didn't flinch. Only one Elite stands before the Champion now.",
		},
		{
			npc = "Elite4", name = "Elite Draven", specialty = "Dragon",
			team = { { "Galewing", 62 }, { "Tidecrest", 63 }, { "Cindrake", 64 }, { "Skydrake", 66 } },
			coins = 1300, xp = 1300, rematchCoins = 350, rematchXP = 350,
			intro = "I am Draven, master of dragons and the last of the Elite Four. Nobody passes me easily.",
			win = "Unbelievable... You've beaten the Elite Four. The Champion is waiting on the dais.",
		},
	},
	champion = {
		npc = "Champion", name = "Champion Kai", specialty = "Mixed",
		team = { { "Stormane", 66 }, { "Glaciorn", 66 }, { "Galewing", 67 }, { "Tidecrest", 67 }, { "Skydrake", 68 } },
		starterLevel = 70,
		coins = 5000, xp = 5000, rematchCoins = 1200, rematchXP = 1200,
		firstRewards = { ApexBall = 5, MaxRevive = 3, BugCharm = 1, FightingCharm = 1, DarkCharm = 1, NormalCharm = 1 },
		intro = "Took you long enough! I became Champion while you were catching bugs. Let's settle this for real!",
		win = "No way... You beat me. You're the Champion now. I'll be back stronger, I promise.",
	},
}

-- Region 2 League, at the end of the Region 2 arm. Needs all 16 badges, which also removes the
-- level cap and unlocks stars. team entries: { species, level, stars } (stars 1-3 perfect the
-- creature's best stats; 3 = IV Trained). Everything here is Lv 100, so stars are what make it harder.
GameData.League2 = {
	badges = 16,
	name = "Dragon Spire",
	members = {
		{
			npc = "Elite1", name = "Elite Juno", specialty = "Water & Ice",
			team = { { "Tidecrest", 100 }, { "Glaciorn", 100 }, { "Torrentail", 100 }, { "Icicrest", 100, 1 } },
			coins = 3000, xp = 3000, rematchCoins = 800, rematchXP = 800,
			intro = "So you finished the second region. I'm Juno. The cold here doesn't forgive mistakes.",
			win = "Frozen solid and still you pushed through. Go on.",
		},
		{
			npc = "Elite2", name = "Elite Rocco", specialty = "Ground & Steel",
			team = { { "Dunehorn", 100 }, { "Cragmaul", 100, 1 }, { "Sandsnip", 100 }, { "Glaciorn", 100, 1 } },
			coins = 3300, xp = 3300, rematchCoins = 880, rematchXP = 880,
			intro = "Rocco. My team trained past level 100. Every star on them was earned the hard way.",
			win = "You cracked the mountain. Respect.",
		},
		{
			npc = "Elite3", name = "Elite Noct", specialty = "Ghost & Dark",
			team = { { "Phantorb", 100, 1 }, { "Nightfang", 100, 1 }, { "Gloomwisp", 100, 2 }, { "Shadeshroom", 100, 1 } },
			coins = 3600, xp = 3600, rematchCoins = 960, rematchXP = 960,
			intro = "Noct. Most trainers never see a two star creature. Tonight you'll fight one.",
			win = "The dark bows to you. One Elite left.",
		},
		{
			npc = "Elite4", name = "Elite Seraph", specialty = "Dragon & Flying",
			team = { { "Galewing", 100, 1 }, { "Cindrake", 100, 2 }, { "Stormane", 100, 1 }, { "Skydrake", 100, 2 } },
			coins = 4000, xp = 4000, rematchCoins = 1050, rematchXP = 1050,
			intro = "Seraph, last of the Elite Four. My dragons have stars to spare.",
			win = "Incredible. The Grand Champion is waiting at the top of the Spire.",
		},
	},
	champion = {
		npc = "Champion", name = "Grand Champion Kai", specialty = "Mixed",
		team = { { "Stormane", 100, 2 }, { "Glaciorn", 100, 2 }, { "Galewing", 100, 2 }, { "Tidecrest", 100, 3 }, { "Skydrake", 100, 3 } },
		starterLevel = 100, starterStars = 3,
		coins = 12000, xp = 12000, rematchCoins = 3000, rematchXP = 3000,
		firstRewards = { ApexBall = 10, MaxRevive = 5, SteelCharm = 1, FlyingCharm = 1, PsychicCharm = 1 },
		intro = "You again! I went to the second region too, and I trained every one of these to three stars. Ready?",
		win = "...Okay. You're the real deal. Grand Champion. I'll keep chasing you.",
	},
}

-- Game passes. Create each pass on the Creator Dashboard and paste its ID here (0 = not set up yet).
-- Lean set (2026-11-02): four passes are sold (PassOrder). VIP bundles the cosmetic passes through
-- `grants`; the old single passes stay defined so their perks keep working, but aren't sold on their own.
GameData.GamePasses = {
	DoubleCoins = { id = 0, name = "2x Coins", price = 199, description = "Earn double coins from everything." },
	DoubleXP = { id = 0, name = "2x XP", price = 299, description = "Your creatures earn double XP from every battle, so they level up and evolve twice as fast." },
	ExtraSlots = { id = 0, name = "+6 Team Slots", price = 149, description = "Your base holds 6 more creatures." },
	VIP = { id = 0, name = "VIP", price = 349, grants = { "PremiumDecor", "RainbowTrail", "Gladiator" },
		description = "Royal Throne, Diamond Fountain, Neon Sign, the Night Garden theme, a rainbow trail and the ⚔ Gladiator name tag every player sees." },
	-- not sold on their own any more (VIP grants them; 2x BP is now a timed boost product)
	RainbowTrail = { id = 0, name = "Rainbow Trail", price = 99, retired = true, description = "A rainbow trail follows you everywhere." },
	PremiumDecor = { id = 0, name = "Premium Decor Pack", price = 249, retired = true, description = "Royal Throne, Diamond Fountain, Neon Sign and the Night Garden theme." },
	DoubleBP = { id = 0, name = "2x Battle Points", price = 299, retired = true, description = "Earn double Battle Points from every Coliseum battle." },
	Gladiator = { id = 0, name = "Gladiator Title", price = 149, retired = true, description = "A ⚔ Gladiator mark and a red name tag that every player sees." },
}
GameData.PassOrder = { "DoubleCoins", "DoubleXP", "ExtraSlots", "VIP" }

-- Is a 2x perk active? A game pass, a timed boost the player bought (Boost_<key> = server time it ends),
-- or a server-wide boost (ReplicatedStorage ServerBoost_<key>, from the weekly event or a Server Boost).
function GameData.hasBoost(player: Player, key: string): boolean
	if player:GetAttribute("Pass_" .. key) then
		return true
	end
	local now = workspace:GetServerTimeNow()
	local mine = player:GetAttribute("Boost_" .. key)
	if type(mine) == "number" and mine > now then
		return true
	end
	local server = game:GetService("ReplicatedStorage"):GetAttribute("ServerBoost_" .. key)
	return type(server) == "number" and server > now
end

-- Developer products: bought with Robux every time you use them. Create each one on the
-- Creator Dashboard (Monetization > Developer Products) and paste its ID here (0 = not set up yet).
-- Everything here is fixed and shown up front: nothing random is sold for Robux.
--   boost = { key, minutes }       stacks onto the player's Boost_<key> timer
--   serverBoost = { key, minutes } everyone in the server gets it (and is told who bought it)
--   items = { [itemId] = n }       straight into the Bag
GameData.Products = {
	InstantHeal = { id = 0, name = "Instant Heal", price = 15,
		description = "Fully heal your whole team right now, anywhere. No walk back to Nurse Ivy." },
	SummonRare = { id = 0, name = "Summon Rare Spawn", price = 99,
		description = "Start the rare spawn event now for the whole server: the rarest creature of the best region you've unlocked appears, Huge, for 5 minutes." },
	BoostCoins = { id = 0, name = "2x Coins (30 min)", price = 39, boost = { key = "DoubleCoins", minutes = 30 },
		description = "Double coins from everything for 30 minutes. Buying again adds another 30." },
	BoostXP = { id = 0, name = "2x XP (30 min)", price = 39, boost = { key = "DoubleXP", minutes = 30 },
		description = "Double battle XP for 30 minutes. Buying again adds another 30." },
	BoostBP = { id = 0, name = "2x Battle Points (30 min)", price = 49, boost = { key = "DoubleBP", minutes = 30 },
		description = "Double Battle Points from Coliseum battles for 30 minutes." },
	ServerBoost = { id = 0, name = "Server Boost: 2x Coins", price = 99, serverBoost = { key = "DoubleCoins", minutes = 15 },
		description = "Everyone in this server earns double coins for 15 minutes, and everyone sees that you bought it." },
	NovaPack = { id = 0, name = "10 Nova Balls", price = 49, items = { UltraBall = 10 },
		description = "10 Nova Balls (catch x2.2) straight into your Bag." },
	ApexPack = { id = 0, name = "5 Apex Balls", price = 79, items = { ApexBall = 5 },
		description = "5 Apex Balls (catch x3) straight into your Bag." },
	ReviveKit = { id = 0, name = "Revive Kit", price = 29, items = { MaxRevive = 3 },
		description = "3 Revival Blooms: bring fainted creatures back at full HP." },
}
GameData.ProductOrder = { "InstantHeal", "BoostCoins", "BoostXP", "NovaPack", "ApexPack", "ReviveKit", "SummonRare", "ServerBoost", "BoostBP" }

-- Weekly appointment event (Grow a Garden style): every week at the same time the server goes wild.
-- Saturday 10:00 Pacific time. US daylight saving is handled automatically (WeeklyEventService),
-- so nothing needs changing in March or November. Move hourPacific to the hour before each update if you like.
GameData.WeeklyEvent = {
	name = "Rare Storm",
	weekday = 7,         -- 1 = Sunday ... 7 = Saturday (Pacific calendar)
	hourPacific = 10,    -- 0-23, Pacific local time (PST in winter, PDT in summer)
	minutes = 60,
	rareEverySeconds = 300, -- a rare spawn every 5 minutes during the storm
	boosts = { "DoubleCoins", "DoubleXP" }, -- server-wide while it runs
	warnMinutes = { 60, 15, 5, 1 },
}

-- Music and sound effects (Roblox asset IDs; licensed tracks from the Creator Store).
-- Swap any ID to change a track. Music crossfades between areas; players can mute music.
GameData.Audio = {
	musicVolume = 0.35,
	fade = 1.2,
	music = {
		overworld = 1839864816, -- "Daisy Fresh" (APM) - hub, bases and routes
		tower = 1840777445,     -- "Worlds Of Darkness" (APM) - inside the Dark Tower
		battle = 1841476670,    -- "Drums of Combat" (APM) - wild and trainer battles
		boss = 125421681778301, -- "Epic Boss Fight" - gym leader, tower boss and PvP
	},
	sfx = {
		hit = { id = 126976659766267, volume = 0.5 },   -- an attack lands
		levelUp = { id = 135996502799215, volume = 0.6 }, -- creature or trainer level up
	},
}


-- Story rewards cannot be bought or rolled by any wild/paid spawn pool.
GameData.Items.JuniperJournal = { name = "Juniper's Journal", category = "Story", storyOnly = true,
    color = Color3.fromRGB(170, 120, 230), description = "Recovered from the Havoc lab. Open Journey > Story to read Juniper's notes." }
GameData.Items.HavocLens = { name = "Havoc Lens", category = "Held Items", storyOnly = true,
    held = { superBoost = 1.15 }, color = Color3.fromRGB(180, 90, 230), description = "Recovered from a Norven Havoc base. Super-effective hits deal 15% more damage." }
GameData.Items.CrystalAnchor = { name = "Crystal Anchor", category = "Held Items", storyOnly = true,
    held = { guard = 0.9 }, color = Color3.fromRGB(90, 190, 230), description = "Recovered from a Norven Havoc base. Takes 10% less damage." }
GameData.Items.TimeClover = { name = "Time Clover", category = "Held Items", storyOnly = true,
    held = { xpMult = 1.15 }, color = Color3.fromRGB(110, 220, 170), description = "Recovered from a Norven Havoc base. Earns 15% more battle XP." }
GameData.Creatures.Chronowisp = { type = "Ghost", type2 = "Steel", rarity = "Legendary", shape = "ghost", size = 4.2,
    color = Color3.fromRGB(180, 155, 230), accent = Color3.fromRGB(80, 240, 220), floats = true, storyOnly = true }
table.insert(GameData.IndexOrder, "Chronowisp")

return GameData
