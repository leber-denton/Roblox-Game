# BattleFX
`src/StarterPlayer/StarterPlayerScripts/BattleFX.luau` · module · StarterPlayer · 878 lines

## Requires
- (none)

## Required by
- [[BattleUI]]

## Functions
- `rootOf(model: Model?)`
- `play(inst: Instance, time: number, props, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)`
- `effectPart(shape: Enum.PartType, size: number, color: Color3, position: Vector3)`
- `burst(position: Vector3, color: Color3, size: number)`
- `sparkle(position: Vector3, color: Color3, count: number, spread: number)`
- `flash(model: Model?, color: Color3, times: number)`
- `shake(part: BasePart, amount: number)`
- `shakeCamera(strength: number, duration: number)`
- `screenFlash(color: Color3, amount: number)`
- `groundRing(position: Vector3, color: Color3, size: number, time: number?)`
- `groundY(model: Model?, root: BasePart)`
- `charge(model: Model?, root: BasePart, color: Color3, time: number)`
- `rearBack(root: BasePart, home: CFrame, time: number)`
- `projectile(from: Vector3, to: Vector3, color: Color3, size: number, time: number, arc: number)`
- `lightning(target: Vector3, color: Color3)`
- `impact(defender: Model?, d: BasePart, fromDir: Vector3, color: Color3, strong: boolean, mult: number, onImpact)`
- `BattleFX.attack(attacker: Model?, defender: Model?, fx, onImpact)`
- `BattleFX.faint(model: Model?)`
- `setHidden(model: Model, hidden: boolean, saved)`
- `plainBall(def)`
- `BattleFX.makeBall(ballId: string?)`
- `ballParts(ball: BasePart)`
- `fadeBall(ball: BasePart, time: number)`
- `glow(ball: BasePart, brightness: number, color: Color3?, time: number?)`
- `latch(ball: BasePart, color: Color3, time: number?)`
- `setLid(ball: BasePart, angle: number, time: number)`
- `scaleModel(model: Model, from: number, to: number, time: number, toward: Vector3?, style)`
- `BattleFX.throw(fromPos: Vector3, wildModel: Model?, caught: boolean, shakes: number, ballId: string?, onShake)`
- `BattleFX.levelUp(model: Model?)`
- `BattleFX.statChange(model: Model?, stages: number)`
- `BattleFX.statusMove(attacker: Model?, moveType: string)`
- `BattleFX.statusEffect(model: Model?, color: Color3)`
- `BattleFX.sendOut(model: Model?)`

_Auto-generated from `src/` — edit hand-written notes in `Systems/`, not this file._
