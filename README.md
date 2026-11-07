# ForeverBuffs

A small World of Warcraft: Forever addon that shows an icon for every important buff you are missing: your own class self-buffs (Inner Fire, Demon Armor, Aspects, weapon imbues, poisons...), group buffs that someone in your party or raid can actually cast (Fortitude, Intellect, Mark of the Wild, Blessings, Battle Shout), and optionally consumables (flask, elixir, Well Fed, weapon oil or stone) with a recommendation for your class, role and level.

## Install

Copy this folder to `World of Warcraft\_forever_\Interface\AddOns\ForeverBuffs` (the folder must contain `ForeverBuffs.toc`). Reload the UI or log in.

## Commands

| Command | What it does |
|---|---|
| `/fbuffs` | Opens the options panel (also under Game Menu > Options > AddOns) |
| `/fbuffs unlock` | Shows every tracked icon on a backdrop so you can drag the display |
| `/fbuffs lock` | Locks and saves the position |
| `/fbuffs test` | Toggles test mode: every tracked buff shows as missing |
| `/fbuffs reset` | Puts the display back in the default spot |
| `/fbuffs debug` | Prints what is tracked, why, and its current state |
| `/fbuffs api` | Lists which game functions the addon found on this client |
| `/fbuffs ids` | Lists every spell and item ID the addon uses with the name the client resolves |

`/forbuffs` works the same as `/fbuffs`.

## Display styles

- **Always-on grid** (default): every tracked buff stays on screen. Buffs you have are grey and dim; missing ones light up with a red border.
- **Plain row**: only missing buffs, red border, nothing else.
- **Flashing with names**: only missing buffs, pulsing, with the buff name beside each icon.

Alert styles: icon only, flash, sound, or both. Sound plays once when a buff you had drops off, at most once per buff every 30 seconds. Battle Shout from another warrior never flashes or sounds, because it only lasts a few minutes.

## Consumables and recommendations

Flask, elixir, Well Fed and weapon oil/stone reminders are shown inside raid instances, and anywhere once you have used one this session and it wears off. Both rules are toggles. The icon and tooltip name the item recommended for your class, role and level; any flask, elixir, food or weapon enhancement still counts as "have it". Set your role (Caster, Melee, Healer, Tank) in the options.

## Combat

Forever hides buff data from addons during combat, so the display freezes at its last known state when you enter combat and updates the moment combat ends. You can choose to hide it in combat instead. If the game also restricts buff data out of combat somewhere, a small "?" appears next to the display to show it may be stale.

## First-run checklist (in game)

The spell and item IDs were taken from Wowhead's Forever database and spot-checked, but the full list is verified in game. With the game running:

1. `/reload`, then `/console scriptErrors 1`
2. `/fbuffs api` and paste the output (every line should say OK)
3. `/fbuffs ids`, run it twice, and paste the output (look for UNKNOWN lines)
4. `/fbuffs test` shows every tracked icon; `/fbuffs unlock`, drag it, `/fbuffs lock`, `/reload`, position kept
5. `/fbuffs` opens the options panel; try each of the three styles
6. Cast your self-buff: the icon dims (grid) or disappears (row). Cancel it: the icon lights up, and with alert style Sound a sound plays once
7. Hover the Elixir, Well Fed and Weapon icons in test mode: the tooltip names the recommended item; change Role in options and it changes
8. Join a party with another class: the group buff icon appears only for classes present
9. Enter combat briefly: no errors, display frozen; leave combat: display updates
10. `/fbuffs debug` and paste the output (it includes what both weapon-enchant APIs report, which settles whether imbues and poisons are detected)

## Development

Tests run outside the game under Lua 5.1 via Python's `lupa` package:

```
python -m pip install lupa
python tests/run_tests.py
```
