--[[
	BattleData: type chart, moves, base stats, learnsets and the level/XP curve.
	Shared so both the server (damage) and client (move colours) agree.
]]

local GameData = require(script.Parent.GameData)

local BattleData = {}

BattleData.MaxLevel = 100

-- Attacking type -> defending type -> multiplier. Anything missing is 1x.
BattleData.Types = {
	"Normal", "Fire", "Water", "Grass", "Electric", "Ice", "Fighting", "Poison", "Ground",
	"Flying", "Psychic", "Bug", "Rock", "Ghost", "Dragon", "Dark", "Steel", "Fairy",
}

-- Attacking type -> defending type -> multiplier (the standard 18-type chart). Missing = 1x.
BattleData.TypeChart = {
	Normal   = { Rock = 0.5, Ghost = 0, Steel = 0.5 },
	Fire     = { Fire = 0.5, Water = 0.5, Grass = 2, Ice = 2, Bug = 2, Rock = 0.5, Dragon = 0.5, Steel = 2 },
	Water    = { Fire = 2, Water = 0.5, Grass = 0.5, Ground = 2, Rock = 2, Dragon = 0.5 },
	Grass    = { Fire = 0.5, Water = 2, Grass = 0.5, Poison = 0.5, Ground = 2, Flying = 0.5, Bug = 0.5, Rock = 2, Dragon = 0.5, Steel = 0.5 },
	Electric = { Water = 2, Grass = 0.5, Electric = 0.5, Ground = 0, Flying = 2, Dragon = 0.5 },
	Ice      = { Fire = 0.5, Water = 0.5, Grass = 2, Ice = 0.5, Ground = 2, Flying = 2, Dragon = 2, Steel = 0.5 },
	Fighting = { Normal = 2, Ice = 2, Poison = 0.5, Flying = 0.5, Psychic = 0.5, Bug = 0.5, Rock = 2, Ghost = 0, Dark = 2, Steel = 2, Fairy = 0.5 },
	Poison   = { Grass = 2, Poison = 0.5, Ground = 0.5, Rock = 0.5, Ghost = 0.5, Steel = 0, Fairy = 2 },
	Ground   = { Fire = 2, Grass = 0.5, Electric = 2, Poison = 2, Flying = 0, Bug = 0.5, Rock = 2, Steel = 2 },
	Flying   = { Grass = 2, Electric = 0.5, Fighting = 2, Bug = 2, Rock = 0.5, Steel = 0.5 },
	Psychic  = { Fighting = 2, Poison = 2, Psychic = 0.5, Dark = 0, Steel = 0.5 },
	Bug      = { Fire = 0.5, Grass = 2, Fighting = 0.5, Poison = 0.5, Flying = 0.5, Psychic = 2, Ghost = 0.5, Dark = 2, Steel = 0.5, Fairy = 0.5 },
	Rock     = { Fire = 2, Ice = 2, Fighting = 0.5, Ground = 0.5, Flying = 2, Bug = 2, Steel = 0.5 },
	Ghost    = { Normal = 0, Psychic = 2, Ghost = 2, Dark = 0.5 },
	Dragon   = { Dragon = 2, Steel = 0.5, Fairy = 0 },
	Dark     = { Fighting = 0.5, Psychic = 2, Ghost = 2, Dark = 0.5, Fairy = 0.5 },
	Steel    = { Fire = 0.5, Water = 0.5, Electric = 0.5, Ice = 2, Rock = 2, Steel = 0.5, Fairy = 2 },
	Fairy    = { Fire = 0.5, Fighting = 2, Poison = 0.5, Dragon = 2, Dark = 2, Steel = 0.5 },
}

-- Multiplier against a creature with one or two types (multiplied together, so 4x and 0.25x are possible)
function BattleData.effectiveness(moveType: string, defenderType: string, defenderType2: string?): number
	local row = BattleData.TypeChart[moveType] or {}
	local mult = row[defenderType] or 1
	if defenderType2 then
		mult *= row[defenderType2] or 1
	end
	return mult
