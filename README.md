# Roblox-Game
Code a Creature Quest: Catch &amp; Battle Roblox Game


## Layout

- `src/` holds the game scripts, in folders matching their Roblox services. The server entry point is `src/ServerScriptService/Main.server.luau`.
- `tests/` holds the Studio test scripts. They aren't synced into the game.
- Place files (`.rbxl`), which contain the map, models and UI, are not stored here.

## Syncing to Studio

[Rojo](https://rojo.space) syncs `src/` into Studio, as set out in `default.project.json`. Install the tools with `rokit install`, run `rojo serve`, then connect from the Rojo plugin in Studio.

File endings set the script type: `.server.luau` is a Script, `.client.luau` is a LocalScript, and plain `.luau` is a ModuleScript. Anything in Studio that isn't in `src/`, such as `Remotes` and `Shared.BallModels`, is left alone.

## Status

Tested in single-player Studio only. Trading, Coliseum matches, multiplayer saving and a full playthrough are untested.

Known gap: `ColiseumService` calls `BattleService.getPublicBattle`, which doesn't exist yet, so the public battle list stays empty.
