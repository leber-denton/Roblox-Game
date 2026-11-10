# RegionPathValidator

`src/ServerStorage/RegionPathValidator.luau`. A read-only Studio tool, run from the command bar in Edit mode.

- `recon("Lane1")`: surveys the place where a region goes. It prints `Map` children, the `Map.Lanes` spawn zone parts, the gym box, the trainer models, ground height along the centerline and across three depths, existing terrain in the write box, and the parts in the bounds, grouped as protected or slab. Run it before filling in the RECON values in [[RegionPaths]].
- `validate("Lane1")`: after a [[RegionTerrainBuilder]] build. It prints PASS/WARN/FAIL lines for each check and a `RESULT` line:
  - data
  - road (16-stud width at road height, 10 studs of clearance above)
  - slope (along and across)
  - verge
  - trainers (feet on the ground, not buried)
  - keepClear (no terrain in the gym box)
  - boundary (ridge line ≥ `minWall` over the road, except the road cut)
  - connect (road height matches just past both ends)
  - spawns (WildSpawner's spawn maths, then the ray `Wander.groundAt` uses)

The walkability rays use `RespectCanCollide`. The spawn rays copy `Wander.groundAt`'s ignore list (`Map.Decor`, `Map.Bounds`, creatures).

Data-only tests: `tests/RegionPathsTests.luau`.
