# Obstacle Courses

Optional parkour courses, one per route (16 in total), each ending in a treasure chest that pays coins. Added 2026-11-11. They never block the road: each course runs along the west wall of its lane, outside the wild-spawn area and clear of every route trainer's sight box.

## Files

- `ReplicatedStorage.Shared.CourseConfig`: the one tuning table. Per route: `Id`, `Lane`, `RouteName`, `Theme`, `Difficulty`, `CoinReward`, optional `Cooldown` (default `DefaultCooldown` = 600 s) and `FirstClearBonus` (default = `CoinReward`). `Difficulties` holds the builder tuning (steps, gaps, rise, max height, element weights, spinner/mover/vanish speeds) and `MinSeconds`, the shortest time a real run can take.
- `ServerStorage.ObstacleCourseBuilder`: Edit-only builder for the test place, same conventions as [[MountainLookouts]]'s `MountainPartBuilder`. `plan(id)` prints the placement, `build(id)` creates `Workspace.Obstacles.<RouteName>` only if it is missing, `remove(id)` deletes a course and puts back the decor it moved, `buildAll()`. Run it with `loadstring(game.ServerStorage.ObstacleCourseBuilder.Source)()`; it loads `CourseConfig` from source, because `require` in Edit keeps the first copy for the whole Studio session.
- `ServerScriptService.ObstacleCourses`: server side (runs, resets, chest claims, save section).
- `StarterPlayerScripts.ObstacleCourses`: client looks only (moving parts, chest full/empty state, open effect, start hint).
- `tests/ObstacleCourseTests.luau`: run in Edit; checks the config and every built course (213 checks).

## Placement (read from the place, not hand-picked)

- Lane box from `RegionStyle.laneBox` (falls back to the `Map.Lanes.<Lane>` part, which Meadow needs). The road runs up the lane centre ([[RegionPaths]]).
- Wild creatures spawn anywhere within the lane part's half-width minus 10 (`WildSpawner.spawnInLane`), so a course starts 1 stud outside that and runs out to the first wall or bound (Region 1: `Walls.Divider` at x -64.5 for Meadow, `RoadBound` at -75 after it; Region 2: the `MountainHints` touch parts at x 385–389, which have `CanQuery` off, so the builder checks them by hand).
- Trainers look 26 studs toward the hub across the whole lane (`RouteTrainerService`). The builder blocks each trainer's z from 32 ahead to 16 behind, plus 40 studs after the lane start and 60 before the gym, and uses the longest free stretch (about 126 studs, between each route's first and second trainer).
- Strips under 12.5 studs (Meadow, 7.5) get a single row; wider ones get a switchback, so the chest ends up beside the start sign, high up.
- Decor whose bounds reach into a course is moved, whole, to `ServerStorage.ObstacleDisplacedDecor.<Id>` with an `OriginalParentPath` attribute. Meadow moved 34 items (6 oaks, a flower bed, bushes, a boulder), because both of its walls are lined with oaks.

## Structure of one course

`Workspace.Obstacles.<RouteName>` (Folder, attributes `CourseId`, `Lane`, `RouteName`, `Difficulty`, `FloorY`, `Route`):
- `Start`: `StartPad` (attribute `CourseStart`), `StartSign`, sign posts, `AccessStep`s up from the lane floor when the ground is lower.
- `Path`: platforms (`Hop`, `Stair`, `Climb`, `Beam`, `Rest`, `Landing`, `Turn`, `SpinnerBase`, `HazardRun`), tagged parts (`Mover` = `CourseMover`, `SpinnerBar` = `CourseSpinner`, `Vanish` = `CourseVanish`, `ResetStrip` = `CourseHazard`), non-colliding `Support` posts.
- `Chest` (Model, attribute `CourseChest`): `Base` (PrimaryPart, `ChestPrompt`: hold E / controller X for 1 s), `Lid` + welded `LidBand`, `Coins` (glow, sparkle, `CoinBurst` emitter), `Lock`.
- `CourseBounds`: invisible footprint the server uses for falls.
- `ChestPlatform`, `FlagPole`, `Flag`.

The `Route` attribute lists the landing points in climb order; the test and the walk-test bot use it.

## Rules (server authoritative)

- A run starts when the server sees the player standing on the `StartPad`; its clock starts when they step off.
- Chest claim: the prompt is the only input. The server checks a living character within `PromptDistance` (10) of the chest, not in battle, the route's badge gate (`GameData.canEnter`), the per-player cooldown, an active run for that course and at least `MinSeconds` since leaving the pad. Prompt attempts are rate limited to one per second.
- Pays `CoinReward` through `PlayerData.addCoins` (so the 2x Coins pass doubles it, like other coin rewards), plus `FirstClearBonus` once per player ever. Toast: "Parkour cleared! +N coins".
- Falling below the start pad inside the footprint, or touching a `ResetStrip`, only moves the player back to that course's start pad (never hurts, never costs anything). Both only happen during a run, so nobody walking under a course is moved, and nobody is ever moved between routes.
- A run ends after `RunTimeout` (900 s) or once the player is 24 studs outside the footprint.

## Saving

`SaveService.register("courses", ...)`: `{ v = 1, cleared = { ids }, cooldowns = { id = server time it refills } }`. It is an extra section, so older saves without it load with nothing cleared; no global save version bump was needed. Cooldowns survive a rejoin, and a loaded cooldown is never longer than the configured one.

## Client

One `Heartbeat` loop moves every tagged part from `workspace:GetServerTimeNow()`, so all players see the same timing; movers also set `AssemblyLinearVelocity`, so a player standing on one rides along. Chests read the player attribute `CourseCooldowns` (JSON, set by the server) and show full (coins, glow, sparkle) or empty with "Empty · refills in m:ss" for that player only. The server's `Remotes.CourseChest` event (server to client only) plays the lid, coin burst and the game's level-up sting (`Sfx.play("levelUp")`). Walking within 18 studs of a start pad shows a one-line hint once every 90 s. Chests re-register when their parts stream in.

## Adding a route

Add one `CourseConfig.Courses` entry (and a theme in `ObstacleCourseBuilder.THEMES` if it needs a new look), then run `build("<Id>")` in Edit and `tests/ObstacleCourseTests.luau`.
