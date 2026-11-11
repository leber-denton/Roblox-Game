# RegionStyle

`src/ReplicatedStorage/Shared/RegionStyle.luau` is the data source for the Phase 2 route themes. It defines the shared Meadow-derived `spec`, two region geometries, and one `lanes` theme per non-Meadow route.

- A theme carries route identity/order, deterministic seed, gym location, material palette, terrain settings, and decor rules.
- `laneBox(laneKey)` converts a theme into its world-space lane bounds; `trainerSpot(laneKey, index)` returns the three Meadow-spaced trainer positions.
- [[RegionPaths]] consumes this data to make the paths used by [[RegionTerrainBuilder]], [[RegionDecorator]], and [[RegionPathValidator]].
- Each decor rule names an existing `Workspace.Map.Decor` template. [[ModelSyncLookup]] derives the read-only Route Decor Sets showcase section from those rules, so do not duplicate that list by hand.

## Edit workflow

Change a theme, then use [[RegionRollout]] `run(lane)` in Edit mode. Studio caches module requires, so loaders that need fresh data must not rely on a plain `require` in Edit mode. [[ModelSyncLookup]] handles this by compiling the current `RegionStyle.Source` with `loadstring` in Edit mode (and using `require` in Play, where `loadstring` is off and the module cannot have changed). [[RegionRollout]] uses a cloned module set instead.

Related: [[RegionRollout]], [[RegionDecorator]], [[ShowcaseBuilder]].
