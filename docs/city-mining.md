# city_mining

Mining, the second legal job after fishing. Anyone with a **mining licence** can mine, pan and sell; there is no job or boss. The design mixes New World (shared veins that come back, tiers unlocked by level, a refining chain, a public smelter) with Stardew Valley (geodes, a skill tree with one "profession", hidden daily luck). Decisions were made with the server owner in quizzes (November 2026) and live in the design doc "Mineração: Stardew Valley × New World", tab "Implementação no servidor". Every number below is a starting value in `config.lua`, `shared/gear.lua`, `shared/levels.lua` or `server/config.lua`, to be tuned after the first test.

Targets the numbers come from: about **$3,000/h** for a tier 1 beginner selling raw ore, about **$12,000/h** at the top (tier 4 + smelting + geodes), about **15 s per vein**, and **level 30 in about 80 hours** (tier 4 at level 24 around 50 h).

## Where

Veins sit only on **points placed by hand** with `/miningpoints` (staff, `group.admin` on admin duty): aim at the ground, E saves a point for the chosen region and kind (vein, gravel, passage), G / H change region / kind, DEL removes the nearest. Points are saved in `city_mining_points`; a region's area (centre, radius, blip) is worked out from its points, so no coordinates have to be guessed in config. A region holds about a third fewer veins than points, so a new vein always appears somewhere else (rotation).

| Region (`Config.Regions`) | Tiers | Active veins |
|---|---|---|
| Davis Quartz quarry | 80% T1, 20% T2 | 25 |
| Grand Senora canyons | 60% T1, 40% T2 | 15 |
| Tataviam Highlands | T2 | 15 |
| Great Chaparral mine (gallery, blocked passage) | T3 | 10 |
| Mount Gordo | T3 | 10 |
| San Chianski | T3 | 10 |
| Mount Chiliad | T4 | 8 |
| Cassidy Creek, Raton Canyon, Alamo Sea (gravel) | panning | 4 each |

NPCs (check the coordinates in game): mining shop at the Davis Quartz office, smelter and ore buyer at Stoner Cement Works, the jeweller inside Vangelico, and the crime buyer, who moves every day between three hidden points in Grand Senora (`server/config.lua` `crime.points`).

## Veins

| Tier | Ore | Ore per vein | XP | Respawn | Level |
|---|---|---|---|---|---|
| T1 | copper or iron (+ coal 35%) | 2–5 | 10 | 4 min | 1 |
| T2 | silver or quartz (+ saltpeter 30%) | 2–4 | 14 | 6 min | 8 |
| T3 | gold (+ rough gem 6%) | 1–3 | 20 | 10 min | 16 |
| T4 | platinum (+ rough gem 8%) | 1–3 | 28 | 15 min | 24 |

- Each region is replicated in its own `GlobalState['mining:<region>']` (only the active veins); it changes only when a vein is taken or appears. Clients create the rocks as **local objects** within 90 m (ox_target on them) and draw a coloured glow only within 15 m.
- Mining: `city_mining:start` (vein id: distance, level, pickaxe tier, passage) → the strike minigame (5 strikes, a marker sweeps the bar; a hit inside the zone, perfect inside its centre) → `city_mining:finish` (session, perfect strikes). The server checks the time (at least 12 s × pickaxe and skill speed), rolls the drop (`server/rolls.lua`), wears the pickaxe and gives XP. First to finish takes the vein.
- Perfect strikes raise the chance of the top of the range; 5 of 5 add one ore and +1% geode. Above 80 veins in the last hour extra ore and geode chances halve; above 120 a vein gives only the minimum.
- Geodes: 3% per T1–T2 vein, 4% deep geode on T3, 5% ancient geode on T4 (and 2% of the tier below).
- **Super rocks**: every 30 min, 40% chance of one boulder in each T1–T2 region with none. Only dynamite breaks it: 15–25 ore, 25% geode, 60 XP; what doesn't fit drops on the ground.

## Licences, tools and safety gear

The shop sells, repairs (40% of the price for a fully worn tool) and resets skills ($5,000). Paid cash first, then bank.