end

-- Colours used for type tags and effects
BattleData.TypeColors = {
	Normal = Color3.fromRGB(168, 167, 122), Fire = Color3.fromRGB(238, 129, 48), Water = Color3.fromRGB(99, 144, 240),
	Grass = Color3.fromRGB(122, 199, 76), Electric = Color3.fromRGB(230, 190, 40), Ice = Color3.fromRGB(110, 200, 200),
	Fighting = Color3.fromRGB(194, 46, 40), Poison = Color3.fromRGB(163, 62, 161), Ground = Color3.fromRGB(205, 170, 80),
	Flying = Color3.fromRGB(150, 130, 230), Psychic = Color3.fromRGB(240, 85, 135), Bug = Color3.fromRGB(150, 175, 30),
	Rock = Color3.fromRGB(180, 160, 55), Ghost = Color3.fromRGB(115, 87, 151), Dragon = Color3.fromRGB(111, 53, 252),
	Dark = Color3.fromRGB(112, 87, 70), Steel = Color3.fromRGB(150, 150, 180), Fairy = Color3.fromRGB(214, 133, 173),
}

-- Stat stages go from -6 to +6. Each stage is +50% (or the matching fraction below 0).
function BattleData.stageMult(stage: number): number
	if stage >= 0 then
		return (2 + stage) / 2
	end
	return 2 / (2 - stage)
end

BattleData.StatNames = { atk = "Attack", def = "Defense", spd = "Speed" }
BattleData.StatShort = { atk = "ATK", def = "DEF", spd = "SPD" }

-- Status conditions. inflict = { status, chance } on a move gives it a chance to cause one.
--   brn: loses 1/16 max HP each turn, Attack halved      psn: loses 1/8 max HP each turn
--   par: Speed halved, 25% chance to be unable to move    slp: can't move for 1-3 turns
--   frz: can't move; 20% chance to thaw each turn
-- Types that are immune: Fire can't burn, Poison/Steel can't be poisoned, Electric can't be
-- paralysed, Ice can't freeze. A creature only ever has one status at a time.
BattleData.StatusInfo = GameData.StatusInfo
BattleData.StatusImmune = {
	brn = { Fire = true }, psn = { Poison = true, Steel = true }, par = { Electric = true }, frz = { Ice = true },
}
function BattleData.canGetStatus(status: string, type1: string, type2: string?): boolean
	local immune = BattleData.StatusImmune[status]
	return not (immune and (immune[type1] or (type2 and immune[type2])))
end

