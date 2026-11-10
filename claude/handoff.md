# Overhaul run: handoff

Resume notes for the world/dungeon/UI overhaul started 2026-11-10. Update after each phase.

## Continuation verification (2026-11-10; supersedes environment claims below)

- Status: **INCOMPLETE**. Phase 2 runtime ray checks passed, but the local place backup and remaining validation gates are unresolved. Phases 3–6 have not started.
- Working checkout: `C:\Users\Leber\OneDrive\Documents\ChatGPT\Pokemon game`; branch `overhaul/p2-verification`, based on Phase 2 `0d5a58deaa8af1ba6ee010fc880b7d43cb976eb5`. Latest fetched main reference: `04ad1249ed22d6c3154230e5dcbaa333d77af4f9`. Future phase branches must retain Phase 2 and branch from their predecessor. No branches were reset or recreated.
- Original checkout located at `C:\Claude\Roblox-Game`, on `overhaul/p2-regions` at the same Phase 2 commit. Its untracked `.agents/` and `AGENTS.md` were preserved. The vault and graph are actually at `C:\Claude\Roblox` and `C:\Claude\Roblox-Game\graphify-out\graph.json`; the supplied `C:\Codex` paths are stale.
- Verified Studio bridge: `38919e79-bf48-4475-a486-b4c4b8ceeb23`, test place `94034385545160`, named `LilDiesel468's Place: 11102026_1`. Studio is now in Edit mode.
- Rojo 7.7.1 started from PowerShell with `rojo serve default.project.json --address 127.0.0.1 --port 34872` in the working checkout. Terminal session `28467`; server PID observed `20996`. Verified an established TCP connection from `RobloxStudioBeta.exe` PID `16016` to port 34872. Restart from this checkout if the process ends. Do not start a competing server from the original checkout.
- Owner confirmed saving after the previous session. This continuation did not save or publish. No `.rbxl`/`.rbxlx` exists in the searched `C:\Claude` tree, workspace/parent, Documents, Desktop, or Downloads. **Backup: NOT TESTED / unavailable.** A cloud save and in-place clones do not satisfy the required local `.rbxl` backup. Obtain the actual local file, save the verified test place locally, then copy it beside itself with unique phase/timestamp and verify nonzero size before implementation.
- No source or unmanaged Edit-place changes were made by this continuation. Temporary Play changes were character teleports, hidden tutorial/story overlays, camera positioning, and test access attributes; the playtest has ended. The attempted unsupported `fireproximityprompt` call failed without triggering a battle.
- Required development skills `creature-quest-dev-pipeline` and `roblox-dev:roblox-ui` were not found in available skills or searched project skill folders. Their workflows have not run. The graphify skill was read; the original supplied graph path was absent. Query the newly located graph before further source investigation.
- Resume: first resolve the local backup. Then finish Meadow's ending screenshot, repeat gym interactions with isolated NoSave test data and the existing tutorial/admin test controls, and narrow/test RouteWalker's gate-arch cover exclusion. Update audit/rollout evidence, save locally, and commit Phase 2 closure before branching Phase 3. Do not use a numeric RouteWalker pass alone to declare the full gate passed.

## Environment facts
- Studio has the cloud test place "LilDiesel468's Place: 11102026_1" (placeId 94034385545160) open; Rojo (`rojo serve`, 7.7.1) syncs into it. The live game (113252540027729) is never touched.
- `CQ_NewestSource_TEST.rbxl` does not exist on disk, and the owner declined Studio control for "Save to File As". **Backups are in-place**: before each phase a folder `ServerStorage.Backups.Phase<N>_<HHMM>` gets clones of what that phase changes, plus TerrainRegion copies. These only persist if the owner saves the place (File > Save to Roblox). Nothing in this run saves or publishes the place.
- Branches are stacked (each phase from the previous one) because Rojo syncs whatever is checked out into Studio; a branch from bare `main` would roll back earlier phases' scripts in Studio. Base: `fix/meadow-corridor-decor-exempt` (rebased on main, pushed), then `overhaul/p1-audit`, `overhaul/p2-regions`, ...
- MCP `execute_luau` in Edit can't `require` repo modules: use `loadstring(module.Source)()`. On the server in Play, `loadstring` is off; `require` works there. Rojo changes reach Play only after stopping and starting Play.
- StreamingEnabled: Play screenshots far from the character show unstreamed (missing) parts. Use Edit-mode `screen_capture` with a camera position, or move the character first.

## Phase status
- [x] Phase 1 audit: `claude/audit.md`, tool `src/ServerStorage/RouteWalker.luau`. Branch `overhaul/p1-audit`.
- [x] Phase 2 regions: all 16 routes themed, checked and screenshot-reviewed (`claude/region-rollout.md`), branch `overhaul/p2-regions`. Studio NOT saved yet. Left: vault notes for RegionStyle/RegionRollout/RouteWalker.
- [ ] Phase 3 showcase
- [ ] Phase 4 dungeon
- [ ] Phase 5 Trade Center / Coliseum
- [ ] Phase 6 UI
- [ ] Final checks, changes-report.md

## Decisions so far
- The main cause of the bad look is `NPCAnimator.buildQuestWorld()` (GateBaffles, decor trim, divider spine), which runs at server start. Phase 2 changes it as well as the place.
- Lighting stays one global set (Meadow's). Per-route mood comes from palette, materials and decor.
- Uncommitted "Theming Overhaul" files from the earlier session (`RegionPaths`, `RegionTerrainBuilder`, `RegionPathValidator`, `RegionDecorator`, their vault notes, `tests/RegionPathsTests.luau`, the Meadow trainer z values in GameData) are carried into the phase 2 branch.