| Item | Price | Level | Durability | Effect |
|---|---|---|---|---|
| `mining_license` | $500 / 7 days | – | – | Needed to sell ore and use the smelter |
| `explosives_license` | $2,000 / 14 days | 16 | – | Sold only to characters an officer granted the **Explosives** licence in the MDT (`metadata.licences.explosives`) |
| `pickaxe` (T1) | $250 | 1 | 120 veins | base speed |
| `steel_pickaxe` (T2) | $2,500 | 8 | 250 | −10% time |
| `hardened_pickaxe` (T3) | $9,000 | 16 | 400 | −20% time |
| `diamond_pickaxe` (T4) | $25,000 | 24 | 600 | −30% time |
| `gold_pan` | $400 | 1 | 200 pans | |
| `sluice_box` | $8,000 | Golden Pan capstone | – | works a gravel spot every 30 s for up to 60 min while you stay within 15 m |
| `mining_helmet` | $1,200 | 1 | – | used to put on: a lamp, cave-in damage 15 instead of 40 |
| `mining_gloves` | $800 | 1 | – | tools wear 25% slower while carried |
| `mining_boots` | $1,000 | 1 | – | +10% run speed carrying over 60% of the weight limit |
| `home_furnace` | $25,000 | 10 | – | see smelting |

## Smelting

| Ingot | Recipe | Price (stamped) | Smelter time / fee each | XP each |
|---|---|---|---|---|
| `copper` | 4 copper ore + 1 coal | $95 | 20 s / $5 | – |
| `iron` | 4 iron ore + 1 coal | $115 | 30 s / $6 | – |
| `steel` | 2 iron + 2 coal | $300 | 60 s / $15 | 3 |
| `silver_bar` | 4 silver ore + 1 coal | $210 | 45 s / $10 | 3 |
| `goldbar` | 4 gold ore + 1 silver bar + 2 coal | $780 | 90 s / $40 | 6 |
| `platinum_bar` | 4 platinum ore + 1 gold bar + 2 coal | $1,950 | 120 s / $100 | 10 |

- **Public smelter**: one order per character (up to 50, more with Big Batches), saved in `city_mining_orders` with its ready time; collect within 48 h. Ingots used as inputs must be stamped. Output is **stamped**: `metadata.stamped`, `serial` (per order) and `smeltedBy`, shown in the description (police see it in a search).
- **Home furnace**: installed by using the item inside a qbx_properties property you own or have keys to (`metadata.currentPropertyId`), saved in `city_mining_furnaces`. 3× slower, up to 10, no fee, only copper, iron, steel, gunpowder (3 saltpeter + 1 coal) and homemade dynamite (2 gunpowder + 1 metal scrap). Output is unstamped. The owner can pack it up.
- Coal drops from T1 veins and is sold at the smelter for $30.

## Selling

- **Ore buyer** (smelter, licence needed): coal $12, copper ore $15, iron ore $20, quartz $30, saltpeter $35, silver ore $40, nugget $60, gold ore $90, platinum ore $180 and the ingots above; unstamped ingots get 60%. Every unit sold lowers that item's price by 0.3% (ingots 1%), never under 50%, recovering 1% a minute (`server/demand.lua`). Reason `mining-sell`.
- **Vangelico** buys gems, jewellery and collectibles (`mining-jeweler-sell`).
- **Crime buyer**: unstamped ingots at 110% of the stamped price, gunpowder $90, dynamite $1,500, gold nuggets, gems and jewellery at half price (`mining-crime`).

## Vangelico

| Geode | Open fee | Average value inside | XP |
|---|---|---|---|
| `geode` | $50 | ~$150 | 5 |
| `deep_geode` | $150 | ~$500 | 15 |
| `ancient_geode` | $400 | ~$1,500 | 30 |

- The contents are rolled on the server when the geode is opened (`server/config.lua` `geodes`); a closed geode can be traded.
- **Cutting** (an NPC for now; a jeweller job can take over): 15% of the cut price, 5 minutes. 8% chance to break into `gem_dust` (Gemologist 3%); 1/2/3 stars at 60/30/10% (Gemologist 40/40/20); stars multiply the price ×1 / ×1.4 / ×2 and are kept in `metadata.quality`.

| Gem | Rough | Cut (1★) |
|---|---|---|
| Amethyst | $80 | $150 |
| Topaz | $100 | $190 |
| Emerald | $300 | $600 |
| Ruby | $350 | $700 |
| Diamond | $900 | $1,800 |

