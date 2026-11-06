# SaveService
Code: `src/ServerScriptService/Modules/SaveService.luau`. DataStore key prefix `SnatchThemAll_Save_v1` (never rename: it would wipe saves).

## Load (called from `Main.server` on join)
`claim(player)` takes a **session lock** (`lock = {job, t}`) with `UpdateAsync`, waiting up to ~18s if another server holds a fresh lock (stale after 150s). Then `PlayerData.load`, `BaseManager.restore`, then every registered section's `load`. If the load fails, the player is marked `loaded = false` and **nothing is ever saved for them**, so a failed load cannot wipe a real save.

## Save
`SaveService.save(player, release?)` writes `{player, base, dungeonFloor, tutorialDone, savedAt}` plus each registered section's `serialize()`. It refuses to overwrite if another server took the lock. Admin `NoSave` sessions skip saving but still release the lock.

## When saves happen
- Every 120s for all players (autosave loop in `init`)
- `requestSave(player)`: soon after a catch/win, throttled to once per 30s per player
- Immediately after trades (`SocialService`) and decor changes
- On leave (`onLeave`, releases lock then frees base/data) and on server shutdown (`BindToClose`)

## Extending
`SaveService.register(key, {serialize, load, release})`. Used by `coliseum`, `decor`, `social`, `story`. Be careful with `PlayerData.serialize/load`: mistakes damage real saves.

## Related
[[BattleService]], [[Architecture Map]]
