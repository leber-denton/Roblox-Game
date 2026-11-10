# RegionDecorator

`src/ServerStorage/RegionDecorator.luau`. A Studio tool, run from the command bar in Edit mode after [[RegionTerrainBuilder]] `build`.

- `placeTrainers(lane)`: moves each route trainer model to its `GameData.RouteTrainers` x/z, with its lowest part on the terrain. It also stamps `HomePos` so NpcGuard keeps it there. The first original pivot and HomePos are saved in `ServerStorage.RegionTerrainBackups."<lane> trainers"`.
- `dress(lane)`: places the `RegionPaths.<lane>.dressing` rules into `Map.Decor.<dressing.folder>`, replacing any earlier pass. Clones of existing decor keep their names, so ModelSync still finds them. Fences are built from the `Fence` folder's Post and Rail parts. A spot is skipped if it lands on the road, near a trainer or the gym, outside the walls, or on other decor.
- `preview(lane)` is a dry run. `undo(lane)` removes the dressing folder and puts the trainers back.

## Gotchas
- Studio's command bar keeps modules it has already required. After Rojo syncs a change, require a clone: `require(game.ServerStorage.RegionDecorator:Clone())`. For new GameData, call `D.useGameData(require(game.ReplicatedStorage.Shared.GameData:Clone()))`. The validator's trainer check can still show the old data spots as WARN in that same session.
- The trainer models' lowest part sat 2.4 studs above the ground. The whole rig was high: R15, HipHeight 2.19, HRP pivot at y 6. `placeTrainers` sets it at ground + (pivot - lowest point).

## Lane1 (2026-11-10)
- Trainers moved from z 590/650/705, bunched by the gym, to 370 (meadow), 540 (edge of Whisperwood) and 670 (deep woods). GameData data z values are now 250/420/550, plus RoadOffsets +120.
- 66 dressing items: 20 fence runs, 17 flower bushes, 6 meadow oaks, 4 boulders, 5 avenue oaks, 12 glow mushrooms, 2 gateway boulders.

## Gym approach (2026-11-10)
- `Map.MeadowGateDecor` (outside `Map.Decor`, like `Map.MeadowMidDecor`) continues the meadow look past depth 0.6: 5 fence runs, 6 flower bushes, 3 boulders, 126 flowers (stem + petals cloned from MeadowMidDecor). It was placed by a one-off script, not `dress()`, so re-running `dress` leaves it alone. Delete the folder to undo it.
- Overlap gotcha: each OakTree is one mesh inside a nested `body` model, so its bounding box covers the whole canopy down to the ground. The one-off script treated only a 3.5-stud radius around each trunk as taken. `spotFree` still blocks the whole canopy, so `dress` puts almost nothing under the Whisperwood oaks.

Related: [[RegionPaths]], [[RegionPathValidator]].
