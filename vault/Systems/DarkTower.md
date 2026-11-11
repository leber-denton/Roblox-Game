# Dark Tower (dungeon)

Two stacked towers of ten floors, plus a rest room at the top (Overhaul Phase 4, 2026-11-10).

| Floors | Rooms | Theme | Boss |
|---|---|---|---|
| 1.1-1.10 | Room1-Room10 | Bone Crypt: grey stone, bone pillars, moss carpet, pale green glow | 1.10 Tower Warden Nyx |
| 2.1-2.10 | Room11-Room20 | Ember Forge: black stone, basalt floor, lava carpet, orange/red glow | 2.10 Forge Warden Ignar |
| 3.1 (rest) | Room21 | Ember Forge | none |

Each x.10 room uses the darker boss variant of its tower's theme, with gold trim. There is no purple anywhere.

## Where things live
- Floors, teams and rewards: `GameData.Dungeon.floors`. Floor index i = `Workspace.Map.DungeonTower.Room<i>`.
- Colours and stage names: `ReplicatedStorage.Shared.TowerThemes`, keyed by tower number (`forFloor(i)` merges the boss overrides).
- Rooms in the place file: `ServerStorage.TowerBuilder`. Its `build()` adds missing rooms (clones of Room9), fixes trainers and paints them, `paint()` re-applies the theme, and `purpleReport()` should return an empty list. After running it, save the place.
- Trainer clothes and props at runtime: [[DungeonNPCStyler]], called by [[DungeonService]] with the floor index.
- Lift glow, notifications: [[DungeonService]]. Banners and lift tint: [[DungeonClient]].
- Showcase: `ModelSyncLookup` lists DUNGEON TRAINERS for rooms 1-20. Rooms 11-20 have no `NPCBackup` copy.

## Gotchas
- `StoryService` places Juniper's journal at `Room11.StartPad` and unlocks it at DungeonFloor >= 11. Room11 kept its StartPad when it became floor 2.1.
- Saves store the floor index. A player saved on the old 2.1 rest room (index 11) now meets 2.1's trainer.
- Trainers are R15 avatars with dynamic heads. The face is on the head mesh. The old Studio build hid it under a `ClassicHead`, `Hood` and `Collar`; TowerBuilder removes those, and nothing may cover the head again.
- Cloning an `Accessory` from another NPC keeps its `AccessoryRigidConstraint`, which still points at the source NPC's head. Remove it before wearing the clone, or every rig wearing that hair is chained together and moves as one assembly. TowerBuilder's `wear()` handles this.
- In Edit tools, remove parts with `Parent = nil` rather than `Destroy()`: Studio's undo cannot restore destroyed instances.
