--!strict
--[[
	CourseConfig: the optional parkour courses, one entry per route. Tune rewards, cooldowns and
	difficulty here; nothing else needs editing.

	  Courses[i] = { Id, Lane, RouteName, Theme, Difficulty, CoinReward, Cooldown?, FirstClearBonus?, Seed? }
	    Id               stable key (saved in player data for the one-time bonus); use the lane key
	    Lane             the route's lane key (Map.Lanes.<Lane>); the builder reads its box, walls and trainers
	    RouteName        shown on the start sign and in the hint
	    Theme            look of the platforms (ObstacleCourseBuilder.THEMES)
	    Difficulty       "Easy" | "Medium" | "Hard" | "Expert" (see Difficulties below)
	    CoinReward       coins per chest claim (doubled by the 2x Coins pass, like other coin rewards)
	    Cooldown         seconds before the same player can claim that chest again (default DefaultCooldown)
	    FirstClearBonus  one-time extra coins on a player's first ever clear (default = CoinReward)

	Adding a route: add one entry, then run ObstacleCourseBuilder.build("<Id>") in the Studio command bar.
	See vault/Systems/ObstacleCourses.md.
]]

export type Difficulty = "Easy" | "Medium" | "Hard" | "Expert"

export type Course = {
	Id: string,
	Lane: string,
	RouteName: string,
	Theme: string,
	Difficulty: Difficulty,
	CoinReward: number,
	Cooldown: number?,
	FirstClearBonus: number?,
	Seed: number?,
}

-- Builder tuning per difficulty. Gap = edge-to-edge jump in studs (default jump clears about 7.5 on
-- the flat), Rise = max climb per hop, Steps = platforms in the course, MaxHeight = highest platform
-- above the start pad. Elements: Hop, Stairs, Climb, Beam, Mover, Spinner, Vanish, Hazard.
-- MinSeconds: a chest claim needs at least this long since the player stepped on the start pad.
export type Tuning = {
	Steps: number,
	GapMin: number,
	GapMax: number,
	Rise: number,
	MaxHeight: number,
	Elements: { [string]: number }, -- element = weight
	SpinSpeed: number, -- radians per second
	MoverPeriod: number, -- seconds per round trip
	VanishPeriod: number, -- seconds per visible + hidden cycle
	MinSeconds: number,
	Label: string,
}

local CourseConfig = {}

CourseConfig.DefaultCooldown = 600 -- 10 minutes
CourseConfig.PromptDistance = 10 -- studs from the chest
CourseConfig.RunTimeout = 900 -- a run older than this no longer counts

CourseConfig.Difficulties = {
	Easy = {
		Steps = 12, GapMin = 2.5, GapMax = 4, Rise = 2, MaxHeight = 12,
		Elements = { Hop = 3, Stairs = 1 },
		SpinSpeed = 0, MoverPeriod = 6, VanishPeriod = 4, MinSeconds = 8, Label = "Easy",
	},
	Medium = {
		Steps = 18, GapMin = 3.5, GapMax = 5, Rise = 2.5, MaxHeight = 18,
		Elements = { Hop = 4, Stairs = 1, Climb = 1, Beam = 1, Mover = 1, Spinner = 1 },
		SpinSpeed = 1.6, MoverPeriod = 6, VanishPeriod = 4, MinSeconds = 14, Label = "Medium",
	},
	Hard = {
		Steps = 22, GapMin = 4, GapMax = 5.5, Rise = 2.5, MaxHeight = 24,
		Elements = { Hop = 3, Climb = 2, Beam = 1, Mover = 1, Spinner = 1, Vanish = 1, Hazard = 1 },
		SpinSpeed = 2.2, MoverPeriod = 5, VanishPeriod = 3.6, MinSeconds = 18, Label = "Hard",
	},
	Expert = {
		Steps = 26, GapMin = 4.5, GapMax = 6, Rise = 2.5, MaxHeight = 30,
		Elements = { Hop = 3, Climb = 3, Beam = 1, Mover = 1, Spinner = 1, Vanish = 2, Hazard = 1 },
		SpinSpeed = 2.8, MoverPeriod = 4.5, VanishPeriod = 3.2, MinSeconds = 22, Label = "Expert",
	},
} :: { [Difficulty]: Tuning }

-- Region 1 in road order, then Region 2. Later routes are longer, harder and pay more.
CourseConfig.Courses = {
	{ Id = "Lane1", Lane = "Lane1", RouteName = "Meadow Route", Theme = "Meadow", Difficulty = "Easy", CoinReward = 100 },
	{ Id = "Lane1B", Lane = "Lane1B", RouteName = "Boulder Pass", Theme = "Boulder", Difficulty = "Easy", CoinReward = 125 },
	{ Id = "Lane3", Lane = "Lane3", RouteName = "Tide Coast", Theme = "Tide", Difficulty = "Easy", CoinReward = 150 },
	{ Id = "Lane4", Lane = "Lane4", RouteName = "Volt Plains", Theme = "Volt", Difficulty = "Medium", CoinReward = 200 },
	{ Id = "Lane2", Lane = "Lane2", RouteName = "Ember Ridge", Theme = "Ember", Difficulty = "Medium", CoinReward = 250 },
	{ Id = "Lane5", Lane = "Lane5", RouteName = "Frost Peak", Theme = "Frost", Difficulty = "Medium", CoinReward = 300 },
	{ Id = "Lane6", Lane = "Lane6", RouteName = "Shadow Woods", Theme = "Shadow", Difficulty = "Hard", CoinReward = 350 },
	{ Id = "Lane7", Lane = "Lane7", RouteName = "Sky Spire", Theme = "Sky", Difficulty = "Hard", CoinReward = 400 },
	{ Id = "Lane9", Lane = "Lane9", RouteName = "Sunpetal Fields", Theme = "Sunpetal", Difficulty = "Hard", CoinReward = 450 },
	{ Id = "Lane10", Lane = "Lane10", RouteName = "Mirage Desert", Theme = "Mirage", Difficulty = "Hard", CoinReward = 500 },
	{ Id = "Lane11", Lane = "Lane11", RouteName = "Coral Reef", Theme = "Reef", Difficulty = "Hard", CoinReward = 550 },
	{ Id = "Lane12", Lane = "Lane12", RouteName = "Thunder Mesa", Theme = "Mesa", Difficulty = "Expert", CoinReward = 600 },
	{ Id = "Lane13", Lane = "Lane13", RouteName = "Toxic Bog", Theme = "Bog", Difficulty = "Expert", CoinReward = 650 },
	{ Id = "Lane14", Lane = "Lane14", RouteName = "Crystal Caverns", Theme = "Crystal", Difficulty = "Expert", CoinReward = 700 },
	{ Id = "Lane15", Lane = "Lane15", RouteName = "Phantom Manor", Theme = "Manor", Difficulty = "Expert", CoinReward = 750 },
	{ Id = "Lane16", Lane = "Lane16", RouteName = "Dragon Peaks", Theme = "Dragon", Difficulty = "Expert", CoinReward = 800 },
} :: { Course }

local byId: { [string]: Course } = {}
for _, course in CourseConfig.Courses do
	byId[course.Id] = course
end

function CourseConfig.get(id: string): Course?
	return byId[id]
end

function CourseConfig.cooldown(course: Course): number
	return course.Cooldown or CourseConfig.DefaultCooldown
end

function CourseConfig.firstClearBonus(course: Course): number
	return course.FirstClearBonus or course.CoinReward
end

function CourseConfig.tuning(course: Course): Tuning
	return CourseConfig.Difficulties[course.Difficulty]
end

return CourseConfig
