# PlayerData
`src/ServerScriptService/Modules/PlayerData.luau` · module · ServerScriptService · 372 lines

## Requires
- [[GameData]]

## Required by
- [[AdminService]]
- [[BattleService]]
- [[ColiseumService]]
- [[DecorService]]
- [[GymService]]
- [[LeagueService]]
- [[Main]]
- [[PassService]]
- [[ProgressService]]
- [[RouteTrainerService]]
- [[SaveService]]
- [[StoryService]]
- [[TutorialService]]

## Functions
- `finite(n)`
- `sync(player: Player)`
- `defaults()`
- `PlayerData.init(player: Player)`
- `PlayerData.load(player: Player, saved)`
- `PlayerData.serialize(player: Player)`
- `PlayerData.hasBeatenTrainer(player: Player, id: string)`
- `PlayerData.markTrainerBeaten(player: Player, id: string)`
- `PlayerData.setMusicMuted(player: Player, muted: boolean)`
- `PlayerData.addStat(player: Player, name: string, amount: number?)`
- `PlayerData.setStatMax(player: Player, name: string, value: number)`
- `PlayerData.addBoost(player: Player, key: string, minutes: number)`
- `PlayerData.getPending(player: Player, key: string)`
- `PlayerData.setPending(player: Player, key: string, value)`
- `PlayerData.get(player: Player)`
- `PlayerData.addCoinsRaw(player: Player, amount: number)`
- `PlayerData.coins(player: Player)`
- `PlayerData.addCoins(player: Player, amount: number)`
- `PlayerData.spend(player: Player, amount: number)`
- `PlayerData.addBP(player: Player, amount: number)`
- `PlayerData.spendBP(player: Player, amount: number)`
- `PlayerData.addXP(player: Player, amount: number)`
- `PlayerData.addItem(player: Player, id: string, count: number)`
- `PlayerData.takeItem(player: Player, id: string)`
- `PlayerData.hasBadge(player: Player, badge: string)`
- `PlayerData.addBadge(player: Player, badge: string)`
- `PlayerData.remove(player: Player)`

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