-- category = "status" moves do no damage; effect = { target = "opponent"|"self", stat, stages }
BattleData.Moves = {
	Squeak            = { type = "Normal",   power = 0,  accuracy = 1.00, category = "status", effect = { target = "opponent", stat = "atk", stages = -1 } },
	Harden            = { type = "Normal",   power = 0,  accuracy = 1.00, category = "status", effect = { target = "self", stat = "def", stages = 1 } },
	Tackle            = { type = "Normal",   power = 40, accuracy = 1.00 },
	Gnaw              = { type = "Normal",   power = 50, accuracy = 0.95 },
	["Quick Peck"]     = { type = "Flying",   power = 40, accuracy = 1.00 },
	Gust              = { type = "Flying",   power = 55, accuracy = 0.95 },
	["Wing Slash"]     = { type = "Flying",   power = 60, accuracy = 0.95 },
	["Poison Prick"]   = { type = "Poison",   power = 40, accuracy = 1.00, inflict = { status = "psn", chance = 0.3 } },
	["Toxic Thorn"]    = { type = "Poison",   power = 60, accuracy = 0.90, inflict = { status = "psn", chance = 0.3 } },
	Jab               = { type = "Fighting", power = 40, accuracy = 1.00 },
	["Power Punch"]    = { type = "Fighting", power = 65, accuracy = 0.90 },
	["Bug Nibble"]     = { type = "Bug",      power = 40, accuracy = 1.00 },
	Stinger           = { type = "Bug",      power = 45, accuracy = 1.00, inflict = { status = "psn", chance = 0.2 } },
	["Shell Slam"]     = { type = "Bug",      power = 55, accuracy = 0.95 },
	["Vine Snap"]      = { type = "Grass",    power = 45, accuracy = 1.00 },
	["Leaf Swirl"]     = { type = "Grass",    power = 65, accuracy = 0.90 },
	["Ember Nip"]      = { type = "Fire",     power = 45, accuracy = 1.00, inflict = { status = "brn", chance = 0.1 } },
	["Flame Rush"]     = { type = "Fire",     power = 65, accuracy = 0.90, inflict = { status = "brn", chance = 0.1 } },
	["Splash Jet"]     = { type = "Water",    power = 45, accuracy = 1.00 },
	["Tide Pulse"]     = { type = "Water",    power = 65, accuracy = 0.90 },
	Spark             = { type = "Electric", power = 45, accuracy = 1.00, inflict = { status = "par", chance = 0.1 } },
	["Volt Burrow"]    = { type = "Electric", power = 70, accuracy = 0.90, inflict = { status = "par", chance = 0.1 } },
	["Rock Throw"]     = { type = "Rock",     power = 50, accuracy = 0.90 },
	Rockfall          = { type = "Rock",     power = 75, accuracy = 0.90 },
	["Mud Slap"]       = { type = "Ground",   power = 45, accuracy = 1.00 },
	Moonbeam          = { type = "Psychic",   power = 70, accuracy = 1.00 },
	["Astral Gale"]    = { type = "Psychic",   power = 90, accuracy = 0.90 },
	-- added with the new regions
	["Glimmer Beam"]   = { type = "Fairy",    power = 55, accuracy = 1.00 },
	["Fairy Wink"]     = { type = "Fairy",    power = 0,  accuracy = 1.00, category = "status", effect = { target = "opponent", stat = "atk", stages = -1 } },
	["Spore Puff"]     = { type = "Grass",    power = 40, accuracy = 1.00, inflict = { status = "slp", chance = 0.25 } },
	["Echo Screech"]   = { type = "Poison",   power = 50, accuracy = 0.95, inflict = { status = "psn", chance = 0.1 } },
	["Sand Burst"]     = { type = "Ground",   power = 55, accuracy = 0.95 },
	["Quake Stomp"]    = { type = "Ground",   power = 75, accuracy = 0.90 },
	["Pincer Snap"]    = { type = "Water",    power = 55, accuracy = 0.95 },
	["Thunder Lash"]   = { type = "Electric", power = 80, accuracy = 0.90, inflict = { status = "par", chance = 0.2 } },
	["Static Buzz"]    = { type = "Electric", power = 50, accuracy = 1.00, inflict = { status = "par", chance = 0.3 } },
	["Inferno Dive"]   = { type = "Fire",     power = 85, accuracy = 0.85, inflict = { status = "brn", chance = 0.2 } },
	["Magma Slam"]     = { type = "Fire",     power = 70, accuracy = 0.90, inflict = { status = "brn", chance = 0.2 } },
	["Frost Bite"]     = { type = "Ice",      power = 45, accuracy = 1.00, inflict = { status = "frz", chance = 0.1 } },
	["Hail Lance"]     = { type = "Ice",      power = 75, accuracy = 0.90, inflict = { status = "frz", chance = 0.1 } },
	["Shade Claw"]     = { type = "Ghost",    power = 55, accuracy = 1.00 },
	["Phantom Wail"]   = { type = "Ghost",    power = 80, accuracy = 0.90 },
	["Night Snap"]     = { type = "Dark",     power = 60, accuracy = 0.95 },
	["Sky Dive"]       = { type = "Flying",   power = 80, accuracy = 0.90 },
	["Dragon Rush"]    = { type = "Dragon",   power = 90, accuracy = 0.85 },
	["Drake Breath"]   = { type = "Dragon",   power = 60, accuracy = 1.00 },
	["Cloud Veil"]     = { type = "Flying",   power = 0,  accuracy = 1.00, category = "status", effect = { target = "self", stat = "def", stages = 1 } },
	["Tailwind"]       = { type = "Flying",   power = 0,  accuracy = 1.00, category = "status", effect = { target = "self", stat = "spd", stages = 1 } },
	["Bloom Burst"]    = { type = "Grass",    power = 90, accuracy = 0.90 },
	["Torrent Blast"]  = { type = "Water",    power = 90, accuracy = 0.90 },
	["Iron Claw"]      = { type = "Steel",    power = 55, accuracy = 1.00 },
	["Steel Beam"]     = { type = "Steel",    power = 80, accuracy = 0.90 },
	["Umbra Pulse"]    = { type = "Dark",     power = 80, accuracy = 0.90 },
	["Pixie Burst"]    = { type = "Fairy",    power = 75, accuracy = 0.90 },
}

