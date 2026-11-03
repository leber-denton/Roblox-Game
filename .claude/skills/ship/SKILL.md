---
name: ship
description: Lint the current Luau changes, commit them on a fresh branch from main, push, and open a PR for Graphify to review. Use when the user says /ship or asks to ship, push, or open a PR for their changes.
---

# /ship

Runs the routine from CLAUDE.md in one go. Invoking `/ship` is the user's go-ahead to commit, push and open a PR. It is never a go-ahead to merge.

Tools come from `rokit.toml` (`rojo`, `selene`, `gh`). If one is missing, run `rokit install`. Use `~/.rokit/bin/<tool>` if it isn't on PATH.

## Steps

1. **Look first.** `git status` and `git diff`. If nothing changed, say so and stop. Never stage `.rbxl`/`.rbxlx` place files (they're gitignored) and never publish or connect Rojo to the published place.
2. **Lint.** Run `selene` on the changed `.luau` files (run `selene generate-roblox-std` first if `roblox.yml` is missing). Fix errors in files you changed. Warnings are fine to ship; mention any new ones. If an error is in code you didn't touch, report it and continue.
3. **Save-safety check.** If the diff touches `PlayerData.serialize`, `PlayerData.load` or `SaveService`, stop and tell the user: a Play test in the unpublished `.rbxl` can't prove saving works.
4. **Play test reminder.** Ask whether they Play tested in Studio, unless they already said so this session.
5. **Branch.** `git fetch origin`. If the current branch is `main` or already merged, create a new branch from the latest `origin/main` with a short kebab-case name describing the change, carrying the working changes over. Don't reuse a merged branch.
6. **Commit.** Stage only the intended source files by name. Write a short imperative message that matches the repo's history (e.g. "Add getPublicBattle for the Coliseum watch list").
7. **Push and open the PR.** `git push -u origin <branch>`, then `gh pr create --base main` with a title and a body covering what changed, why, and how it was tested. If `gh auth status` fails, tell the user to run `gh auth login` and stop.
8. **Review.** Report the PR link. Graphify reviews in roughly 20-30 minutes; check it later with Graphify's `review_status` (repo `leber-denton/Roblox-Game`) and relay the findings. Do not merge. The user decides.
9. **After the merge** (only when the user tells you it's merged): remind them to click **Sync now** in the Claude Project so it sees the new `main`.

## Output

End with the branch name, the PR URL, the Selene result in one line, and the next step for the user.
