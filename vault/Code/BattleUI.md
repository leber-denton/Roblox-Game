# BattleUI
`src/StarterPlayer/StarterPlayerScripts/BattleUI.client.luau` · client · StarterPlayer · 879 lines

## Requires
- [[BattleData]]
- [[BattleFX]]
- [[GameData]]
- [[Sfx]]

## Required by
- (none)

## Functions
- `new(className: string, props, parent)`
- `round(inst, radius)`
- `pad(inst, px)`
- `label(props, parent)`
- `hex(c: Color3)`
- `makeCard(guiName: string, parent: Instance, anchor: Vector2, position: UDim2, showXP: boolean)`
- `attachCard(card, _model)`
- `setStatus(card, status: string?)`
- `setStages(card, stages)`
- `zeroStages()`
- `setColumns(cols: number)`
- `clearButtons()`
- `useList()`
- `inventory()`
- `act(action: string, arg)`
- `button(order: number, title: string, subtitle: string?, color: Color3, onClick, strokeColor: Color3?, parent: Instance?)`
- `lockButton(b: GuiButton)`
- `pulse(b: GuiButton)`
- `moveStyle(move)`
- `promptText()`
- `showMenu(kind: string, extra)`
- `hpColor(f: number)`
- `setCardHP(card, hp: number, maxHP: number)`
- `typeText(c)`
- `setCard(card, c, nameColor: Color3?)`
- `animateXP(card, from: number, to: number, levels: number)`
- `applyState(s)`
- `floatDamage(model: Model?, damage: number, mult: number?)`
- `playTurn(entries, state)`
- `battleCamera(state)`
- `restoreCamera()`
- `resolveModels(state)`
- `showOwnTag(visible: boolean)`
- `handle(kind: string, data)`

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
