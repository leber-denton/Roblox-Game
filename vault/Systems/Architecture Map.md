# Architecture Map

Rojo maps `src/` into the place (see `default.project.json`). Everything else (Remotes, map geometry) lives in the Studio place file.

## Layers
| Layer | Rojo path | What lives there |
|---|---|---|
| Shared data | `ReplicatedStorage.Shared` | `GameData` (creatures, items, rarities), `BattleData`, `CreatureBuilder`, `DecorData`, `TrainerAnimations` |
| Server entry | `ServerScriptService` | `Main.server` (wires everything, handles join/leave, NPC prompts, teleports), `NPCAnimator.server`, `Showcase.server` |
| Server services | `ServerScriptService.Modules` | One module per system: Battle, Save, PlayerData, Base, Decor, Dungeon, Gym, League, Coliseum, Social, Story, Tutorial, Pass, Progress, Wild spawner, events, Admin, Leaderboard |
| Studio tooling | `ServerStorage` | `ModelSync`, `ModelSyncLookup`, `MeshIntake`, `ShowcaseBuilder` |
| Client | `StarterPlayer.StarterPlayerScripts` | One `.client` script per screen: `BattleUI`, `HUD`, `Menus`, `Bag`, `DecorUI`, `Story`, `Tutorial`, ... plus helpers `BattleFX`, `Sfx` |

## Biggest files
`GameData` 1.3k lines, `BattleService` 1.5k, `DecorService` 1.4k, `Menus.client` 0.9k, `BattleUI.client` 0.8k, `Main.server` 0.8k.

## How systems talk
- `Main.server` requires every module, then each module exposes `init()` and functions the others call.
- Server to client goes through RemoteEvents under `ReplicatedStorage.Remotes` (`BattleEvent`, `BattleAction`, `Notify`, `Settings`, `Teleport`, ...).
- Systems that need to persist data call `SaveService.register(key, {serialize, load, release})`. Current sections: `coliseum`, `decor`, `social`, `story`.

Details: [[BattleService]], [[SaveService]].
