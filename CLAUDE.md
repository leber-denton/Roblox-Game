# Creature Quest

Roblox catch-and-battle game, written in Luau. See `README.md` for status and known gaps.

## Sync
- Rojo syncs `src/` into Studio. Edit the files here, not scripts in Studio, or the next sync can overwrite the change.
- Sync only into `CQ_NewestSource_TEST.rbxl`, one folder above this repo. The published place has older scripts, so never connect Rojo to it or publish without asking.
- Map, models and UI live in the place file, not this repo. Things like `Remotes` and `Shared.BallModels` exist only in Studio.

## Workflow
- Start each change on a new branch from the latest `main`. Don't reuse a merged branch.
- Rojo sends saved files to Studio, so Play test there before committing.
- Run `/ship` to lint, branch, commit, push and open the PR in one step (see `.claude/skills/ship/SKILL.md`). Graphify reviews the PR, usually in 20-30 minutes.
- Check the review with Graphify's `review_status` before merging. The user decides when to merge.
- After a merge, the user clicks **Sync now** in the Claude Project so it sees the new `main`.
- Research from the Claude Project comes through the Google Drive folder `claude`.

## Tooling
- `rokit install` installs the pinned tools in `rokit.toml`: `rojo`, `selene`, `stylua` and `gh`. `stylua --check <file>` previews formatting; the codebase is not formatted with it yet, so only run it on files you are already changing.
- `selene src tests` lints the Luau. Config is in `selene.toml`; run `selene generate-roblox-std` once to create the git-ignored `roblox.yml`.
- `gh` needs a one-time `gh auth login` before `/ship` can open PRs.

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
