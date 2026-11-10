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