-- Base stats and the moves each creature learns, with the level it learns them at.
BattleData.Species = {
	Fluttle   = { hp = 40,  atk = 45,  def = 40,  spd = 56,  xpYield = 50,
		learnset = { { "Tackle", 1 }, { "Quick Peck", 1 }, { "Gust", 7 } } },
	Nibbit    = { hp = 30,  atk = 56,  def = 35,  spd = 72,  xpYield = 50,
		learnset = { { "Tackle", 1 }, { "Squeak", 1 }, { "Gnaw", 4 } } },
	Squawkit  = { hp = 40,  atk = 60,  def = 30,  spd = 70,  xpYield = 55,
		learnset = { { "Tackle", 1 }, { "Quick Peck", 1 }, { "Wing Slash", 8 } } },
	Thornip   = { hp = 46,  atk = 52,  def = 50,  spd = 44,  xpYield = 60,
		learnset = { { "Tackle", 1 }, { "Poison Prick", 1 }, { "Toxic Thorn", 9 } } },
	Brawlet   = { hp = 40,  atk = 78,  def = 35,  spd = 70,  xpYield = 65,
		learnset = { { "Tackle", 1 }, { "Jab", 1 }, { "Power Punch", 9 } } },
	Wigglet   = { hp = 45,  atk = 30,  def = 35,  spd = 45,  xpYield = 40,
		learnset = { { "Tackle", 1 }, { "Bug Nibble", 1 }, { "Harden", 3 }, { "Gnaw", 5 } } },
	Stingle   = { hp = 40,  atk = 35,  def = 30,  spd = 50,  xpYield = 40,
		learnset = { { "Stinger", 1 }, { "Poison Prick", 1 }, { "Echo Screech", 8 }, { "Toxic Thorn", 12 } } },
	Shellum   = { hp = 50,  atk = 22,  def = 62,  spd = 30,  xpYield = 70,
		learnset = { { "Tackle", 1 }, { "Harden", 1 }, { "Shell Slam", 1 } } },
	Voltmole  = { hp = 50,  atk = 62,  def = 52,  spd = 80,  xpYield = 110,
		learnset = { { "Tackle", 1 }, { "Spark", 1 }, { "Volt Burrow", 8 } } },
	Lumifawn  = { hp = 55,  atk = 52,  def = 58,  spd = 62,  xpYield = 95,
		learnset = { { "Tackle", 1 }, { "Fairy Wink", 1 }, { "Vine Snap", 5 }, { "Glimmer Beam", 12 }, { "Leaf Swirl", 18 }, { "Pixie Burst", 28 } } },
	Lunaryx   = { hp = 100, atk = 110, def = 100, spd = 100, xpYield = 250,
		learnset = { { "Quick Peck", 1 }, { "Gust", 8 }, { "Moonbeam", 16 }, { "Astral Gale", 24 } } },
	Pebblit   = { hp = 45,  atk = 60,  def = 80,  spd = 25,  xpYield = 75,
		learnset = { { "Tackle", 1 }, { "Rock Throw", 1 }, { "Harden", 5 } } },
	Cragmaul  = { hp = 70,  atk = 85,  def = 95,  spd = 30,  xpYield = 140,
		learnset = { { "Tackle", 1 }, { "Rock Throw", 1 }, { "Harden", 1 }, { "Mud Slap", 1 } } },
	-- Starters
	Sproutle    = { hp = 45, atk = 49, def = 52, spd = 45, xpYield = 64,
		learnset = { { "Tackle", 1 }, { "Squeak", 1 }, { "Vine Snap", 3 }, { "Spore Puff", 10 }, { "Leaf Swirl", 13 } } },
	Bramblet    = { hp = 60, atk = 62, def = 66, spd = 58, xpYield = 142,
		learnset = { { "Vine Snap", 1 }, { "Leaf Swirl", 1 }, { "Toxic Thorn", 20 }, { "Harden", 24 } } },
	Thornwarden = { hp = 82, atk = 85, def = 88, spd = 76, xpYield = 236,
		learnset = { { "Leaf Swirl", 1 }, { "Toxic Thorn", 1 }, { "Harden", 1 }, { "Bloom Burst", 36 } } },
	Kindlit     = { hp = 39, atk = 54, def = 43, spd = 64, xpYield = 62,
		learnset = { { "Tackle", 1 }, { "Squeak", 1 }, { "Ember Nip", 3 }, { "Mud Slap", 5 }, { "Quick Peck", 10 }, { "Flame Rush", 13 } } },
	Blazefox    = { hp = 58, atk = 70, def = 58, spd = 80, xpYield = 142,
		learnset = { { "Ember Nip", 1 }, { "Flame Rush", 1 }, { "Gnaw", 1 }, { "Magma Slam", 22 } } },
	Infernyx    = { hp = 78, atk = 92, def = 78, spd = 100, xpYield = 240,
		learnset = { { "Flame Rush", 1 }, { "Magma Slam", 1 }, { "Wing Slash", 1 }, { "Inferno Dive", 36 } } },
	Drizzlet    = { hp = 44, atk = 48, def = 62, spd = 43, xpYield = 63,
		learnset = { { "Tackle", 1 }, { "Squeak", 1 }, { "Splash Jet", 3 }, { "Harden", 10 }, { "Tide Pulse", 13 } } },
	Torrentail  = { hp = 59, atk = 63, def = 80, spd = 58, xpYield = 142,
		learnset = { { "Splash Jet", 1 }, { "Tide Pulse", 1 }, { "Harden", 1 }, { "Pincer Snap", 22 } } },
	Tidalgon    = { hp = 80, atk = 84, def = 100, spd = 78, xpYield = 239,
		learnset = { { "Tide Pulse", 1 }, { "Pincer Snap", 1 }, { "Harden", 1 }, { "Torrent Blast", 36 } } },
	Puddlepup = { hp = 50,  atk = 50,  def = 50,  spd = 45,  xpYield = 70,
		learnset = { { "Tackle", 1 }, { "Splash Jet", 1 }, { "Tide Pulse", 10 } } },
	Embercub  = { hp = 45,  atk = 60,  def = 40,  spd = 55,  xpYield = 70,
		learnset = { { "Tackle", 1 }, { "Ember Nip", 1 }, { "Flame Rush", 10 }, { "Magma Slam", 26 } } },
	-- Boulder Pass / Glimmer Cavern
	Sporelet  = { hp = 45, atk = 45, def = 50, spd = 35, xpYield = 60,
		learnset = { { "Tackle", 1 }, { "Spore Puff", 1 }, { "Bug Nibble", 1 }, { "Leaf Swirl", 12 } } },
	Echoling  = { hp = 40, atk = 50, def = 35, spd = 70, xpYield = 60,
		learnset = { { "Quick Peck", 1 }, { "Poison Prick", 1 }, { "Echo Screech", 11 } } },
	Glintle   = { hp = 60, atk = 40, def = 55, spd = 45, xpYield = 80,
		learnset = { { "Tackle", 1 }, { "Fairy Wink", 1 }, { "Glimmer Beam", 10 }, { "Pixie Burst", 18 } } },
	-- Tide Coast
	Ripplefin    = { hp = 45, atk = 50, def = 45, spd = 60, xpYield = 65,
		learnset = { { "Splash Jet", 1 }, { "Tackle", 1 }, { "Tide Pulse", 16 } } },
	Tidecrest = { hp = 80, atk = 85, def = 75, spd = 75, xpYield = 160,
		learnset = { { "Splash Jet", 1 }, { "Tide Pulse", 1 }, { "Drake Breath", 1 }, { "Dragon Rush", 30 } } },
	Sandsnip  = { hp = 45, atk = 55, def = 50, spd = 55, xpYield = 65,
		learnset = { { "Tackle", 1 }, { "Mud Slap", 1 }, { "Sand Burst", 17 } } },
	Dunehorn  = { hp = 75, atk = 85, def = 80, spd = 50, xpYield = 150,
		learnset = { { "Mud Slap", 1 }, { "Sand Burst", 1 }, { "Harden", 1 }, { "Quake Stomp", 24 } } },
	Pinchard   = { hp = 55, atk = 70, def = 80, spd = 35, xpYield = 100,
		learnset = { { "Pincer Snap", 1 }, { "Harden", 1 }, { "Rock Throw", 1 }, { "Tide Pulse", 21 } } },
	-- Volt Plains
	Zapkit    = { hp = 40, atk = 55, def = 40, spd = 85, xpYield = 65,
		learnset = { { "Tackle", 1 }, { "Spark", 1 }, { "Static Buzz", 20 } } },
	Stormane  = { hp = 75, atk = 90, def = 65, spd = 105, xpYield = 170,
		learnset = { { "Spark", 1 }, { "Static Buzz", 1 }, { "Volt Burrow", 1 }, { "Thunder Lash", 30 } } },
	Buzzbolt  = { hp = 50, atk = 65, def = 55, spd = 70, xpYield = 110,
		learnset = { { "Stinger", 1 }, { "Spark", 1 }, { "Static Buzz", 22 } } },
	-- Ember Ridge
	Cindrake  = { hp = 80, atk = 100, def = 70, spd = 85, xpYield = 180,
		learnset = { { "Ember Nip", 1 }, { "Flame Rush", 1 }, { "Drake Breath", 1 }, { "Inferno Dive", 32 } } },
	Scorchling = { hp = 45, atk = 65, def = 40, spd = 80, xpYield = 75,
		learnset = { { "Quick Peck", 1 }, { "Ember Nip", 1 }, { "Flame Rush", 24 } } },
	Cinderock   = { hp = 55, atk = 70, def = 75, spd = 30, xpYield = 85,
		learnset = { { "Rock Throw", 1 }, { "Ember Nip", 1 }, { "Magma Slam", 25 } } },
	-- Frost Peak
	Frostpaw  = { hp = 55, atk = 65, def = 55, spd = 65, xpYield = 85,
		learnset = { { "Tackle", 1 }, { "Frost Bite", 1 }, { "Gnaw", 1 }, { "Hail Lance", 30 } } },
	Rimeling = { hp = 50, atk = 50, def = 70, spd = 50, xpYield = 85,
		learnset = { { "Frost Bite", 1 }, { "Harden", 1 }, { "Hail Lance", 29 } } },
	Glaciorn  = { hp = 90, atk = 95, def = 110, spd = 45, xpYield = 190,
		learnset = { { "Frost Bite", 1 }, { "Rock Throw", 1 }, { "Hail Lance", 1 }, { "Rockfall", 34 } } },
	Icicrest  = { hp = 55, atk = 70, def = 50, spd = 85, xpYield = 110,
		learnset = { { "Gust", 1 }, { "Frost Bite", 1 }, { "Wing Slash", 1 }, { "Hail Lance", 31 } } },
	-- Shadow Woods
	Gloomwisp     = { hp = 45, atk = 60, def = 45, spd = 80, xpYield = 90,
		learnset = { { "Shade Claw", 1 }, { "Squeak", 1 }, { "Night Snap", 32 } } },
	Phantorb  = { hp = 80, atk = 105, def = 75, spd = 95, xpYield = 200,
		learnset = { { "Shade Claw", 1 }, { "Night Snap", 1 }, { "Squeak", 1 }, { "Phantom Wail", 36 } } },
	Shadeshroom = { hp = 60, atk = 65, def = 65, spd = 40, xpYield = 95,
		learnset = { { "Spore Puff", 1 }, { "Toxic Thorn", 1 }, { "Leaf Swirl", 1 } } },
	Nightfang = { hp = 65, atk = 90, def = 60, spd = 85, xpYield = 130,
		learnset = { { "Gnaw", 1 }, { "Night Snap", 1 }, { "Shade Claw", 34 }, { "Umbra Pulse", 42 } } },
	-- Sky Spire
	Zephlet  = { hp = 50, atk = 60, def = 50, spd = 80, xpYield = 95,
		learnset = { { "Quick Peck", 1 }, { "Gust", 1 }, { "Tailwind", 1 }, { "Wing Slash", 1 } } },
	Galewing  = { hp = 75, atk = 90, def = 70, spd = 100, xpYield = 170,
		learnset = { { "Gust", 1 }, { "Wing Slash", 1 }, { "Tailwind", 1 }, { "Sky Dive", 38 } } },
	Nimbuff     = { hp = 80, atk = 60, def = 85, spd = 70, xpYield = 150,
		learnset = { { "Gust", 1 }, { "Cloud Veil", 1 }, { "Glimmer Beam", 1 }, { "Sky Dive", 40 } } },
	Skydrake  = { hp = 90, atk = 110, def = 85, spd = 100, xpYield = 230,
		learnset = { { "Wing Slash", 1 }, { "Drake Breath", 1 }, { "Sky Dive", 1 }, { "Dragon Rush", 44 } } },
}

