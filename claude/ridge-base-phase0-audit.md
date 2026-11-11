# Ridge + base progression — Phase 0 audit

Date: 2026-11-10. Status: owner approved this plan and its Extra Slots/passive-income amendments with “yes do it all.” Implementation and evidence are now in `claude/ridge-base-validation.md`. The audit below preserves the pre-change findings.

## Checkpoint

- Working branch: `overhaul/ridge-base-progression`, stacked at `e679a1793` (Phase 6 UI). Creating this branch did not change the scripts synced by Rojo. Phase 6 remains unapproved in the existing handoff; it is carried forward, not marked closed.
- Connected Studio: `38919e79-bf48-4475-a486-b4c4b8ceeb23`, Edit mode, cloud test place `94034385545160`, universe `10775717161`. Live place `113252540027729` was not accessed.
- Initial tracked worktree was clean. Existing untracked `.agents/`, `AGENTS.md`, both planning briefs, and `scripts/Close-Phase3.ps1` were preserved.
- `selene src tests --display-style quiet`: **0 errors, 66 warnings, 0 parse errors**. Warnings give Selene exit status 1. First sandbox run could not locate the tool home; rerun outside the sandbox produced the baseline above.
- Knowledge lookup: requested `C:\Codex` locations are absent. Used `C:\Claude\Roblox\Docs\vault\Code\{BaseManager,DecorService,DecorData}.md` and current repository vault notes for SaveService/BattleService, plus `C:\Claude\Roblox-Game\graphify-out\graph.json`. Graphify CLI was unavailable; inspected graph seed neighborhoods directly in PowerShell, then confirmed facts in source. Graph relations have unreliable call direction, so they were used for discovery only.
- Graph vocabulary matched: base, manager, decor, service, canopy, expansion, save, capacity, training, badge, battle. Seeds: `BaseManager.serialize()` (L391), `BaseManager.restore()` (L404), `actions.canopy()` (L800). Related source modules: SaveService, DecorService, PlayerData, BattleData.

## Conflicts requiring an explicit decision

1. **Team capacity is already capable of 18.** `BaseManager.recalcCapacity` starts at 6, adds 6 for expansion, then adds 6 for `Pass_ExtraSlots`. `PassService.apply` recalculates after pass activation. The Extra Slots product advertises six more slots (`GameData.GamePasses.ExtraSlots`, currently id 0 in this checkout). Admin tools can set capacity to 60; restore intentionally uses `force = true` to retain every saved creature. A universal 12 cap conflicts with existing entitlement behavior and must never delete overflow creatures. Proposed resolution for review: normal expansion progression caps at 12; preserve the existing Extra Slots entitlement and all saved creatures pending a separate entitlement policy. If the owner wants a universal 12 cap, define what replaces the pass benefit and how overflow teams work first.
2. **Passive coin generation already exists.** `DecorService.incomeRate`, `tick`, and `onLoaded` fill a saved Coin Jar online and for up to eight offline hours at half speed. Coin Fountain, Golden Statue, Starry Fountain, Aurora Tree, and premium Diamond Fountain have generation rates. `BaseLevels` boosts those rates; a product advertises permanent Coin Fountains. This conflicts with a literal active-play-only economy while the brief also says not to change existing income rates. Proposed resolution for review: add no passive sources or multipliers in this build, preserve existing earnings, and make any retirement a separate economy migration with an ownership policy.
3. **Expansion currently has no badge gate.** `Main.server.luau:428` checks ownership, prior unlock, and 500 coins only. Proposed change: require one badge for new purchases; retain all previously purchased expansions regardless of badge count.
4. **Canopy tiers and base decoration levels are separate existing progressions.** Canopy tiers cost 300/1000/2500/5000/9000 coins and share 10/20/30/40/50% battle XP. Decoration levels Small/Medium/Large/Grand/Legendary control decor caps, side wings, and jar bonuses. Preserve both saved progressions; introduce homestead stage alongside them. Do not map decoration level or Canopy tier directly to a homestead stage, delete wings, or charge returning players for already-owned XP sharing.
5. XP Balcony's stage purchase price remains `OWNER_CONFIRMATION_REQUIRED`. Keep stage purchase disabled until confirmed; existing Canopy XP sharing/upgrades remain accessible. Champion Terrace's collection milestone was unspecified. Proposed milestone for review: Champion plus completion of the existing Region 1 Index group, using existing index data rather than a new counter.

## Studio hierarchy and terrain findings

