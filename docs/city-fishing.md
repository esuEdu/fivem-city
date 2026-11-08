# city_fishing

Fishing, the city's first legal job. Anyone can fish: there is no job, boss or clocking in, only a **fishing licence**. The rules and numbers start from the Stardew Valley research ([research/stardew-fishing.md](research/stardew-fishing.md)), with our own names, text and art. Decisions were made with the server owner in a quiz (November 2026). Every number below is a starting value in `config.lua`, `shared/gear.lua`, `shared/levels.lua` or `server/config.lua`.

## Decisions

| Topic | Decided |
|---|---|
| Who fishes | Anyone, with a licence item that expires |
| Minigame | Our own NUI bar (Stardew-style): hold to raise the bar, keep the fish inside it |
| Progress | 30 levels of fishing XP, unlocks per level and a **skill tree** (1 point per level, 3 branches, one capstone) |
| Where | Any water. The **region** (ocean, deep sea, Alamo Sea, river, lake, canal) and the distance from shore decide the fish |
| Seasons | None. Region, game hour and weather decide |
| Selling | A fish market NPC with a **dynamic price** per species |
| Extras in v1 | Treasure chest, legendary fish, crab pots, frenzies and tournaments |
| Boat | Rented at the marina, or the player's own |
| App | A City OS (tablet) app |
| Fish item | Stacks by species + quality; size counts only for records and tournaments |
| Cost of a cast | Hunger and thirst, and rod durability |
| Crab pots | Saved in the database; anyone can pull them (theft is RP) |
| Events | Frenzies start on their own; tournaments run on a schedule and staff can open one |

## Licence

- Item `fishing_license`, bought at the fishing shop for $250 (`gear.licence`). Metadata: holder name, citizenid and expiry (7 real days). Buying again while one is valid extends it; using the item shows it.
- Without a valid licence of your own you can still fish, but the fish market won't buy, and police can fine it: "Fishing without a licence" in city_police's penal code ($500).
- The tablet app shows the licence and the time left.

## Gear and the shop

The fishing shop is an NPC (ox_target → ox_lib menu): licence, rods, bait, tackle, crab pots, **repair my rods** and **reset my skills**. Prices come from `shared/gear.lua`, paid cash first, then bank (`fishing-shop`, `fishing-licence`, `fishing-repair`, `fishing-respec`). Each item needs a fishing level; the Merchant branch gives a discount.

| Rod | Level | Price | Bait | Tackle slots | Durability |
|---|---|---|---|---|---|
| Starter rod | 1 | $150 | no | 0 | 150 casts |
| Fiberglass rod | 5 | $1,200 | yes | 0 | 300 |
| Carbon rod | 12 | $6,000 | yes | 1 | 500 |
| Pro rod | 22 | $20,000 | yes | 2 | 800 |

