# RegionTerrainBuilder

`src/ServerStorage/RegionTerrainBuilder.luau`. A Studio tool, run from the command bar in Edit mode. It writes one region's Terrain from [[RegionPaths]].

```lua
local B = require(game.ServerStorage.RegionTerrainBuilder)
B.preview("Lane1")   -- dry run
B.build("Lane1")     -- snapshot, then write ({ stashGround = true } also moves old flat ground parts)
B.restore("Lane1")   -- paste back the newest snapshot
```

## Safety
- Writes only inside `bounds`, from `floorY` up to `clearAbove` (default 110) studs over the road. Everything in that box is replaced.
- Every build first saves the box as a TerrainRegion in `ServerStorage.RegionTerrainBackups` ("Lane1 #n"). `restore` pastes the newest one back and removes it.
- Decor (`path.decor`) standing in the road or verge is shifted to the nearest free spot inside the walls, never deleted. An item is a Model in a decor folder, or a cluster of loose parts closer than `clusterGap` (a flower, a fence run). It prefers sideways moves; items may overlap the outer 60% of others (tree canopies). `preview` lists every move and any item with no free spot. `build` records old positions in the snapshot's `MovedDecor`, and `restore` puts them back.
- Never moves or edits other parts, except with `stashGround`, which moves flat ground slabs lying fully inside the bounds into the snapshot. `restore` puts them back using a `Home` ObjectValue.
- Protection: visible anchored parts in the bounds hold the ground at or below their bottom, then let it rise again at 45° over 12 studs. `preview` lists the parts that hold it down most, which are the ones that would have been buried. These are not protected: `Map.Lanes` (wild spawn zones, which WildSpawner reads), `Map.Bounds`, invisible parts, and flat slabs (Size.Y ≤ 6, footprint ≥ 400, top near the road).
- Refuses to run if `RegionPaths.check` reports data problems.

## Gotchas (learned on the Lane1 build, 2026-11-10)
- Smooth terrain puts the surface about 2 studs (half a voxel) above "bottom of the top voxel + occupancy x 4". The builder writes voxels for `height - SURFACE_OFFSET` (2). Without that, the road came out at 2.4 instead of 0.4.
- Run `validate` as its own command bar command after `build`. Rays cast in the same frame as `WriteVoxels` still see the old terrain.
- Parts centred outside the bounds, or with a bottom more than 4 studs under the road (sunken meshes such as BoulderPass `Hill`, 70 studs deep), are not protected. Protecting them dug a pit to `floorY`.
- Without Rojo, the modules can be loaded as `ServerStorage.RegionTerrainTools` by pasting a loader into the command bar. The loader sets each ModuleScript's `.Source` and points the requires at that folder.

## Status
Lane1 was built on 2026-11-10 in the open playtester place ("Creature Quest: Catch & Battle"), at the owner's request: 78 decor items moved, snapshot `Lane1 #1`. [[RegionPathValidator]] `validate` passed, with 3 warnings for the trainers' existing 2.4-stud float. Phase A1 stays INCOMPLETE until the owner Play tests and confirms.

Later on 2026-11-10 the gym approach (Whisperwood) was repainted by hand to match the meadow, with heights unchanged: LeafyGrass to Grass and Mud to Ground for x ±136, z 568–772, then Rock to Ground inside the walls (x ±60, z 584–772). Snapshot `Lane1 #2` was taken just before, so `restore("Lane1")` undoes both. RegionPaths' Whisperwood zone now has the matching materials, but its `hill` of 19 still makes rock banks on a rebuild.
