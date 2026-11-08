# Forever consumable sources and buff rank ladders (2026-11-08)

Client 1.60.1. Sources: WH = Wowhead Forever tooltip API (`nether.wowhead.com/forever/tooltip/item|spell/<ID>`). www.wowhead.com pages return 403 to scripts and their "Created by"/"Sold by" tabs are JS-only, so recipe data comes from recipe-item and recipe-spell tooltips. WHB = wowhandbook.com Forever dumps (`/classes/<class>/` spellbook JSON, `/classes/hunter/talents/`, `/professions/<prof>/` recipe tables). Fetched 2026-11-08.

## 1. Consumable sources

Confidence: `confirmed` = WH recipe item gives required skill, recipe spell and reagents, and the reagents match WHB. `partial` = reagents confirmed on WH (recipe spell tooltip) and WHB, but WH does not publish the required skill (trainer recipes), or the source is only partly known. `unconfirmed` = no Forever source data found.

Columns: `rlvl` = required level (WH). `list` = `catalogue` (Data.lua CATALOGUE) or `research` (research file only). `req skill` = learn skill from the WH recipe item. `WHB y/g/gr` = WHB difficulty yellow/green/grey (WHB does not publish orange). `recipe spell` = WH spell that creates the item.

| itemID | name | rlvl | list | source | profession req skill | WHB y/g/gr | recipe spell | reagents (itemID xN name) | where / notes | confidence |
|---|---|---|---|---|---|---|---|---|---|---|
| 2454 | Elixir of Minor Strength | - | catalogue | crafted | Alchemy ? (WH gives no skill for trainer recipes) | 55/75/95 | 2329 | 2449 x1 Earthroot, 765 x1 Silverleaf, 3371 x1 Empty Vial | trainer recipe (WHB: no recipe item) | partial |
| 2457 | Elixir of Minor Agility | 2 | catalogue | crafted | Alchemy 50 | 80/100/120 | 3230 | 2452 x1 Swiftthistle, 765 x1 Silverleaf, 3371 x1 Empty Vial | recipe item 2553 (Recipe: Elixir of Minor Agility) | confirmed |
| 2458 | Elixir of Minor Fortitude | 2 | catalogue | crafted | Alchemy ? (WH gives no skill for trainer recipes) | 80/100/120 | 2334 | 2449 x2 Earthroot, 2447 x1 Peacebloom, 3371 x1 Empty Vial | trainer recipe (WHB: no recipe item) | partial |
| 2862 | Rough Sharpening Stone | - | catalogue | crafted | Blacksmithing ? (WH gives no skill for trainer recipes) | 15/35/55 | 2660 | 2835 x1 Rough Stone | trainer recipe (WHB: no recipe item) | partial |
| 2863 | Coarse Sharpening Stone | 5 | catalogue | crafted | Blacksmithing ? (WH gives no skill for trainer recipes) | 40/47/55 | 2665 | 2836 x1 Coarse Stone | trainer recipe (WHB: no recipe item) | partial |
| 2871 | Heavy Sharpening Stone | 15 | catalogue | crafted | Blacksmithing ? (WH gives no skill for trainer recipes) | 100/107/115 | 2674 | 2838 x1 Heavy Stone | trainer recipe (WHB: no recipe item) | partial |
| 3239 | Rough Weightstone | - | catalogue | crafted | Blacksmithing ? (WH gives no skill for trainer recipes) | 15/35/55 | 3115 | 2835 x1 Rough Stone | trainer recipe (WHB: no recipe item) | partial |
| 3240 | Coarse Weightstone | 5 | catalogue | crafted | Blacksmithing ? (WH gives no skill for trainer recipes) | 40/47/55 | 3116 | 2836 x1 Coarse Stone | trainer recipe (WHB: no recipe item) | partial |
| 3241 | Heavy Weightstone | 15 | catalogue | crafted | Blacksmithing ? (WH gives no skill for trainer recipes) | 100/107/115 | 3117 | 2838 x1 Heavy Stone | trainer recipe (WHB: no recipe item) | partial |
| 3383 | Elixir of Wisdom | 10 | catalogue | crafted | Alchemy ? (WH gives no skill for trainer recipes) | 120/140/160 | 3171 | 785 x1 Mageroyal, 2450 x2 Briarthorn, 3371 x1 Empty Vial | trainer recipe (WHB: no recipe item) | partial |
| 3389 | Elixir of Lesser Defense | 16 | catalogue | crafted | Alchemy ? (WH gives no skill for trainer recipes) | 155/175/195 | 3177 | 3355 x1 Wild Steelbloom, 3820 x1 Stranglekelp, 3372 x1 Leaded Vial | trainer recipe (WHB: no recipe item) | partial |
| 3390 | Elixir of Lesser Agility | 18 | catalogue | crafted | Alchemy 140 | 165/185/205 | 2333 | 3355 x1 Wild Steelbloom, 2452 x1 Swiftthistle, 3372 x1 Leaded Vial | recipe item 3396 (Recipe: Elixir of Lesser Agility) | confirmed |
| 3391 | Elixir of Ogre Strength | 20 | catalogue | crafted | Alchemy 150 | 175/195/215 | 3188 | 2449 x1 Earthroot, 3356 x1 Kingsblood, 3372 x1 Leaded Vial | recipe item 6211 (Recipe: Elixir of Ogre's Strength) | confirmed |
| 3726 | Big Bear Steak | 5 | catalogue | crafted | Cooking 110 | 150/170/190 | 3397 | 3730 x1 Big Bear Meat, 2692 x1 Hot Spices | recipe item 3734 (Recipe: Big Bear Steak) | confirmed |
| 3825 | Elixir of Lesser Fortitude | 25 | catalogue | crafted | Alchemy 175 | 195/215/235 | 3450 | 3355 x1 Wild Steelbloom, 3821 x1 Goldthorn, 3372 x1 Leaded Vial | recipe item 3830 (Recipe: Elixir of Lesser Fortitude) | confirmed |
| 5997 | Elixir of Minor Defense | - | catalogue | crafted | Alchemy ? (WH gives no skill for trainer recipes) | 55/75/95 | 7183 | 765 x1 Silverleaf, 2447 x1 Peacebloom, 3371 x1 Empty Vial | trainer recipe (WHB: no recipe item) | partial |
| 6373 | Elixir of Fire Power | 18 | catalogue | crafted | Alchemy ? (WH gives no skill for trainer recipes) | 165/185/205 | 7845 | 6371 x2 Fire Oil, 3356 x1 Kingsblood, 3372 x1 Leaded Vial | trainer recipe (WHB: no recipe item) | partial |
| 6888 | Herb Baked Egg | - | catalogue | crafted | Cooking ? (WH gives no skill for trainer recipes) | 45/65/85 | 8604 | 6889 x1 Small Egg, 2678 x1 Mild Spices | trainer recipe (WHB: no recipe item) | partial |
| 7964 | Solid Sharpening Stone | 25 | catalogue | crafted | Blacksmithing ? (WH gives no skill for trainer recipes) | 175/180/185 | 9918 | 7912 x1 Solid Stone | trainer recipe (WHB: no recipe item) | partial |
| 7965 | Solid Weightstone | 25 | catalogue | crafted | Blacksmithing ? (WH gives no skill for trainer recipes) | 175/180/185 | 9921 | 7912 x1 Solid Stone | trainer recipe (WHB: no recipe item) | partial |
| 8949 | Elixir of Agility | 27 | catalogue | crafted | Alchemy ? (WH gives no skill for trainer recipes) | 205/225/245 | 11449 | 3820 x1 Stranglekelp, 3821 x1 Goldthorn, 3372 x1 Leaded Vial | trainer recipe (WHB: no recipe item) | partial |
| 8951 | Elixir of Defense | 29 | catalogue | crafted | Alchemy ? (WH gives no skill for trainer recipes) | 215/235/255 | 11450 | 3355 x1 Wild Steelbloom, 3821 x1 Goldthorn, 3372 x1 Leaded Vial | trainer recipe (WHB: no recipe item) | partial |
| 9155 | Arcane Elixir | 37 | catalogue | crafted | Alchemy ? (WH gives no skill for trainer recipes) | 250/270/290 | 11461 | 8839 x1 Blindweed, 3821 x1 Goldthorn, 8925 x1 Crystal Vial | trainer recipe (WHB: no recipe item) | partial |
| 9179 | Elixir of Greater Intellect | 37 | catalogue | crafted | Alchemy ? (WH gives no skill for trainer recipes) | 250/270/290 | 11465 | 8839 x1 Blindweed, 3358 x1 Khadgar's Whisker, 8925 x1 Crystal Vial | trainer recipe (WHB: no recipe item) | partial |
| 9187 | Elixir of Greater Agility | 38 | catalogue | crafted | Alchemy ? (WH gives no skill for trainer recipes) | 255/275/295 | 11467 | 8838 x1 Sungrass, 3821 x1 Goldthorn, 8925 x1 Crystal Vial | trainer recipe (WHB: no recipe item); item itself: Dropped by: Batrider Pele'keiki | partial |
| 9206 | Elixir of Greater Strength | 48 | catalogue | crafted | Alchemy 245 | 260/280/300 | 11472 | 8838 x1 Sungrass, 8846 x1 Gromsblood, 8925 x1 Crystal Vial | recipe item 9298 (Recipe: Elixir of Giants) | confirmed |
| 9224 | Potion of Demon Slaying | 40 | catalogue | crafted | Alchemy 250 | 265/285/305 | 11477 | 8846 x1 Gromsblood, 8845 x1 Ghost Mushroom, 8925 x1 Crystal Vial | recipe item 9300 (Recipe: Potion of Demon Slaying); recipe dropped by Cenarion Hold Infantry; item itself: Dropped by: Cenarion Hold Infantry | confirmed |
| 9264 | Elixir of Shadow Power | 40 | catalogue | crafted | Alchemy 250 | 265/285/305 | 11476 | 8845 x3 Ghost Mushroom, 8925 x1 Crystal Vial | recipe item 9301 (Recipe: Elixir of Shadow Power); recipe dropped by Batrider Pele'keiki; item itself: Dropped by: Batrider Pele'keiki | confirmed |
| 12210 | Roast Raptor | 15 | research | crafted | Cooking 175 | 215/235/255 | 15855 | 12184 x1 Raptor Flesh, 2692 x1 Hot Spices | recipe item 12228 (Recipe: Roast Raptor) | confirmed |
| 12212 | Jungle Stew | 35 | catalogue | crafted | Cooking 175 | 215/235/255 | 15861 | 12202 x1 Tiger Meat, 159 x1 Refreshing Spring Water, 4536 x2 Shiny Red Apple | recipe item 12231 (Recipe: Jungle Stew) | confirmed |
| 12218 | Monster Omelet | 35 | catalogue | crafted | Cooking 225 | 265/285/305 | 15933 | 12207 x1 Giant Egg, 3713 x2 Soothing Spices | recipe item 16110 (Recipe: Monster Omelet) | confirmed |
| 12404 | Dense Sharpening Stone | 35 | catalogue | crafted | Blacksmithing ? (WH gives no skill for trainer recipes) | 230/232/235 | 16641 | 12365 x1 Dense Stone | trainer recipe (WHB: no recipe item) | partial |
| 12643 | Dense Weightstone | 35 | catalogue | crafted | Blacksmithing ? (WH gives no skill for trainer recipes) | 230/232/235 | 16640 | 12365 x1 Dense Stone | trainer recipe (WHB: no recipe item) | partial |
| 13445 | Elixir of Greater Defense | 43 | catalogue | crafted | Alchemy 265 | 280/300/320 | 17554 | 13423 x2 Stonescale Oil, 8838 x1 Sungrass, 8925 x1 Crystal Vial | recipe item 13478 (Recipe: Elixir of Superior Defense) | confirmed |
| 13447 | Elixir of the Sages | 38 | research | crafted | Alchemy 270 | 285/305/325 | 17555 | 13463 x1 Dreamfoil, 13466 x2 Plaguebloom, 8925 x1 Crystal Vial | recipe item 13479 (Recipe: Elixir of the Sages); recipe dropped by Commander Eligor Dawnbringer; item itself: Dropped by: Commander Eligor Dawnbringer | confirmed |
| 13452 | Elixir of the Mongoose | 46 | catalogue | crafted | Alchemy 280 | 295/315/335 | 17571 | 13465 x2 Mountain Silversage, 13466 x2 Plaguebloom, 8925 x1 Crystal Vial | recipe item 13491 (Recipe: Elixir of the Mongoose); recipe dropped by Commander Eligor Dawnbringer; item itself: Dropped by: Commander Eligor Dawnbringer | confirmed |
| 13453 | Elixir of Brute Force | 45 | catalogue | crafted | Alchemy 275 | 290/310/330 | 17557 | 8846 x2 Gromsblood, 13466 x2 Plaguebloom, 8925 x1 Crystal Vial | recipe item 13481 (Recipe: Elixir of Brute Force) | confirmed |
| 13454 | Greater Arcane Elixir | 47 | catalogue | crafted | Alchemy 285 | 300/320/340 | 17573 | 13463 x3 Dreamfoil, 13465 x1 Mountain Silversage, 8925 x1 Crystal Vial | recipe item 13493 (Recipe: Greater Arcane Elixir) | confirmed |
| 13510 | Flask of the Titans | 50 | catalogue | crafted | Alchemy 300 | 315/322/330 | 17635 | 8846 x30 Gromsblood, 13423 x10 Stonescale Oil, 13468 x1 Black Lotus, 8925 x1 Crystal Vial | recipe item 13519 (Recipe: Flask of the Titans); recipe dropped by General Drakkisath (4.05%) | confirmed |
| 13511 | Flask of Distilled Wisdom | 50 | catalogue | crafted | Alchemy 300 | 315/322/330 | 17636 | 13463 x30 Dreamfoil, 13467 x10 Icecap, 13468 x1 Black Lotus, 8925 x1 Crystal Vial | recipe item 13520 (Recipe: Flask of Distilled Wisdom) | confirmed |
| 13512 | Flask of Supreme Power | 50 | catalogue | crafted | Alchemy 300 | 315/322/330 | 17637 | 13463 x30 Dreamfoil, 13465 x10 Mountain Silversage, 13468 x1 Black Lotus, 8925 x1 Crystal Vial | recipe item 13521 (Recipe: Flask of Supreme Power); recipe dropped by Ras Frostwhisper (4.46%) | confirmed |
| 13513 | Flask of Chromatic Resistance | 50 | catalogue | crafted | Alchemy 300 | 315/322/330 | 17638 | 13467 x30 Icecap, 13465 x10 Mountain Silversage, 13468 x1 Black Lotus, 8925 x1 Crystal Vial | recipe item 13522 (Recipe: Flask of Chromatic Resistance); recipe dropped by Gyth (4.22%) | confirmed |
| 13810 | Blessed Sunfruit | 45 | catalogue | vendor | - | - | - | - | BoP, requires Argent Dawn Revered (WH); Classic: Argent Dawn quartermaster, vendor NPC not confirmed on Forever | partial |
| 13813 | Blessed Sunfruit Juice | 45 | catalogue | vendor | - | - | - | - | BoP, requires Argent Dawn Revered (WH); Classic: Argent Dawn quartermaster, vendor NPC not confirmed on Forever | partial |
| 13928 | Grilled Squid | 35 | catalogue | crafted | Cooking 240 | 280/300/320 | 18240 | 13755 x1 Raw Winter Squid, 3713 x1 Soothing Spices | recipe item 13942 (Recipe: Grilled Squid) | confirmed |
| 13931 | Nightfin Soup | 35 | catalogue | crafted | Cooking 250 | 290/310/330 | 18243 | 13759 x1 Raw Nightfin Snapper, 159 x1 Refreshing Spring Water | recipe item 13945 (Recipe: Nightfin Soup) | confirmed |
| 13932 | Poached Sunscale Salmon | 35 | research | crafted | Cooking 250 | 290/310/330 | 18244 | 13760 x1 Raw Sunscale Salmon | recipe item 13946 (Recipe: Poached Sunscale Salmon) | confirmed |
| 13934 | Mightfish Steak | 45 | research | crafted | Cooking 275 | 315/335/355 | 18246 | 13893 x1 Large Raw Mightfish, 2692 x1 Hot Spices, 3713 x1 Soothing Spices | recipe item 13948 (Recipe: Mightfish Steak) | confirmed |
| 13935 | Baked Salmon | 45 | research | crafted | Cooking 275 | 315/335/355 | 18247 | 13889 x1 Raw Whitescale Salmon, 3713 x1 Soothing Spices | recipe item 13949 (Recipe: Baked Salmon) | confirmed |
| 17222 | Spider Sausage | 35 | research | crafted | Cooking ? (WH gives no skill for trainer recipes) | 240/260/280 | 21175 | 12205 x2 White Spider Meat | trainer recipe (WHB: no recipe item) | partial |
| 17708 | Elixir of Frost Power | 28 | catalogue | crafted | Alchemy 190 | 210/230/250 | 21923 | 3819 x2 Wintersbite, 3358 x1 Khadgar's Whisker, 3372 x1 Leaded Vial | recipe item 17709 (Recipe: Elixir of Frost Power) | confirmed |
| 18045 | Tender Wolf Steak | 35 | catalogue | crafted | Cooking 225 | 265/285/305 | 22480 | 12208 x1 Tender Wolf Meat, 3713 x1 Soothing Spices | recipe item 18046 (Recipe: Tender Wolf Steak) | confirmed |
| 18254 | Runn Tum Tuber Surprise | 35 | catalogue | crafted | Cooking 275 | 315/335/355 | 22761 | 18255 x1 Runn Tum Tuber, 3713 x1 Soothing Spices | recipe item 18267 (Recipe: Runn Tum Tuber Surprise); recipe dropped by Pusillin (82.70%) | confirmed |
| 18262 | Elemental Sharpening Stone | 50 | catalogue | crafted | Blacksmithing 300 | 275/285/295 | 22757 | 7067 x2 Elemental Earth, 12365 x3 Dense Stone | recipe item 18264 (Plans: Elemental Sharpening Stone) | confirmed |
| 20004 | Major Troll's Blood Elixir | 53 | research | crafted | Alchemy 290 | 305/325/345 | 24368 | 8846 x1 Gromsblood, 13466 x2 Plaguebloom, 8925 x1 Crystal Vial | recipe item 20014 (Recipe: Major Troll's Blood Elixir) | confirmed |
| 20007 | Mageblood Elixir | 40 | catalogue | crafted | Alchemy 275 | 290/310/330 | 24365 | 13463 x1 Dreamfoil, 13466 x2 Plaguebloom, 8925 x1 Crystal Vial | recipe item 20011 (Recipe: Mageblood Elixir) | confirmed |
| 20452 | Smoked Desert Dumplings | 45 | catalogue | crafted | Cooking ? (WH gives no skill for trainer recipes) | 325/345/365 | 24801 | 20424 x1 Sandworm Meat, 3713 x1 Soothing Spices | WHB lists no recipe item; Classic: quest "Desert Recipe" reward (unconfirmed on Forever) | partial |
| 20744 | Minor Wizard Oil | 5 | catalogue | crafted | Enchanting ? (WH gives no skill for trainer recipes) | 30/47/65 | 25124 | 10940 x1 Strange Dust, 17034 x1 Maple Seed, 3371 x1 Empty Vial | trainer recipe (WHB: no recipe item) | partial |
| 20745 | Minor Mana Oil | 20 | catalogue | crafted | Enchanting 150 | 160/170/180 | 25125 | 11083 x1 Soul Dust, 17034 x2 Maple Seed, 3372 x1 Leaded Vial | recipe item 20752 (Formula: Minor Mana Oil) | confirmed |
| 20746 | Lesser Wizard Oil | 30 | catalogue | crafted | Enchanting 200 | 210/220/230 | 25126 | 11137 x1 Vision Dust, 17035 x2 Stranglethorn Seed, 3372 x1 Leaded Vial | recipe item 20753 (Formula: Lesser Wizard Oil) | confirmed |
| 20747 | Lesser Mana Oil | 40 | catalogue | crafted | Enchanting 250 | 260/270/280 | 25127 | 11176 x1 Dream Dust, 8831 x1 Purple Lotus, 8925 x1 Crystal Vial | recipe item 20754 (Formula: Lesser Mana Oil) | confirmed |
| 20748 | Brilliant Mana Oil | 45 | catalogue | crafted | Enchanting 300 | 310/320/330 | 25130 | 14344 x2 Large Brilliant Shard, 8831 x3 Purple Lotus, 18256 x1 Imbued Vial | recipe item 20757 (Formula: Brilliant Mana Oil) | confirmed |
| 20749 | Brilliant Wizard Oil | 45 | catalogue | crafted | Enchanting 300 | 310/320/330 | 25129 | 14344 x2 Large Brilliant Shard, 4625 x3 Firebloom, 18256 x1 Imbued Vial | recipe item 20756 (Formula: Brilliant Wizard Oil) | confirmed |
| 20750 | Wizard Oil | 40 | catalogue | crafted | Enchanting 275 | 285/295/305 | 25128 | 16204 x3 Illusion Dust, 4625 x2 Firebloom, 8925 x1 Crystal Vial | recipe item 20755 (Formula: Wizard Oil) | confirmed |
| 21023 | Dirge's Kickin' Chimaerok Chops | 45 | catalogue | crafted | Cooking 300 | 325/345/365 | 25659 | 2692 x1 Hot Spices, 9061 x1 Goblin Rocket Fuel, 8150 x1 Deeprock Salt, 21024 x1 Chimaerok Tenderloin | recipe item 21025 (Recipe: Dirge's Kickin' Chimaerok Chops) | confirmed |
| 21072 | Smoked Sagefish | 10 | catalogue | crafted | Cooking 80 | 120/140/160 | 25704 | 21071 x1 Raw Sagefish, 2678 x1 Mild Spices | recipe item 21099 (Recipe: Smoked Sagefish) | confirmed |
| 21217 | Sagefish Delight | 30 | catalogue | crafted | Cooking 175 | 215/235/255 | 25954 | 21153 x1 Raw Greater Sagefish, 2692 x1 Hot Spices | recipe item 21219 (Recipe: Sagefish Delight) | confirmed |
| 21546 | Elixir of Holy Power | 40 | catalogue | crafted | Alchemy 250 | 265/285/305 | 26277 | 6371 x3 Fire Oil, 4625 x3 Firebloom, 8925 x1 Crystal Vial | recipe item 21547 (Recipe: Elixir of Greater Firepower) | confirmed |
| 23122 | Consecrated Sharpening Stone | 50 | research | quest | - | - | - | - | BoP; WH shows no source. Classic: Argent Dawn reward for Necrotic Runes (Scourge Invasion); Forever source unknown | unconfirmed |
| 23123 | Blessed Wizard Oil | 50 | research | quest | - | - | - | - | BoP; WH shows no source. Classic: Argent Dawn reward for Necrotic Runes (Scourge Invasion); Forever source unknown | unconfirmed |
| 246948 | Distilled Firewater | 45 | research | crafted | Alchemy 250 | 260/265/270 | 1244421 | 3819 x4 Wintersbite, 8846 x2 Gromsblood, 3372 x1 Leaded Vial | recipe item 236754 (Recipe: Distilled Firewater) | confirmed |
| 247754 | Minor Arcane Elixir | - | research | crafted | Alchemy ? (WH gives no skill for trainer recipes) | 10/12/15 | 1245246 | 2447 x1 Peacebloom, 3371 x1 Empty Vial | trainer recipe (WHB: no recipe item) | partial |
| 249869 | Sunny Tea | 35 | research | crafted | Cooking 200 | 220/235/250 | 1249961 | 1645 x1 Moonberry Juice, 8838 x2 Sungrass | recipe item 249883 (Recipe: Sunny Tea) | confirmed |
| 249870 | Sage's Tea | 45 | research | crafted | Cooking 250 | 260/275/290 | 1249962 | 8766 x1 Morning Glory Dew, 13465 x2 Mountain Silversage | recipe item 249884 (Recipe: Sage's Tea) | confirmed |
| 249875 | Spicy Smoothie | 35 | research | crafted | Cooking 200 | 215/220/225 | 1249967 | 1645 x1 Moonberry Juice, 3713 x3 Soothing Spices, 4402 x1 Small Flame Sac | recipe item 249889 (Recipe: Spicy Smoothie) | confirmed |
| 249876 | Wicked Smoothie | 45 | research | crafted | Cooking 250 | 255/262/270 | 1249968 | 8766 x1 Morning Glory Dew, 3713 x4 Soothing Spices, 8146 x1 Wicked Claw | recipe item 249890 (Recipe: Wicked Smoothie) | confirmed |
| 250065 | Savory Stag Sliders | 35 | research | crafted | Cooking 225 | 230/237/245 | 1250142 | 5471 x2 Stag Meat, 2692 x3 Hot Spices | recipe item 250173 (Recipe: Savory Stag Sliders) | confirmed |
| 250068 | Savory Turtle Stew | 45 | research | crafted | Cooking 275 | 280/295/310 | 1250145 | 3712 x3 Turtle Meat, 3713 x3 Soothing Spices | recipe item 250176 (Recipe: Savory Turtle Stew) | confirmed |
| 250071 | Steaming Stag Steak | 45 | research | crafted | Cooking 275 | 280/295/310 | 1250148 | 5471 x3 Stag Meat, 3713 x4 Soothing Spices | recipe item 250179 (Recipe: Steaming Stag Steak) | confirmed |
| 250072 | Swiftstrike Steak | 45 | research | crafted | Cooking 275 | 280/295/310 | 1250149 | 12202 x3 Tiger Meat, 3713 x2 Soothing Spices | recipe item 250180 (Recipe: Swiftstrike Steak) | confirmed |
| 250075 | Prehistoric Pulled Raptor | 45 | research | crafted | Cooking 275 | 280/295/310 | 1250152 | 12184 x3 Raptor Flesh, 3713 x4 Soothing Spices | recipe item 250183 (Recipe: Prehistoric Pulled Raptor) | confirmed |
| 250076 | Raptor Rouladen | 35 | research | crafted | Cooking 225 | 230/237/245 | 1250153 | 12184 x2 Raptor Flesh, 2692 x4 Hot Spices | recipe item 250184 (Recipe: Raptor Rouladen) | confirmed |
| 250328 | Elixir of Cunning | 55 | research | crafted | Alchemy 275 | 280/282/285 | 1250777 | 13463 x3 Dreamfoil, 8846 x2 Gromsblood, 8925 x1 Crystal Vial | recipe item 250364 (Recipe: Elixir of Cunning) | confirmed |
| 250329 | Elixir of the Phalanx | 55 | research | crafted | Alchemy 250 | 255/257/260 | 1250778 | 13464 x2 Golden Sansam, 8838 x4 Sungrass, 8925 x1 Crystal Vial | recipe item 250365 (Recipe: Elixir of the Phalanx) | confirmed |
| 250333 | Greater Cleric's Elixir | 55 | research | crafted | Alchemy 195 | 200/202/205 | 1250782 | 8836 x3 Arthas' Tears, 8831 x1 Purple Lotus, 8925 x1 Crystal Vial | recipe item 250369 (Recipe: Greater Cleric's Elixir) | confirmed |
| 250335 | Elixir of Greater Fortitude | 55 | research | crafted | Alchemy 200 | 205/207/210 | 1250784 | 8838 x4 Sungrass, 8925 x1 Crystal Vial | recipe item 250371 (Recipe: Elixir of Greater Fortitude) | confirmed |
| 250336 | Elixir of Wicked Regeneration | 55 | research | crafted | Alchemy 285 | 290/292/295 | 1250785 | 13464 x3 Golden Sansam, 13463 x2 Dreamfoil, 8925 x1 Crystal Vial | recipe item 250372 (Recipe: Elixir of Wicked Regeneration) | confirmed |
| 250337 | Elixir of the Owl | 55 | research | crafted | Alchemy 280 | 285/287/290 | 1250786 | 13463 x4 Dreamfoil, 13465 x2 Mountain Silversage, 18256 x1 Imbued Vial | recipe item 250373 (Recipe: Elixir of the Owl) | confirmed |
| 250338 | Elixir of Sages | 55 | research | crafted | Alchemy 275 | 280/282/285 | 1250787 | 13463 x4 Dreamfoil, 13464 x2 Golden Sansam, 18256 x1 Imbued Vial | recipe item 250374 (Recipe: Elixir of Sages) | confirmed |
| 250341 | Greater Mageblood Elixir | 55 | research | crafted | Alchemy 175 | 180/182/185 | 1250790 | 8839 x3 Blindweed, 8836 x2 Arthas' Tears, 8925 x1 Crystal Vial | recipe item 250377 (Recipe: Greater Mageblood Elixir) | confirmed |
| 250343 | Elixir of Nature Power | 55 | research | crafted | Alchemy 285 | 290/292/295 | 1250792 | 13464 x4 Golden Sansam, 8838 x2 Sungrass, 8925 x1 Crystal Vial | recipe item 250379 (Recipe: Elixir of Nature Power) | confirmed |
| 250347 | Elixir of Greater Spirit | 55 | research | crafted | Alchemy 165 | 170/172/175 | 1250796 | 8836 x3 Arthas' Tears, 8831 x2 Purple Lotus, 8925 x1 Crystal Vial | recipe item 250383 (Recipe: Elixir of Greater Spirit) | confirmed |
| 250348 | Elixir of the Whale | 55 | research | crafted | Alchemy 275 | 280/282/285 | 1250797 | 13463 x3 Dreamfoil, 8846 x1 Gromsblood, 8925 x1 Crystal Vial | recipe item 250384 (Recipe: Elixir of the Whale) | confirmed |
| 250350 | Elixir of Ferocity | 55 | research | crafted | Alchemy 275 | 280/282/285 | 1250799 | 8846 x3 Gromsblood, 8845 x1 Ghost Mushroom, 8925 x1 Crystal Vial | recipe item 250386 (Recipe: Elixir of Ferocity) | confirmed |
| 250351 | Elixir of the Grizzly | 55 | research | crafted | Alchemy 300 | 305/307/310 | 1250800 | 8846 x3 Gromsblood, 8839 x1 Blindweed, 8925 x1 Crystal Vial | recipe item 250387 (Recipe: Elixir of the Grizzly) | confirmed |
| 274273 | Flask of Natural Accuracy | 55 | research | crafted | Alchemy 300 | 320/325/330 | 1293559 | 248822 x1 Death Lotus, 248821 x12 Demonsage, 13464 x9 Golden Sansam, 18256 x1 Imbued Vial | recipe item 274277 (Recipe: Flask of Natural Accuracy) | confirmed |
| 274274 | Flask of Natural Aggression | 55 | research | crafted | Alchemy 300 | 320/325/330 | 1293560 | 248822 x1 Death Lotus, 248821 x18 Demonsage, 13465 x6 Mountain Silversage, 18256 x1 Imbued Vial | recipe item 274278 (Recipe: Flask of Natural Aggression) | confirmed |
| 274275 | Flask of Natural Precision | 55 | research | crafted | Alchemy 300 | 320/325/330 | 1293561 | 248822 x1 Death Lotus, 248823 x12 Marefoil, 13463 x9 Dreamfoil, 18256 x1 Imbued Vial | recipe item 274279 (Recipe: Flask of Natural Precision) | confirmed |
| 274276 | Flask of Natural Swiftness | 55 | research | crafted | Alchemy 300 | 320/325/330 | 1293562 | 248822 x1 Death Lotus, 248823 x18 Marefoil, 13467 x6 Icecap, 18256 x1 Imbued Vial | recipe item 274280 (Recipe: Flask of Natural Swiftness) | confirmed |

Totals section 1: 99 rows; confirmed 69, partial 28, unconfirmed 2.

## 2. Rank ladders

`WH lvl` = "Requires level" on the WH Forever spell tooltip (tooltip name checked against the family). `WHB lvl` = learn level of that rank in the WHB Forever spellbook. `level` = level learned on Forever. `confirmed` = WH and WHB agree. `inData` = spell ID present in Data.lua `Data.entries` (`no` = not in the addon). Poisons: `kind` cast = learned spell (WH tooltip lists reagents), enchant = "Item Effect" spell that the weapon enchant uses.

| family | rank | spellID | WH lvl | WHB lvl | level | inData | confidence | note |
|---|---|---|---|---|---|---|---|---|
| Power Word: Fortitude | 1 | 1243 | 1 | 1 | 1 | yes | confirmed |  |
| Power Word: Fortitude | 2 | 1244 | 12 | 12 | 12 | yes | confirmed |  |
| Power Word: Fortitude | 3 | 1245 | 24 | 24 | 24 | yes | confirmed |  |
| Power Word: Fortitude | 4 | 2791 | 36 | 36 | 36 | yes | confirmed |  |
| Power Word: Fortitude | 5 | 10937 | 48 | 48 | 48 | yes | confirmed |  |
| Power Word: Fortitude | 6 | 10938 | 60 | 60 | 60 | yes | confirmed |  |
| Prayer of Fortitude | 1 | 21562 | 48 | 48 | 48 | yes | confirmed |  |
| Prayer of Fortitude | 2 | 21564 | 60 | 60 | 60 | yes | confirmed |  |
| Divine Spirit | 1 | 14752 | 30 | 30 | 30 | yes | confirmed | Forever change: baseline trainable at 30 (Classic: Discipline talent); WHB status "trained" |
| Divine Spirit | 2 | 14818 | 40 | 40 | 40 | yes | confirmed |  |
| Divine Spirit | 3 | 14819 | 50 | 50 | 50 | yes | confirmed |  |
| Divine Spirit | 4 | 27841 | 60 | 60 | 60 | yes | confirmed |  |
| Prayer of Spirit | 1 | 27681 | 60 | 60 | 60 | yes | confirmed |  |
| Shadow Protection | 1 | 976 | 30 | 30 | 30 | yes | confirmed |  |
| Shadow Protection | 2 | 10957 | 42 | 42 | 42 | yes | confirmed |  |
| Shadow Protection | 3 | 10958 | 56 | 56 | 56 | yes | confirmed |  |
| Prayer of Shadow Protection | 1 | 27683 | 56 | 56 | 56 | yes | confirmed |  |
| Inner Fire | 1 | 588 | 12 | 12 | 12 | yes | confirmed |  |
| Inner Fire | 2 | 7128 | 20 | 20 | 20 | yes | confirmed |  |
| Inner Fire | 3 | 602 | 30 | 30 | 30 | yes | confirmed |  |
| Inner Fire | 4 | 1006 | 40 | 40 | 40 | yes | confirmed |  |
| Inner Fire | 5 | 10951 | 50 | 50 | 50 | yes | confirmed |  |
| Inner Fire | 6 | 10952 | 60 | 60 | 60 | yes | confirmed |  |
| Arcane Intellect | 1 | 1459 | 1 | 1 | 1 | yes | confirmed |  |
| Arcane Intellect | 2 | 1460 | 14 | 14 | 14 | yes | confirmed |  |
| Arcane Intellect | 3 | 1461 | 28 | 28 | 28 | yes | confirmed |  |
| Arcane Intellect | 4 | 10156 | 42 | 42 | 42 | yes | confirmed |  |
| Arcane Intellect | 5 | 10157 | 56 | 56 | 56 | yes | confirmed |  |
| Arcane Brilliance | 1 | 23028 | 56 | 56 | 56 | yes | confirmed |  |
| Frost Armor | 1 | 168 | 1 | 1 | 1 | yes | confirmed |  |
| Frost Armor | 2 | 7300 | 10 | 10 | 10 | yes | confirmed |  |
| Frost Armor | 3 | 7301 | 20 | 20 | 20 | yes | confirmed |  |
| Ice Armor | 1 | 7302 | 30 | 30 | 30 | yes | confirmed |  |
| Ice Armor | 2 | 7320 | 40 | 40 | 40 | yes | confirmed |  |
| Ice Armor | 3 | 10219 | 50 | 50 | 50 | yes | confirmed |  |
| Ice Armor | 4 | 10220 | 60 | 60 | 60 | yes | confirmed |  |
| Mage Armor | 1 | 6117 | 34 | 34 | 34 | yes | confirmed |  |
| Mage Armor | 2 | 22782 | 46 | 46 | 46 | yes | confirmed |  |
| Mage Armor | 3 | 22783 | 58 | 58 | 58 | yes | confirmed |  |
| Demon Skin | 1 | 687 | 1 | 1 | 1 | yes | confirmed |  |
| Demon Skin | 2 | 696 | 10 | 10 | 10 | yes | confirmed |  |
| Demon Armor | 1 | 706 | 20 | 20 | 20 | yes | confirmed |  |
| Demon Armor | 2 | 1086 | 30 | 30 | 30 | yes | confirmed |  |
| Demon Armor | 3 | 11733 | 40 | 40 | 40 | yes | confirmed |  |
| Demon Armor | 4 | 11734 | 50 | 50 | 50 | yes | confirmed |  |
| Demon Armor | 5 | 11735 | 60 | 60 | 60 | yes | confirmed |  |
| Mark of the Wild | 1 | 1126 | 1 | 1 | 1 | yes | confirmed |  |
| Mark of the Wild | 2 | 5232 | 10 | 10 | 10 | yes | confirmed |  |
| Mark of the Wild | 3 | 6756 | 20 | 20 | 20 | yes | confirmed |  |
| Mark of the Wild | 4 | 5234 | 30 | 30 | 30 | yes | confirmed |  |
| Mark of the Wild | 5 | 8907 | 40 | 40 | 40 | yes | confirmed |  |
| Mark of the Wild | 6 | 9884 | 50 | 50 | 50 | yes | confirmed |  |
| Mark of the Wild | 7 | 9885 | 60 | 60 | 60 | yes | confirmed |  |
| Gift of the Wild | 1 | 21849 | 50 | 50 | 50 | yes | confirmed |  |
| Gift of the Wild | 2 | 21850 | 60 | 60 | 60 | yes | confirmed |  |
| Thorns | 1 | 467 | 6 | 6 | 6 | yes | confirmed |  |
| Thorns | 2 | 782 | 14 | 14 | 14 | yes | confirmed |  |
| Thorns | 3 | 1075 | 24 | 24 | 24 | yes | confirmed |  |
| Thorns | 4 | 8914 | 34 | 34 | 34 | yes | confirmed |  |
| Thorns | 5 | 9756 | 44 | 44 | 44 | yes | confirmed |  |
| Thorns | 6 | 9910 | 54 | 54 | 54 | yes | confirmed |  |
| Blessing of Might | 1 | 19740 | 4 | 4 | 4 | yes | confirmed |  |
| Blessing of Might | 2 | 19834 | 12 | 12 | 12 | yes | confirmed |  |
| Blessing of Might | 3 | 19835 | 22 | 22 | 22 | yes | confirmed |  |
| Blessing of Might | 4 | 19836 | 32 | 32 | 32 | yes | confirmed |  |
| Blessing of Might | 5 | 19837 | 42 | 42 | 42 | yes | confirmed |  |
| Blessing of Might | 6 | 19838 | 52 | 52 | 52 | yes | confirmed |  |
| Blessing of Might | 7 | 25291 | 60 | 60 | 60 | yes | confirmed |  |
| Blessing of Wisdom | 1 | 19742 | 14 | 14 | 14 | yes | confirmed |  |
| Blessing of Wisdom | 2 | 19850 | 24 | 24 | 24 | yes | confirmed |  |
| Blessing of Wisdom | 3 | 19852 | 34 | 34 | 34 | yes | confirmed |  |
| Blessing of Wisdom | 4 | 19853 | 44 | 44 | 44 | yes | confirmed |  |
| Blessing of Wisdom | 5 | 19854 | 54 | 54 | 54 | yes | confirmed |  |
| Blessing of Wisdom | 6 | 25290 | 60 | 60 | 60 | yes | confirmed |  |
| Blessing of Kings | 1 | 20217 | 20 | 20 | 20 | yes | confirmed | Forever change: baseline trainable at 20 (Classic: Protection talent); WHB status "trained" |
| Greater Blessing of Might | 1 | 25782 | 52 | 52 | 52 | yes | confirmed |  |
| Greater Blessing of Might | 2 | 25916 | 60 | 60 | 60 | yes | confirmed |  |
| Greater Blessing of Wisdom | 1 | 25894 | 54 | 54 | 54 | yes | confirmed |  |
| Greater Blessing of Wisdom | 2 | 25918 | 60 | 60 | 60 | yes | confirmed |  |
| Greater Blessing of Kings | 1 | 25898 | 60 | 60 | 60 | yes | confirmed | trained at 60 on Forever, no talent needed |
| Devotion Aura | 1 | 465 | 1 | 1 | 1 | yes | confirmed |  |
| Devotion Aura | 2 | 10290 | 10 | 10 | 10 | yes | confirmed |  |
| Devotion Aura | 3 | 643 | 20 | 20 | 20 | yes | confirmed |  |
| Devotion Aura | 4 | 10291 | 30 | 30 | 30 | yes | confirmed |  |
| Devotion Aura | 5 | 1032 | 40 | 40 | 40 | yes | confirmed |  |
| Devotion Aura | 6 | 10292 | 50 | 50 | 50 | yes | confirmed |  |
| Devotion Aura | 7 | 10293 | 60 | 60 | 60 | no | confirmed | rank 7; missing from Data.lua paladin_aura ids |
| Retribution Aura | 1 | 7294 | 16 | 16 | 16 | yes | confirmed |  |
| Retribution Aura | 2 | 10298 | 26 | 26 | 26 | yes | confirmed |  |
| Retribution Aura | 3 | 10299 | 36 | 36 | 36 | yes | confirmed |  |
| Retribution Aura | 4 | 10300 | 46 | 46 | 46 | yes | confirmed |  |
| Retribution Aura | 5 | 10301 | 56 | 56 | 56 | yes | confirmed |  |
| Concentration Aura | 1 | 19746 | 22 | 22 | 22 | yes | confirmed |  |
| Shadow Resistance Aura | 1 | 19876 | 28 | 28 | 28 | yes | confirmed |  |
| Shadow Resistance Aura | 2 | 19895 | 40 | 40 | 40 | yes | confirmed |  |
| Shadow Resistance Aura | 3 | 19896 | 52 | 52 | 52 | yes | confirmed |  |
| Frost Resistance Aura | 1 | 19888 | 32 | 32 | 32 | yes | confirmed |  |
| Frost Resistance Aura | 2 | 19897 | 44 | 44 | 44 | yes | confirmed |  |
| Frost Resistance Aura | 3 | 19898 | 56 | 56 | 56 | yes | confirmed |  |
| Fire Resistance Aura | 1 | 19891 | 36 | 36 | 36 | yes | confirmed |  |
| Fire Resistance Aura | 2 | 19899 | 48 | 48 | 48 | yes | confirmed |  |
| Fire Resistance Aura | 3 | 19900 | 60 | 60 | 60 | yes | confirmed |  |
| Righteous Fury | 1 | 25780 | 10 | 10 | 10 | yes | confirmed |  |
| Battle Shout | 1 | 6673 | 1 | 1 | 1 | yes | confirmed |  |
| Battle Shout | 2 | 5242 | 12 | 12 | 12 | yes | confirmed |  |
| Battle Shout | 3 | 6192 | 22 | 22 | 22 | yes | confirmed |  |
| Battle Shout | 4 | 11549 | 32 | 32 | 32 | yes | confirmed |  |
| Battle Shout | 5 | 11550 | 42 | 42 | 42 | yes | confirmed |  |
| Battle Shout | 6 | 11551 | 52 | 52 | 52 | yes | confirmed |  |
| Battle Shout | 7 | 25289 | 60 | 60 | 60 | yes | confirmed |  |
| Aspect of the Hawk | 1 | 13165 | 10 | 10 | 10 | yes | confirmed |  |
| Aspect of the Hawk | 2 | 14318 | 18 | 18 | 18 | yes | confirmed |  |
| Aspect of the Hawk | 3 | 14319 | 28 | 28 | 28 | yes | confirmed |  |
| Aspect of the Hawk | 4 | 14320 | 38 | 38 | 38 | yes | confirmed |  |
| Aspect of the Hawk | 5 | 14321 | 48 | 48 | 48 | yes | confirmed |  |
| Aspect of the Hawk | 6 | 14322 | 58 | 58 | 58 | yes | confirmed |  |
| Aspect of the Hawk | 7 | 25296 | 60 | 60 | 60 | yes | confirmed |  |
| Aspect of the Monkey | 1 | 13163 | 4 | 4 | 4 | yes | confirmed |  |
| Aspect of the Wild | 1 | 20043 | 46 | 46 | 46 | yes | confirmed |  |
| Aspect of the Wild | 2 | 20190 | 56 | 56 | 56 | yes | confirmed |  |
| Trueshot Aura | 1 | 19506 | 40 | - | WH 40 | yes | unconfirmed | Forever: Marksmanship talent in row 4 of 7 (WHB), so available from 25 if talented (derived); WHB talent text "+20 ranged AP" vs WH "+50/+75/+100, 30 min"; not in WHB spellbook; Data.lua learnLevel=60 |
| Trueshot Aura | 2 | 20905 | 50 | - | WH 50 | yes | unconfirmed |  |
| Trueshot Aura | 3 | 20906 | 60 | - | WH 60 | yes | unconfirmed |  |
| Lightning Shield | 1 | 324 | 8 | 8 | 8 | yes | confirmed |  |
| Lightning Shield | 2 | 325 | 16 | 16 | 16 | yes | confirmed |  |
| Lightning Shield | 3 | 905 | 24 | 24 | 24 | yes | confirmed |  |
| Lightning Shield | 4 | 945 | 32 | 32 | 32 | yes | confirmed |  |
| Lightning Shield | 5 | 8134 | 40 | 40 | 40 | yes | confirmed |  |
| Lightning Shield | 6 | 10431 | 48 | 48 | 48 | yes | confirmed |  |
| Lightning Shield | 7 | 10432 | 56 | 56 | 56 | yes | confirmed |  |
| Rockbiter Weapon | 1 | 8017 | 1 | 1 | 1 | yes | confirmed |  |
| Rockbiter Weapon | 2 | 8018 | 8 | 8 | 8 | no | confirmed |  |
| Rockbiter Weapon | 3 | 8019 | 16 | 16 | 16 | no | confirmed |  |
| Rockbiter Weapon | 4 | 10399 | 24 | 24 | 24 | no | confirmed |  |
| Rockbiter Weapon | 5 | 16314 | 34 | 34 | 34 | no | confirmed |  |
| Rockbiter Weapon | 6 | 16315 | 44 | 44 | 44 | no | confirmed |  |
| Rockbiter Weapon | 7 | 16316 | 54 | 54 | 54 | no | confirmed |  |
| Flametongue Weapon | 1 | 8024 | 10 | 10 | 10 | yes | confirmed |  |
| Flametongue Weapon | 2 | 8027 | 18 | 18 | 18 | no | confirmed |  |
| Flametongue Weapon | 3 | 8030 | 26 | 26 | 26 | no | confirmed |  |
| Flametongue Weapon | 4 | 16339 | 36 | 36 | 36 | no | confirmed |  |
| Flametongue Weapon | 5 | 16341 | 46 | 46 | 46 | no | confirmed |  |
| Flametongue Weapon | 6 | 16342 | 56 | 56 | 56 | no | confirmed |  |
| Frostbrand Weapon | 1 | 8033 | 20 | 20 | 20 | yes | confirmed |  |
| Frostbrand Weapon | 2 | 8038 | 28 | 28 | 28 | no | confirmed |  |
| Frostbrand Weapon | 3 | 10456 | 38 | 38 | 38 | no | confirmed |  |
| Frostbrand Weapon | 4 | 16355 | 48 | 48 | 48 | no | confirmed |  |
| Frostbrand Weapon | 5 | 16356 | 58 | 58 | 58 | no | confirmed |  |
| Windfury Weapon | 1 | 8232 | 30 | 30 | 30 | yes | confirmed |  |
| Windfury Weapon | 2 | 8235 | 40 | 40 | 40 | no | confirmed |  |
| Windfury Weapon | 3 | 10486 | 50 | 50 | 50 | no | confirmed |  |
| Windfury Weapon | 4 | 16362 | 60 | 60 | 60 | no | confirmed |  |
| Instant Poison | 1 | 8681 | 20 | 20 | 20 | yes | confirmed | cast |
| Instant Poison | 2 | 8687 | 28 | - | 28 (WH only) | no | unconfirmed | cast; WH name "Instant Poison II"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Instant Poison | 3 | 8691 | 36 | - | 36 (WH only) | no | unconfirmed | cast; WH name "Instant Poison III"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Instant Poison | 4 | 11341 | 44 | - | 44 (WH only) | no | unconfirmed | cast; WH name "Instant Poison IV"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Instant Poison | 5 | 11342 | 52 | - | 52 (WH only) | no | unconfirmed | cast; WH name "Instant Poison V"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Instant Poison | 6 | 11343 | 60 | - | 60 (WH only) | no | unconfirmed | cast; WH name "Instant Poison VI"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Instant Poison | 1 | 8679 | 20 | 20 | 20 | no | confirmed | enchant |
| Instant Poison | 2 | 8686 | 28 | - | 28 (WH only) | no | unconfirmed | enchant; WH name "Instant Poison II"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Instant Poison | 3 | 8688 | 36 | - | 36 (WH only) | no | unconfirmed | enchant; WH name "Instant Poison III"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Instant Poison | 4 | 11338 | 44 | - | 44 (WH only) | no | unconfirmed | enchant; WH name "Instant Poison IV"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Instant Poison | 5 | 11339 | 52 | - | 52 (WH only) | no | unconfirmed | enchant; WH name "Instant Poison V"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Instant Poison | 6 | 11340 | 60 | - | 60 (WH only) | no | unconfirmed | enchant; WH name "Instant Poison VI"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Deadly Poison | 1 | 2835 | 30 | 30 | 30 | no | confirmed | cast |
| Deadly Poison | 2 | 2837 | 38 | - | 38 (WH only) | no | unconfirmed | cast; WH name "Deadly Poison II"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Deadly Poison | 3 | 11357 | 46 | - | 46 (WH only) | no | unconfirmed | cast; WH name "Deadly Poison III"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Deadly Poison | 4 | 11358 | 54 | - | 54 (WH only) | no | unconfirmed | cast; WH name "Deadly Poison IV"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Deadly Poison | 5 | 25347 | 60 | - | 60 (WH only) | no | unconfirmed | cast; WH name "Deadly Poison V"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Deadly Poison | 1 | 2823 | 30 | 30 | 30 | yes | confirmed | enchant |
| Deadly Poison | 2 | 2824 | 38 | - | 38 (WH only) | no | unconfirmed | enchant; WH name "Deadly Poison II"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Deadly Poison | 3 | 11355 | 46 | - | 46 (WH only) | no | unconfirmed | enchant; WH name "Deadly Poison III"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Deadly Poison | 4 | 11356 | 54 | - | 54 (WH only) | no | unconfirmed | enchant; WH name "Deadly Poison IV"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Deadly Poison | 5 | 25351 | 60 | - | 60 (WH only) | no | unconfirmed | enchant; WH name "Deadly Poison V"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Crippling Poison | 1 | 3420 | 20 | 20 | 20 | no | confirmed | cast |
| Crippling Poison | 2 | 3421 | 50 | - | 50 (WH only) | no | unconfirmed | cast; WH name "Crippling Poison II"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Crippling Poison | 1 | 3408 | 20 | 20 | 20 | yes | confirmed | enchant |
| Crippling Poison | 2 | 11202 | 50 | - | 50 (WH only) | no | unconfirmed | enchant; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Mind-numbing Poison | 1 | 5763 | 24 | 24 | 24 | no | confirmed | cast |
| Mind-numbing Poison | 2 | 8694 | 38 | - | 38 (WH only) | no | unconfirmed | cast; WH name "Mind-numbing Poison II"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Mind-numbing Poison | 3 | 11400 | 52 | - | 52 (WH only) | no | unconfirmed | cast; WH name "Mind-numbing Poison III"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Mind-numbing Poison | 1 | 5761 | 24 | 24 | 24 | yes | confirmed | enchant |
| Mind-numbing Poison | 2 | 8693 | 38 | - | 38 (WH only) | no | unconfirmed | enchant; WH name "Mind-numbing Poison II"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Mind-numbing Poison | 3 | 11399 | 52 | - | 52 (WH only) | no | unconfirmed | enchant; WH name "Mind-numbing Poison III"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Wound Poison | 1 | 13220 | 32 | 32 | 32 | no | confirmed | cast |
| Wound Poison | 2 | 13228 | 40 | - | 40 (WH only) | no | unconfirmed | cast; WH name "Wound Poison II"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Wound Poison | 3 | 13229 | 48 | - | 48 (WH only) | no | unconfirmed | cast; WH name "Wound Poison III"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Wound Poison | 4 | 13230 | 56 | - | 56 (WH only) | no | unconfirmed | cast; WH name "Wound Poison IV"; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Wound Poison | 1 | 13219 | 32 | 32 | 32 | yes | confirmed | enchant |
| Wound Poison | 2 | 13225 | 40 | - | 40 (WH only) | no | unconfirmed | enchant; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Wound Poison | 3 | 13226 | 48 | - | 48 (WH only) | no | unconfirmed | enchant; WHB lists only Rank 1, learnability on Forever unconfirmed |
| Wound Poison | 4 | 13227 | 56 | - | 56 (WH only) | no | unconfirmed | enchant; WHB lists only Rank 1, learnability on Forever unconfirmed |

Totals section 2: 192 rows; confirmed 159, unconfirmed 33.

## Notes

- Not on Forever (absent from the WHB paladin spellbook, matches the Data.lua comment): Blessing of Salvation, Blessing of Light and their Greater versions.
- WHB rogue spellbook has a new "Occult Poison II" (learned at 60, counts as Deadly Poison); spell ID not found, not tracked.
- WHB lists each poison as one learned spell, Rank 1 only (Instant 20, Crippling 20, Mind-numbing 24, Deadly 30, Wound 32). WH still has the Classic II-VI spells with required levels; whether they are learnable on Forever is unconfirmed. Data.lua castIDs mix one cast spell (8681) with enchant IDs (3408, 5761, 2823, 13219).
- The level-55 Forever elixirs have low skill requirements (for example Greater Mageblood Elixir: WH req skill 175, WHB 180/182/185).
- WH lists item drops for Elixir of the Mongoose 13452 and Elixir of the Sages 13447 (Commander Eligor Dawnbringer) and Elixir of Greater Agility 9187 and Elixir of Shadow Power 9264 (Batrider Pele'keiki).
- `inData = no` on shaman imbue and poison ranks is expected (weapon enchants are tracked by enchant presence, castIDs hold rank 1 only). Devotion Aura rank 7 (10293) is a real gap: the paladin_aura entry tracks by aura ID.
- Recipe-item vendors are not in the WH tooltips; only drop sources are listed where WH shows them.
