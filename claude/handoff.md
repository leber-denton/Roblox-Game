# Overhaul run: handoff

## Ridge/base build checkpoint — 2026-11-10 (Codex)

- Owner approved implementation and the Phase 0 amendment preserving existing Extra Slots and passive-income benefits. Branch `overhaul/ridge-base-progression`, stacked on Phase 6 `e679a1793`.
- Implemented coastal reverse-face terrain, four homestead stage models on eight bases, additive `base.baseStage`, legacy expansion/Canopy compatibility, one-badge + 500-coin new expansion gate, stage/training UI and actual battle reward summaries. No new income/XP multipliers or BP sales. Normal stage capacity remains 6→12; existing Extra Slots still adds six. All old creatures are retained.
- XP Balcony construction cost is deliberately `OWNER_CONFIRMATION_REQUIRED`; stage-3 purchase is disabled. Existing XP-sharing upgrades remain available at original prices. Stage 4 requires Champion and Region 1 collection completion; stages 3/4 were tested with NoSave fixtures.
- Test place 94034385545160 alone now uses `CQ_RidgeBase_TEST_v1`. Other places retain the production store/key/locking behavior. API access remains disabled: **real persistence/rejoin is NOT TESTED**.
- PASSED: 49 pure progression assertions, 16 server module fixture checks, live purchase/badge/price-bypass checks, original Canopy upgrade, live normal/2× coin and bench-XP reward fixtures, training cap/no-stars fixture, both portal round trips, four stage Play visual fixtures, ridge Edit/Play captures, Edit ModelSync audit (0 findings), final Selene **0 errors / 66 warnings / 0 parse errors**.
- Studio recovery: `ServerStorage.Backups.RidgeBase_PreBuild` contains original bases/terrain and 93 tree/bush models moved out of deck footprints. Nothing in that group was permanently deleted. Gallery references and ShowcaseArea rebuilt. File → Download a Copy saved the cloud test place and wrote `C:\Claude\Roblox-Game-zip-backup\CQ_RidgeBase_20261110.rbxl` (10,330,353 bytes at first checkpoint); final recovery-copy evidence is in `claude/ridge-base-validation.md`.
- Remaining: construction price, isolated real save/rejoin, two-player security/trade/PvP, complete climb/exploit and controller/mobile staircase testing. Hub terrain in Play screenshots can be partially unstreamed away from the character; Edit captures and retained boundary are the structural reference.
- Prior Phase 4–6 gaps remain open except the two arena portal round trips now passed here. Do not infer Phase 6 approval or multiplayer trade/PvP coverage.
- Detailed files, source contracts, tests and limitations: `claude/ridge-base-validation.md`, `vault/Systems/BaseProgression.md`. Do not push, open a PR, publish live, or migrate production saves without owner approval.

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
- Local backups: see the Phase 2 closure section above (`C:\Claude\CQ_NewestSource_TEST*.rbxl`, made with File > Download a Copy). Before each phase a folder `ServerStorage.Backups.Phase<N>_<HHMM>` also gets clones of what that phase changes, plus TerrainRegion copies; these persist only if the place is saved. The owner keeps his own backups, so the script does not make one.
- Branches are stacked (each phase from the previous one) because Rojo syncs whatever is checked out into Studio; a branch from bare `main` would roll back earlier phases' scripts in Studio. Base: `fix/meadow-corridor-decor-exempt` (rebased on main, pushed), then `overhaul/p1-audit`, `overhaul/p2-regions`, ...
- MCP `execute_luau` in Edit can't `require` repo modules: use `loadstring(module.Source)()`. On the server in Play, `loadstring` is off; `require` works there. Rojo changes reach Play only after stopping and starting Play.
- StreamingEnabled: Play screenshots far from the character show unstreamed (missing) parts. Use Edit-mode `screen_capture` with a camera position, or move the character first.

