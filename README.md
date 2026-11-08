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
| `/fbuffs report` | Saves the api, ids, debug, catalogue and rank output to the saved variables (then `/reload`) |
| `/fbuffs debug` | Prints what is tracked, why, and its current state |
| `/fbuffs api` | Lists which game functions the addon found on this client |
| `/fbuffs ids` | Lists every spell and item ID the addon uses with the name the client resolves |

`/forbuffs` works the same as `/fbuffs`.

## The window

Opened with `/fbuffs`. Tabs down the left; ESC closes it; drag it by its title bar. Its opacity is a slider.

- **Display**: look (icons, names beside, names below), when icons show (always, only when missing, or when missing or running out), the running-out thresholds, icon size, spacing, grow direction, icons per row, High and Low sizes, window opacity.
- **Alerts**: for each priority (High, Normal, Low) a sound with a Play button, how often to repeat while the buff is missing, a raid-warning text on screen, whether the icon flashes, and a Test button. Plus "alert once when a buff is running out", combat behaviour, and hiding while mounted or resting.
- **Buffs**: every buff for your class and every group buff from other classes. Each has a Show tick (icon in the bar), a Sound tick (alerts, repeats and screen text), its rank ("Rank 3/6, next at 24", or "rank available!" when you can train a new one; hover for every rank and its level), a priority and a visibility override.
- **Consumables**: role, and for each group (elixir, flask, Well Fed, weapon oil/stone) Show and Sound ticks, where it shows (everywhere, dungeons and raids, raids only, never), priority and visibility. Each group lists its items with level, where to get it ("Alchemy 165", "Cooking", "Vendor"), its effect, and the recommended one; hover for the recipe's reagents. Tick your own pick to use a cheaper one. Groups collapse.
- **Position**: unlock/lock, reset, test mode, snap to grid, grid size, show the grid while unlocked.
- **About**: version, author, bug-report and download links.

## Priority

Every tracked buff has a priority. **High** icons are bigger with a gold border. **Low** icons are smaller. Each priority has its own sound, repeat interval, screen text and flash setting (Alerts tab). Your own buffs default to Normal; buffs other people give you and consumables default to Low, and their Sound tick starts off, so they stay quiet until you turn it on.

## Running out

With "When missing or running out", a buff stays hidden while you have it and appears when it is about to run out: buffs lasting 15 minutes or more at 5 minutes left, shorter ones at 1 minute left (both adjustable). Running-out icons get an amber border and a countdown. The countdown keeps going in combat from the end time the addon saw before the fight.

## Display styles

- **Icons**: just the icons.
- **Icons with names beside / below**: the buff name next to or under each icon.

## Consumables and recommendations

Each consumable group shows where you choose: everywhere, in dungeons and raids (the default for elixirs, food and weapon oils), in raids only (the default for flasks), or never. Once you have used one this session and it wears off, it is also reminded anywhere unless set to never. The icon and tooltip name the item recommended for your class, role and level, or your own pick. Any item in the group counts as "have it": the addon asks the game which buff each listed item gives, so new Forever items are recognised too.

Data: Wowhead's Forever item and spell data and Method's Forever consumables list (November 2026). No class-by-class Forever consumable guides exist yet, so recommendations are inferred from what each item does.

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

Consumable sources and spell ranks are generated from `docs/superpowers/research/2026-11-08-sources-and-ranks.md` by `python tools/gen_data.py`, which writes `DataGen.lua`.

New versions: commit to `main`, `git tag vX.Y.Z`, push the tag; GitHub Actions publishes the release zip.