- The ridge is **Workspace.Terrain**, not a grey Part. Twenty terrain-only horizontal rays sampled X = -400/-200/0/200/400 and Y = 10/60/120/200 from Z = -1050 toward the hub. Every ray hit Rock at Z between -481.96 and -479.34: the reverse face is nearly vertical through the whole sampled height. This samples the central face, not its complete outer bounds.
- `Workspace.Map.Bounds.Part` at `(232.5, 200, -232)`, size `(1027, 400, 2)`, is collidable. Preserve it and the terrain screen. Do not turn visual shelves into a way across this boundary.
- Hub portals: `Map.Hub.TradePortal` at `(46, 6.8, -60)` and `Map.Hub.ColiseumPortal` at `(-46, 6.8, -60)`.
- Coliseum: `Map.Coliseum.Arrive` `(0, 1.1, -1130)`; `ExitPortal` `(0, 8, -1086)`.
- Trade: `Map.TradePlaza.Arrive` `(0, 1.2, -1750)`; `ExitPortal` `(0, 8, -1726)`.
- Rojo manages `Map.TradePlazaBeach` and `Map.Coliseum.RomanShell`; leave these generated models in place.
- Captured and visually reviewed Edit views individually: `RidgeAudit_Hub`, `RidgeAudit_Coliseum`, `RidgeAudit_Trade`, `RidgeAudit_Base1`. They confirm a snowy/dark hub face and a flat grey reverse face. These tool captures are visual evidence, **not recoverable place backups**.
- Existing `ServerStorage.Backups` includes Phase2_1135, Phase3_1305 and Phase5_1706. Local `C:\Claude\CQ_NewestSource_TEST.rbxl` is timestamped 13:04:58 and predates the current Phase 5/6 checkpoint. Do not treat it as a current backup.
- Before terrain work: determine the ridge's complete bounds with further probes, copy the affected TerrainRegion and relevant instance attributes into a named backup, and persist a fresh test-place copy using the established Download a Copy workflow. No terrain or Studio content was modified during this audit.

## Base geometry and save contracts

- Eight separate bases: `Workspace.Map.Bases.Base1`–`Base8`. Their floors center at X ±78 and Z -8/66/140/214. Each floor is 90×0.6×38; neighboring rows are 74 studs apart.
- Each has `Floor`, `Pen`, `Creatures`, `Cottage`, `Canopy`, `Expansion`, `Wings`, `Fence`, `Gate`, `SpawnPoint`, `SignAnchor`, `PC`, and `Path`.
- Base1: floor `(-78, 0.3, -8)`; starter Pen 64×0.1×30 at `(-80, 0.65, -8)`; Expansion.ExpFloor 30×0.6×38 at `(-138.5, 0.3, -8)`; Pen2 22×0.1×30 at `(-140, 0.65, -8)`. Expansion retains its barrier, pond, fence and UnlockBoard. Canopy is approximately 16.1×9.5×13 with `Bench` and `CanopySign`.
- Side wings open at decoration levels 3 and 4. Both together widen the main floor to 66 studs. Preserve neighboring-base separation and existing wing entitlements.
- `DecorData` layout version is 2. Saved placement uses mirrored local X/Z relative to Floor, with existing version-1 migration shift -15. Placement ignores height and always builds at Floor height. Elevated buildable decks therefore require a real surface-aware placement contract, not just expanded X/Z bounds. Proposed first pass keeps movable decor pads on ground/terrace-level surfaces compatible with existing saves; raised balcony carries fixed training/trophy presentation unless an additive surface field is implemented and tested.
- `BaseManager.serialize` emits `{team, index, expansion}`. `restore` rebuilds the team and retains overflow via forced adds. `assign` and `release` must reset stage state consistently to prevent a new owner inheriting an old owner's progress.
- SaveService stores `{v, player, base, decor, dungeonFloor, tutorialDone, savedAt, lock, ...registeredSections}` in `SnatchThemAll_Save_v1` at key `u_<UserId>`. It restores PlayerData, then BaseManager, then registered sections (including DecorService). Preserve store name, keys, version and session lock behavior.
- DecorService persists `decor.canopy`, `decor.level`, `decor.placed`, `decor.layout`, `decor.bank`, and related ownership fields. `onLoaded` restores placed decor, applies layout migration and themes, then online/offline training/income behavior.
- Proposed additive field: `base.baseStage` in BaseManager only. Without it, strict legacy expansion true maps to stage 2; otherwise stage 1. Preserve legacy Boolean when serializing and allow only valid finite integer stages. Restore stage before placed decor; keep Canopy tier separate. Fixtures must cover legacy/new/malformed state, repeated restoration into fresh sessions, and overflow preservation.

