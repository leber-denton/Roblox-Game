# Overhaul run: handoff

Resume notes for the world/dungeon/UI overhaul started 2026-11-10. Update after each phase.

## Obstacle courses — 2026-11-11 (Claude)

- One optional parkour course per route (16), each ending in a coin chest. New: `ReplicatedStorage.Shared.CourseConfig` (the only tuning table: reward, cooldown, first-clear bonus, difficulty tuning), `ServerStorage.ObstacleCourseBuilder` (Edit-only, test place, builds missing courses into `Workspace.Obstacles.<RouteName>`), `ServerScriptService.ObstacleCourses` (runs, fall/strip resets, chest claims, `SaveService` section "courses"), `StarterPlayerScripts.ObstacleCourses` (moving parts, per-player chest state, open effect, start hint), `tests/ObstacleCourseTests.luau`. Note: `vault/Systems/ObstacleCourses.md`.
- Placement is computed: west wall strip of each lane, outside the wild-spawn x range, clear of trainer sight boxes, the lane start and the gym. Region 1 courses at x -56 to -74 (Meadow -56 to -64, single row); Region 2 at x 390–404.
- Rewards: Meadow 100, Boulder 125, Tide 150, Volt 200, Ember 250, Frost 300, Shadow 350, Sky 400, Sunpetal 450, Mirage 500, Coral 550, Thunder 600, Bog 650, Crystal 700, Manor 750, Dragon 800; 10-minute cooldown; first-clear bonus = reward. Easy: Meadow, Boulder, Tide. Medium: Volt, Ember, Frost. Hard: Shadow, Sky, Sunpetal, Mirage, Coral. Expert: Thunder, Bog, Crystal, Manor, Dragon.
- Decor moved (whole, with `OriginalParentPath`) to `ServerStorage.ObstacleDisplacedDecor.<Id>`: 189 items in total, Meadow 34 (6 oaks, a flower bed, bushes, a boulder). `ObstacleCourseBuilder.remove(id)` puts them back.
- PASSED (Play, NoSave):
  - Real-Humanoid walks start → chest: Meadow, Boulder Pass, Tide Coast (all 17 landings each).
  - Real E presses: Meadow paid 100 + 100 bonus (50 → 250); Tide paid 150 + 150; second press → "empty, refills in 9:18"; no run → refused; claim 1 s after leaving the pad → refused.
  - Fall into the footprint during a run → back on the pad. Reset strip → back on the pad. On the ground under a course without a run → not moved.
  - Client: movers, spinners and vanishing platforms animate from the server clock; a player standing on a mover rides it exactly; the claimed chest shows empty with a timer while others stay full; the lid opens; start hint toast.
  - `tests/ObstacleCourseTests.luau` in Edit: 213 checks, 0 failed. Selene: 0 errors / 66 warnings (baseline).
- NOT TESTED: the server-side bot can't time moving platforms (they only move on clients), so Medium+ courses weren't walked end to end by a bot (a human needs to); real save/rejoin of the "courses" section (Studio API access is off); mobile/controller prompt feel; two players on one course.
- Save the place in Studio to keep the courses.

## Part-built mountains — done 2026-11-11 (Claude)

