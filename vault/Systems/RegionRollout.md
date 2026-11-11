# RegionRollout

`src/ServerStorage/RegionRollout.luau` is the Edit-mode, per-route coordinator for the Phase 2 theming pass.

- `load()` creates a temporary `__RegionFresh` set of cloned `GameData`, `RegionStyle`, `RegionPaths`, and terrain/decor/validation tools, avoiding Studio's ModuleScript require cache.
- `run(lane)` validates data, restores an earlier themed pass when necessary, hides the original lane floor, snapshots/stashes eligible ground, rebuilds terrain, positions trainers and the gym leader, paints the outer material, and recreates route dressing.
- `validate(lane)` combines [[RouteWalker]]'s pass/fail gate with [[RegionPathValidator]]. Run it in a later frame after terrain writes.
- `undo(lane)` removes dressing, restores terrain and moved ground, restores trainer positions, and exposes the original lane floor.

The rollout protects any decor template used by any themed route before stashing old ground. That prevents a later run from burying a template another route needs.

Related: [[RegionStyle]], [[RegionTerrainBuilder]], [[RegionDecorator]], [[RouteWalker]].
