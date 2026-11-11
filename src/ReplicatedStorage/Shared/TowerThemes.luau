--[[
	TowerThemes: the look of each Dark Tower stage, keyed by tower number (10 floors each).
	  Tower 1 = floors 1.1-1.10 (rooms 1-10): Bone Crypt, grey stone, bone and moss.
	  Tower 2 = floors 2.1-2.10 (rooms 11-20): Ember Forge, black iron, orange and red.
	  The final rest room (room 21, "3.1") uses the last tower's theme.
	Floor 10 of every tower is the boss room: the same theme, darker, with gold trim (the `boss` overrides).

	Used by:
	  ServerStorage.TowerBuilder           paints the rooms in the place file (Edit, re-runnable)
	  DungeonNPCStyler                      trainer clothes, glow and trim (rank palettes)
	  DungeonService / DungeonClient        lift glow, notifications, banners and the lift tint
	To restyle a tower: change its colours here, run TowerBuilder.paint() in Studio, save the place.
	No purple anywhere: the old Dark Tower violet is gone on purpose.
]]

local TowerThemes = {}

TowerThemes.FLOORS_PER_TOWER = 10

local rgb = Color3.fromRGB
local M = Enum.Material

TowerThemes.towers = {
	[1] = {
		name = "Bone Crypt",
		stage = "first",
		room = {
			wall = { rgb(92, 90, 84), M.Slate },
			floor = { rgb(74, 72, 66), M.Cobblestone },
			ceiling = { rgb(62, 60, 56), M.Slate },
			pillar = { rgb(206, 198, 176), M.Limestone },
			carpet = { rgb(72, 94, 54), M.Fabric },
			trim = { rgb(160, 225, 130), M.Neon }, -- window slits, lift rings
			torch = { rgb(170, 235, 140), M.Neon },
			torchLight = rgb(190, 240, 160),
			hatch = { rgb(120, 170, 100), M.Neon },
			startPad = { rgb(214, 204, 172), M.Neon },
			exit = { rgb(130, 205, 170), M.Neon },
			exitText = rgb(235, 245, 230),
			sign = rgb(232, 224, 202),
			signStroke = rgb(30, 28, 24),
			outer = { rgb(84, 82, 76), M.Slate }, -- battlements, ground
			beacon = { rgb(160, 225, 130), M.Neon },
		},
		lift = rgb(170, 235, 140),
		tint = rgb(225, 240, 215), -- screen tint while the lift rises
		banner = rgb(220, 240, 200),
		bannerStroke = rgb(24, 30, 20),
		npc = {
			ranks = {
				Trainee = { cloth = rgb(104, 100, 92), glow = rgb(170, 235, 140) },
				Adept = { cloth = rgb(70, 86, 58), glow = rgb(190, 240, 160) },
				Veteran = { cloth = rgb(118, 108, 90), glow = rgb(220, 210, 150) },
				Warden = { cloth = rgb(30, 28, 26), glow = rgb(255, 200, 90) },
			},
			bone = rgb(214, 206, 184),
			trim = rgb(196, 188, 160),
			belt = rgb(70, 52, 38),
		},
		boss = {
			room = {
				wall = { rgb(54, 52, 48), M.Slate },
				floor = { rgb(44, 42, 38), M.Cobblestone },
				ceiling = { rgb(38, 36, 33), M.Slate },
				pillar = { rgb(120, 114, 98), M.Limestone },
				carpet = { rgb(40, 54, 30), M.Fabric },
				trim = { rgb(255, 200, 90), M.Neon },
				torch = { rgb(255, 196, 80), M.Neon },
				torchLight = rgb(255, 205, 120),
				sign = rgb(255, 206, 110),
			},
			npcTrim = rgb(255, 200, 90),
		},
	},
	[2] = {
		name = "Ember Forge",
		stage = "second",
		room = {
			wall = { rgb(30, 28, 27), M.Slate },
			floor = { rgb(44, 40, 38), M.Basalt },
			ceiling = { rgb(24, 22, 21), M.Slate },
			pillar = { rgb(56, 50, 46), M.Metal },
			carpet = { rgb(205, 80, 34), M.CrackedLava },
			trim = { rgb(255, 128, 40), M.Neon },
			torch = { rgb(255, 110, 40), M.Neon },
			torchLight = rgb(255, 140, 60),
			hatch = { rgb(255, 120, 45), M.Neon },
			startPad = { rgb(255, 170, 90), M.Neon },
			exit = { rgb(255, 150, 60), M.Neon },
			exitText = rgb(255, 236, 214),
			sign = rgb(255, 188, 120),
			signStroke = rgb(40, 14, 6),
			outer = { rgb(36, 32, 30), M.Basalt },
			beacon = { rgb(255, 128, 40), M.Neon },
		},
		lift = rgb(255, 140, 50),
		tint = rgb(255, 222, 200),
		banner = rgb(255, 180, 110),
		bannerStroke = rgb(40, 12, 4),
		npc = {
			ranks = {
				Adept = { cloth = rgb(46, 40, 38), glow = rgb(255, 140, 50) },
				Veteran = { cloth = rgb(110, 34, 26), glow = rgb(255, 110, 60) },
				Master = { cloth = rgb(24, 20, 18), glow = rgb(255, 70, 40) },
				Warden = { cloth = rgb(16, 13, 12), glow = rgb(255, 205, 90) },
			},
			bone = rgb(90, 84, 80), -- iron masks and horns
			trim = rgb(210, 70, 34),
			belt = rgb(40, 30, 26),
		},
		boss = {
			room = {
				wall = { rgb(18, 16, 15), M.Slate },
				floor = { rgb(30, 26, 24), M.Basalt },
				ceiling = { rgb(14, 12, 12), M.Slate },
				pillar = { rgb(40, 36, 34), M.Metal },
				carpet = { rgb(150, 40, 20), M.CrackedLava },
				trim = { rgb(255, 205, 90), M.Neon },
				torch = { rgb(255, 196, 80), M.Neon },
				torchLight = rgb(255, 205, 120),
				sign = rgb(255, 210, 110),
			},
			npcTrim = rgb(255, 205, 90),
		},
	},
}

-- Which tower a floor index (1-based, as in GameData.Dungeon.floors) belongs to.
function TowerThemes.towerOf(index: number): number
	local n = math.ceil(math.max(1, index) / TowerThemes.FLOORS_PER_TOWER)
	return math.clamp(n, 1, #TowerThemes.towers)
end

-- True for floor 10 of a tower (x.10), which is the boss floor.
function TowerThemes.isBossFloor(index: number): boolean
	return index <= #TowerThemes.towers * TowerThemes.FLOORS_PER_TOWER and index % TowerThemes.FLOORS_PER_TOWER == 0
end

-- The tower's theme with the boss overrides merged in on a boss floor. Returns (theme, room, isBoss).
function TowerThemes.forFloor(index: number)
	local theme = TowerThemes.towers[TowerThemes.towerOf(index)]
	local boss = TowerThemes.isBossFloor(index)
	local room = table.clone(theme.room)
	if boss then
		for k, v in theme.boss.room do
			room[k] = v
		end
	end
	return theme, room, boss
end

return TowerThemes
