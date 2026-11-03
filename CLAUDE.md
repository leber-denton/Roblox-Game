# Creature Quest

Roblox catch-and-battle game, written in Luau. See `README.md` for status and known gaps.

## Sync
- Rojo syncs `src/` into Studio. Edit the files here, not scripts in Studio, or the next sync can overwrite the change.
- Sync only into `CQ_NewestSource_TEST.rbxl`, one folder above this repo. The published place has older scripts, so never connect Rojo to it or publish without asking.
- Map, models and UI live in the place file, not this repo. Things like `Remotes` and `Shared.BallModels` exist only in Studio.

## File endings
- `.server.luau` is a Script, `.client.luau` is a LocalScript, plain `.luau` is a ModuleScript.
- Keep these endings when adding files, or the script won't run.

## Layout
- `src/ServerScriptService/Main.server.luau`: server entry point
- `src/ServerScriptService/Modules/`: server systems, such as `BattleService`, `PlayerData` and `SaveService`
- `src/ReplicatedStorage/Shared/`: data shared with clients
- `src/StarterPlayer/StarterPlayerScripts/`: client scripts and UI
- `tests/`: run by hand in Studio; not synced

## Reading code
- `GameData.luau` is very large, so search it instead of reading all of it.
- Use Graphify (`leber-denton/Roblox-Game`) to find code and callers. It covers indexed commits only and can miss calls, so confirm in the file before editing.

## Testing
- Saving doesn't work in `CQ_NewestSource_TEST.rbxl` because it's unpublished. Don't treat a Play test as proof that saving works.
- Be careful changing `PlayerData.serialize`, `PlayerData.load` or `SaveService`: mistakes can damage player saves.
