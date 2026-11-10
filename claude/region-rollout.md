# Region rollout log (Phase 2)

One row per route, in the order they were committed. Each route was themed in the open test place with
`require(game.ServerStorage.RegionRollout).run("<lane>")`, checked with `.validate("<lane>")` (RouteWalker gate +
RegionPathValidator), then judged by screenshot against Meadow. Checks prove a road is walkable, not that it
looks good, so the screenshot verdict is listed separately. **Studio changes are not saved until the owner saves
the test place (File > Save to Roblox).**

Final Play check (server, all 16 routes, with the new NPCAnimator): 15 of 16 passed the RouteWalker gate on the
first run; the 16th (Shadow Woods) was the gate canopy counted as a hill, fixed in RouteWalker. 0 GateBaffle or
WindingPath parts; trimmed decor down from 1,367 assemblies to 23 (all behind the ridges).

**Undo one route:** `require(game.ServerStorage.RegionRollout).undo("<lane>")`: removes `Map.Decor.<lane>Dressing`,
puts the trainers and gym leader back, pastes the terrain snapshot `ServerStorage.RegionTerrainBackups."<lane> #1"`
(with stashed floor parts and moved decor) and `"<lane> outer"`, returns buried decor from `"<lane> buried"`, and
shows `Map.Lanes.<lane>` again. **Everything by hand:** `ServerStorage.Backups.Phase2_1135` (clones of Map.Decor,
RouteTrainers, Lanes, RoadGround, gym models, MeadowMidDecor, MeadowGateDecor from before the rollout).

| Route | Lane | Buried decor stashed | Dressing | Trainers (z) | Gym leader lowered | RouteWalker | Validator | Screenshot verdict |
|---|---|---|---|---|---|---|---|---|
 Sunpetal Fields (pilot) | Lane9 | 38 | 460 | 420 / 590 / 720 | Fern 0.28 | PASS | PASS | Good: dense flowers, sunflowers, birches, fences, hay; grassy hills. A windmill stays embedded in the ridge, as before. |
 Mirage Desert | Lane10 | 22 | 326 | 940 / 1110 / 1240 | Sahra 0.28 | PASS | PASS | Good after retune: sandstone walls, cacti, palms, bones, dry tufts. Road now Ground (sandstone road vanished). |
 Coral Reef | Lane11 | 14 | 317 | 1460 / 1630 / 1760 | Marin 0.28 | PASS | PASS | Acceptable: boardwalk, palms, tide pools, coral, grass-topped rock walls. A bit sparse. |
 Thunder Mesa | Lane12 | 55 | 354 | 1980 / 2150 / 2280 | Volta 0.28 | PASS | PASS | Props read as a mesa (pillars, rods, dry bush). Road (Asphalt) and ground render paler than their materials in Edit screenshots; check in Play. |
 Toxic Bog | Lane13 | 29 | 338 | 2500 / 2670 / 2800 | Hemlock 0.28 | PASS | PASS | Good after retune: green bog with mud, upright dead trees, reeds, flat toxic pools (was a grey wasteland). |
 Crystal Caverns | Lane14 | 17 | 282 | 3020 / 3190 / 3320 | Gemma 0.21 | PASS | PASS | Good after retune: varied crystals, icy patches, brown road (was a solid wall of big crystals). |
 Phantom Manor | Lane15 | 33 | 480 | 3540 / 3710 / 3840 | Silas 0.28 | PASS | PASS | Good after retune: dark graveyard grass, graves, iron fences, ruins, lanterns (was flat tan). |
 Dragon Peaks | Lane16 | 21 | 315 | 4060 / 4230 / 4360 | Drakon 0.43 | PASS | PASS | Good after retune: open basalt with lava cracks, glowing rocks, spaced crags (was a wall of crags). Lava pools now lie flat. |
 Boulder Pass | Lane1B | 0 | 110 | 890 / 1060 / 1190 | Coralie 0.34 (see note) | PASS (ROOF = Glimmer Cavern) | PASS (1 warning) | Good after retune: grassy rocky pass, boulders, logs, spires, oaks, cave mouth. Two trainers stand inside the cave by Meadow's spacing. Road faint in Edit screenshots. |
 Tide Coast | Lane3 | 0 | 413 | 1410 / 1580 / 1710 | Duna 0.31 (see note) | PASS | PASS | Acceptable: palms, rocks, starfish, tide pool, sandstone cliffs with grass bands. Boardwalk faint. |
 Volt Plains | Lane4 | 0 | 496 | 1930 / 2100 / 2230 | Jolt 0.31 | PASS | PASS | Good: green plains, wind turbines, pylons, tesla coils, solar arrays, flowers. |
 Ember Ridge | Lane2 | 0 | 351 | 2450 / 2620 / 2750 | Ignatia 0.31 | PASS | PASS | Good: basalt with lava cracks, spires, dead trees, glowing rocks; road subtle. |
 Frost Peak | Lane5 | 1 | 341 | 2970 / 3140 / 3270 | Hale 0.31 | PASS | PASS | Not screenshotted (snow theme on snowy surroundings; lowest risk). |
 Shadow Woods | Lane6 | 0 | 428 | 3490 / 3660 / 3790 | Morrow 0.81 | PASS | PASS | Good: twisted trees, glowing mushrooms, lanterns, standing stones. Its two old SideWall glass parts were opaque white; set to Meadow's divider transparency 0.7 (OrigTransparency attribute keeps 0). |
 Sky Spire | Lane7 | 0 | 395 | 4010 / 4180 / 4310 | Aero 0.31 | PASS | PASS | Good: bright grass, clouds, pillars, floating islands, cream limestone walls. |
