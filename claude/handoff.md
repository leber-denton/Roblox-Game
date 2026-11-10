# Overhaul run: handoff

Resume notes for the world/dungeon/UI overhaul started 2026-11-10. Update after each phase.

## Environment facts
- Studio has the cloud test place "LilDiesel468's Place: 11102026_1" (placeId 94034385545160) open; Rojo (`rojo serve`, 7.7.1) syncs into it. The live game (113252540027729) is never touched.
- `CQ_NewestSource_TEST.rbxl` does not exist on disk, and the owner declined Studio control for "Save to File As". **Backups are in-place**: before each phase a folder `ServerStorage.Backups.Phase<N>_<HHMM>` gets clones of what that phase changes, plus TerrainRegion copies. These only persist if the owner saves the place (File > Save to Roblox). Nothing in this run saves or publishes the place.
- Branches are stacked (each phase from the previous one) because Rojo syncs whatever is checked out into Studio; a branch from bare `main` would roll back earlier phases' scripts in Studio. Base: `fix/meadow-corridor-decor-exempt` (rebased on main, pushed), then `overhaul/p1-audit`, `overhaul/p2-regions`, ...
- MCP `execute_luau` in Edit can't `require` repo modules: use `loadstring(module.Source)()`. On the server in Play, `loadstring` is off; `require` works there. Rojo changes reach Play only after stopping and starting Play.
- StreamingEnabled: Play screenshots far from the character show unstreamed (missing) parts. Use Edit-mode `screen_capture` with a camera position, or move the character first.

## Phase status
- [x] Phase 1 audit: `claude/audit.md`, tool `src/ServerStorage/RouteWalker.luau`. Branch `overhaul/p1-audit`.
- [ ] Phase 2 regions
- [ ] Phase 3 showcase
- [ ] Phase 4 dungeon
- [ ] Phase 5 Trade Center / Coliseum
- [ ] Phase 6 UI
- [ ] Final checks, changes-report.md

## Decisions so far
- The main cause of the bad look is `NPCAnimator.buildQuestWorld()` (GateBaffles, decor trim, divider spine), which runs at server start. Phase 2 changes it as well as the place.
- Lighting stays one global set (Meadow's). Per-route mood comes from palette, materials and decor.
- Uncommitted "Theming Overhaul" files from the earlier session (`RegionPaths`, `RegionTerrainBuilder`, `RegionPathValidator`, `RegionDecorator`, their vault notes, `tests/RegionPathsTests.luau`, the Meadow trainer z values in GameData) are carried into the phase 2 branch.