## Phase status
- [x] Phase 1 audit: `claude/audit.md`, tool `src/ServerStorage/RouteWalker.luau`. Branch `overhaul/p1-audit`.
- [x] Phase 2 regions: all 16 routes themed, checked and screenshot-reviewed (`claude/region-rollout.md`), branch `overhaul/p2-regions`. Closed 2026-11-10 (canopy exclusion narrowed, gyms and Meadow end verified). Left for Phase 3: vault notes for RegionStyle/RegionRollout/RouteWalker.
- [x] Phase 3 showcase: approved and merged as PR #19 (2026-11-10). Branch `overhaul/p3-showcase`, stacked on `overhaul/p2-regions`. Compact, route-labelled, reference-only Route Decor Sets.
  - PASSED (Edit, fresh build, no injected loader): `ShowcaseBuilder.build()` gives format 2, 99 route-decor entries across 15 routes, 15 row titles, 0 missing sources. Section counts: TRAINERS 9, GYM LEADERS 16, ROUTE TRAINERS 48, DUNGEON TRAINERS 10, NPCS 17, BALLS 20, CREATURES 50, DECORATIONS 10, MAP PROPS 43.
  - PASSED: `ModelSync.audit()` 0 findings; `ModelSync.apply("Mirage Desert: Cactus")` refused ("reference-only gallery model").
  - PASSED: screenshot of the route rows (titles at the west end, sets read left to right).
  - PASSED: `selene src tests` 0 errors, 69 warnings (baseline).
  - NOT TESTED: `/showcase` typed in chat in Play (owner arrives at (-3045, 56, 0); non-owner gets nothing). Automated chat injection was unreliable and was dropped to save time. By code review, `Showcase.server.luau` returns before doing anything when `origin.UserId ~= 1170990981`. To test: Play, type `/showcase`, then `/showcase off`.
  - The rebuilt `Workspace.ShowcaseArea` lives in the place file: save the place in Studio to keep it.
  - Runtime vs Edit audit: they disagree by design, see below.
- [x] Phase 4 dungeon: approved by the owner 2026-11-10 (the NOT TESTED items below are still open). Branch `overhaul/p4-dungeon`, stacked on `overhaul/p3-showcase`. See `vault/Systems/DarkTower.md`.
  - PASSED (Edit): Room1-21 exist; Room11 StartPad intact; all 20 trainers have a visible face and hair; `TowerBuilder.purpleReport()` returns 0; a second `build()` run changes nothing; showcase rebuilt (20 dungeon trainers, 99 route decor); `ModelSync.audit()` 0 findings; Selene 0/69.
  - PASSED (Play, NoSave): hub portal (E) entered floor 1.10; boss battle won; the lift carried the player to Room11 with the banner "EMBER FORGE · FLOOR 2.1"; tint reset after; runtime styling 20/20, faces and hair kept.
  - NOT TESTED: the leave portal and a defeat (testing was stopped there by request); the 3.1 rest-room arrival; the Tower 2 team balance in real play.
  - Fixed after the Play run, not re-run: the lantern-case and pauldron props were a near-black violet, now warm grey.
  - Save the place in Studio to keep Rooms 12-21, the repainted tower and portal, and the fixed trainers.