- **Jewellery** ($150 and 10 minutes; the gem's stars carry over; ingots must be stamped): silver ring (silver bar + amethyst) $500, emerald necklace (gold bar + emerald) $1,650, ruby ring (gold bar + ruby) $1,800, gold chain (2 gold bars) $1,900, golden watch (2 gold bars + topaz) $2,100, diamond ring (gold bar + diamond) $3,000, platinum watch (platinum bar + diamond) $4,800.
- Collectibles: ancient coin $400, fossil $600, old relic $800, Heart of the Mountain $15,000.

## Panning

- Gravel spots in the rivers rotate and run out like veins (12 points per river, 4 active, back after 3 min). A pan at a spot: the band minigame (hold E to keep the marker inside a drifting band, about 16 s), at least 12 s, then a 3 s wait. Losing the band makes junk likelier.
- Drops: metal scrap 35%, copper/iron/silver ore 35%, gold nugget 25%, river geode 3%, rough amethyst/topaz 1.5%, ancient coin/relic 0.5%. 4 XP.

## Dynamite and danger

- **Legal**: the police grant the Explosives licence in the MDT, the shop sells the card, the smelter sells dynamite ($600, 3 a day per character, logged).
- **Illegal**: homemade dynamite from the home furnace; 10% chance it goes off early (60 damage).
- Uses: break a super rock, open the Great Chaparral passage for 20 minutes (its veins can't be mined while it's closed), or set it off anywhere (using the item): a visual blast that hurts nobody; outside the mining regions it sends a police call (`exports.city_police:Alert`).
- **Cave-ins** in gallery regions: every 10 minutes 5% (25% within 3 minutes of a blast). Players inside get an 8 s warning; those still inside take 40 damage (15 with the helmet on), are trapped for up to 60 s (`Player(src).state.miningTrapped`) unless someone digs them out (ox_target on the player), and the passage closes.

## Levels and skills

Same curve and code as fishing: 30 levels, XP = 100 × (level − 1)^1.9, one skill point per level from 2, four branches of 9 ranks, a capstone costs 3 points, needs 8 in its branch, only one capstone. Learned in the **Mining** tablet app (also profile, tiers, buyer prices, open orders and vein tracking).

| Branch | Nodes | Capstone |
|---|---|---|
| Miner | speed −5/−10/−15% · +1 ore 15/30% · pickaxe wear −15/−30% · coal and saltpeter +25/+50% | Master Miner: +1 ore per vein |
| Geologist | geodes +15/+30/+45% · gems +15/+30% · tracking (veins within 80 m as blips for a minute) · rare +10/+20/+30% | Gemologist: gems +25% and better cutting |
| Smelter | smelting time −15/−30/−45% · coal −25/−50% · batch +25/+50% · ingot price +5/+10% | Blacksmith: 15% chance of an extra ingot each |
| Panner | pan time −10/−20/−30% · nuggets +15/+30% · river geodes +50/+100% · wait −25/−50% | Golden Pan: the sluice box and double nuggets |

**Daily luck**: rolled on the server each day between −20% and +30%, never shown. It multiplies rare finds, geodes, gems, nuggets and 3-star chances, and at the extremes moves the top of a vein's range by one.

## Items and images

The existing `copper`, `iron`, `steel`, `goldbar`, `diamond`, `goldchain`, `diamond_ring` and `rolex` are reused (ingots, the cut diamond, jewellery; their weights changed). New items are in `city_inventory/data/items.lua` under "Mining". Images are placeholders (existing pictures) until the real ones are made: pickaxes ×4, gold pan, sluice box, helmet, gloves, boots, the two licence cards, dynamite, homemade dynamite, home furnace, gunpowder, copper/iron/silver/gold/platinum ore, coal, quartz, saltpeter, gold nugget, silver and platinum bars, the three geodes, five rough and four cut gems (and `diamond.png`), gem dust, silver ring, emerald necklace, ruby ring, platinum watch, ancient coin, old relic, fossil, Heart of the Mountain.

## Data

- `city_mining_points` (staff points), `city_mining_profiles` (XP, skills, stats, today's dynamite; written every minute and on logout), `city_mining_orders` (smelting, cutting, jewellery), `city_mining_furnaces`. All created at start.
- Money reasons in `city_economy`: credits `mining-sell`, `mining-jeweler-sell`, `mining-crime`; debits `mining-shop`, `mining-licence`, `mining-explosives-licence`, `mining-repair`, `mining-respec`, `mining-smelter`, `mining-coal`, `mining-dynamite`, `mining-geode`, `mining-jeweler`.

## To check in game

Coordinates of the NPCs and crime points, the rock and prop models (`prop_rock_4_*`, `prop_tool_pickaxe`, `prop_tool_hardhat`, `prop_copper_pan`), and the first points in each region with `/miningpoints`. Nothing spawns until points are placed.
