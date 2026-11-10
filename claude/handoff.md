# Overhaul run: handoff

Resume notes for the world/dungeon/UI overhaul started 2026-11-10. Update after each phase.

## Phase 2 closure (2026-11-10, Claude; supersedes Codex's verification notes and the environment claims below)

- Status: Phase 2 **closed**, every gate PASSED (details in `claude/changes-report.md`). Phases 3-6 not started.
- Working checkout: `C:\Claude\Roblox-Game`, branch `overhaul/p2-regions` (Codex's docs commit `72b49bfb2` fast-forwarded in; the Codex checkout under OneDrive is no longer used). Later phases branch from their predecessor, never from bare `main`.
- Rojo 7.7.1 serves **this** checkout: `rojo serve default.project.json --address 127.0.0.1 --port 34872`. Codex's server (PIDs 19816/20996) was stopped first; Studio (test place `94034385545160`) reconnected by itself. Check with `netstat -ano | findstr 34872` before editing; never run two servers.
- Local place file: `C:\Claude\CQ_NewestSource_TEST.rbxl`, made with Studio **File > Download a Copy** (there is no "Save to File As" for a cloud place). Download a Copy first saves the test place to Roblox (a cloud save of the test place, not a publish), then writes the file. Phase backups are timestamped copies beside it: `CQ_NewestSource_TEST.<Phase>_<yyyymmdd-hhmm>.rbxl`. First one: `...Phase2-closure_20261110-1254.rbxl` (9,828,766 bytes, hash-matched).
- Gym test recipe (Play): on the client call `Remotes.Admin:InvokeServer` with `saving {on=false}`, `finishTutorial`, `allBadges`, `champion`; check `NoSave == true` on the server; tap through the Professor Maple dialogue (Return); stand 6 studs from the leader and hold E for about a second. Leave a battle with `Remotes.BattleAction:FireServer("run")`. Simulated mouse clicks on BattleUI buttons did not register.
- Skills: `anthropic-skills:creature-quest-dev-pipeline` exists and was followed; `roblox-dev:roblox-ui` exists and is for Phase 6.

## Environment facts
- Studio has the cloud test place "LilDiesel468's Place: 11102026_1" (placeId 94034385545160) open; Rojo (`rojo serve`, 7.7.1) syncs into it. The live game (113252540027729) is never touched.
- `CQ_NewestSource_TEST.rbxl` does not exist on disk, and the owner declined Studio control for "Save to File As". **Backups are in-place**: before each phase a folder `ServerStorage.Backups.Phase<N>_<HHMM>` gets clones of what that phase changes, plus TerrainRegion copies. These only persist if the owner saves the place (File > Save to Roblox). Nothing in this run saves or publishes the place.
- Branches are stacked (each phase from the previous one) because Rojo syncs whatever is checked out into Studio; a branch from bare `main` would roll back earlier phases' scripts in Studio. Base: `fix/meadow-corridor-decor-exempt` (rebased on main, pushed), then `overhaul/p1-audit`, `overhaul/p2-regions`, ...
- MCP `execute_luau` in Edit can't `require` repo modules: use `loadstring(module.Source)()`. On the server in Play, `loadstring` is off; `require` works there. Rojo changes reach Play only after stopping and starting Play.
- StreamingEnabled: Play screenshots far from the character show unstreamed (missing) parts. Use Edit-mode `screen_capture` with a camera position, or move the character first.

## Phase status
- [x] Phase 1 audit: `claude/audit.md`, tool `src/ServerStorage/RouteWalker.luau`. Branch `overhaul/p1-audit`.
- [x] Phase 2 regions: all 16 routes themed, checked and screenshot-reviewed (`claude/region-rollout.md`), branch `overhaul/p2-regions`. Closed 2026-11-10 (canopy exclusion narrowed, gyms and Meadow end verified). Left for Phase 3: vault notes for RegionStyle/RegionRollout/RouteWalker.
- [ ] Phase 3 showcase
- [ ] Phase 4 dungeon
- [ ] Phase 5 Trade Center / Coliseum
- [ ] Phase 6 UI
- [ ] Final checks, changes-report.md

## Decisions so far
- The main cause of the bad look is `NPCAnimator.buildQuestWorld()` (GateBaffles, decor trim, divider spine), which runs at server start. Phase 2 changes it as well as the place.
- Lighting stays one global set (Meadow's). Per-route mood comes from palette, materials and decor.
- Uncommitted "Theming Overhaul" files from the earlier session (`RegionPaths`, `RegionTerrainBuilder`, `RegionPathValidator`, `RegionDecorator`, their vault notes, `tests/RegionPathsTests.luau`, the Meadow trainer z values in GameData) are carried into the phase 2 branch.