-- Stat multiplier for a size class (Tiny 0.9 ... Huge 1.1)
function BattleData.sizeMult(sizeClass: string?): number
	for _, c in GameData.SizeClasses do
		if c.name == sizeClass then
			return c.statMult or 1
		end
	end
	return 1
end

----------------------------------------------------------------------------------------------
-- IVs and Stars
-- Every creature has hidden IVs (0-31) per stat. New creatures roll 0-20.
-- Reaching level 100 earns Star 1; XP past 100 keeps counting toward Star 2 and Star 3.
-- Each star perfects (sets to 31) the IV of the creature's next-best base stat; Star 3 perfects
-- every stat and the creature becomes "IV Trained".
----------------------------------------------------------------------------------------------
BattleData.IVMax = 31
BattleData.IVRollMax = 20
BattleData.StatKeys = { "hp", "atk", "def", "spd" }
BattleData.StarXP = { 0, 100000, 250000 } -- extra XP past level 100 needed for star 1, 2, 3
BattleData.MaxStars = 3

function BattleData.rollIVs(rng: Random?)
	rng = rng or Random.new()
	local t = {}
	for _, k in BattleData.StatKeys do
		t[k] = rng:NextInteger(0, BattleData.IVRollMax)
	end
	return t
end

-- Clean up saved/untrusted IVs; missing ones are rolled
function BattleData.cleanIVs(ivs)
	local out = {}
	local rng = Random.new()
	for _, k in BattleData.StatKeys do
		local v = typeof(ivs) == "table" and tonumber(ivs[k]) or nil
		if v == nil or v ~= v then
			v = rng:NextInteger(0, BattleData.IVRollMax)
		end
		out[k] = math.clamp(math.floor(v), 0, BattleData.IVMax)
	end
	return out
