# Systems Overview
**Read this first if you're unsure what the game is supposed to be.** Backfilled 2026-11-05 from the claude.ai Project's Game Overview doc. Formerly "Snatch Them All" (renamed 2026-10-29; old name still appears in save keys like SnatchThemAll_Save_v1, don't rename those).

## One-line pitch
A Roblox creature-catching RPG in the spirit of classic Pokemon (Kanto-style journey: routes, gyms, badges, Elite Four, Champion), with fully original creatures, names, characters and story, plus Roblox-style base decorating and monetization inspired by Steal an Egg.

## What it is NOT
- Not a stealing/base-raiding game. No Steal a Brainrot style mechanic.
- Not a Pokemon copy. No Pokemon names, designs, characters or music.
- Not real-time combat. Battles are turn-based.
- Not pay-to-win gacha. Nothing random is sold for Robux; crates are coins only; BP is never sold.

## Core loop
1. Walk up to a wild creature, press E to battle.
2. Turn-based battle, catch by throwing a ball from inside the battle.
3. Level up, evolve, build a team.
4. Beat route trainers, then the region's gym leader, for a badge.
5. Badges unlock the next region. Repeat through the League.
6. Spend coins on balls, medicine, base decorating. Daily shop, weekly Rare Storm, story beats bring players back.

## World structure
- **Region 1 ("Maple")**: one continuous road, areas in progression order, no route teleports. Meadow Route, Boulder Pass, Glimmer Cavern, Brook Town, Tide Coast, Volt Plains, Ember Ridge, Frost Peak, Shadow Woods, Sky Spire, ending at Maple Victory Road and the League (Elite Four + Champion Kai).
- **Region 2**: second set of 8 new regions beyond the League, own Victory Road and League2, Summit Town ("Area 2") as hub.
- Unlocks gate on badge count (server-checked, not just visual). Locked regions greyed out with name + some scenery visible.
- Three route trainers per region, late, mandatory.
- Hub buildings: blue-roofed shop/awning, white Healing Center/red cross roof, dark stone dungeon fortress/purple glow.

## Creatures
40+ original species, types: Grass, Fire, Water, Electric, Rock, Ground, Flying, Dragon, Ice, Bug, Poison, Ghost, Dark, Psychic, Fairy. AI-generated stylized 3D meshes. Huge and shiny variants. Hourly region rares plus weekly Saturday Rare Storm.

## Story
Juniper (professor's daughter) joins as companion after the first heal, returns at milestones. Team Havoc is the original evil team, airship visible in the sky. Twist (secret from players): Juniper is the hidden mastermind behind Team Havoc.

## Side systems
Player base decorating (habitats, functional items, XP Canopy upgraded with coins), shop with daily rotation, Battle Coliseum (PvP, BP-only rewards), trading area, dungeon, leaderboards, owner-only admin mode.

## Monetization rules to keep
Lean pass set (DoubleCoins, DoubleXP, ExtraSlots, VIP) and dev products (Instant Heal, Summon Rare fixed-pick, timed boosts, packs). No random Robux rewards, no BP for sale. Players/retention matter more than shop breadth.

## Code map
Every script in `src/` has an auto-generated note in `Code/` showing what it requires, who requires it, and its functions. Start at [[Code Map]].

See [[Decision Log]] for the "why" behind each of these, and `claude/launch-checklist.md` for current launch-blocking tasks.
