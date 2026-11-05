# TutorialService
`src/ServerScriptService/Modules/TutorialService.luau` · module · ServerScriptService · 473 lines

## Requires
- [[BaseManager]]
- [[BattleService]]
- [[GameData]]
- [[NPC]]
- [[PlayerData]]
- [[WildSpawner]]

## Required by
- [[AdminService]]
- [[GymService]]
- [[Main]]
- [[RouteTrainerService]]
- [[StoryService]]

## Functions
- `TutorialService.logFunnel(player: Player, step: number, stepName: string)`
- `setStep(player: Player, step: string, target: Instance?)`
- `clearModels(player: Player)`
- `spawnFor(player: Player, name: string, level: number, z: number, tag: string)`
- `starterInfo(name: string)`
- `dialogue(player: Player, id: string, speaker: string, lines)`
- `profIntro(player: Player)`
- `pickStarter(player: Player)`
- `playerStarter(player: Player)`
- `rivalTeam(player: Player, s)`
- `rivalChallenge(player: Player)`
- `startNibbit(player: Player)`
- `guideTarget(step: string)`
- `TutorialService.isGuideStep(step: string?)`
- `TutorialService.resumeGuide(player: Player, step: string)`
- `TutorialService.start(player: Player)`
- `onProfessor(player: Player)`
- `startRivalBattle(player: Player)`
- `TutorialService.init()`
- `TutorialService.onHeal(player: Player)`
- `TutorialService.finishGuide(player: Player)`
- `TutorialService.onShop(player: Player)`

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
