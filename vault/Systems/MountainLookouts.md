# Mountain Lookouts

Region 2's mountains, the Region 1 / Region 2 divider, the hub's east ridge and the coastal escarpment are editable Part models (owner decision 2026-11-10, rebuilt 2026-11-11). The old terrain trails are gone.

## Part-built mountains

Each mountain is its own Model at `Workspace.Map.Mountains.<Group>.Mountain_<Name>`, built from plain Parts and WedgeParts (no unions, no terrain). Its PrimaryPart is `MountainPivot`, an invisible part at the base of the lane-facing cliff. Move or scale the whole Model and the trail, prompts and collision all move with it.

Sub-folders:
- `Cliff`: rock bands (`Band`, `Tier<k>`), grass caps (`*Cap`), sloped faces and sides (`Face`, `Side` WedgeParts), `Boulder`s.
- `Paths`: ramps (`Ramp<k>`), turning landings (`Landing<k>`), fences, timber supports, the `EntranceSign`. `Order` attributes give the climb order.
- `Lookouts`: one `Lookout<i>Deck` Model per deck. The marker is the brass stand `Lookout<i>`.
- `Summit`: summit deck, cairn, flag, crags. The marker is `SummitMarker`.
- `Decor`: part-built pines. Decor is non-collidable.

Markers are visible parts with attribute `MountainMarker` = `"Summit"` or `"Lookout"`. Drag a marker to move its prompt.

Model attributes (edit in Studio; prompts update live):
- `MountainName`, `RouteName`, `Lane` (gates the prompt by that route's badges; omit for no gate)
- `SummitName`, `SummitPrompt` (action text), `SummitMessage`
- `LookoutPrompt`, and per marker `Lookout<i>Name`, `Lookout<i>Message`
- `PromptDistance` (optional, default 10)

`ServerScriptService.MountainLookouts` finds every marker under `Map.Mountains`, adds a `MountainPrompt` (E / controller X / touch) and reads all text from those attributes. The server checks a living character, distance, battle state, a 3 s cooldown and the route's badge gate. Prompts only show a message. They grant no coins, XP, BP, items or saved progress.

`ServerStorage.MountainPartBuilder` is an Edit-only tool for the test place `94034385545160`. `clearTerrain(name)` removes the terrain in a spec's box; east trail mountains also get a flat floor in the lane's own material (`ClearTerrain.GroundMaterial`) in front of the cliff. `build(name)` creates the Model only if it is missing, so it never overwrites manual edits. To regenerate a mountain from source, delete the Model first. Run it with `loadstring(game.ServerStorage.MountainPartBuilder.Source)()` in the command bar. Decor that clipped into a new cliff is moved, whole, to `ServerStorage.MountainDisplacedDecor.<Mountain>` with an `OriginalParentPath` attribute.

Trail layout: eight 36-stud terraces, 30 studs deep, in an exact zone (|a| ≤ 90 along the range). Ramps are 12 wide, rise 36 over 80 (24°), alternate direction, and lean on the terrace face. Each one ends in a fenced 12×12 landing that opens onto the next terrace.

Spec options (in `Builder.Specs`): `Palette` (Meadow, Desert, Reef, Mesa, Bog, Crystal, Manor, Dragon, Boulder, Volt, Ember, Alpine, Sky, Coast; `Tree` picks the ledge decor: pines, cacti, coral, crystals, mushrooms or dead trees), `Back = { Palette, Drop }` builds a second, mirrored face `2 * Depth` further in (two-faced ridges), `JoinEnds = { Low, High }` runs an end flat into the next mountain instead of sloping to a saddle, `Advance` sets how far each band steps back (smaller = steeper). Scenery faces sit at least 32 studs inside the nearest lane wall, because band fronts and their sloped faces can reach that far in front of `Origin`.

## Mountain list

All 20 models, 9,412 parts in total (counted 2026-11-11). Every trail was walk-tested lane → summit with a real Humanoid; prompts and badge gate verified with real E presses.

| Model | Where | Trail | Faces |
| --- | --- | --- | --- |
| `Region2.Mountain_SunpetalFields` (Sunpetal Crag) | East of Lane9, x 562–896, z 300–820 | Windmill Ledge, Falcon Rest, summit | Meadow |
| `Region2.Mountain_MirageDesert` (Mirage Butte) | East of Lane10, z 820–1340 | Dune Watch, Vulture Perch, summit | Desert |
| `Region2.Mountain_CoralReef` (Shellback Bluff) | East of Lane11, z 1340–1860 | Tidepool Ledge, Gull Point, summit | Reef |
| `Region2.Mountain_ThunderMesa` (Stormcap Mesa) | East of Lane12, z 1860–2380 | Red Rock Shelf, Lightning Ledge, summit | Mesa |
| `Region2.Mountain_ToxicBog` (Mirebrow Hill) | East of Lane13, z 2380–2900 | Spore Shelf, Fogwatch, summit | Bog |
| `Region2.Mountain_CrystalCaverns` (Glimmerspire) | East of Lane14, z 2900–3420 | Frost Ledge, Prism Point, summit | Crystal |
| `Region2.Mountain_PhantomManor` (Gloomcrest) | East of Lane15, z 3420–3940 | Raven Ledge, Lantern Watch, summit | Manor |
| `Region2.Mountain_DragonPeaks` (Wyrmspine) | East of Lane16, z 3940–4460 | Ember Ledge, Wyrm's Rest, summit | Dragon |
| `Divider.Mountain_Divider1`–`7` | Between Region 1 (RoadBound x 76) and Region 2 (ArmBound x 384), one per lane pair, z 820–4460 | No (a climb would cross regions) | West: Boulder, Reef, Volt, Ember, Alpine, Manor, Sky. East: that route's Region 2 palette |
| `Divider.Mountain_Divider8` | Victory Road stretch, z 4460–4700 | No | Alpine / Dragon |
| `Hub.Mountain_HubEastRidge` | East of the hub and Summit Town (ArmBound x 746), x 780–980, z -290–300 | No | Alpine |
| `Coast.Mountain_CoastWest` / `CoastCentre` / `CoastEast` | South of the hub, x -520–980, z -615 to -285 | No | Hub side Alpine, sea side Coast (sandstone) |

Left as terrain: the low foothills between Meadow Route and Sunpetal Fields (z 300–820, under 60 studs), the foothill strip between the hub and the escarpment (z -276 to -250), and the hub's west arm (x < -520). `Map.CoastalEscarpment` is now an empty marker (`ReplacedBy` attribute); its six rim trees are in `ServerStorage.MountainDisplacedDecor.Mountain_Coast`, and `CoastalEscarpmentBuilder` (it arrives with the ridge-base work, not yet on `main`) must refuse `build()` while `Map.Mountains.Coast` exists; add that guard when it lands. Don't run its `restore()`: it pastes the old terrain back over the part ridge.

## Old terrain trails (removed)

`ServerStorage.RegionTwoMountainBuilder` built eight out-and-back boardwalk trails on the terrain east mountains (`Map.MountainTrails.Lane9`–`Lane16`), opening low windows in the x = 536 bound. All eight were deleted when their part mountains were built; `Map.MountainTrails` is empty and `MountainLookouts` no longer reads it. Its `restore()` predates the part mountains, so don't run it. Route separators (`Map.Bounds.MountainRouteBound*`, `TrailSideBound`, `TrailWindowTop`, `MountainOuterBound`) stay in place for the part mountains; they keep each excursion inside its own route.

See `claude/region2-mountain-validation.md` for the earlier terrain-trail verification.
