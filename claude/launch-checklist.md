# Creature Quest: Catch & Battle: Launch Checklist

(Formerly "Snatch Them All." Renamed on Creator Hub on 2026-10-29.)

## What you need to do before it makes money

1. **Create the products.** On the Creator Dashboard, create the game passes and developer products below, then paste each ID into the matching `id = 0` in Studio. Until you do, those buttons say "Coming soon."
   - **Game passes** (in `ReplicatedStorage.Shared.GameData.GamePasses`, lean set as of 2026-11-02): DoubleCoins, DoubleXP, ExtraSlots, VIP. Do NOT create RainbowTrail, PremiumDecor, DoubleBP or Gladiator: they're retired (VIP grants the cosmetic ones, 2x BP is now a timed product).
   - **Developer products** (in `GameData.Products`): InstantHeal, SummonRare, BoostCoins, BoostXP, BoostBP, ServerBoost, NovaPack, ApexPack, ReviveKit
   - **Developer products** (in `ReplicatedStorage.Shared.DecorData`):
     - `DecorData.CoinProducts`: Pouch (1,000), Bag (5,500), Chest (12,000), Vault (32,500) coins
     - `DecorData.Bundles`: Starter Pack (one time), Swift Ball Bundle, Medicine Kit, Shard Pouch, Coin Fountain Deal
2. **Turn on saving.** Done on Creator Hub (Studio access to API services is on). Publish from Studio so the live game picks it up.
3. **Test one real purchase** after publishing. Robux purchases can't be fully tested in Studio.

## Creator Hub listing (saved 2026-10-29)

- Name: Creature Quest: Catch & Battle
- Genre: RPG / Turn-based RPG (can only be changed every 3 months)
- Description: saved (673 characters)
- Icon: drafted, needs uploading. Thumbnails: not made yet.

## Pushback

This gives you places to spend Robux, but players are what make money. With zero players, a good shop earns nothing. Most of your effort after this should go into getting people to play and keeping them coming back. The likes board, daily shop, Journey tracker, Juniper's story, the Saturday Rare Storm and rare catch banners help with that, but promoting the game matters more than adding more items.

## Assumptions