- [x] Phase 5 Trade Center / Coliseum: approved by owner after the 2026-11-10 checkpoint; branch `overhaul/p5-arenas`, stacked on `overhaul/p4-dungeon`. Visual-only: no trade, Coliseum, economy, or battle logic changed. Its explicit untested items remain recorded below.
  - PASSED (Edit): exactly one `Workspace.Map.Coliseum` and one `RomanShell`; the stale duplicate Roman-shell copies are no longer in the live map. The Roman arena has a three-storey arcade, tiered stands, gallery, braziers, entrance tunnel, cypresses, and an enclosed red-and-cream velarium. The Trade Center has a continuous lagoon shoreline and beach dressing clear of the arrival route, fountain, palms, and stalls. One screenshot was captured and reviewed at a time for Coliseum exterior, Coliseum interior, and Trade Center.
  - PASSED (Play, fresh start): `StadiumShell=0`, `MarketHall=0`, `RomanShell=1`; both `Map.Coliseum` and `Map.TradePlaza` retain `Arrive` and `ExitPortal`; both area models load on the client. This confirms the old runtime wrappers no longer cover the Rojo-synced designs.
  - PASSED: `ModelSync.audit()` 0 findings in Edit (its source was evaluated with an injected `ModelSyncLookup`, because bare `loadstring(ModelSync.Source)()` has no `script.Parent` in the Studio command executor); `selene src tests` 0 errors, 66 warnings (three fewer than the previous 69-warning baseline, because the removed runtime wrapper helpers carried warnings).
  - NOT TESTED: triggering the hub portals and exit prompts end-to-end, a multiplayer trade, or a Coliseum match. The automated character navigator cannot route across the intentionally disconnected arena islands, so it could not substitute for a portal test. Existing Studio console warnings were unrelated Dungeon NPC-guard resets, disabled DataStore API access, and a legacy asset-type mismatch.
  - Save the Studio place to preserve any live-place cleanup of stale Coliseum copies/backups before switching branches.
- [ ] Phase 6 UI: awaiting owner approval after the 2026-11-10 checkpoint; branch `overhaul/p6-ui`, stacked on `overhaul/p5-arenas`. Visual-only: `Shared.UIStyle` is mounted by HUD, Menus, BattleUI, BagUI, ColiseumUI, DecorUI, DungeonUI, and EventHUD; it applies safe-area clipping, text-size constraints, shared button strokes, hover/press/selection feedback, disabled feedback, and future reusable size/list helpers. No remote, callback, input binding, battle, trade, or economy logic changed.
  - PASSED (Play): all eight scoped ScreenGuis reported `UIStyleMounted=true`; every currently-created `GuiButton` in HUD, Menus, Bag, ColiseumUI, and DecorUI reported styled. BattleUI had zero live buttons because no battle was entered.
  - PASSED (screenshots, one at a time): HUD remained visible without clipping on iPhone 17 Pro (874x402 landscape), iPad Pro M5 13in (1376x1032 landscape), and Average Windows (1366x768). Studio Device Simulator was stopped and reset to its default viewport afterwards.
  - PASSED: `selene src tests` 0 errors, 66 existing warnings; no new client UI runtime errors. Existing console warnings remain disabled Studio DataStore API access, Dungeon NPC guard resets, a legacy asset-type mismatch, and the Assistant plugin version warning.
  - NOT TESTED: actual BattleUI action buttons, Coliseum-shop purchase button, Decor build-mode buttons, and UI state changes reached through live gameplay. The fresh-test onboarding cinematic remained active, so its title/letterboxing was not treated as a Phase 6 regression.
- [ ] Final checks, changes-report.md

## Phase 3 audit note: Play vs Edit

`ModelSync.audit()` in a Play server reports 13 findings; in Edit mode it reports 0. The difference is not a bug in the lookup. At runtime gym leaders are renamed and StoryMilestones NPCs are spawned in, so the Play server contains NPCs that have no source in the Edit place, and the static lookup (an Edit-place table) deliberately does not map them. **The Edit-mode audit is the one that counts.** Ignore the Play-time findings unless they name something outside those two groups.

## Decisions so far
- The main cause of the bad look is `NPCAnimator.buildQuestWorld()` (GateBaffles, decor trim, divider spine), which runs at server start. Phase 2 changes it as well as the place.
- Lighting stays one global set (Meadow's). Per-route mood comes from palette, materials and decor.
- Uncommitted "Theming Overhaul" files from the earlier session (`RegionPaths`, `RegionTerrainBuilder`, `RegionPathValidator`, `RegionDecorator`, their vault notes, `tests/RegionPathsTests.luau`, the Meadow trainer z values in GameData) are carried into the phase 2 branch.