## Rewards and training integration

- BattleService `grantXP` calculates active creature XP and uses `CanopyShare` for benched creatures, applying existing battle caps. `giveReward` grants coins and trainer XP through PlayerData. Current logs separately report creature XP, shared XP, coins and trainer XP; add a structured summary without granting a second reward.
- PlayerData owns coin spending/grants, trainer XP and BP. ProgressService supplies dailies/quests/Index rewards, TutorialService supplies tutorial rewards, and other gameplay services feed the existing battle/reward hooks. No new reward sources are required.
- DecorService `trainingRates` computes base rate 0.015 level share/minute, up to three dummies at +0.015 each, and up to two matching habitats at +0.02 each. `train` stops at `GameData.BaseTraining.levelCap`, which is three levels below the badge/Champion battle cap (minimum 5). Offline training is half speed for up to eight hours. It cannot earn stars because its cap remains below max level.
- `sync` owns `CanopyLevel` and `CanopyShare`. Retain those attribute names and `decor.canopy`; rename visible strings to XP Balcony and add stage/training details to the Decor public state.
- Decor remotes dispatch server-owned state with a 0.12-second throttle and battle checks. Canopy and expansion prompts check the owner. Keep ownership, affordability, badge/collection gating and action validation server-side; validate prompt proximity for changed purchase paths.
- BP paths include player battles, tournament placement, and an existing timed practice reward. Do not add a BP purchase path or alter these rewards in this build.

## Proposed file/hierarchy implementation plan

1. `src/ServerStorage/CoastalEscarpmentBuilder.luau`: bounded, repeatable Edit tool with terrain backup/restore and read-only report. Work on the arena-facing terrain only, retaining the existing hub mass and collider. Build dark lower rock, warm shelves and sparse upper vegetation; check full bounds and screenshots before accepting. Add gallery references for new reusable props according to AGENTS.md.
2. `src/ReplicatedStorage/Shared/BaseProgressionData.luau`: shared stage names, approved gates, migration normalization, unresolved-price sentinel and next-goal text. No new XP multipliers. Keep old DecorData levels and Canopy tier tables.
3. `BaseManager.luau`: additive stage serialization/restoration, release/assign reset, stage attributes and gated geometry. Capacity behavior follows the owner decision on Extra Slots; forced restore retains all creatures.
4. `DecorService.luau` and `Main.server.luau`: use existing canopy action/state, add stage purchase action and one-badge expansion gate, report training details, refresh boards. XP Balcony stage purchase stays unavailable until the price is set. Existing Canopy benefits continue for returning players.
5. `src/ServerStorage/BaseHomesteadBuilder.luau`: back up all eight bases; add ranch/coastal stage presentation using mirrored Floor coordinates. Preserve floor origins, starter Pen, Pen2, spawn, PC, placement layout and existing wings. Raised deck needs safe access/rails; preserve creature roaming on existing pens. Build and review one reference before applying to all bases.
6. `DecorData.luau` and `DecorUI.client.luau`: compatible placement/surface rules as needed, stage/goal/gate view, active training details and visible XP Balcony terminology. Retain Phase 6 styling.
7. `BattleService.luau` and `BattleUI.client.luau`: structured reward summary from existing grants, with clear distinction between nominal and capped XP and any existing coin boost. Preserve reward tables and existing battle flow.
8. Focused tests for migration/ownership/gates/capacity, old decor placement, retained Canopy tier and training caps. Play in NoSave mode with test fixtures and verify test-store isolation before enabling API access for persistence tests: the current store name is shared and cloud test place alone does not prove separate data. Do not claim a real save/rejoin test from an in-memory fixture.
9. Update handoff, changes report and vault notes with actual tests and Studio changes; commit scoped files only after validation. Preserve all outstanding Phase 4–6 checks; request approval before push/PR/publish.

## Tests still required after implementation

No Play tests were run during this read-only Studio audit. Portal round trips, each stage's visual and collision checks, roaming/placement, new and legacy save fixtures, isolated save/rejoin, reward regression and multiplayer checks remain open. Full terrain backup and saved cloud test-place snapshot remain prerequisites to terrain changes.

The next checkpoint requires approval of this file/hierarchy plan and decisions on Extra Slots and the existing passive-income economy. The implementation brief itself explicitly requires this review before terrain or save-schema edits; the audit does not reinterpret that requirement as approval to change paid benefits.
