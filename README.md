# ForeverBuffs

A small World of Warcraft: Forever addon that shows an icon for every important buff you are missing: your own class self-buffs (Inner Fire, Demon Armor, Aspects, weapon imbues, poisons...), group buffs that someone in your party or raid can actually cast (Fortitude, Intellect, Mark of the Wild, Blessings, Battle Shout), and optionally consumables (flask, elixir, Well Fed, weapon oil or stone) with a recommendation for your class, role and level.

Author: colinzmulan (Claude AI assisted).

## Install

**With WowUp (gets updates automatically):** in WowUp pick your Forever installation, choose *Get Addons > Install from URL*, paste `https://github.com/colinz-severed/ForeverBuffs` and click Install. WowUp then offers each new release as an update.

**By hand:** download the latest `ForeverBuffs-vX.Y.Z.zip` from the [Releases page](https://github.com/colinz-severed/ForeverBuffs/releases), and extract it into `World of Warcraft\_forever_\Interface\AddOns\` so that you end up with `...\AddOns\ForeverBuffs\ForeverBuffs.toc`. Reload the UI or log in.

## Commands

| Command | What it does |
|---|---|
| `/fbuffs` | Opens the ForeverBuffs window (also from the minimap addon list) |
| `/fbuffs unlock` | Shows every tracked icon on a backdrop so you can drag the display |
| `/fbuffs lock` | Locks and saves the position |
| `/fbuffs test` | Toggles test mode: every tracked buff shows as missing |
| `/fbuffs reset` | Puts the display back in the default spot |
| `/fbuffs report` | Saves the api, ids and debug output to the saved variables (then `/reload`) |
| `/fbuffs debug` | Prints what is tracked, why, and its current state |
| `/fbuffs api` | Lists which game functions the addon found on this client |
| `/fbuffs ids` | Lists every spell and item ID the addon uses with the name the client resolves |

`/forbuffs` works the same as `/fbuffs`.

## The window

Opened with `/fbuffs`. Tabs down the left; ESC closes it; drag it by its title bar. Its opacity is a slider.

- **Display**: style, icon size, spacing, grow direction, icons per row, names, High and Low sizes, window opacity.
- **Alerts**: alert style for Normal priority, a sound for Normal and a sound for High (17 game sounds plus none), combat behaviour, hide while mounted or resting.
- **Buffs**: every buff for your class and every group buff from other classes, each with an on/off tick and a priority.
- **Consumables**: role, where consumables show, and the full list of flasks, elixirs, foods and weapon oils or stones. The recommended one is marked; tick your own pick to use a cheaper one instead.
- **Position**: unlock/lock, reset, test mode.
- **About**: version, author, bug-report and download links.

## Priority

Every tracked buff has a priority. **High** icons are bigger with a gold border, always flash, and play the High sound. **Normal** icons follow the alert style. **Low** icons are smaller and never flash or sound. Your own buffs default to Normal; buffs other people give you and consumables default to Low, so they look secondary at a glance. Change any of them in the Buffs or Consumables tab.

## Display styles

- **Always-on grid** (default): every tracked buff stays on screen. Buffs you have are grey and dim; missing ones light up with a red border.
- **Plain row**: only missing buffs, red border, nothing else.
- **Flashing with names**: only missing buffs, pulsing, with the buff name beside each icon.

## Consumables and recommendations

Flask, elixir, Well Fed and weapon oil/stone reminders are shown inside raid instances, and anywhere once you have used one this session and it wears off. Both rules are toggles. The icon and tooltip name the item recommended for your class, role and level, or the one you picked in the Consumables tab. Any flask, elixir, food or weapon enhancement still counts as "have it".

## Combat

Forever hides buff data from addons during combat, so the display freezes at its last known state when you enter combat and updates the moment combat ends. You can choose to hide it in combat instead. If the game also restricts buff data out of combat somewhere, a small "?" appears next to the display to show it may be stale.

## Reporting a bug

Open an issue at https://github.com/colinz-severed/ForeverBuffs/issues. If something looks wrong in game, type `/fbuffs report`, then `/reload`, and attach the file `World of Warcraft\_forever_\WTF\Account\<your account>\SavedVariables\ForeverBuffs.lua`.

## Publishing to CurseForge

1. Create a project on CurseForge for World of Warcraft, game version "Forever", named ForeverBuffs, and upload the release zip from the GitHub releases page.
2. Once the project exists, add `## X-Curse-Project-ID: <id>` to `ForeverBuffs.toc` so addon managers can match the folder to the project.
3. Each later release: tag a version in git (GitHub builds the zip), then upload that zip to CurseForge.

## Development

Tests run outside the game under Lua 5.1 via Python's `lupa` package:

```
python -m pip install lupa
python tests/run_tests.py
```

New versions: commit to `main`, `git tag vX.Y.Z`, push the tag; GitHub Actions publishes the release zip.
