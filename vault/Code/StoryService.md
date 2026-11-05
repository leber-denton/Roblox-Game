# StoryService
`src/ServerScriptService/Modules/StoryService.luau` · module · ServerScriptService · 303 lines

> Juniper's milestone story. Encounters are earned on the server, found in the world,

## Requires
- [[BaseManager]]
- [[BattleService]]
- [[GameData]]
- [[NPC]]
- [[PlayerData]]
- [[SaveService]]
- [[TutorialService]]

## Required by
- [[AdminService]]
- [[LeagueService]]
- [[Main]]

## Functions
- `count(player)`
- `atBadge(n)`
- `get(player)`
- `nextScene(player)`
- `sync(player)`
- `linesFor(player,scene)`
- `free(player)`
- `complete(player,scene)`
- `begin(player,scene)`
- `check(player)`
- `StoryService.chat()`
- `StoryService.onHeal(player)`
- `StoryService.onLoaded(player)`
- `StoryService.hasCompleted(player,id)`
- `StoryService.requestMilestone(player,id)`
- `laneSpot(key,side,depth)`
- `part(parent,name,size,position,color,material)`
- `makeGrunt(parent,position,label)`
- `setupWorld()`
- `StoryService.init()`

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
