# Roblox-Game
Code a Creature Quest: Catch &amp; Battle Roblox Game


## Layout

- `src/` holds the game scripts, in folders matching their Roblox services. The server entry point is `src/ServerScriptService/Main.luau`.
- `tests/` holds the Studio test scripts.
- Place files (`.rbxl`), which contain the map, models and UI, are not stored here.

## Status

Tested in single-player Studio only. Trading, Coliseum matches, multiplayer saving and a full playthrough are untested.

Known gap: `ColiseumService` calls `BattleService.getPublicBattle`, which doesn't exist yet, so the public battle list stays empty.
