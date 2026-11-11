--[[
	DecorData: everything about base decorations, shared by server and client.
	  Items       - every decoration: price, where it's sold, rarity, footprint, what it does, how it looks
	  Boxes       - coin-only crates with their pools and odds (odds are shown to players)
	  Themes      - one-click base looks (floor, path, fence, lamp colours)
	  BaseLevels  - base upgrades: decor cap, coin bonus, how much the coin jar holds
	  CoinProducts- Robux coin bundles (developer products; set the ids from the Creator Dashboard)
	Sold: "shop" (always for sale), "daily" (only in the rotating daily shop), "box" (crates or shards only),
	      "premium" (Premium Decor game pass).
	Footprints are in studs on a 1-stud grid. Models are built from parts by DecorData.build(id).
]]

local DecorData = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

DecorData.Rarities = {
	Common = { color = rgb(200, 200, 210), order = 1, shards = 1, shardCost = 10 },
	Rare = { color = rgb(80, 160, 255), order = 2, shards = 3, shardCost = 30 },
	Epic = { color = rgb(185, 95, 255), order = 3, shards = 8, shardCost = 80 },
	Legendary = { color = rgb(255, 190, 40), order = 4, shards = 20, shardCost = 200 },
}

-- Habitat types: a habitat pays +habitatCoins per minute for each creature on your team of a matching type
DecorData.HabitatCoins = 1
DecorData.HabitatCountCap = 6 -- creatures counted per habitat
DecorData.MaxHealPads = 3
DecorData.TickSeconds = 60
DecorData.OfflineHours = 8 -- the coin jar keeps filling while you're away (at half rate), up to this long
DecorData.OfflineRate = 0.5
DecorData.LikeCoins = 10 -- the owner gets this when someone likes their base
DecorData.DailyShopSize = 5

-- XP Canopy: shares battle XP with the creatures that didn't fight. Starts at 0%; upgrade it with coins
-- at the canopy in your base (each level costs more, like a Steal an Egg upgrade pad).
DecorData.CanopyTiers = {
	{ share = 0, cost = 0 },
	{ share = 0.10, cost = 300 },
	{ share = 0.20, cost = 1000 },
	{ share = 0.30, cost = 2500 },
	{ share = 0.40, cost = 5000 },
	{ share = 0.50, cost = 9000 },
}

DecorData.BaseLevels = {
	{ name = "Small", cap = 18, cost = 0, bonus = 0, jarMinutes = 60 },
	{ name = "Medium", cap = 30, cost = 750, bonus = 0.10, jarMinutes = 90 },
	{ name = "Large", cap = 45, cost = 2000, bonus = 0.20, jarMinutes = 120, wing = "left" },
	{ name = "Grand", cap = 63, cost = 5000, bonus = 0.35, jarMinutes = 180, wing = "right" },
	{ name = "Legendary", cap = 90, cost = 12000, bonus = 0.50, jarMinutes = 240 },
}

DecorData.Themes = {
	Meadow = { name = "Meadow", price = 0, order = 1, floor = rgb(125, 195, 95), floorMat = "Grass", path = rgb(215, 198, 160), pathMat = "Pavement", fence = rgb(150, 105, 65), cap = rgb(231, 76, 60), lamp = rgb(255, 235, 170) },
	Coastal = { name = "Coastal", price = 2500, order = 2, floor = rgb(235, 215, 160), floorMat = "Sand", path = rgb(240, 240, 235), pathMat = "WoodPlanks", fence = rgb(245, 245, 240), cap = rgb(60, 150, 230), lamp = rgb(170, 225, 255) },
	Snowfield = { name = "Snowfield", price = 2500, order = 3, floor = rgb(235, 242, 250), floorMat = "Snow", path = rgb(165, 190, 215), pathMat = "Ice", fence = rgb(110, 85, 70), cap = rgb(200, 40, 50), lamp = rgb(200, 235, 255) },
	Volcano = { name = "Volcano", price = 2500, order = 4, floor = rgb(70, 55, 55), floorMat = "Basalt", path = rgb(255, 120, 40), pathMat = "CrackedLava", fence = rgb(45, 40, 40), cap = rgb(255, 90, 30), lamp = rgb(255, 140, 60) },
	CrystalCave = { name = "Crystal Cave", price = 4000, order = 5, floor = rgb(80, 75, 110), floorMat = "Slate", path = rgb(150, 220, 255), pathMat = "Glass", fence = rgb(60, 55, 85), cap = rgb(190, 110, 255), lamp = rgb(170, 120, 255) },
	NightGarden = { name = "Night Garden", price = -1, premium = true, order = 6, floor = rgb(40, 80, 70), floorMat = "Grass", path = rgb(60, 60, 95), pathMat = "Cobblestone", fence = rgb(35, 35, 50), cap = rgb(110, 255, 220), lamp = rgb(120, 255, 210) },
}
DecorData.ThemeOrder = { "Meadow", "Coastal", "Snowfield", "Volcano", "CrystalCave", "NightGarden" }

-- Robux coin bundles. Create developer products on the Creator Dashboard and put their ids here.
-- robux is only the suggested price shown when the id isn't set; the real price comes from Roblox.
DecorData.CoinProducts = {
	{ key = "Coins1", id = 0, coins = 1000, robux = 49, label = "Pouch of Coins" },
	{ key = "Coins2", id = 0, coins = 5500, robux = 199, label = "Bag of Coins", tag = "+10% bonus" },
	{ key = "Coins3", id = 0, coins = 12000, robux = 399, label = "Chest of Coins", tag = "+20% bonus" },
	{ key = "Coins4", id = 0, coins = 32500, robux = 899, label = "Vault of Coins", tag = "Best value" },
}

