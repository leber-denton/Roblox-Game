# BaseManager
`src/ServerScriptService/Modules/BaseManager.luau` · module · ServerScriptService · 498 lines

## Requires
- [[BattleData]]
- [[CreatureBuilder]]
- [[DecorData]]
- [[GameData]]
- [[Wander]]

## Required by
- [[AdminService]]
- [[BattleService]]
- [[ColiseumService]]
- [[DecorService]]
- [[LeagueService]]
- [[Main]]
- [[PassService]]
- [[ProgressService]]
- [[RouteTrainerService]]
- [[SaveService]]
- [[SocialService]]
- [[StoryService]]
- [[TutorialService]]

## Functions
- `finite(n)`
- `BaseManager.getIndex(player: Player)`
- `recordIndex(player: Player, record)`
- `sortedBases()`
- `setSign(base: Model, text: string)`
- `setGateOpen(base: Model, open: boolean)`
- `setExpansionOpen(base: Model, open: boolean)`
- `BaseManager.setWings(base: Model, level: number)`
- `BaseManager.isExpansionUnlocked(player: Player)`
- `BaseManager.recalcCapacity(player: Player)`
- `BaseManager.unlockExpansion(player: Player)`
- `refreshTag(record)`
- `BaseManager.assign(player: Player)`
- `BaseManager.release(player: Player)`
- `BaseManager.getBase(player: Player)`
- `BaseManager.getTeam(player: Player)`
- `BaseManager.hasRoom(player: Player)`
- `BaseManager.findById(player: Player, id: number)`
- `BaseManager.firstHealthy(player: Player)`
- `BaseManager.newRecord(name: string, level: number, hp: number?, shiny: boolean?, sizeClass: string?, ivs)`
- `spawnModel(player: Player, record)`
- `BaseManager.addCreature(player: Player, record, opts)`
- `BaseManager.removeCreature(player: Player, id: number)`
- `BaseManager.evolve(player: Player, record, into: string)`
- `BaseManager.serialize(player: Player)`
- `BaseManager.restore(player: Player, saved)`
- `BaseManager.refresh(player: Player)`
- `BaseManager.healAll(player: Player)`
- `BaseManager.snapshot(player: Player)`
- `BaseManager.spawnCFrame(player: Player)`

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
