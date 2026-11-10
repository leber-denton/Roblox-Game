# Current Priorities
Backfilled 2026-11-05 from two stale Drive handoff docs ("Creature Quest - To-Do Checklist" and "Needed changes from Claude Code," both dated 2026-11-03), cross-checked against the current repo. Items confirmed already done are left off. Tags: [CODE] Claude Code/editable in src/. [STUDIO] needs Studio open. [DENTON] Denton's decision or Creator Hub work. [TEST] play-test needed.

## Known code gaps
- [CODE] Spectator UI: server can list live Coliseum matches (`BattleService.getPublicBattle`, confirmed merged), but `ColiseumUI` only handles `openShop` — nothing shows the watch list, spectator view, or updates the arena screen despite its "Use WATCH" sign.
- [CODE] Juniper drop-in admin button does nothing (`StoryService.chat` always returns false) — remove or rewire.
- [CODE] Branch sign still hardcoded "Region 2 · Summit Town," nothing updates it at runtime once region names are confirmed.
- [CODE] `MeshIntake` still lives in `src/ServerStorage` — delete from repo too, or Rojo restores it, if it's meant to be gone.
- [CODE] Stale `GameData` comments still describe the old 400-stud layout (lanes are 520) and old region names in places.
- [CODE] Shop audit (`claude/shop-audit.md`) pending Denton's approval, then remove cut items from `GameData.Shop` only (keep definitions in `GameData.Items` so old saves still load).
- [CODE] Paid-creature tradeability: trades currently look creature-only, so Robux *items* probably can't be traded, but creatures obtained via paid Summon Rare might be — needs a decision before the Trade Center ships.
- [DENTON] Product IDs: all still `id = 0` for the 4 passes and dev products — paste real IDs once created on Creator Dashboard.

## Gyms and battle balance
- [CODE] Steel/Dark/Fairy move gaps, Wigglet/Stingle learnsets, Lunaryx move spread — per the Nov 3 doc these were added (Iron Claw, Steel Beam, Umbra Pulse, Pixie Burst all confirmed present in `BattleData.luau`); re-verify learnset levels still make sense.
- [CODE+STUDIO] Confirm Boulder Pass/Tide Coast gym-type swap (Boulder Pass = Ground, Tide Coast = Water) actually landed; re-run `NpcGuard.stamp()` after any NPC move.
- [STUDIO] Gym 1 (Slate, Meadow Gym) floats with rocks around him and the Meadow path doesn't reach the gym base. `ServerStorage.MeadowGymFix` fixes it (dry run first); not yet run on the real place file. The path is `WindingPath` paint from the NPCAnimator world polish, which stops at the end of Lane1.
- [DENTON] Shinies are currently only a gold sparkle — add real color variants (starters/rares first) or stop advertising shiny odds in the Hot Zone copy.

## Retention / launch
- [CODE] 7-day login streak with Apex Ball on day 7 — confirmed built, shows in Quests menu not HUD; decide if it should also show in HUD.
- [CODE] Onboarding analytics funnel (picked starter → first catch → first trainer → tutorial done → first badge) — steps 1-3 confirmed firing in test; confirm 4 and 5.
- [TEST] First catch under 60s and first badge in ~15 min on a brand-new save.

## Map / performance
- [STUDIO] Decoration count still ~9,087 parts; current runtime code moves excess to `ServerStorage.WorldPolishArchive` rather than deleting — confirm that's the intended final approach vs. the checklist's "delete" guidance.
- [TEST] Phone performance pass (creatures run 3,500-4,000 triangles, up to 160 loaded).
- [STUDIO] `buildQuestWorld` (fog, ocean/coastline, gate ridges, solid mountain wall, floor-lettering removal) only renders in Play mode — visually confirm, not yet checked in Edit mode.

## Untested, highest risk first
- [TEST] Trading — highest risk (can duplicate or delete creatures). Test every cancel case.
- [TEST] Coliseum matches and multiplayer saving, 2-3 real players (saving can't be proven in the unpublished test place).
- [TEST] Leave Dungeon prompt (purple portal → E at exit) — flagged as untested/possibly broken on 2026-11-03, re-check it first.

## Post-launch roadmap (already partly built, per Nov 3 audit)
Built: Wild Shift / Hot Zone rotation, both Juniper story arcs. Mostly built: Battle Coliseum, Trade Center. Partly built: map polish. Not built: Dark Tower overhaul (floor banners only), day/night cycle.

## Source docs retired
Archived from Google Drive into this list on 2026-11-05 (see Denton for the live Drive folder state): "Creature Quest - To-Do Checklist," "Needed changes from Claude Code," "Creature Quest - Setup and Plan" (superseded by CLAUDE.md), "Old Skill Details" (superseded by the installed roblox-vibe-pipeline skill), the duplicate `launch-checklist.md`, and `connection-test.md`.