- The Robux prices in the scripts are suggestions. You set the real prices on the dashboard.
- Nothing random is sold for Robux. Crates are coins only, and a paid Summon Rare Spawn is a fixed pick (your furthest region's rarest creature, Huge, never shiny).
- The mouse-driven decoration placement preview uses the same rules as the server, which were tested. Place a few items yourself and report anything that feels off.
- Region 1 had no name, so it's "Maple" (its Victory Road is "Maple Victory Road"). Change `GameData.Region1.name` to rename it everywhere.

## Where to edit things

- Juniper's lines and milestones: `ServerScriptService.Modules.StoryService` (the SCENES table)
- Trainer's Guide lines, Professor intro and the jump to the first Nibbit: `ServerScriptService.Modules.TutorialService`
- Region tour camera shots and captions: `StarterPlayerScripts.Story`
- What locked regions hide: `StarterPlayerScripts.LockedLanes` (SMALL sets the prop size that gets hidden)
- Decorations, crates, themes, base levels, bundles: `ReplicatedStorage.Shared.DecorData`
- Game passes, dev products, timed boosts (`GameData.hasBoost`): `ReplicatedStorage.Shared.GameData` (GamePasses, Products) and `ServerScriptService.Modules.PassService`
- Receipt handling (all dev products): `ServerScriptService.Modules.DecorService` (processReceipt)
- Paid items owed but not delivered yet (Instant Heal bought mid-battle, queued Summon Rare): saved in `PlayerData` under `settings.pending` (`PlayerData.getPending` / `setPending`), delivered on join by `PassService.onLoaded`
- Weekly Rare Storm (day, Pacific hour, length, boosts): `GameData.WeeklyEvent` (`hourPacific`; daylight saving is automatic) and `ServerScriptService.Modules.WeeklyEventService` (admin panel button "Start Rare Storm" or command `storm` starts one for testing)
- Rare spawn picks (free and paid): `ServerScriptService.Modules.RareEventService`
- Rare catch banner, catch feed, storm countdown, boost timers: `StarterPlayerScripts.EventHUD` (server side sends `Remotes.RareCatch` from BattleService)
- Catch ball looks: `ReplicatedStorage.Shared.BallModels` (one model per ball id); throw, lid, shake and catch animation: `StarterPlayerScripts.BattleFX` (BattleFX.throw)
- Side ground per region and the blends between regions: `Workspace.Map.RoadGround.LaneGround`
- Region 2 arm scenery: `Workspace.Map.Decor.Region2Fill` (one folder per lane) plus the older `Decor.Region2`
- Summit Town shop and Healing Center: `Workspace.Map.SummitTown`; Nurse Ivy's heal and respawn point (LastHealStop = "SummitTown"): `ServerScriptService.Main` (Summit Town block)
- Region names and Victory Road names: `GameData.Region1`, `GameData.Region2.region`, `GameData.VictoryRoads`
- Victory Road wild spawns: data in `GameData.Lanes.LaneVR` (Region 1) and `GameData.Lanes.LaneVR2` (Region 2); the spawn zones are the invisible parts `Workspace.Map.Lanes.LaneVR` / `LaneVR2`, which stop 10 studs short of each League hall
- Victory Road arches over each road: `Workspace.Map.Lanes.VictoryArch` (Region 1) and `VictoryArch2` (Region 2); signs `LeagueSign` and `League2Sign`
- HUD MAP panel (region names, road order): `StarterPlayerScripts.HUD` (MAP block)
- Gym badge names: `GameData.GymLeaders` (each badge name must be unique, or the second gym counts as a rematch and gives no badge)
- Route trainer spots: the models in `Workspace.Map.RouteTrainers` are the source of truth; data in `GameData.RoadOffsets` (Region 1) and the Region 2 crews block (lanes are 520 studs; offsets 340/400/455). `RouteTrainerService` warns in the output if data and a model drift apart
- Elite Four / Champion stand spots: `Map.League.Hall` and `Map.League2.Hall` (EliteNPad, ChampionDais)
- NPC position guard: `ServerScriptService.Modules.NpcGuard`. Every NPC has a `HomePos` attribute; on server start any NPC more than 150 studs off is warned about and snapped back. After moving an NPC on purpose, run `require(game.ServerScriptService.Modules.NpcGuard).stamp()` in the command bar
- Region road and land shape (Theming Overhaul): data in `ReplicatedStorage.Shared.RegionPaths` (one entry per lane, Lane1 first); Terrain is written by `ServerStorage.RegionTerrainBuilder` (`preview`/`build`/`restore`, snapshots in `ServerStorage.RegionTerrainBackups`) and checked by `ServerStorage.RegionPathValidator` (`recon`/`validate`); trainers and route dressing are placed by `ServerStorage.RegionDecorator` (`placeTrainers`/`dress`/`undo`, rules in `RegionPaths.<lane>.dressing`). Tests: `tests/RegionPathsTests.luau`
- Route looks (Overhaul Phase 2): one theme per route in `ReplicatedStorage.Shared.RegionStyle` (materials, palette, decor templates, density overrides; StyleSpec measured from Meadow). Re-theme a route in Edit mode with `require(game.ServerStorage.RegionRollout).run("<lane>")`, check with `.validate("<lane>")`, undo with `.undo("<lane>")`. Road audit/gate: `ServerStorage.RouteWalker` (run on the server in Play; its gate-canopy rule is covered by `tests/RouteWalkerTests.luau`). Per-route results: `claude/region-rollout.md`. `NPCAnimator.buildQuestWorld` no longer adds GateBaffles or trims decor inside route corridors
- Mountains (all Part models, no terrain): `Workspace.Map.Mountains` — `Region2` (the eight east trail mountains), `Divider` (Region 1 / Region 2 range, x 80-380, z 820-4700, one segment per lane pair), `Hub` (east of the hub and Summit Town) and `Coast` (south of the hub). Summit and lookout text: attributes on each mountain Model (`MountainName`, `SummitMessage`, `Lookout<i>Name`, ...), read by `ServerScriptService.MountainLookouts`; drag the `SummitMarker` / `Lookout<i>` parts to move a prompt. Shapes, palettes and new mountains: `ServerStorage.MountainPartBuilder` (`Builder.Specs`; Edit only, builds missing models only). The walk-up messages at the divider are `Workspace.Map.MountainHints` + `StarterPlayerScripts.Regions`. Note: `vault/Systems/MountainLookouts.md`
- Obstacle courses (optional parkour, one per route, coin chest at the end): rewards, cooldowns, first-clear bonus and difficulty all live in `ReplicatedStorage.Shared.CourseConfig` (`Courses` = { RouteName, Difficulty, CoinReward, Cooldown, FirstClearBonus } per route; `Difficulties` = gaps, climb, height, which obstacles, spinner/mover/vanish speed, minimum run time; `DefaultCooldown` = 600 s). The courses themselves are `Workspace.Obstacles.<RouteName>` (edit by hand in Studio, or regenerate with `ServerStorage.ObstacleCourseBuilder`: `remove("<Id>")` then `build("<Id>")`; looks per route in its `THEMES`). Chest claims, fall resets and the saved first-clear/cooldowns: `ServerScriptService.ObstacleCourses`. Moving platforms, chest full/empty look and the start hint: `StarterPlayerScripts.ObstacleCourses`. New route = one `CourseConfig.Courses` entry, then `build`. Checks: `tests/ObstacleCourseTests.luau`. Note: `vault/Systems/ObstacleCourses.md`
- Model sync (edit once, push everywhere): reference copies are in `Workspace.ShowcaseArea`, built by `ServerStorage.ShowcaseBuilder`. `ServerStorage.ModelSyncLookup` is the table of where each model's real copies live: map paths for trainers and NPCs, templates for balls, creatures and companions, name matching for decorations and props. `ServerStorage.ModelSync` does `preview`, `apply`, `restore`, `addToMap` and `audit`. Add new models to the lookup, run `ModelSync.audit()`, then rebuild the showcase. Tests are in `tests/ModelSyncTests.luau`.
