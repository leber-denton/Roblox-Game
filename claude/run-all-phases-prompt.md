# Run all phases, skipping what is already done

Paste the block into a fresh Claude Code session in C:\Claude\Roblox-Game.
Known state from claude/handoff.md: Phases 1 and 2 closed, Phase 3 built but its Studio checks open, Phases 4 to 6 not started. The prompt re-checks all of this itself instead of trusting it.

```
Run the full Creature Quest overhaul, Phases 1 to 6, but only do work that is not already done. Follow the creature-quest-dev-pipeline skill, use roblox-dev:roblox-ui for Phase 6 only, run Graphify recall first. I keep my own backups, so make none. Never merge, publish, or touch DataStores, economy or battle logic. One Rojo server only (netstat -ano | findstr 34872). Stacked branches: each phase branches from the previous one.

STEP 0, DETECT (read only, no edits). For each phase run its check, then print a table: phase, evidence, DONE / PARTIAL / TODO. Read claude/handoff.md, claude/changes-report.md, git log and git branch -a for context, but a phase is DONE only if its check passes now.
- P1 audit: claude/audit.md and src/ServerStorage/RouteWalker.luau exist; RouteWalker runs in Edit with no errors.
- P2 regions: ModelSync.audit() and RegionPathValidator report 0 problems in Edit for all 16 routes; no route has mountain terrain over its road (raycast up from each road sample, 60 studs either side); Meadow end and gym leaders are not floating.
- P3 showcase: fresh Edit build gives 99 entries across 15 routes, 0 missing sources; ModelSync.apply refuses reference-only entries; /showcase works for the owner (UserId 1170990981) and gives nothing to others.
- P4 dungeon: GameData.Dungeon.floors has 2.1 to 2.10; Room11 to Room20 exist with StartPad intact; a theme config keyed by tower exists; nothing purple remains (loop over every floor printing theme and palette).
- P5 Trade Center and Coliseum: both fully enclosed, no void visible from inside or from the main island (raycast the horizon from several points), beach theme with day dome and Roman interior with roof.
- P6 UI: every ScreenGui (HUD, Menus, BattleUI, Bag, ColiseumUI, DecorUI, DungeonClient, EventHUD) uses the shared style module, Scale plus constraints, and is checked at phone, tablet and desktop sizes.
Then STOP and wait for me to reply "go" so I can see the table.

STEP 1, EXECUTE only PARTIAL and TODO phases, in order. Fix only the failing parts of a PARTIAL phase. Specs:
- P2 mountains: the side mountains are voxel Terrain. Clear terrain above each route's road surface plus a 45 stud margin (Terrain:FillBlock to Air, scripts/Fix-Mountains.luau is the starting point, dry run first), keep the outer perimeter ridge, then re-verify no voids. Every route in both regions gets Meadows Route's quality (decor, trainer placement, pacing) in its own theme.
- P3: finish the Studio checks listed above, then update /showcase for any changed trainers.
- P4 dungeon: one theme config keyed by tower number (palette, material, accessories). Tower 1 Bone Crypt (grey, bone, moss), Tower 2 Ember Forge (black, orange, red). Floor 10 of each is a darker boss variant with gold trim. Remove the purple look everywhere. Make DungeonNPCStyler theme-driven and keep real R15 avatars with faces and hair. Add floors 2.1 to 2.10 to GameData.Dungeon.floors with stronger teams, keep a final rest entry. Build Room11 to Room20 by cloning a standard room and applying the theme. Keep Room11 StartPad intact (StoryService uses it). Extend ModelSyncLookup to the new rooms. Fix any broken dungeon trainer. Test the lift, battles, leave portal and DungeonClient banners.
- P5: rebuild the look (tools/gen_coliseum.py, tools/gen_trade_beach.py or directly in Studio). Trade Center: beach theme, sun/day dome. Coliseum: roof, Roman colosseum interior. Fully enclosed, themed, proper lighting.
- P6 UI only: restyle with one shared style module, UIListLayout, TweenService, CanvasGroup, pressed/hover/disabled states. No logic changes.

CHECKPOINT after each phase: save state to claude/handoff.md, run selene src tests (baseline 0 errors, 69 warnings), commit and push the branch (no PR), then print the model to use next and "type /clear when you approve". Wait for "approved" before the next phase. Never write a phase complete until its Studio checks have actually run; mark untested checks NOT TESTED.

AT THE END: update "Where to edit things" in claude/launch-checklist.md and the vault notes; update claude/changes-report.md grouped by area (what changed, where to look in Studio or /showcase, which commit undoes it, what you were unsure about; checks as passed, failed or not tested).
```