- All 20 mountain models are Parts (9,412 parts): 8 east trail mountains `Map.Mountains.Region2.*`, divider `Map.Mountains.Divider.Mountain_Divider1`–`8` (two-faced, each face themed to the lane it faces), `Map.Mountains.Hub.Mountain_HubEastRidge`, coast `Map.Mountains.Coast.Mountain_CoastWest/Centre/East` (hub face Alpine, sea face sandstone). Terrain in those boxes was cleared (no backup, per the owner). All eight `Map.MountainTrails` trails are deleted; `MountainLookouts` lost its legacy branch.
- Builder additions: 13 more palettes and themed ledge decor (cacti, coral, crystals, mushrooms, dead trees), `Back` (mirrored far face), `JoinEnds`, `Advance`, generic `clearTerrain` with the lane's floor material. The `Map.CoastalEscarpment` marker folder is kept (empty, `ReplacedBy` attribute). `CoastalEscarpmentBuilder` is not on `main` yet (it comes with the unpushed ridge-base commit); once it lands, add the guard from `overhaul/region2-mountain-trails` fb27322c3 so `build()` refuses while `Map.Mountains.Coast` exists.
- PASSED: all 8 trails walked lane → summit with a real Humanoid; prompts on all 24 markers carry the right text; real E presses on Wyrmspine: badge gate refused, then the summit message once Champion. Screenshots of every new mountain from its lane, the divider from both regions, the corner from the hub and the coast from the hub and the sea, all against Meadow / Sunpetal. Selene at baseline.
- Left as terrain: the low hills between Meadow and Sunpetal (z 300–820, under 60 studs), the foothill strip between the hub and the coast (z -276 to -250), the hub's west arm (x < -520). The divider is now one continuous ridge; the old terrain one was described as having see-through valleys (`JoinEnds = false` on a segment gives a saddle instead).
- Save the place in Studio to keep them.


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
- [ ] Phase 5 Trade Center / Coliseum: awaiting owner approval after the 2026-11-10 checkpoint; branch `overhaul/p5-arenas`, stacked on `overhaul/p4-dungeon`. Visual-only: no trade, Coliseum, economy, or battle logic changed.
  - PASSED (Edit): exactly one `Workspace.Map.Coliseum` and one `RomanShell`; the stale duplicate Roman-shell copies are no longer in the live map. The Roman arena has a three-storey arcade, tiered stands, gallery, braziers, entrance tunnel, cypresses, and an enclosed red-and-cream velarium. The Trade Center has a continuous lagoon shoreline and beach dressing clear of the arrival route, fountain, palms, and stalls. One screenshot was captured and reviewed at a time for Coliseum exterior, Coliseum interior, and Trade Center.
  - PASSED (Play, fresh start): `StadiumShell=0`, `MarketHall=0`, `RomanShell=1`; both `Map.Coliseum` and `Map.TradePlaza` retain `Arrive` and `ExitPortal`; both area models load on the client. This confirms the old runtime wrappers no longer cover the Rojo-synced designs.
  - PASSED: `ModelSync.audit()` 0 findings in Edit (its source was evaluated with an injected `ModelSyncLookup`, because bare `loadstring(ModelSync.Source)()` has no `script.Parent` in the Studio command executor); `selene src tests` 0 errors, 66 warnings (three fewer than the previous 69-warning baseline, because the removed runtime wrapper helpers carried warnings).
  - NOT TESTED: triggering the hub portals and exit prompts end-to-end, a multiplayer trade, or a Coliseum match. The automated character navigator cannot route across the intentionally disconnected arena islands, so it could not substitute for a portal test. Existing Studio console warnings were unrelated Dungeon NPC-guard resets, disabled DataStore API access, and a legacy asset-type mismatch.
  - Save the Studio place to preserve any live-place cleanup of stale Coliseum copies/backups before switching branches.
- [ ] Phase 6 UI
- [ ] Final checks, changes-report.md

## Phase 3 audit note: Play vs Edit

`ModelSync.audit()` in a Play server reports 13 findings; in Edit mode it reports 0. The difference is not a bug in the lookup. At runtime gym leaders are renamed and StoryMilestones NPCs are spawned in, so the Play server contains NPCs that have no source in the Edit place, and the static lookup (an Edit-place table) deliberately does not map them. **The Edit-mode audit is the one that counts.** Ignore the Play-time findings unless they name something outside those two groups.

## Decisions so far
- The main cause of the bad look is `NPCAnimator.buildQuestWorld()` (GateBaffles, decor trim, divider spine), which runs at server start. Phase 2 changes it as well as the place.
- Lighting stays one global set (Meadow's). Per-route mood comes from palette, materials and decor.
- Uncommitted "Theming Overhaul" files from the earlier session (`RegionPaths`, `RegionTerrainBuilder`, `RegionPathValidator`, `RegionDecorator`, their vault notes, `tests/RegionPathsTests.luau`, the Meadow trainer z values in GameData) are carried into the phase 2 branch.