end

-- Base stats of a species, best first (hp/atk/def/spd ties keep that order)
function BattleData.bestStats(name: string): { string }
	local s = BattleData.Species[name]
	local list = table.clone(BattleData.StatKeys)
	table.sort(list, function(a, b)
		if s[a] == s[b] then
			return table.find(BattleData.StatKeys, a) < table.find(BattleData.StatKeys, b)
		end
		return s[a] > s[b]
	end)
	return list
end

-- How many stars this record has earned from its level and XP
function BattleData.starsFor(record): number
	if (record.level or 0) < BattleData.MaxLevel then
		return 0
	end
	local extra = (record.xp or 0) - BattleData.xpForLevel(BattleData.MaxLevel)
	local stars = 0
	for i, need in BattleData.StarXP do
		if extra >= need then
			stars = i
		end
	end
	return stars
end

-- Progress (0-1) toward the next star, or nil below level 100 / at 3 stars
function BattleData.starProgress(record): number?
	local stars = BattleData.starsFor(record)
	if stars == 0 or stars >= BattleData.MaxStars then
		return nil
	end
	local extra = record.xp - BattleData.xpForLevel(BattleData.MaxLevel)
	local lo, hi = BattleData.StarXP[stars], BattleData.StarXP[stars + 1]
	return math.clamp((extra - lo) / (hi - lo), 0, 1)