- **Durability** is in the rod's metadata; each cast takes 1. A broken rod can't cast; the shop repairs every rod you carry at $2 per point.
- **Each cast** also takes 0.4 hunger and 0.4 thirst; under 10 you're too weak to cast.
- **Bait**: using a bait item sets it on every rod that takes bait (`metadata.bait`); each cast takes one from the inventory while any is left. Worm (−50% wait), deluxe (−67% wait, bar +12), magnet (+15% chest), wild (25% chance of 2 fish), challenge (perfect = 3 fish, each escape one less, 3 escapes lose it).
- **Tackle**: using a tackle item fits it on the first rod with a free slot (`metadata.tackle`), for 20 bites (junk doesn't wear it). Spinner, trap bobber, lead bobber, sonar bobber, cork bobber, treasure hook, barbed hook, quality bobber, curiosity lure; two of the same add up (research §7).

## A catch

1. **Cast**: use the rod (E holds and releases the power bar, X puts it away). The bobber lands up to 12 m away (+1 m at levels 5, 12 and 20). The client probes for open water (rivers too) and measures the shore distance.
2. **Server check** (`city_fishing:cast`): the rod is still in the slot that was used and not broken, the bobber is within reach, hunger/thirst, not driving, a 1.5 s cooldown. The server takes the bait and a durability point and works out the **region** from the position.
3. **Wait**: the server picks the bite time (0.6–30 s, minus 0.5 s per level, bait, spinner, the Patience skill, −25% on the first bite of a cast, halved in a frenzy).
4. **Bite**: "!" and a sound; 1 s to press E. A miss starts a new wait.
5. **What bit** (`city_fishing:hook`, research §4): entries by precedence, region, hour, weather, level, shore distance and chance; with bait the list is tried twice before junk. Junk, seaweed and jellyfish come straight away, without the minigame.
6. **Minigame** (`web/index.html`): the physics run on the client, only as input. The bar size, difficulty, behaviour, chest and tackle effects come from the server.
7. **Result** (`city_fishing:finish`): caught or not, perfect, chest taken, seconds outside the bar, escapes. The server checks it's the open session, that it took at least the fastest possible catch (5.8 s) and at most 3 minutes, that the player is within 8 m of where they cast and still has the rod; then works out size, stars, XP and chest loot itself.

The game hour comes from Renewed-Weathersync's `GlobalState.currentTime`, the weather from `GlobalState.weather`.

## Regions and shore distance

| Region | Where |
|---|---|
| Ocean | Salt water inside the coast outline |
| Deep sea | Outside the coast outline (the island plus a few hundred metres); in practice from a boat |
| Alamo Sea | The salt lake |
| River | Zancudo River, Cassidy Creek / Raton Canyon |
| Lake | Land Act Reservoir, Mirror Park lake, Vinewood Lake |
| Canal | LS River canal |

- Rough polygons in `server/regions.lua`; the server decides the region from the bobber position.
- **Shore distance** 0–5: how many 4 m rings around the bobber are all open water (piers and rocks count as shore). The server caps it by region (river 3, canal 2) and the deep sea is always 5. More distance = bigger fish, more stars, less junk.

## Fish

38 species in `server/fish.lua` (server only), each with price, difficulty, behaviour (`mixed`/`smooth`/`sinker`/`floater`/`dart`), size in cm, regions, hours, weather, depth and minimum level:

- **Ocean**: anchovy, sardine, mackerel, sea bass, rockfish, red snapper, halibut, yellowtail, squid, octopus, leopard shark
- **Deep sea**: bluefin tuna, mahi-mahi, swordfish, blue marlin, mako shark
- **Alamo Sea**: tilapia, mullet, desert pupfish (and sturgeon, catfish, carp)
- **River**: rainbow trout, steelhead, chinook salmon, smallmouth bass, white sturgeon
- **Lake**: largemouth bass, bluegill, crappie, yellow perch, walleye, channel catfish, common carp
- **Canal**: carp, American eel, brown bullhead
- **Not fish**: jellyfish, seaweed, junk (can, boot, tyre, newspaper)

**Stars** (`metadata.quality`, 1–4): price ×1, ×1.25, ×1.5, ×2. Same species and stars stack.

## Legendary fish

Not one per character: **extremely rare** fish anyone can catch again. Each lives in one secret spot (a circle in `server/regions.lua`) under one hour window and weather, with difficulty 90–110.

| Fish | Where and when |
|---|---|
| Ghost Sturgeon | Alamo Sea, north shore, fog, 03–05 |
| Golden Marlin | Deep sea far off Paleto Bay, thunder, 21–04 |
| King of Zancudo | Zancudo river mouth, rain, 05–08 |
| Chiliad Rainbow | Cassidy Creek, clear, 06–08 |
| Canal Leviathan | LS River canal, rain, 00–03 |

- Chance per bite when everything matches: 0.15% + 0.01% per level + Legend lore (up to +0.15%) + curiosity lure (+0.05%) + deluxe bait (+0.03%), capped at 1.5%; the Legend Seeker capstone doubles it (and the cap).
- A crown in the minigame, XP ×5, and every player online gets a notification with the name, fish and size.

## XP, levels and skill tree

- **XP per fish**: `stars × 3 + difficulty / 3`, ×2.2 with the chest, ×2.4 if perfect, ×5 legendary (stars before the perfect bonus). Anything else 3 XP; pulling a ready crab pot 5 XP.
- **Levels 1–30**: total XP for level n is `round(100 × (n − 1)^1.9)` (level 10 ≈ 6,500, level 30 ≈ 60,000). A level makes the catch bar bigger (+5), the bite sooner and the cast longer, and unlocks gear.
- **Skill points**: 1 per level from 2 (29 in all), spent in the tablet app; a reset at the shop costs $5,000.
- **Branches** (`shared/levels.lua`; each node needs the one before it):
  - **Merchant**: better prices (5/10/15%), steady market (your sales lower the price 25/50% less), regular customer (10/20% off), showman (+25% tournament prizes). Capstone **Fishmonger**: +25% on 3★ and 4★ fish.
  - **Hunter**: steady hands (bar +8/16/24), patience (10/20% sooner), treasure nose (+5/10% chest), rare finds (+10/20% for difficulty 60+), legend lore, sonar sense. Capstone **Legend Seeker**: legendary chance ×2.
  - **Trapper**: more pots (+1/2/3), quick pots (15/30% sooner), clean pots (5/10% less junk), thrifty (30% chance a pot keeps its bait). Capstone **Mariner**: pots never catch junk and every crustacean is as likely.
- A capstone costs 3 points, needs 8 spent in its branch, and only one per character.

## Treasure chest

- Chance 15% (+15% magnet bait, +5% per treasure hook, + Treasure nose), shown 1–3 s into the minigame with its own progress bar.
- Loot (`loot` in `server/config.lua`): 1–3 rolls by weight, gated by shore distance and level: bait, scrap, copper, iron, a gold chain, a pearl, rarely a diamond ring, tackle. No cash.

## Crab pots

- Item `crab_pot` (shop, level 3). Using it at the water's edge or from a boat sets it, with one bait from the inventory (deluxe first). Saved in `city_fishing_pots`, so it survives restarts; clients spawn a buoy only when near.
- Ready after 45 real minutes (Quick pots for the owner). The catch is rolled when pulled: 20% junk, then each crustacean in turn. Salt water: lobster, crab, shrimp, oyster, mussel, clam; fresh water: crayfish, snail. Deluxe bait gives 2★.
- 3 pots per character (+ More pots). A pot left 48 hours is lost.
- **Anyone can pull any pot** (ox_target on the buoy, 4 s). Whoever pulls it gets the catch (if ready) and the pot. When it isn't the owner, the owner gets a phone notification and the server logs it.

## Fish market

- An NPC (ox_target "Sell my catch") sells every fish and crustacean in the inventory at once. Needs a valid licence of your own and standing at the NPC.
- Price = base × stars × skills × **demand**. Each species' demand starts at 1.0, drops 0.5% per fish sold by anyone (less with Steady market), never under 45%, and recovers 1% a minute. Kept in memory (resets on restart); the app's Market tab shows it.
- Paid in cash (`fishing-sell`). If city_economy refuses the payment, the fish are given back.

## Boat

- Marina at Puerto del Sol: rent a boat (`suntrap`, server-spawned with keys) for a $250 fee plus a $1,500 deposit. Returning it at the marina refunds the deposit if the boat is still whole; a lost or sunk boat keeps it. One rental per character; logging out deletes the boat and keeps the deposit.
- Players' own boats work too.

## Frenzies and tournaments

- **Frenzy**: every 20 minutes a 25% chance to start one at a random spot from `frenzy.spots`, for one species of that region that's in season at that hour, for 15–30 minutes. Everyone gets a notification and a radius blip (`GlobalState.fishingFrenzy`). Inside it only that species bites (a legendary still can) and the wait is halved.
- **Tournaments**: from `tournaments.schedule` (server clock weekday and hour) or opened by staff (`group.mod` on admin duty) from the app's Events tab, which also starts a frenzy on demand; both go to the staff log. Modes: biggest fish (cm, optionally one species), most fish, total weight (kg). Players join in the app; only catches inside the tournament's region while it runs count. The top 3 online at the end get $5,000 / $2,500 / $1,000 (`fishing-tournament`, + Showman). Results go to `city_fishing_tournaments`.

## Tablet app

`city_fishing` registers a **Fishing** app on City OS (everyone sees it):

- **Profile**: level, XP bar, free points, licence and time left, catches, legendaries, biggest fish
- **Skills**: the tree, learning nodes and the capstone
- **Collection**: every species (unknown until caught), count and best size; legendaries only appear once caught
- **Market**: today's price of each species at 1★ and how far it has dropped
- **Events**: the frenzy, the running tournament (join, time left, ranking), the schedule, the last results; the staff form
- **Crab pots**: your pots with time left and a route

## Data

- `city_fishing_profiles`: citizenid, xp, skills (JSON), caught, legendaries, biggest (JSON)
- `city_fishing_collection`: citizenid, species, count, best size, first catch
- `city_fishing_pots`: id, owner, owner name, coords, region, bait, placed_at
- `city_fishing_tournaments`: label, mode, region, species, who started it, start/end, results (JSON)

Tables are created on start (`CREATE TABLE IF NOT EXISTS`).

## Security

- The server picks the fish, its size, stars, XP and loot; the client only sends the bobber position, the shore distance (capped by region), the hook press and the minigame result.
- One cast and one session per player; a hook outside the bite window, a result faster than the fastest possible catch, too far from the cast or without the rod is refused.
- Perfect, the chest and escapes are the client's word, but a chest only counts when the server showed one, and they only change stars and XP.
- Secret spots, legendary conditions and chances stay in server files.

## Coordinates to check in game

The shop, market and marina NPCs, the boat spawn, the region polygons, the legendary spots and the frenzy spots were placed from the map without the game open. Check them with `/coords` (city_base) and fix `config.lua`, `server/regions.lua` and `server/config.lua`.

## Not in v1

Smoker and cooking, fish ponds, targeted bait, fishing contracts/orders, a tournament HUD (the ranking is in the app), an in-car dashboard view.
