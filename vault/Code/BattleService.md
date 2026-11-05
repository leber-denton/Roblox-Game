# BattleService
`src/ServerScriptService/Modules/BattleService.luau` · module · ServerScriptService · 1581 lines

## Requires
- [[ArenaManager]]
- [[BaseManager]]
- [[BattleData]]
- [[CreatureBuilder]]
- [[GameData]]
- [[PlayerData]]
- [[Wander]]

## Required by
- [[AdminService]]
- [[ColiseumService]]
- [[DecorService]]
- [[DungeonService]]
- [[GymService]]
- [[LeagueService]]
- [[Main]]
- [[PassService]]
- [[ProgressService]]
- [[RouteTrainerService]]
- [[SocialService]]
- [[StoryService]]
- [[TutorialService]]
- [[WildSpawner]]

## Functions
- `BattleService.onEnded(fn)`
- `BattleService.onReleased(fn)`
- `fire(list, ...)`
- `playbackTime(log)`
- `info(name: string)`
- `statsOf(c)`
- `movesFor(c)`
- `say(log, text: string, fx)`
- `setTag(model: Model?, enabled: boolean)`
- `newStages()`
- `prefixFor(b, s: string)`
- `heldCheck(b, log, side: string)`
- `speedOf(c, stage: number)`
- `xpFrac(c)`
- `snapshot(c)`
- `moveOptions(b)`
- `copySnapshot(list)`
- `buildState(b)`
- `send(b, kind: string, log, extra)`
- `groundAt(b, position: Vector3)`
- `modelOf(b, side: string)`
- `placeAlly(b)`
- `placeTrainerCreature(b)`
- `setupField(b, character: Model, hrp: BasePart, humanoid: Humanoid, place)`
- `release(b)`
- `finish(b, result: string, log)`
- `damage(b, side: string, moveName: string)`
- `useMove(b, log, side: string, moveName: string)`
- `residual(b, log, side: string)`
- `wildTurn(b, log)`
- `capFor(player: Player?)`
- `applyXP(record, amount: number, log, announce: boolean, model, player: Player?)`
- `BattleService.applyXP(record, amount: number, player: Player?)`
- `grantXP(b, log)`
- `giveReward(b, log, coins: number, xp: number)`
- `makeCreature(name: string, level: number, stars: number?)`
- `allyFainted(b, log)`
- `opponentFainted(b, log)`
- `afterTurn(b, log)`
- `doFight(b, moveName: string, log)`
- …and 25 more

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
