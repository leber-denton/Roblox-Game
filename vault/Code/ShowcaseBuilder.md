# ShowcaseBuilder
`src/ServerStorage/ShowcaseBuilder.luau` · module · ServerStorage · 276 lines

## Requires
- [[ModelSyncLookup]]

## Required by
- [[ModelSync]]
- [[Showcase]]

## Functions
- `resolve(path)`
- `firstPropCopy(name, rootPath)`
- `sourceOf(name, e)`
- `galleryTrainers(list)`
- `categories()`
- `mkPart(parent, name, size, cf, color)`
- `label(parent, text, adornee, offsetY, big)`
- `extents(inst)`
- `prepare(clone)`
- `ShowcaseBuilder.build()`
- `ShowcaseBuilder.arrivalCFrame()`

## Phase 3: route decor sets

`ROUTE DECOR SETS` is a reference-only category supplied by [[ModelSyncLookup]]. It has one labelled, packed row per themed route, ordered by region and route order. The builder derives the rows from `Lookup.ROUTE_ORDER` and `Lookup.ROUTE_SETS`; it does not maintain a second decor list. Each model is packed by its own bounds, wrapping only after 420 studs, so small props remain visible beside large landmarks.

In Edit mode [[ModelSyncLookup]] compiles the current `RegionStyle.Source`, so a rebuild after a theme change sees the new themes instead of Studio's cached module. The intended validation is: build (no missing), fresh Edit-mode `ModelSync.audit()` (zero problems), then build again for repeatability. Route sets reject `ModelSync.apply()` because every entry is `reference = true`.

The audit run in a Play server reports extra findings (13 when last checked) because gym leaders are renamed at runtime and StoryMilestones NPCs spawn in, and neither exists in the Edit place. The Edit-mode audit is the one that counts.

Related: [[RegionStyle]], [[RegionRollout]], [[ModelSyncLookup]].

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
