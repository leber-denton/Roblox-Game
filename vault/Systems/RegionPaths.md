# RegionPaths

`src/ReplicatedStorage/Shared/RegionPaths.luau`. Theming Overhaul Phase A1 (Meadow Route pilot, 2026-11-10). Data for each region's road and land shape, plus pure geometry helpers. Only `Lane1` (Meadow Route) is filled in so far.

## What's in a region entry
- `waypoints`: road centerline `{x, y, z}`, where `y` is the walkable road surface. It runs `shoulder` studs past the south and north `bounds` edges, so the cut through the ridge is clean.
- `corridorWidth` 16, `buffer` 12 (the flat verge where route trainers stand), `shoulder` 20 (where the verge blends up into the hills), `maxSlopeDeg` 10.
- `bounds`: the box the [[RegionTerrainBuilder]] owns. For Lane1 that's x -136..136: the corridor plus 71 studs of mountain outside each glass wall. The Region 1/2 range starts at x ~170.
- `groundParts`: the old ground (`Baseplate`, `Map.RoadGround`, `Map.Walkway`). These are never protected, or the land would be flattened to their bottoms (the Baseplate is 16 studs thick). `avoidY` and `protectSink` keep terrain from sitting level with the y 0 baseplate, where it would flicker.
- `decor`: decor in the road or verge is shifted aside by the builder.
- `keepClear`: boxes held flat at their own `floorY` (the gym).
- `trainerIds`: looked up in `GameData.RouteTrainers`, not copied, so the two can't drift.
- `zones`: theme bands by depth (0 = south edge, 1 = north edge), matching the wild spawn bands in `GameData.Lanes`. Neighbouring zones blend their land over `zoneBlend`, because each zone has its own noise scale and would otherwise leave a seam.
- `boundary`: a ridge rising along the `sides` edges, fading over `endTaper` at the region's ends. For Lane1 that's west and east only, outside the glass walls. The walls, the invisible `Bounds` caps and the gate close the corridor itself.

## Height model (`heightAt`)
The distance `d` to the nearest road point picks the band: road, then verge (both flat at road height minus `surfaceSink`), then shoulder (blend), then wild (`max(rolling hills, ridge)`). Keep-clear boxes are blended to their floor last. `materialAt` picks the surface material: road, then peak above `peakAbove`, then cliff above `cliffSlopeDeg`, then zone accent patches, then zone ground.

## Lane1 facts (read-only recon, 2026-11-10)
- Corridor 130 studs wide: `Walls.Divider` glass plus `Bounds.DividerCap` at x +-65, z 250-770. North end: `Gates.Gate_Lane1B` (ForceField, z 770). South end: `Map.Walkway` (top 0.4).
- Ground: `Workspace.Baseplate` (top 0, to z 695), then `RoadGround.LaneGround.Ground_Lane1`. There was no terrain and no road.
- The gym (x -19..19, z 734-767) blocks x=0, so the road swings east to x=40 around it and back to x=0 behind the gate.
- Decor stood on the centreline: fences, a boulder and the dense Whisperwood (27 oaks, z 598-748). The owner chose to shift it aside.
- The trainer models' lowest part is 2.8 studs above the ground. That was there before the terrain; the validator warns about it.

## Gotchas
- Players can climb any terrain (Humanoid MaxSlopeAngle), so the ridge is a visual boundary like the old range with `MountainHints`, not a hard wall.

Related: [[RegionTerrainBuilder]], [[RegionPathValidator]], [[Architecture Map]].
