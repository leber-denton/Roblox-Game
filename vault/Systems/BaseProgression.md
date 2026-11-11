# Base Progression

Owner approved the ridge/base plan and its Phase 0 amendments on 2026-11-10. Implementation branch: `overhaul/ridge-base-progression`.

`Shared.BaseProgressionData` defines Starter Yard → Habitat Garden → XP Balcony → Champion Terrace. This stage is independent of `decor.level` (old decoration caps, side wings and income bonuses) and `decor.canopy` (unchanged battle-XP sharing tiers).

[[BaseManager]] saves additive `base.baseStage` and retains `base.expansion`. Missing/invalid stage defaults to 1; a legacy Boolean true expansion guarantees at least stage 2. Stage 2+ implies expansion. All saved creatures are retained, including overflow. Normal stage capacity stays 6→12; the existing Extra Slots entitlement adds six, as explicitly approved in the audit review. Assign/release reset stage geometry and the Canopy position.

New Habitat Garden purchases require one badge and the existing 500 coins. Existing expanded saves keep their purchase with no new badge check. XP Balcony's construction cost is deliberately `OWNER_CONFIRMATION_REQUIRED`, so the stage purchase fails closed. Existing XP-share upgrades work at the original costs regardless of homestead stage. Champion Terrace requires stage 3, Champion and all species in the nine existing Region 1 Index groups; it grants no XP/capacity/income bonus.

[[DecorService]] exposes stage goals, bench share, per-creature training rates, bonus sources, cap and next practical goal. Fixed boards and the Base tab display these. The old Canopy model is moved onto the raised deck at stage 3; saved field and attribute names stay unchanged. [[BattleService]] sends `rewardSummary` at battle end using XP deltas after caps and actual coin balance deltas after boosts. The client displays this without granting rewards again.

The Champion Terrace has ground-level decoration pads, validated by the same mirrored Floor coordinate system on server/client. Elevated deck placement is not supported; the deck is fixed presentation. `DecorData.LayoutVersion` remains 2, existing coordinates retain their meaning, and old wings remain available independently of homestead stage.

`ServerStorage.BaseHomesteadBuilder` and `CoastalEscarpmentBuilder` are Edit tools restricted to cloud test place 94034385545160. Terrain, base originals and 93 intersecting tree/bush models are retained under `ServerStorage.Backups.RidgeBase_PreBuild`. Trees were moved there, not deleted. Gallery references are registered as reference-only in ModelSyncLookup. Builders are repeatable; the terrain builder also has a restore method.

[[SaveService]] uses `CQ_RidgeBase_TEST_v1` only in cloud test place 94034385545160. Everywhere else retains `SnatchThemAll_Save_v1`, including its existing key and lock scheme. Never enable APIs against a production store to validate these fixtures. Studio API access is currently disabled, so persistence/rejoin has not been proven.

Existing passive coin generators and all paid benefits were preserved by owner decision. This build adds no passive income source, rate, BP sale or training-cap bypass.

Validation and recovery details: `claude/ridge-base-validation.md`. Pure fixtures: `tests/BaseProgressionTests.luau` (49 assertions). Existing Phase 4–6 validation gaps remain separate.
