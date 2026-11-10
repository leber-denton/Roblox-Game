# World audit (Phase 1, 2026-11-10)

Read only. Place: the cloud test place "LilDiesel468's Place: 11102026_1" (placeId 94034385545160), which Rojo syncs into. `CQ_NewestSource_TEST.rbxl` does not exist on disk (see `claude/handoff.md`).

Tool: `ServerStorage.RouteWalker` (new, `src/ServerStorage/RouteWalker.luau`). It walks each road in 4-stud steps, casting each ray down from just above the last foothold (so tunnels and arches don't confuse it), and reports gaps, height jumps, blocked steps, terrain or roofs over the road, hills inside the corridor, eye-level sightlines to the world edge or the other region, ground layering, and floating or buried NPCs. Run it in Play on the server (`require(game.ServerStorage.RouteWalker)`), because `NPCAnimator` changes the world when the server starts (below).

## The main finding: Edit mode and Play differ

`ServerScriptService.NPCAnimator` → `buildQuestWorld()` runs on every server start and builds `Map.WorldPolish`:

- **GateBaffle**: two slabs, 68 x 74 x 14 studs, across the road 38 and 78 studs past every gate except Meadow's, with a `RidgeCrest` on top. A straight walk is blocked twice per route (RouteWalker: BLOCKED at gate+34..+74 on all 15 routes). A painted `WindingPath` zig-zags round them. These are the "mountains blocking the road".
- **trim()**: archives decor into `ServerStorage.WorldPolishArchive` on every route except the Meadow corridor: anything within 25 studs of the road centre, plus everything in 116 of every 174 studs. 1,367 assemblies are removed in each Play session. This is why Meadow is the only route that looks dressed in Play.
- **GateRidge** (150 x 82 x 27 slabs at x ±140) and **GateCanopy** (130 x 14 x 28, 82 studs up) at every gate, **MountainDivider** (`SolidMountainSpine` 100 x 180 x 4,550 at x 257 plus 30 `SnowRidge` wedges), a terrain water ring, coastal cliffs, and the lighting (fog 600–1500, atmosphere).
- Also `StadiumShell` round the Coliseum and `MarketHall` round the Trade Plaza.

Fixing the look means changing `buildQuestWorld` as well as the place: Edit-mode work alone is undone by trim() and hidden by the baffles in Play.

## Road walk per route (Play, server)

| Route | Lane | Road base y | Road surface | Findings |
|---|---|---|---|---|
| Meadow Route | Lane1 | 0.4 | Terrain Ground (road), Grass | Clean walk. Slate floats 3.0 studs above the gym floor. |
| Boulder Pass | Lane1B | 0.5 | Grass, Ground, Rock, Cobblestone | GateBaffle blocks z 804–844. Rock plateau (`Decor.BoulderPass` cave, 28 studs) covers the whole lane z 920–1190; the road runs through the `CaveRoof` tunnel (intended: Glimmer Cavern). `House` (Brook Town) stands in the straight line at z 1236. |
| Tide Coast | Lane3 | 0.4 | Sand part | GateBaffle blocks z 1324–1364. |
| Volt Plains | Lane4 | 0.4 | Grass, Ground parts | GateBaffle blocks z 1844–1884. |
| Ember Ridge | Lane2 | 0.4 | Basalt, Slate parts | GateBaffle blocks z 2364–2404. In Edit a `ShadowTree` and a Plastic block stand in the gym bypass at z 2804–2820. |
| Frost Peak | Lane5 | 0.4 | Ice, Snow parts | GateBaffle blocks z 2884–2924. |
| Shadow Woods | Lane6 | 1.0 | Grass, Ground parts | GateBaffle blocks z 3404–3444. Road 0.6 higher than its neighbours (part ground at 0.8 vs 0.2). |
| Sky Spire | Lane7 | 0.4 | Marble, Salt parts | GateBaffle blocks z 3924–3964. |
| Sunpetal Fields | Lane9 | 1.0 | Grass part | GateBaffle z 334–374. Three trainers float 0.7–0.8. 40 decor items fully inside the terrain cliffs. |
| Mirage Desert | Lane10 | 1.0 | Sand part | GateBaffle. Trainers float 0.7–0.8. 22 decor buried. |
| Coral Reef | Lane11 | 1.0 | Sand part | GateBaffle. Trainers float. 16 decor buried. |
| Thunder Mesa | Lane12 | 1.0 | Sandstone part | GateBaffle. Trainers float. 56 decor buried. |
| Toxic Bog | Lane13 | 1.0 | Mud part | GateBaffle. Trainers float. 39 decor buried. |
| Crystal Caverns | Lane14 | 1.0 | Slate part | GateBaffle. Trainers float. 22 decor buried. |
| Phantom Manor | Lane15 | 1.0 | Ground part | GateBaffle. Trainers float. 42 decor buried. |
| Dragon Peaks | Lane16 | 1.0 | Basalt part | GateBaffle. Trainers float. 24 decor buried. |

- No gaps or voids under any road, and no dead ends once the baffles are walked round. Height jumps: none on the walked line apart from the baffles.
- Eye-level sightlines (1.8 m, slightly down) found no world edge and no other region from the roads. From higher up (y 84, e.g. on a RidgeCrest) you see Region 2 from Region 1 and the reverse: the MountainDivider and terrain range are lower than the gate structures.

### Mountains and ground layers (Edit screenshots + rays)

- **Every route except Meadow is a canyon.** Terrain cliffs (Rock with Snow tops) rise straight up at the 130-stud lane edges, on beach, desert, reef and lava routes alike. At their foot runs a brown band of terrain Ground/Mud that doesn't match the lane's ground part (Sand, Grass, Basalt...). Snow peaks over a beach is the clearest theme mismatch.
- The lane floors are flat ground parts (Sand, Grass, Mud...) over the Baseplate, with a 12-stud dirt stripe for a road. Meadow is the only route on terrain, with a shaped road, verge and hills.
- **Region 2 decor is buried**: 261 decor items are fully inside the terrain cliffs (Sunpetal 40, Mirage 22, Coral 16, Thunder Mesa 56, Toxic Bog 39, Crystal 22, Phantom Manor 42, Dragon Peaks 24), and a windmill and trees stick out of the cliff faces. Region 1 has none buried.
- Meadow: 45 flower parts are under terrain (small hill clipping).

### Floating NPCs

- Gym leaders: only **Slate (Meadow) floats, by 3.0 studs**. The other 15 are within 0.6 studs.
- Region 2 route trainers (24): all float 0.7–0.8 studs. Region 1 route trainers: grounded.
- Data drift: route trainer model `s9c` has `TrainerId = r1a`, `s10b` has `r6c`, `s10c` has `r7a`. The model name, not the attribute, matches GameData. Not changed (battle data is off limits); noted for the owner.

## StyleSpec (measured from Meadow Route, in Play)

Lane: 520 studs long, 130 wide (glass dividers at ±65).

- **Road**: 16 studs wide, terrain Ground, flat; flat verge of 12 studs each side at road height (trainers stand on it); a 20-stud shoulder blends up into rolling hills (max slope 10° along the road). The road swings 40 studs east round the gym and back.
- **Ground**: terrain Grass with LeafyGrass patches (accent above noise 0.62); Ground patches in the middle and the woods. Three depth zones: Meadow (0–0.35), Middle stretch (0.35–0.65), Whisperwood (0.65–1).
- **Decor density per 100 studs of road** (inside the 130-wide lane): trees 13.7 (oaks), flower bushes 14.2, single flowers 95, mushrooms 5.2, fence runs 4.8, boulders and rocks 6.5, picnic blankets 3.1. About 150 items per 100 studs in all, counting each flower once.
- **Spacing off the road centre**: nothing within 8 studs (the road); 8–16 studs: fences (9.5) and mushrooms (10.5) only; most items 16–50 studs out (bushes 22, boulders 28, avenue trees 34, oaks 38); a quarter beyond 50. No decor within 9 studs of a trainer.
- **Lighting** (global, set by NPCAnimator): ClockTime 13.5, Brightness 2.5, Ambient and OutdoorAmbient (70,70,70), fog 600–1500 colour (164,191,204), Atmosphere density 0.28, haze 2.1, Bloom 1/24/2, SunRays 0.01, ColorCorrection saturation +0.15. One lighting set for the whole map.
- **Trainers**: three per route at depth 0.23, 0.56 and 0.81 (z0 + 120, +290, +420), standing on the verge at x +14, −14, +14 (6 studs off the road edge), facing south toward the hub. The first stands in open meadow, the second at the zone change, the third deep in the last zone before the gym. Everywhere else they're bunched at depth 0.65–0.88 (offsets 340/400/455).
- **Boundary**: hills rise outside the verge and a ridge runs behind the glass walls, so the walls never look like the edge.

## What's wrong with the end of Meadow Route

Screenshot from (10, 25, 640) toward the gym:
1. The boundary ridge tapers away at the north end (`endTaper`), so past the gym you see flat beach, the sea and Region 1 roofs: the void-like horizon the rest of Meadow hides.
2. The Boulder Pass gate banner (`Lane1BSign` text, "BOULDER PASS ... Gym B...") shows right behind the gym roof and overlaps it.
3. Slate floats 3.0 studs above the gym floor.
4. The road stops at the gym door; there is no path round the gym to the gate at z 770, so it reads as a dead end even though you can walk round.
5. GateCanopy (82 studs up) over z 764–768 in Play.

## Other areas (current state)

- **Trade Center**: `Map.TradePlaza` (737 parts, box x −86..86, z −1961..−1639, 405 Metal, 9 purple parts, 10 neon, 9 lights), wrapped in Play by `WorldPolish.MarketHall` (sandstone walls, wood roof, painted-sky windows). `Map.TradePlazaBeach` (540 parts) is Rojo-synced from `src/Workspace/TradePlazaBeach.model.json`; one of its parts spans x ±9,216 (a sea or ground plane).
- **Battle Coliseum**: three `Map.Coliseum` folders. #1 is the real one (843 parts: seats, banners, ArenaFloor, ArenaMaster, ExitPortal, its own RomanShell). #2 and #3 each hold only another `RomanShell` (657 parts, the same box): the Rojo mapping `Map.Coliseum.RomanShell` created extra folders, so three shells overlap and z-fight. In Play, `WorldPolish.StadiumShell` adds a 36-panel wall and a flat sky ceiling at y 94.
- **Dungeon** (`Map.DungeonTower`, x 0, z −3255): Room1–Room11 stacked 24 studs apart (y 0 to 260), 46 x 46 each, 62–74 parts per room, with 34–55 purple parts and 19–32 neon parts each. Room11 is a half-built rest room (34 parts, 30 purple). 34 Battlements, a Beacon, TowerGround, TowerBound1–4.
- **Showcase** (`Workspace.ShowcaseArea`, x −3121..−2046): TRAINERS 11, GYM LEADERS 18, ROUTE TRAINERS 50, DUNGEON TRAINERS 12, NPCS 19, BALLS 22, CREATURES 52, DECORATIONS 12, MAP PROPS 45. 306 purple parts (dungeon trainers).
- **Duplicates in ServerStorage**: two `ModelSync`, two `ModelSyncLookup`, two `ShowcaseBuilder` and a `ShowcaseBuilder_stale_7301`. Which copy `require` finds is not defined.

## ScreenGuis (client, Play, 1274 x 497 viewport)

| ScreenGui | Objects | Offset-sized | Buttons | Layouts | Constraints | Notes |
|---|---|---|---|---|---|---|
| HUD | 19 | 11 | 5 | 3 | 3 | Mostly fixed pixel sizes |
| Menus | 73 | 16 | 16 | 11 | 7 | |
| BattleUI | 24 | 4 | 0 at rest | 4 | 1 | Buttons are built per battle |
| BagUI | 8 | 2 | 2 | 1 | 1 | Content built when opened |
| ColiseumUI | 6 | 2 | 1 | 1 | 1 | |
| DecorUI | 27 | 6 | 10 | 2 | 2 | |
| DungeonUI | 0 | | | | | Banners built on demand |
| EventHUD | 6 | 6 | 0 | 2 | 0 | All pixel sizes |
| CreatureIndexUI, StoryUI, TutorialUI, MusicUI, AdminUI | 1–51 | | | | | Not in the restyle list |

No ScreenGui uses CanvasGroup, and there is no shared style module: each client script sets its own colours, fonts and corner radii.
