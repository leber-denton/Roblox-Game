# Decision Log
Format: **Date — Decision** — Why — Alternatives rejected.

Backfilled 2026-11-05 from the claude.ai Project's history. Individual dates weren't tracked there, so these are undated; add dates going forward.

- **Name** — Renamed from "Snatch Them All" to Creature Quest: Catch & Battle. Save keys (e.g. SnatchThemAll_Save_v1) were NOT renamed, so old saves still load.
- **Core identity** — Pokemon-spirit catch-and-battle RPG with fully original creatures, names, characters and story, not a Pokemon reskin.
- **Base mechanic** — No stealing/raiding other players' bases (rejected a "Steal a Brainrot" style mechanic). Despite the old name, players never take creatures from each other.
- **Battle system** — Turn-based, catch from inside the battle by throwing a ball. Fainted creatures heal at the Healing Center. Walk up and press E to battle.
- **Movement** — Shift to sprint; sprint speed rises a little per gym leader beaten.
- **Hub layout** — Shop, dungeon, healing center sit behind the bases for a clear view down the lanes; seven region lanes (one open in the middle, three locked each side) in the original plan, later changed (see Region 1 road decision below).
- **Progression structure** — Full original regions for all lanes (Kanto-style journey), unlocked by gym badge count, rather than a shorter structure.
- **Tutorial** — Professor-style intro, pick a Grass/Fire/Water starter (new 3-stage lines). Only forced fight is a wild Nibbit. Rival battle is NOT forced in the tutorial.
- **Route trainers** — Three per region, placed late in the region before its gym; players are forced to fight them.
- **Visual style** — Polished stylized 3D (AI-generated meshes) for creatures; real Roblox R15 avatars for NPCs (classic avatar look: real face, hair, shaded shirt and jeans), not copied from reference art.
- **Admin mode** — Owner-only, OP Lv 100 creatures for stress testing.
- **Evil team** — Original Team Havoc (not a reused IP), with their airship visible in the sky as a setup for later content.
- **Story twist** — Juniper (the professor's daughter) is secretly the mastermind behind Team Havoc, come back from the past to take over the universe. Kept secret from players; foreshadowed, not revealed early.
- **Monetization philosophy** — Coin-based decorations/boxes plus microtransactions, modeled on Steal an Egg's pass structure: 2x XP pass, Instant Heal and Summon Rare Spawn as pay-per-use boosts.
- **World layout (regions, tutorial unlocks)** — Locked regions greyed out (name + some decor visible); tutorial explains rather than forces the dungeon/shop/region-unlock systems, possibly via a quest feature.
- **Hub building look** — Blue-roofed shop with striped awning, white Healing Center with red cross roof, dark stone dungeon fortress with purple glow (matched to a reference image).
- **League** — Elite Four + Champion (rival Kai) at the end of the Region 1 route, continuing past Meadow Route; 8 brand-new regions added beyond it as a second set, built in stages.
- **Region 1 layout** — Boulder Pass moved into the side-region row; Shadow Woods is the region continuing straight on from Meadow Route.
- **Region 1 road structure** — Changed from side-by-side lanes to one continuous road, regions in progression order, no route-to-route teleports, so rare spawns are a race.
- **XP Canopy** — Starts at 0%, upgraded with coins (Steal an Egg style).
- **Battle Coliseum** — Brick Bronze-inspired: hold E to challenge, needs first badge, Battle Points earn exclusive TMs/held items. Same-server area behind a portal, plus a themed trading area the same way. Robux only buys a 2x BP pass and cosmetics; BP itself is never sold.
- **Build tooling** — Moved the build to GitHub (leber-denton/Roblox-Game), worked with Claude Code, Rojo and Graphify, specifically to cut usage.
- **Map enclosure** — Whole map enclosed so the void is never visible (start area, Coliseum, Trade Center included); mountain range fully closes off routes so Region 2 isn't visible until you walk up to it.
- **Area 2 naming** — SummitTown is "Area 2," the hub for the second set of 8 regions (lanes 9-16).

[[Code Map]] has the current script-level structure; this log is intent and "why," not implementation.
