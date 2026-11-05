# Main
`src/ServerScriptService/Main.server.luau` · server script · ServerScriptService · 810 lines

## Requires
- [[AdminService]]
- [[BaseManager]]
- [[BattleData]]
- [[BattleService]]
- [[ColiseumService]]
- [[DecorService]]
- [[DungeonService]]
- [[GameData]]
- [[GymService]]
- [[LeaderboardService]]
- [[LeagueService]]
- [[NpcGuard]]
- [[PassService]]
- [[PlayerData]]
- [[ProgressService]]
- [[RareEventService]]
- [[RouteTrainerService]]
- [[SaveService]]
- [[SocialService]]
- [[StoryService]]
- [[TutorialService]]
- [[WeeklyEventService]]
- [[WildSpawner]]

## Required by
- (none)

## Functions
- `trainerTag(player: Player, character: Model)`
- `onCharacter(player: Player, character: Model)`
- `onPlayerAdded(player: Player)`
- `npcSay(npc: Model, text: string, seconds: number?)`
- `npcWave(npc: Model)`
- `addPrompt(npc: Model, action: string, objectText: string)`
- `canAnyoneEnter(laneKey: string)`
- `refreshActiveLanes()`
- `watchProgress(player: Player)`

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
