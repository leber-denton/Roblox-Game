# BattleService
Code: `src/ServerScriptService/Modules/BattleService.luau`. Client: `BattleUI.client.luau`, `BattleFX.luau`.

## Flow
1. **Start**: `BattleService.start(player, model)` (wild), `startTrainer(player, def)`, `startPvP(p1, p2)`. Checks a base exists, a partner exists and the team isn't fainted/needs healing.
2. **Server tells client**: `send(b, kind, payload)` fires `BattleEvent`. Payload is a list of log entries `{text, fx}`.
3. **Client plays it**: `BattleUI.playTurn(entries, state)` shows each line and runs the `fx.type` animation (attack, stat, status, residual, faint, throw, heal, levelup, sendout, xp). Unknown/no fx just waits.
4. **Player acts**: client fires `BattleAction(action, arg)`. Actions: `fight`, `catch`, `item`, `switch`, `run`, `done`.
5. **Server resolves** (`BattleAction.OnServerEvent`): ignores input while `b.busy`; routes to `doFight`, `doCatch`, `doItem`, `doSwitch`, or `finish(b, "ran")`. PvP goes through `pvpAction`. Errors are pcall-caught and end the battle cleanly.
6. **End**: `finish(...)`, `applyXP`, and `BattleService.onEnded` / `onReleased` hooks let other systems react (progress, gyms, saving).

## Related
[[SaveService]], [[Architecture Map]]
