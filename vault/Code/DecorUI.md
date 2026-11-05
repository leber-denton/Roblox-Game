# DecorUI
`src/StarterPlayer/StarterPlayerScripts/DecorUI.client.luau` · client · StarterPlayer · 1033 lines

## Requires
- [[DecorData]]
- [[GameData]]

## Required by
- (none)

## Functions
- `new(className: string, props, parent)`
- `round(inst, r)`
- `label(props, parent)`
- `button(props, text: string, color: Color3, parent, onClick)`
- `call(action: string, ...)`
- `toast(text: string, kind: string?)`
- `myBase()`
- `preview(id: string, parent: GuiObject, size: UDim2, position: UDim2?)`
- `setStatus(ok: boolean?, text: string?)`
- `clearContent()`
- `gridLayout()`
- `listLayout()`
- `heading(order: number, text: string, color: Color3?)`
- `itemCard(order: number, id: string, sub: string, buttonText: string, buttonColor: Color3, onClick)`
- `placedCount(id: string)`
- `showReveal(result)`
- `staticParts(base: Model)`
- `overlaps(ax, az, afx, afz, bx, bz, bfx, bfz)`
- `check(base: Model, id: string, x: number, z: number, r: number, ignoreUid: number?)`
- `setModelHidden(model: Model?, hidden: boolean)`
- `placedModel(uid: number)`
- `stopBuild()`
- `makeGhost(id: string)`
- `rebuildBar()`
- `startPlacing(id: string, uid: number?, r: number?)`
- `startPicking()`
- `aimRay()`
- `tryCommit()`
- `tryPutAway()`
- `tryPick()`
- `productPrice(p)`
- `tabs.Items()`
- `buyResult(ok, message)`
- `tabs.Shop()`
- `tabs.Daily()`
- `tabs.Crates()`
- `tabs.Themes()`
- `tabs.Base()`
- `tabs.Robux()`
- `openMenu(tab: string?)`

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