-- Robux bundles (developer products). Nothing random is ever sold for Robux.
-- give: coins, items (GameData item ids), decor (DecorData item ids), shards. once = one per player (button hides after).
DecorData.Bundles = {
	{ key = "StarterPack", id = 0, robux = 99, label = "Starter Pack", tag = "One time only", once = true,
		desc = "2,500 coins, 10 Spark Balls, 5 Mini Tonics and a Leafy Garden",
		give = { coins = 2500, items = { SwiftBall = 10, Potion = 5 }, decor = { GrassGarden = 1 } } },
	{ key = "ShardPouch", id = 0, robux = 149, label = "Shard Pouch",
		desc = "100 shards: trade them for any crate item you choose", give = { shards = 100 } },
	{ key = "FountainDeal", id = 0, robux = 129, label = "Coin Fountain Deal",
		desc = "2 Coin Fountains (+3 coins/min each, forever)", give = { decor = { CoinFountain = 2 } } },
}

-- Items given by the Premium Decor game pass (GameData.GamePasses.PremiumDecor)
DecorData.PremiumItems = { "RoyalThrone", "DiamondFountain", "NeonSign" }

----------------------------------------------------------------------------------------------
-- Items
-- build(add) adds parts; y = 0 is the ground. add{ s = size, p = position, c = colour, m = material,
--   sh = "Ball"|"Cylinder"|"Wedge", r = {x,y,z} degrees, t = transparency, fx = "fire"|"light"|"sparkle"|"smoke", nc = no collide }
-- vc(h, d, pos, ...) adds an upright cylinder.
----------------------------------------------------------------------------------------------
local WOOD, DARKWOOD, STONE, LEAF, GOLD = rgb(160, 115, 70), rgb(105, 70, 45), rgb(150, 150, 155), rgb(70, 160, 70), rgb(245, 195, 50)

