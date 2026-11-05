# DecorService
`src/ServerScriptService/Modules/DecorService.luau` · module · ServerScriptService · 1469 lines

## Requires
- [[BaseManager]]
- [[BattleData]]
- [[BattleService]]
- [[CreatureBuilder]]
- [[DecorData]]
- [[GameData]]
- [[PlayerData]]
- [[SaveService]]

## Required by
- [[Main]]
- [[PassService]]

## Functions
- `defaults()`
- `floorOf(base: Model)`
- `levelDef(d)`
- `placedCount(d, id: string)`
- `countWith(d, key: string)`
- `incomeRate(player: Player, d)`
- `trainingRates(player: Player, d)`
- `train(player: Player, d, minutes: number)`
- `bankCap(player: Player, d)`
- `publicState(player: Player, d)`
- `sync(player: Player)`
- `themeTargets(base: Model)`
- `rememberOriginals(base: Model)`
- `applyTheme(base: Model, themeId: string)`
- `decorFolder(base: Model)`
- `strongest(player: Player)`
- `dressPedestal(player: Player, model: Model)`
- `dressTrophy(player: Player, model: Model)`
- `dress(player: Player, model: Model)`
- `spawnPlaced(player: Player, p)`
- `despawnPlaced(player: Player, uid: number)`
- `clearModels(player: Player)`
- `collectStatic(base: Model)`
- `overlaps(ax, az, afx, afz, bx, bz, bfx, bfz)`
- `canPlace(player: Player, d, id: string, x: number, z: number, r: number, ignoreUid: number?)`
- `grant(d, id: string, n: number?)`
- `rollBox(boxId: string)`
- `actions.state(player, d)`
- `actions.buy(player, d, id)`
- `actions.buyDaily(player, d, id)`
- `actions.openBox(player, d, boxId)`
- `actions.shardBuy(player, d, id)`
- `cleanArgs(x, z, r)`
- `actions.place(player, d, id, x, z, r)`
- `actions.move(player, d, uid, x, z, r)`
- `actions.remove(player, d, uid)`
- `actions.theme(player, d, themeId)`
- `actions.upgrade(player, d)`
- `actions.canopy(player, d)`
- `actions.collect(player, d)`
- …and 16 more

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
