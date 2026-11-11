# Paste into a fresh Claude Code session in C:\Claude\Roblox-Game

```
Resume the Creature Quest overhaul. Read claude/handoff.md and claude/changes-report.md, run Graphify recall, and follow the creature-quest-dev-pipeline skill. Phase 3 must be ticked first (Close-Phase3.ps1 -TickPhase3). I keep my own backups, so skip the backup step. Branch phase 4 from overhaul/p3-showcase, then each later phase from its predecessor. Never merge, publish, or touch DataStores, economy or battle logic. Rojo serves this checkout; keep one server only.

PHASE 4 DUNGEON. One theme config keyed by tower number (palette, material, accessories). Tower 1 Bone Crypt (grey, bone, moss). Tower 2 Ember Forge (black, orange, red). Floor 10 of each is a darker boss variant with gold trim. Remove the purple look everywhere. Make DungeonNPCStyler theme-driven and keep real R15 avatars with faces and hair. Add floors 2.1 to 2.10 to GameData.Dungeon.floors with stronger teams, keep a final rest entry. Build Room11 to Room20 by cloning a standard room and applying the theme. Keep Room11 StartPad intact (StoryService uses it). Extend ModelSyncLookup to the new rooms and rebuild /showcase. Fix any broken dungeon trainer. Test the lift, battles, leave portal and DungeonClient banners. Finish with a loop printing every floor, its theme and palette, flagging anything still purple.

PHASE 5 TRADE CENTER and BATTLE COLISEUM. Rebuild the look (tools/gen_coliseum.py, tools/gen_trade_beach.py or directly in Studio). Trade Center: beach theme with a sun/day dome. Coliseum: roof and a Roman colosseum interior. Both fully enclosed, no void visible from inside or from the main island, proper lighting.

PHASE 6 UI ONLY, using the roblox-dev:roblox-ui skill. Restyle every ScreenGui (HUD, Menus, BattleUI, Bag, ColiseumUI, DecorUI, DungeonClient, EventHUD): Scale plus constraints, UIListLayout, TweenService, CanvasGroup, pressed/hover/disabled states, one shared style module. Check phone, tablet and desktop emulator sizes. No logic changes.

CHECKPOINTS: after each phase stop, save state to claude/handoff.md, run selene src tests (baseline 0 errors, 69 warnings), commit and push the branch, and print: the model to use next, and "type /clear when you approve". Do not continue until I reply "approved".

AT THE END: update "Where to edit things" in claude/launch-checklist.md and the vault notes, and extend claude/changes-report.md grouped by area. For each change: what changed, where to look in Studio or /showcase, which commit undoes it, what you were unsure about. Mark checks passed, failed or not tested. Never write "complete" for a phase until its Studio checks are done.
```
