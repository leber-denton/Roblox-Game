# Region rollout log (Phase 2)

One entry per route, newest last. Each route was themed in the open test place with
`require(game.ServerStorage.RegionRollout).run("<lane>")` and checked with `.validate("<lane>")`
(RouteWalker gate + RegionPathValidator). Studio changes are not saved to the place until the owner saves.

**Undo one route:** `require(game.ServerStorage.RegionRollout).undo("<lane>")`. It removes
`Map.Decor.<lane>Dressing`, puts the route trainers and gym leader back, pastes the terrain snapshot
`ServerStorage.RegionTerrainBackups."<lane> #1"` (with the stashed floor parts and moved decor), returns the
buried decor from `"<lane> buried"`, and shows `Map.Lanes.<lane>` again.
**Undo everything from Phase 2 by hand:** `ServerStorage.Backups.Phase2_1135` holds clones of Map.Decor,
RouteTrainers, Lanes, RoadGround, the gym models, MeadowMidDecor and MeadowGateDecor from before the rollout.

| Route | Lane | Buried decor stashed | Dressing placed | Trainers (z) | Gym leader | RouteWalker | Validator |
|---|---|---|---|---|---|---|---|
| Sunpetal Fields (pilot) | Lane9 | 38 | 482 | 420 / 590 / 720 | Fern -0.28 | PASS | PASS (0 fails) |