DecorData.Items = {
	-- shop: plain decorations ------------------------------------------------------------
	StonePath = { name = "Stepping Stones", price = 30, sold = "shop", rarity = "Common", size = { 4, 4 }, flat = true, build = function(add)
		for _, o in { { -1, -1 }, { 1, 0.8 }, { -0.8, 1.2 }, { 1.1, -1.1 } } do
			add({ s = { 0.3, 1.6, 1.6 }, p = { o[1], 0.12, o[2] }, c = STONE, m = "Slate", sh = "Cylinder", r = { 0, 0, 90 }, nc = true })
		end
	end },
	FenceSection = { name = "Picket Fence", price = 25, sold = "shop", rarity = "Common", size = { 6, 1 }, build = function(add)
		for i = -2.5, 2.5, 1 do
			add({ s = { 0.5, 2.6, 0.3 }, p = { i, 1.3, 0 }, c = rgb(245, 245, 240) })
		end
		add({ s = { 6, 0.3, 0.2 }, p = { 0, 0.8, 0 }, c = rgb(235, 235, 230) })
		add({ s = { 6, 0.3, 0.2 }, p = { 0, 1.9, 0 }, c = rgb(235, 235, 230) })
	end },
	FlowerPot = { name = "Flower Pot", price = 40, sold = "shop", rarity = "Common", size = { 2, 2 }, build = function(add, vc)
		vc(1.4, 1.6, { 0, 0.7, 0 }, rgb(200, 110, 70), "Slate")
		vc(0.2, 1.4, { 0, 1.42, 0 }, rgb(90, 60, 40), "Ground")
		for i, col in { rgb(255, 90, 120), rgb(255, 210, 60), rgb(160, 110, 255) } do
			local a = i * 2.1
			add({ s = { 0.1, 1, 0.1 }, p = { math.cos(a) * 0.35, 1.9, math.sin(a) * 0.35 }, c = LEAF, nc = true })
			add({ s = { 0.6, 0.6, 0.6 }, p = { math.cos(a) * 0.35, 2.45, math.sin(a) * 0.35 }, c = col, sh = "Ball", nc = true })
		end
	end },
	Hedge = { name = "Hedge", price = 60, sold = "shop", rarity = "Common", size = { 6, 2 }, build = function(add)
		add({ s = { 6, 2.4, 2 }, p = { 0, 1.2, 0 }, c = rgb(60, 140, 60), m = "Grass" })
		for i = -2, 2, 2 do
			add({ s = { 2.2, 2.2, 2.2 }, p = { i, 2.3, 0 }, c = rgb(70, 155, 70), m = "Grass", sh = "Ball" })
		end
	end },
	Bench = { name = "Park Bench", price = 80, sold = "shop", rarity = "Common", size = { 6, 2 }, build = function(add)
		add({ s = { 5.6, 0.3, 1.6 }, p = { 0, 1.3, 0 }, c = WOOD, m = "WoodPlanks" })
		add({ s = { 5.6, 1.2, 0.3 }, p = { 0, 2.1, -0.7 }, c = WOOD, m = "WoodPlanks" })
		for _, x in { -2.4, 2.4 } do
			add({ s = { 0.3, 1.2, 1.6 }, p = { x, 0.6, 0 }, c = rgb(50, 50, 55), m = "Metal" })
		end
	end },
	LampPost = { name = "Lamp Post", price = 120, sold = "shop", rarity = "Common", size = { 2, 2 }, build = function(add, vc)
		vc(0.4, 1.4, { 0, 0.2, 0 }, rgb(45, 45, 50), "Metal")
		vc(6, 0.35, { 0, 3.2, 0 }, rgb(45, 45, 50), "Metal")
		add({ s = { 1.1, 1.3, 1.1 }, p = { 0, 6.8, 0 }, c = rgb(255, 235, 170), m = "Neon", fx = "light" })
		add({ s = { 1.4, 0.3, 1.4 }, p = { 0, 7.55, 0 }, c = rgb(45, 45, 50), m = "Metal" })
	end },
	PicnicTable = { name = "Picnic Table", price = 150, sold = "retired", rarity = "Common", size = { 6, 5 }, build = function(add)
		add({ s = { 5.6, 0.3, 2.4 }, p = { 0, 2.4, 0 }, c = rgb(230, 80, 70) })
		add({ s = { 5.6, 0.31, 0.4 }, p = { 0, 2.42, 0.4 }, c = rgb(245, 245, 245) })
		for _, z in { -1.9, 1.9 } do
			add({ s = { 5.6, 0.3, 0.9 }, p = { 0, 1.3, z }, c = WOOD, m = "WoodPlanks" })
		end
		for _, x in { -2.3, 2.3 } do
			add({ s = { 0.4, 2.3, 0.4 }, p = { x, 1.15, 0 }, c = DARKWOOD, m = "Wood" })
			add({ s = { 0.3, 0.3, 4.6 }, p = { x, 1, 0 }, c = DARKWOOD, m = "Wood" })
		end
	end },
	Campfire = { name = "Campfire", price = 180, sold = "retired", rarity = "Common", size = { 4, 4 }, build = function(add)
		for i = 1, 6 do
			local a = i * math.pi / 3
			add({ s = { 0.7, 0.6, 0.7 }, p = { math.cos(a) * 1.4, 0.3, math.sin(a) * 1.4 }, c = STONE, m = "Slate", sh = "Ball" })
		end
		add({ s = { 2.4, 0.4, 0.4 }, p = { 0, 0.3, 0 }, c = DARKWOOD, m = "Wood", r = { 0, 45, 0 } })
		add({ s = { 2.4, 0.4, 0.4 }, p = { 0, 0.5, 0 }, c = DARKWOOD, m = "Wood", r = { 0, -45, 0 }, fx = "fire" })
	end },
	OakTree = { name = "Oak Tree", price = 200, sold = "shop", rarity = "Common", size = { 6, 6 }, build = function(add, vc)
		vc(7, 1.4, { 0, 3.5, 0 }, rgb(110, 75, 45), "Wood")
		add({ s = { 6, 5, 6 }, p = { 0, 8.2, 0 }, c = LEAF, m = "Grass", sh = "Ball", nc = true })
		add({ s = { 4, 3.5, 4 }, p = { 1.4, 10, 0.8 }, c = rgb(85, 175, 80), m = "Grass", sh = "Ball", nc = true })
	end },
	GrassGarden = { name = "Leafy Garden", price = 600, sold = "shop", rarity = "Rare", size = { 6, 6 }, habitat = { "Grass" }, build = function(add)
		add({ s = { 6, 0.4, 6 }, p = { 0, 0.2, 0 }, c = rgb(95, 65, 40), m = "Ground" })
		for _, o in { { -1.7, -1.7 }, { 1.7, -1.7 }, { -1.7, 1.7 }, { 1.7, 1.7 }, { 0, 0 } } do
			add({ s = { 1.8, 1.8, 1.8 }, p = { o[1], 1.1, o[2] }, c = rgb(80, 175, 70), m = "Grass", sh = "Ball" })
		end
	end },
	FirePit = { name = "Ember Pit", price = 600, sold = "shop", rarity = "Rare", size = { 6, 6 }, habitat = { "Fire" }, build = function(add, vc)
		vc(0.8, 5.6, { 0, 0.4, 0 }, rgb(70, 60, 60), "Basalt")
		vc(0.82, 4, { 0, 0.42, 0 }, rgb(255, 110, 30), "CrackedLava")
		add({ s = { 1, 1, 1 }, p = { 0, 1.2, 0 }, c = rgb(255, 140, 40), m = "Neon", sh = "Ball", fx = "fire", nc = true })
	end },
	WaterPool = { name = "Tide Pool", price = 600, sold = "shop", rarity = "Rare", size = { 6, 6 }, habitat = { "Water" }, flat = true, build = function(add)
		add({ s = { 6, 0.4, 6 }, p = { 0, 0.2, 0 }, c = rgb(225, 210, 160), m = "Sand", nc = true })
		add({ s = { 4.6, 0.42, 4.6 }, p = { 0, 0.22, 0 }, c = rgb(60, 150, 230), m = "Glass", t = 0.15, nc = true })
	end },
	ElectricCoil = { name = "Spark Coil", price = 600, sold = "shop", rarity = "Rare", size = { 4, 4 }, habitat = { "Electric" }, build = function(add, vc)
		vc(0.5, 3.6, { 0, 0.25, 0 }, rgb(60, 60, 70), "Metal")
		vc(5, 0.8, { 0, 3, 0 }, rgb(200, 150, 60), "Metal")
		add({ s = { 1.6, 1.6, 1.6 }, p = { 0, 6, 0 }, c = rgb(255, 230, 60), m = "Neon", sh = "Ball", fx = "sparkle" })
	end },
	RockGarden = { name = "Boulder Den", price = 600, sold = "shop", rarity = "Rare", size = { 6, 6 }, habitat = { "Rock", "Ground" }, build = function(add)
		add({ s = { 3.2, 2.6, 3 }, p = { -1, 1.3, 0.6 }, c = rgb(130, 120, 110), m = "Rock", sh = "Ball" })
		add({ s = { 2.4, 2, 2.4 }, p = { 1.5, 1, -0.8 }, c = rgb(150, 135, 115), m = "Rock", sh = "Ball" })
		add({ s = { 1.6, 1.4, 1.6 }, p = { 1.4, 0.7, 1.8 }, c = rgb(115, 105, 95), m = "Rock", sh = "Ball" })
	end },
	IceBlock = { name = "Frost Grotto", price = 600, sold = "shop", rarity = "Rare", size = { 6, 6 }, habitat = { "Ice" }, build = function(add)
		add({ s = { 6, 0.3, 6 }, p = { 0, 0.15, 0 }, c = rgb(230, 240, 250), m = "Snow" })
		add({ s = { 1.6, 4, 1.6 }, p = { -1.2, 2, -1 }, c = rgb(170, 220, 255), m = "Ice", t = 0.2, r = { 0, 30, 8 } })
		add({ s = { 1.3, 3, 1.3 }, p = { 1.4, 1.5, 0.6 }, c = rgb(190, 230, 255), m = "Ice", t = 0.2, r = { 0, 15, -10 } })
	end },
	BirdPerch = { name = "Sky Perch", price = 600, sold = "shop", rarity = "Rare", size = { 4, 4 }, habitat = { "Flying" }, build = function(add, vc)
		vc(7, 0.6, { 0, 3.5, 0 }, WOOD, "Wood")
		add({ s = { 4, 0.4, 0.4 }, p = { 0, 5.5, 0 }, c = WOOD, m = "Wood" })
		add({ s = { 0.4, 0.4, 3 }, p = { 0, 4, 0 }, c = WOOD, m = "Wood" })
		add({ s = { 1.6, 1.2, 1.6 }, p = { 0, 7.5, 0 }, c = rgb(220, 90, 70), m = "WoodPlanks" })
	end },
	BugLog = { name = "Mossy Log", price = 600, sold = "shop", rarity = "Rare", size = { 6, 3 }, habitat = { "Bug", "Poison" }, build = function(add)
		add({ s = { 5.6, 2.2, 2.2 }, p = { 0, 1.1, 0 }, c = rgb(115, 80, 50), m = "Wood", sh = "Cylinder" })
		add({ s = { 4, 0.4, 1.6 }, p = { 0.3, 2.2, 0 }, c = rgb(90, 160, 70), m = "Grass" })
		add({ s = { 0.6, 0.6, 0.6 }, p = { -2, 2.4, 0.4 }, c = rgb(230, 70, 60), sh = "Ball", nc = true })
	end },

	-- shop: functional ------------------------------------------------------------------------
	CoinFountain = { name = "Coin Fountain", price = 900, sold = "shop", rarity = "Rare", size = { 6, 6 }, gen = 3, build = function(add, vc)
		vc(1, 5.6, { 0, 0.5, 0 }, STONE, "Marble")
		vc(1.02, 4.8, { 0, 0.52, 0 }, rgb(80, 170, 230), "Glass")
		vc(3, 0.8, { 0, 2, 0 }, STONE, "Marble")
		add({ s = { 1.6, 1.6, 1.6 }, p = { 0, 3.8, 0 }, c = GOLD, m = "Metal", sh = "Ball", fx = "sparkle" })
	end },
	HealPad = { name = "Healing Pad", price = 1200, sold = "shop", rarity = "Rare", size = { 4, 4 }, flat = true, heal = 0.15, build = function(add)
		add({ s = { 4, 0.3, 4 }, p = { 0, 0.15, 0 }, c = rgb(240, 240, 245), m = "Marble", nc = true })
		add({ s = { 2.8, 0.32, 0.7 }, p = { 0, 0.18, 0 }, c = rgb(255, 90, 110), m = "Neon", nc = true })
		add({ s = { 0.7, 0.32, 2.8 }, p = { 0, 0.18, 0 }, c = rgb(255, 90, 110), m = "Neon", nc = true, fx = "light" })
	end },
	TrainingDummy = { name = "Training Dummy", price = 1500, sold = "shop", rarity = "Rare", size = { 3, 3 }, train = true, build = function(add, vc)
		vc(0.4, 2.6, { 0, 0.2, 0 }, DARKWOOD, "Wood")
		vc(4, 0.5, { 0, 2.2, 0 }, DARKWOOD, "Wood")
		vc(2.6, 1.8, { 0, 3.4, 0 }, rgb(220, 195, 140), "Fabric")
		add({ s = { 1.3, 1.3, 1.3 }, p = { 0, 5.3, 0 }, c = rgb(220, 195, 140), m = "Fabric", sh = "Ball" })
		add({ s = { 3.4, 0.4, 0.4 }, p = { 0, 4.2, 0 }, c = DARKWOOD, m = "Wood" })
		vc(0.05, 1.2, { 0, 3.9, 0.92 }, rgb(220, 60, 60), "SmoothPlastic")
	end },
	DisplayPedestal = { name = "Display Pedestal", price = 700, sold = "shop", rarity = "Rare", size = { 4, 4 }, pedestal = true, build = function(add, vc)
		vc(0.5, 3.8, { 0, 0.25, 0 }, STONE, "Marble")
		vc(1.6, 2.8, { 0, 1.3, 0 }, rgb(235, 235, 240), "Marble")
		vc(0.3, 3.4, { 0, 2.25, 0 }, GOLD, "Metal")
	end },
	TrophyWall = { name = "Trophy Wall", price = 1000, sold = "shop", rarity = "Rare", size = { 6, 2 }, trophy = true, build = function(add)
		add({ s = { 6, 5, 0.6 }, p = { 0, 2.5, 0 }, c = DARKWOOD, m = "WoodPlanks" })
		add({ s = { 5.4, 4.4, 0.1 }, p = { 0, 2.6, 0.32 }, c = rgb(40, 30, 25), name = "Screen" })
		add({ s = { 6.4, 0.4, 1 }, p = { 0, 5.1, 0 }, c = GOLD, m = "Metal" })
	end },

	-- daily shop only ----------------------------------------------------------------------
	BerryBush = { name = "Berry Bush", price = 350, sold = "daily", rarity = "Common", size = { 3, 3 }, build = function(add)
		add({ s = { 3, 2.6, 3 }, p = { 0, 1.3, 0 }, c = rgb(60, 140, 65), m = "Grass", sh = "Ball" })
		for i = 1, 6 do
			local a = i * 1.05
			add({ s = { 0.4, 0.4, 0.4 }, p = { math.cos(a) * 1.3, 1.6 + (i % 2) * 0.5, math.sin(a) * 1.3 }, c = rgb(90, 80, 220), sh = "Ball", nc = true })
		end
	end },
	Bonsai = { name = "Bonsai", price = 450, sold = "daily", rarity = "Common", size = { 2, 2 }, build = function(add, vc)
		add({ s = { 2, 0.6, 1.4 }, p = { 0, 0.3, 0 }, c = rgb(60, 70, 120), m = "Slate" })
		vc(1.4, 0.3, { 0, 1.3, 0 }, DARKWOOD, "Wood")
		add({ s = { 1.6, 0.8, 1.2 }, p = { 0.2, 2.1, 0 }, c = rgb(70, 140, 70), m = "Grass", sh = "Ball" })
	end },
	Hammock = { name = "Hammock", price = 500, sold = "daily", rarity = "Common", size = { 8, 3 }, build = function(add, vc)
		for _, x in { -3.6, 3.6 } do
			vc(5, 0.5, { x, 2.5, 0 }, WOOD, "Wood")
		end
		add({ s = { 6, 0.2, 2 }, p = { 0, 2.2, 0 }, c = rgb(240, 120, 90), m = "Fabric" })
	end },
	Telescope = { name = "Telescope", price = 650, sold = "daily", rarity = "Rare", size = { 3, 3 }, build = function(add)
		for i = 1, 3 do
			local a = i * 2.1
			add({ s = { 0.2, 3, 0.2 }, p = { math.cos(a) * 0.6, 1.4, math.sin(a) * 0.6 }, c = DARKWOOD, r = { math.sin(a) * 15, 0, -math.cos(a) * 15 } })
		end
		add({ s = { 3, 0.6, 0.6 }, p = { 0, 3.2, 0 }, c = rgb(60, 70, 130), m = "Metal", sh = "Cylinder", r = { 0, 0, 25 } })
	end },
	StoneArch = { name = "Stone Arch", price = 800, sold = "daily", rarity = "Rare", size = { 8, 2 }, build = function(add)
		for _, x in { -3, 3 } do
			add({ s = { 1.6, 7, 1.6 }, p = { x, 3.5, 0 }, c = STONE, m = "Cobblestone" })
		end
		add({ s = { 8, 1.4, 1.8 }, p = { 0, 7.6, 0 }, c = STONE, m = "Cobblestone" })
		add({ s = { 4, 0.6, 1.9 }, p = { 0, 8.5, 0 }, c = rgb(130, 130, 135), m = "Cobblestone" })
	end },
	Windmill = { name = "Windmill", price = 1100, sold = "daily", rarity = "Rare", size = { 5, 5 }, build = function(add, vc)
		vc(9, 4, { 0, 4.5, 0 }, rgb(235, 225, 205), "Plaster")
		add({ s = { 4.6, 2.4, 4.6 }, p = { 0, 10, 0 }, c = rgb(170, 60, 50), m = "WoodPlanks", sh = "Ball" })
		add({ s = { 0.3, 9, 1 }, p = { 0, 8, 2.3 }, c = WOOD, m = "WoodPlanks", r = { 0, 0, 45 }, nc = true })
		add({ s = { 0.3, 9, 1 }, p = { 0, 8, 2.3 }, c = WOOD, m = "WoodPlanks", r = { 0, 0, -45 }, nc = true })
	end },
	Gazebo = { name = "Gazebo", price = 1400, sold = "daily", rarity = "Epic", size = { 8, 8 }, build = function(add, vc)
		vc(0.5, 8, { 0, 0.25, 0 }, rgb(240, 240, 235), "WoodPlanks")
		for i = 1, 6 do
			local a = i * math.pi / 3
			vc(6, 0.5, { math.cos(a) * 3.5, 3.4, math.sin(a) * 3.5 }, rgb(245, 245, 240), "Wood")
		end
		add({ s = { 8.4, 1.6, 8.4 }, p = { 0, 7, 0 }, c = rgb(90, 140, 110), m = "WoodPlanks", sh = "Ball", nc = true })
	end },
	HotSpring = { name = "Hot Spring", price = 950, sold = "daily", rarity = "Rare", size = { 6, 6 }, flat = true, build = function(add)
		add({ s = { 0.4, 5.8, 5.8 }, p = { 0, 0.2, 0 }, c = rgb(110, 105, 100), m = "Rock", sh = "Cylinder", r = { 0, 0, 90 }, nc = true })
		add({ s = { 0.42, 4.6, 4.6 }, p = { 0, 0.22, 0 }, c = rgb(120, 210, 220), m = "Glass", sh = "Cylinder", r = { 0, 0, 90 }, t = 0.15, fx = "smoke", nc = true })
	end },

	-- crate exclusives ---------------------------------------------------------------------
	MushroomRing = { name = "Mushroom Ring", sold = "box", rarity = "Common", size = { 5, 5 }, build = function(add, vc)
		for i = 1, 6 do
			local a = i * math.pi / 3
			local x, z = math.cos(a) * 1.8, math.sin(a) * 1.8
			vc(0.8, 0.35, { x, 0.4, z }, rgb(240, 235, 220), "SmoothPlastic")
			add({ s = { 1, 0.6, 1 }, p = { x, 0.9, z }, c = rgb(220, 60, 60), sh = "Ball", nc = true })
		end
	end },
	ToadstoolLamp = { name = "Toadstool Lamp", sold = "box", rarity = "Common", size = { 2, 2 }, build = function(add, vc)
		vc(2.2, 0.7, { 0, 1.1, 0 }, rgb(245, 240, 225), "SmoothPlastic")
		add({ s = { 2, 1.1, 2 }, p = { 0, 2.5, 0 }, c = rgb(255, 120, 200), m = "Neon", sh = "Ball", fx = "light" })
	end },
	CrateStack = { name = "Crate Stack", sold = "box", rarity = "Common", size = { 4, 4 }, build = function(add)
		add({ s = { 2, 2, 2 }, p = { -0.9, 1, -0.9 }, c = WOOD, m = "WoodPlanks" })
		add({ s = { 2, 2, 2 }, p = { 1, 1, 0.8 }, c = WOOD, m = "WoodPlanks", r = { 0, 15, 0 } })
		add({ s = { 1.6, 1.6, 1.6 }, p = { -0.6, 2.8, -0.6 }, c = rgb(180, 135, 85), m = "WoodPlanks", r = { 0, 30, 0 } })
	end },
	BeachUmbrella = { name = "Beach Umbrella", sold = "box", rarity = "Common", size = { 4, 4 }, build = function(add, vc)
		vc(5.5, 0.25, { 0, 2.75, 0 }, rgb(240, 240, 240), "Metal")
		add({ s = { 5, 1.2, 5 }, p = { 0, 5.5, 0 }, c = rgb(255, 120, 60), m = "Fabric", sh = "Ball", nc = true })
	end },
	Snowman = { name = "Snowman", sold = "box", rarity = "Rare", size = { 3, 3 }, build = function(add)
		add({ s = { 2.8, 2.8, 2.8 }, p = { 0, 1.3, 0 }, c = rgb(250, 250, 255), m = "Snow", sh = "Ball" })
		add({ s = { 2, 2, 2 }, p = { 0, 3.3, 0 }, c = rgb(250, 250, 255), m = "Snow", sh = "Ball" })
		add({ s = { 1.4, 1.4, 1.4 }, p = { 0, 4.8, 0 }, c = rgb(250, 250, 255), m = "Snow", sh = "Ball" })
		add({ s = { 0.25, 0.25, 0.8 }, p = { 0, 4.8, 0.9 }, c = rgb(255, 140, 40), nc = true })
		add({ s = { 1.6, 0.3, 1.6 }, p = { 0, 5.5, 0 }, c = rgb(30, 30, 35), nc = true })
	end },
	LavaLamp = { name = "Lava Lamp", sold = "box", rarity = "Rare", size = { 2, 2 }, build = function(add, vc)
		vc(0.6, 1.4, { 0, 0.3, 0 }, rgb(200, 200, 210), "Metal")
		vc(3, 1.2, { 0, 2.1, 0 }, rgb(255, 80, 120), "Glass")
		add({ s = { 0.7, 0.7, 0.7 }, p = { 0, 2.6, 0 }, c = rgb(255, 200, 60), m = "Neon", sh = "Ball", fx = "light", nc = true })
	end },
	CrystalCluster = { name = "Crystal Cluster", sold = "box", rarity = "Rare", size = { 3, 3 }, build = function(add)
		add({ s = { 0.9, 3.6, 0.9 }, p = { 0, 1.8, 0 }, c = rgb(170, 120, 255), m = "Glass", r = { 0, 45, 6 }, fx = "light" })
		add({ s = { 0.7, 2.4, 0.7 }, p = { 0.8, 1.1, 0.3 }, c = rgb(140, 200, 255), m = "Glass", r = { 0, 20, -20 } })
		add({ s = { 0.6, 2, 0.6 }, p = { -0.7, 0.9, -0.4 }, c = rgb(255, 150, 230), m = "Glass", r = { 15, 0, 20 } })
	end },
	GoldenStatue = { name = "Golden Statue", sold = "box", rarity = "Epic", size = { 4, 4 }, gen = 6, build = function(add)
		add({ s = { 3, 1.2, 3 }, p = { 0, 0.6, 0 }, c = rgb(235, 235, 240), m = "Marble" })
		add({ s = { 1.6, 2.6, 1.6 }, p = { 0, 2.5, 0 }, c = GOLD, m = "Metal", sh = "Ball" })
		add({ s = { 1.3, 1.3, 1.3 }, p = { 0, 4.3, 0 }, c = GOLD, m = "Metal", sh = "Ball", fx = "sparkle" })
	end },
	RainbowArch = { name = "Rainbow Arch", sold = "box", rarity = "Epic", size = { 10, 2 }, build = function(add)
		local cols = { rgb(255, 70, 70), rgb(255, 170, 50), rgb(255, 240, 70), rgb(80, 220, 100), rgb(70, 150, 255), rgb(170, 90, 255) }
		for i = 0, 10 do
			local a = math.pi * i / 10
			for j, col in cols do
				local rad = 4.6 - (j - 1) * 0.35
				add({ s = { 0.4, 1.4, 0.4 }, p = { math.cos(a) * rad, math.sin(a) * rad + 0.2, 0 }, c = col, m = "Neon", r = { 0, 0, math.deg(a) }, nc = true })
			end
		end
	end },
	DragonStatue = { name = "Dragon Statue", sold = "box", rarity = "Epic", size = { 5, 5 }, build = function(add)
		add({ s = { 4, 1, 4 }, p = { 0, 0.5, 0 }, c = rgb(90, 85, 95), m = "Slate" })
		add({ s = { 2.4, 3, 2 }, p = { 0, 2.5, 0 }, c = rgb(60, 140, 120), m = "Marble", sh = "Ball" })
		add({ s = { 1, 2.4, 1 }, p = { 0, 4.6, 0.6 }, c = rgb(60, 140, 120), m = "Marble", r = { 25, 0, 0 } })
		add({ s = { 1.4, 1.2, 1.8 }, p = { 0, 5.8, 1.2 }, c = rgb(60, 140, 120), m = "Marble" })
		add({ s = { 3.6, 2, 0.2 }, p = { -1.6, 3.4, -0.4 }, c = rgb(50, 120, 105), m = "Marble", r = { 0, 30, 30 }, nc = true })
		add({ s = { 3.6, 2, 0.2 }, p = { 1.6, 3.4, -0.4 }, c = rgb(50, 120, 105), m = "Marble", r = { 0, -30, -30 }, nc = true })
	end },
	StarryFountain = { name = "Starry Fountain", sold = "box", rarity = "Legendary", size = { 6, 6 }, gen = 10, build = function(add, vc)
		vc(1, 5.6, { 0, 0.5, 0 }, rgb(40, 40, 70), "Marble")
		vc(1.02, 4.8, { 0, 0.52, 0 }, rgb(90, 80, 220), "Neon")
		vc(3, 0.8, { 0, 2, 0 }, rgb(40, 40, 70), "Marble")
		add({ s = { 1.8, 1.8, 1.8 }, p = { 0, 4, 0 }, c = rgb(255, 245, 160), m = "Neon", sh = "Ball", fx = "sparkle" })
	end },
	AuroraTree = { name = "Aurora Tree", sold = "box", rarity = "Legendary", size = { 6, 6 }, gen = 8, build = function(add, vc)
		vc(7, 1.2, { 0, 3.5, 0 }, rgb(235, 235, 245), "Marble")
		add({ s = { 6, 4.5, 6 }, p = { 0, 8, 0 }, c = rgb(110, 255, 220), m = "Neon", sh = "Ball", t = 0.25, fx = "light", nc = true })
		add({ s = { 3.5, 3, 3.5 }, p = { 1, 10, 0.6 }, c = rgb(200, 140, 255), m = "Neon", sh = "Ball", t = 0.25, nc = true })
	end },

	-- premium pass ---------------------------------------------------------------------------
	RoyalThrone = { name = "Royal Throne", sold = "premium", rarity = "Legendary", size = { 4, 4 }, build = function(add)
		add({ s = { 3.4, 1.6, 3 }, p = { 0, 0.8, 0 }, c = GOLD, m = "Metal" })
		add({ s = { 3, 0.5, 2.6 }, p = { 0, 1.85, 0.1 }, c = rgb(180, 30, 50), m = "Fabric" })
		add({ s = { 3.4, 4.5, 0.6 }, p = { 0, 3.6, -1.2 }, c = GOLD, m = "Metal" })
		add({ s = { 2.6, 3.6, 0.2 }, p = { 0, 3.6, -0.85 }, c = rgb(180, 30, 50), m = "Fabric" })
		add({ s = { 0.8, 0.8, 0.8 }, p = { 0, 6.2, -1.2 }, c = rgb(90, 200, 255), m = "Neon", sh = "Ball", fx = "sparkle" })
	end },
	DiamondFountain = { name = "Diamond Fountain", sold = "premium", rarity = "Legendary", size = { 6, 6 }, gen = 8, build = function(add, vc)
		vc(1, 5.6, { 0, 0.5, 0 }, rgb(230, 240, 255), "Marble")
		vc(1.02, 4.8, { 0, 0.52, 0 }, rgb(140, 220, 255), "Glass")
		add({ s = { 1.8, 2.6, 1.8 }, p = { 0, 2.6, 0 }, c = rgb(200, 240, 255), m = "Glass", r = { 0, 45, 0 }, fx = "sparkle" })
	end },
	NeonSign = { name = "Neon Base Sign", sold = "premium", rarity = "Epic", size = { 6, 1 }, build = function(add)
		add({ s = { 6, 3, 0.4 }, p = { 0, 3, 0 }, c = rgb(25, 25, 35), m = "Metal" })
		add({ s = { 5.4, 0.3, 0.42 }, p = { 0, 4.2, 0 }, c = rgb(255, 60, 200), m = "Neon", fx = "light" })
		add({ s = { 5.4, 0.3, 0.42 }, p = { 0, 1.8, 0 }, c = rgb(60, 220, 255), m = "Neon" })
		for _, x in { -2.4, 2.4 } do
			add({ s = { 0.3, 1.5, 0.3 }, p = { x, 0.75, 0 }, c = rgb(50, 50, 60), m = "Metal" })
		end
	end },
}

