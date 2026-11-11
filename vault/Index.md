# Creature Quest Vault — Start Here

This vault lives in the `Roblox-Game` repo so Claude + Graphify can read it from GitHub.

## Map
- [[Systems/Systems Overview]] — how each game system works
- [[Decisions/Decision Log]] — why we chose X over Y
- [[Pipeline/Dev Pipeline]] — how we build and ship
- [[Todo/Current Priorities]] — what's next
- [[Systems/Architecture Map]] — layers and how systems talk ([[BattleService]], [[SaveService]])
- [[RegionPaths]], [[RegionTerrainBuilder]], [[RegionPathValidator]], [[RegionDecorator]]: region road data and the terrain tools (Theming Overhaul)
- [[RegionStyle]], [[RegionRollout]], [[RouteWalker]]: route-theme data, coordinated rollout, and the Play validation gate
- [[DarkTower]]: the two-tower dungeon, TowerThemes and TowerBuilder (Overhaul Phase 4)
- [[MountainLookouts]], [[ObstacleCourses]]: part-built mountains with summit trails, and the optional parkour courses with coin chests
- [[Code Map]] — every script, its dependencies and dependents (auto-generated)

## Rules for notes
1. One topic per note, plain markdown.
2. Name a note after the script/system it describes (`PetSpawner.md` ↔ `PetSpawner.lua`).
3. Link related notes with [[wikilinks]].
4. Raw thoughts go in `Inbox/`; Claude helps sort them later.
