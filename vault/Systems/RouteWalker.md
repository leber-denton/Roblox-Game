# RouteWalker

`src/ServerStorage/RouteWalker.luau` is the read-only road-audit gate for all 16 routes. It samples the actual `RegionPaths` centreline (including gym detours) and reports gaps, jumps, blocked steps, roof/cover, open sightlines, terrain layering, floating/buried NPCs, and dead ends.

- `walk(lane)` collects a route result; `walkAll()` collects every route; `gate(result)` makes the Phase 2 pass/fail decision.
- [[RegionRollout]] injects its fresh `RegionPaths` module with `useRegionPaths`, so validation follows the newly themed route rather than a cached path.
- Its narrow `isGateCanopy` exception accepts only the actual `Map.WorldPolish.RoutePassages.GateCanopy` slab: correct parent, dimensions, height, lane centre, and real gate offset. It continues the ray below the arch. A similarly named part, including `GateRidge`, is not exempt.
- The regression is `tests/RouteWalkerTests.luau`; run it on the server in Play.

Phase 2 closure: all 16 gates passed. Boulder Pass retains the harmless validator warning that `Map.GlimmerCavern` is not a model; its keep-clear box remains enforced.

Related: [[RegionRollout]], [[RegionPathValidator]], [[RegionStyle]].