-- Coin-only crates. Odds by rarity, then evenly within the rarity. Duplicates of crate items turn into shards.
DecorData.Boxes = {
	CommonCrate = {
		name = "Garden Crate", price = 250, color = rgb(110, 180, 90),
		odds = { Common = 60, Rare = 28, Epic = 10, Legendary = 2 },
		pool = { "MushroomRing", "ToadstoolLamp", "CrateStack", "BeachUmbrella", "Snowman", "LavaLamp", "CrystalCluster", "GoldenStatue", "RainbowArch", "StarryFountain" },
	},
	RareCrate = {
		name = "Mystic Crate", price = 900, color = rgb(150, 90, 230),
		odds = { Rare = 60, Epic = 32, Legendary = 8 },
		pool = { "Snowman", "LavaLamp", "CrystalCluster", "GoldenStatue", "RainbowArch", "DragonStatue", "StarryFountain", "AuroraTree" },
	},
}
DecorData.BoxOrder = { "CommonCrate", "RareCrate" }

-- Display order in the shop
DecorData.ShopOrder = {}
for id, item in DecorData.Items do
	item.id = id
	if item.sold == "shop" then
		table.insert(DecorData.ShopOrder, id)
	end
end
table.sort(DecorData.ShopOrder, function(a, b)
	return DecorData.Items[a].price < DecorData.Items[b].price
end)

