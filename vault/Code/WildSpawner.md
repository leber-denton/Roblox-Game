# WildSpawner
`src/ServerScriptService/Modules/WildSpawner.luau` · module · ServerScriptService · 255 lines

## Requires
- [[BattleService]]
- [[CreatureBuilder]]
- [[GameData]]
- [[Wander]]

## Required by
- [[AdminService]]
- [[Main]]
- [[RareEventService]]
- [[TutorialService]]

## Functions
- `WildSpawner.setHotZone(laneKey: string?)`
- `WildSpawner.getHotZone()`
- `pickEntry(spawns, depth: number, isHotZone: boolean)`
- `WildSpawner.rollVariant(laneKey: string?)`
- `WildSpawner.spawnOne(name: string, level: number, pos: Vector3, opts)`
- `spawnInLane(lane: BasePart, config, laneKey: string)`
- `laneParts(laneKey: string)`
- `WildSpawner.countLane(laneKey: string)`
- `fillLane(laneKey: string, maxNew: number)`
- `WildSpawner.spawnLane(laneKey: string)`
- `WildSpawner.refillLane(laneKey: string)`
- `WildSpawner.canReplace(model: Model)`
- `WildSpawner.clearLane(laneKey: string)`
- `WildSpawner.shift()`
- `WildSpawner.clear()`

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
