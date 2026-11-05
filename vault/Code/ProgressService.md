# ProgressService
`src/ServerScriptService/Modules/ProgressService.luau` · module · ServerScriptService · 287 lines

## Requires
- [[BaseManager]]
- [[BattleService]]
- [[GameData]]
- [[PlayerData]]
- [[SaveService]]

## Required by
- [[Main]]

## Functions
- `today()`
- `questsFor(day: number)`
- `syncQuests(player: Player)`
- `checkDay(player: Player)`
- `ProgressService.onJoin(player: Player)`
- `ProgressService.progress(player: Player, kind: string, amount: number?, info)`
- `ProgressService.checkIndex(player: Player, index, quiet: boolean?)`
- `ProgressService.evolveNow(player: Player, record, into: string)`
- `ProgressService.checkEvolutions(player: Player)`
- `typesOf(name: string)`
- `ProgressService.init()`

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