end

-- Most XP a creature can hold (3 stars)
function BattleData.maxXP(): number
	BattleData.Species.Chronowisp = { hp = 80, atk = 95, def = 95, spd = 90, xpYield = 200,
    learnset = { { "Squeak", 1 }, { "Shade Claw", 1 }, { "Night Snap", 1 }, { "Phantom Wail", 36 }, { "Iron Claw", 40 }, { "Steel Beam", 60 } } }

return BattleData.xpForLevel(BattleData.MaxLevel) + BattleData.StarXP[BattleData.MaxStars]
end

-- Set IVs to match the record's stars. Returns true if anything changed.
function BattleData.applyStars(record): boolean
	record.ivs = record.ivs or BattleData.rollIVs()
	local stars = BattleData.starsFor(record)
	record.stars = stars
	local changed = false
	local order = BattleData.bestStats(record.name)
	local perfect = stars >= BattleData.MaxStars and #order or stars
	for i = 1, perfect do
		local k = order[i]
		if record.ivs[k] ~= BattleData.IVMax then
			record.ivs[k] = BattleData.IVMax
			changed = true
		end
	end
	return changed
end

-- ivs: optional { hp, atk, def, spd } (0-31). Each IV point adds level/100 to that stat.
function BattleData.stats(name: string, level: number, sizeClass: string?, ivs)
	local s = BattleData.Species[name]
	local m = BattleData.sizeMult(sizeClass)
	local iv = ivs or {}
	local function core(k)
		return math.floor((2 * s[k] + (iv[k] or 0)) * level / 100)
	end
	return {
		maxHP = math.floor((core("hp") + level + 10) * m),
		atk = math.floor((core("atk") + 5) * m),
		def = math.floor((core("def") + 5) * m),
		spd = math.floor((core("spd") + 5) * m),
	}
end

-- The (up to) 4 most recently learned moves at this level
function BattleData.movesAt(name: string, level: number): { string }
	local known = {}
	for _, entry in BattleData.Species[name].learnset do
		if entry[2] <= level then
			table.insert(known, entry[1])
		end
	end
	while #known > 4 do
		table.remove(known, 1)
	end
	return known
end

-- Moves learned exactly at this level (for "X learned Y!" messages)
function BattleData.learnedAt(name: string, level: number): { string }
	local list = {}
	for _, entry in BattleData.Species[name].learnset do
		if entry[2] == level then
			table.insert(list, entry[1])
		end
	end
	return list
end

-- Total XP needed to be at a level
function BattleData.xpForLevel(level: number): number
	return level * level * level
end

BattleData.Species.Chronowisp = { hp = 80, atk = 95, def = 95, spd = 90, xpYield = 200,
    learnset = { { "Squeak", 1 }, { "Shade Claw", 1 }, { "Night Snap", 1 }, { "Phantom Wail", 36 }, { "Iron Claw", 40 }, { "Steel Beam", 60 } } }

return BattleData