DecorData.DailyPool = {}
for id, item in DecorData.Items do
	if item.sold == "daily" then
		table.insert(DecorData.DailyPool, id)
	end
end
table.sort(DecorData.DailyPool)

-- The same 5 daily items for everyone, changing at 00:00 UTC
function DecorData.today(): number
	return math.floor(os.time() / 86400)
end
function DecorData.dailyShop(day: number)
	local pool = table.clone(DecorData.DailyPool)
	local rng = Random.new(day * 7919 + 13)
	local out = {}
	for _ = 1, math.min(DecorData.DailyShopSize, #pool) do
		table.insert(out, table.remove(pool, rng:NextInteger(1, #pool)))
	end
	return out
end

-- Odds of each item in a crate, as percentages (for showing players)
function DecorData.boxOdds(boxId: string)
	local box = DecorData.Boxes[boxId]
	local byRarity = {}
	for _, id in box.pool do
		local r = DecorData.Items[id].rarity
		byRarity[r] = (byRarity[r] or 0) + 1
	end
	local list = {}
	for _, id in box.pool do
		local r = DecorData.Items[id].rarity
		table.insert(list, { id = id, rarity = r, pct = (box.odds[r] or 0) / byRarity[r] })
	end
	table.sort(list, function(a, b)
		return a.pct > b.pct
	end)
	return list
end

-- A short line about what an item does (shown in the shop)
function DecorData.describe(id: string): string
	local item = DecorData.Items[id]
	if item.gen then
		return ("+%d coins/min"):format(item.gen)
	elseif item.habitat then
		return ("%s creatures train faster in your base"):format(table.concat(item.habitat, "/"))
	elseif item.heal then
		return ("Heals your team %d%% a minute"):format(item.heal * 100)
	elseif item.train then
		return "Your whole team trains faster in your base"
	elseif item.pedestal then
		return "Shows off your strongest creature"
	elseif item.trophy then
		return "Shows your badges and best catches"
	end
	return "Decoration"
end

----------------------------------------------------------------------------------------------
-- Base layout maths, shared so the client's preview matches what the server allows.
-- Positions are saved relative to the base Floor's centre in a frame where +x points toward the gate,
-- so a layout looks the same on any of the 8 bases (bases on the right side of the map are mirrored).
----------------------------------------------------------------------------------------------
DecorData.Grid = 0.5
DecorData.MainHalf = { 45, 19 } -- the main floor is 90 x 38 (layout 2: was 60 x 38)
DecorData.ExpansionMinX = -75.5 -- the expansion behind the base reaches this far back
DecorData.LayoutVersion = 2 -- layout 1 saves are shifted by LayoutShift when loaded
DecorData.LayoutShift = -15 -- the floor centre moved 15 studs back when the bases were enlarged
DecorData.SpawnClear = 3.5 -- keep this far from the spawn point
-- Side wings widen the main floor: Large (level 3) opens the -z wing, Grand (level 4) the +z wing.
DecorData.WingHalf = 33 -- with both wings the main floor is 90 x 66
DecorData.WingLevels = { left = 3, right = 4 }

function DecorData.zRange(level: number?): (number, number)
	level = level or 1
	local lo = level >= DecorData.WingLevels.left and -DecorData.WingHalf or -DecorData.MainHalf[2]
	local hi = level >= DecorData.WingLevels.right and DecorData.WingHalf or DecorData.MainHalf[2]
	return lo, hi
end

function DecorData.side(floor: BasePart): number
	return floor.Position.X < 0 and 1 or -1
end

function DecorData.footprint(id: string, r: number): (number, number)
	local item = DecorData.Items[id]
	if r % 180 == 90 then
		return item.size[2], item.size[1]
	end
	return item.size[1], item.size[2]
end

function DecorData.snap(v: number): number
	return math.floor(v / DecorData.Grid + 0.5) * DecorData.Grid
end

function DecorData.toWorld(floor: BasePart, x: number, z: number, r: number): CFrame
	local s = DecorData.side(floor)
	local top = floor.Position.Y + floor.Size.Y / 2
	local yaw = s == 1 and r or (360 - r) % 360
	return CFrame.new(floor.Position.X + x * s, top, floor.Position.Z + z) * CFrame.Angles(0, math.rad(yaw), 0)
end

function DecorData.toLocal(floor: BasePart, pos: Vector3): (number, number)
	return (pos.X - floor.Position.X) * DecorData.side(floor), pos.Z - floor.Position.Z
end

-- Is a footprint (centre x, z; size fx, fz) inside the buildable area?
-- level: base level (wings). The buildable area is the main floor (+ its wings) plus the expansion behind it.
function DecorData.inBounds(x: number, z: number, fx: number, fz: number, expansion: boolean, level: number?, stage: number?): boolean
	local x0, x1, z0, z1 = x - fx / 2, x + fx / 2, z - fz / 2, z + fz / 2
	if (stage or 1) >= 4 and x0 >= -150.5 and x1 <= -112 and z0 >= -18.5 and z1 <= 18.5 then
		return true
	end
	local hx, hz = DecorData.MainHalf[1], DecorData.MainHalf[2]
	-- the main floor with any wings
	local lo, hi = DecorData.zRange(level)
	if x0 >= -hx + 0.5 and x1 <= hx - 0.5 and z0 >= lo + 0.5 and z1 <= hi - 0.5 then
		return true
	end
	-- the main floor's centre strip plus the expansion behind it
	local minX = expansion and DecorData.ExpansionMinX or -hx
	return x0 >= minX + 0.5 and x1 <= hx - 0.5 and z0 >= -hz + 0.5 and z1 <= hz - 0.5
end

-- Build a decoration model. Its PrimaryPart "Root" sits on the ground at the footprint's centre.
local function addEffect(part: BasePart, fx: string)
	if fx == "light" then
		local l = Instance.new("PointLight")
		l.Color = part.Color
		l.Range = 14
		l.Brightness = 1.4
		l.Parent = part
	elseif fx == "fire" then
		local f = Instance.new("Fire")
		f.Size = 3
		f.Heat = 6
		f.Parent = part
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 160, 80)
		l.Range = 14
		l.Parent = part
	elseif fx == "sparkle" then
		local p = Instance.new("ParticleEmitter")
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Rate = 6
		p.Lifetime = NumberRange.new(1, 1.6)
		p.Speed = NumberRange.new(1, 2)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Size = NumberSequence.new(0.4, 0)
		p.Color = ColorSequence.new(part.Color)
		p.LightEmission = 0.8
		p.Parent = part
	elseif fx == "smoke" then
		local s = Instance.new("Smoke")
		s.Color = Color3.new(1, 1, 1)
		s.Opacity = 0.08
		s.RiseVelocity = 2
		s.Size = 3
		s.Parent = part
	end
end

function DecorData.build(id: string): Model?
	local item = DecorData.Items[id]
	if not item then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(item.size[1], 0.2, item.size[2])
	root.CFrame = CFrame.new(0, 0.1, 0)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = true
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root
	local function add(spec)
		local p = Instance.new("Part")
		p.Name = spec.name or "Piece"
		p.Anchored = true
		p.Size = Vector3.new(spec.s[1], spec.s[2], spec.s[3])
		local r = spec.r or { 0, 0, 0 }
		p.CFrame = CFrame.new(spec.p[1], spec.p[2], spec.p[3]) * CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
		p.Color = spec.c or Color3.new(1, 1, 1)
		p.Material = Enum.Material[spec.m or "SmoothPlastic"]
		if spec.sh then
			p.Shape = Enum.PartType[spec.sh]
		end
		p.Transparency = spec.t or 0
		p.CanCollide = not (spec.nc or item.flat)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = not item.flat
		if spec.fx then
			addEffect(p, spec.fx)
		end
		p.Parent = model
		return p
	end
	local function vc(h, d, pos, color, mat)
		return add({ s = { h, d, d }, p = pos, c = color, m = mat, sh = "Cylinder", r = { 0, 0, 90 } })
	end
	item.build(add, vc)
	model:SetAttribute("DecorId", id)
	return model
end

return DecorData
