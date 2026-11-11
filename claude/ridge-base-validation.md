# Ridge/base implementation validation — 2026-11-10

Owner approved Phase 0 and explicitly preserved Extra Slots and existing passive-income benefits. Branch `overhaul/ridge-base-progression`, stacked on Phase 6 `e679a1793`. This is a test-place implementation checkpoint, not production publication approval.

## Implemented

- Additive `baseStage` migration with legacy expansion Boolean preserved; Canopy tier and decoration level remain separate, with old prices/rules intact.
- Four stage models on all eight bases. Stage 3 moves the existing Canopy onto a raised coastal balcony; stage 4 adds a fenced trophy terrace and ground-level buildable area. Stair rails and passage gates are stage-aware. Existing Floor origins, Pen/Pen2, cottage, PC, spawn, wings and placement layout version are retained.
- Habitat Garden purchases: one badge + 500 coins; old purchases are grandfathered. Normal stage growth stops at 12 creatures; existing Extra Slots remains an exception up to 18. Overflow creatures are never discarded.
- XP Balcony construction purchase stays disabled while its price is `OWNER_CONFIRMATION_REQUIRED`. Existing Canopy XP-share purchases remain accessible. Champion Terrace uses Champion + all nine Region 1 Index groups.
- Base UI and boards show current stage, next goal, gate, bench share, training rate/bonus sources/status, badge cap and next practical goal. Endgame guidance points to battles for final levels/stars.
- Battle summary reports actual active/bench XP gained after caps, trainer XP and actual coins after existing boosts. No second reward grant.
- Natural layered coastal terrain over the ridge's reverse face, with dark lower rock, sandstone shelves, rocky/green upper ledges and six sparse rim trees. Existing hub-facing terrain mass, collidable boundary, arrival positions and generated arena assets remain.
- Isolated save store `CQ_RidgeBase_TEST_v1` for the exact cloud test place; all other places retain the production store name.

## Passed

- Pure Studio fixtures: **49 assertions** in `tests/BaseProgressionTests.luau`: old/new/malformed save stages, repeated normalization, badge/price/Champion/collection gates, old and new decoration bounds, training caps, original Canopy costs/shares.
- Server module fixture: **16 checks** for legacy stage-2 restore/cap 12, Extra Slots cap 18, all four stage serializations and capacities, closed/open deck collision, Canopy relocation, terrace passage and assign/release reset. These are module fixtures, not proof of persistence.
- Live client/server remote path: a no-badge stage purchase failed without spending; an eight-badge fixture bought Habitat Garden for exactly 500 coins; client-supplied stage/cost arguments did not bypass the unapproved stage-3 price. Original first Canopy upgrade succeeded at 10% share.
- Two actual trainer battle fixtures in NoSave mode, driven through BattleAction: normal summary reported 7/7 active XP, 0 bench XP (share rounded down), 31 trainer XP, 34 coins. Boosted fixture reported 71/71 active XP, 7 bench XP, 31 trainer XP, 68 coins with 2× Coins. The 34/68 values follow the unchanged trainer coin multiplier.
- Live training fixture: 1,000 minutes of simulated training stopped the creature at the zero-badge training cap and awarded no stars.
- Hub → Trade → hub and hub → Coliseum → hub via actual E prompts. The first Coliseum return attempt failed with UI interference; after closing test overlays/repositioning at the exit, the round trip passed. No portal source logic changed.
- Edit screenshots reviewed individually for the hub, Trade and Coliseum ridge faces, base layout and complete stage preview. Play screenshot reviewed for the Base tab and full Champion fixture. Early Play visual captures were obscured by tutorial/trade overlays and were not accepted as terrain visual proof.
- Final Edit `ModelSync.audit()` returned no findings after rebuilding ShowcaseArea with both new gallery references.
- Final fresh Play captures: Starter Yard, Habitat Garden, XP Balcony and Champion Terrace reviewed individually using actual runtime stage fixtures. Trade-facing, Coliseum-facing and hub-facing ridge captures also taken individually; distant hub terrain can be unstreamed, so Edit captures remain the reference for complete terrain coverage.
- Final lint: **0 errors / 66 warnings / 0 parse errors**, identical to baseline. A new local shadow warning was corrected before the final run.

## Recovery and Studio-only content

- `ServerStorage.Backups.RidgeBase_PreBuild` holds eight original base models, the original southern terrain region and 93 intersecting surroundings models moved out of new deck footprints. An early grass fill crossed the terrain backup edge by a small strip; that strip's material was corrected and the final terrain builder tightened to stay within the backed-up region, then rebuilt from backup.
- Final terrain region covers voxel corner (-160,-12,-180) through (260,100,-110), i.e. approximately (-640,-48,-720) through (1040,400,-440) studs. No terrain subtraction or removal of the hub boundary was used.
- Gallery additions: `Balcony Lodge v1`, `Champion Terrace v1`, both with labels; gallery platform/backdrop widened. Lookup entries are reference-only. ShowcaseArea was rebuilt.
- The test place was saved to Roblox through **File → Download a Copy**, and a recovery copy was written to `C:\Claude\Roblox-Game-zip-backup\CQ_RidgeBase_20261110.rbxl` (10,330,353 bytes at the first saved checkpoint). This was a test-place save, not a live publication. A final copy is recorded in the handoff after remaining source changes are saved.
- Temporary runtime fixtures existed only in Play and were discarded when Play stopped. Test coins, badges and creatures were NoSave fixtures.
- Final gallery references were refreshed to include the balcony Canopy and latest rails; ShowcaseArea rebuilt again and its Edit audit still returned zero findings. The final source lint remained 0 errors / 66 warnings / 0 parse errors.
- Final cloud test save and recovery copy verified: `C:\Claude\Roblox-Game-zip-backup\CQ_RidgeBase_20261110_final.rbxl`, **10,331,224 bytes**, timestamp 2026-11-10 18:19:38 Pacific. Both the original checkpoint file and this final file are retained.

## Explicit remaining validation / release holds

- XP Balcony construction price needs owner confirmation. Stage 3 purchase remains unavailable; stages 3/4 were exercised through NoSave fixtures, not real purchases.
- **Real DataStore save/rejoin was not run**: Studio API access is disabled. Console confirmed the attempted store was the isolated test store. In-memory round trips are not presented as persistence proof.
- No second player was connected: cross-owner/multiplayer regression, real trade and Coliseum PvP remain untested. A complete exploit/climb sweep and controller/mobile navigation of new stairs remain manual checks; structural rails and the existing hub boundary are present.
- Edit and Play visual checks do not constitute a complete movement/exploit sweep. Play terrain streaming can hide distant chunks; the hub mass and boundary collider were retained.
- Existing Phase 4 dungeon and Phase 6 button-validation gaps remain open as recorded in the prior handoff. These have not been silently closed by this build.
- No push, PR, live publish or production save migration was authorized or performed.
