# ForeverBuffs 1.1: priorities, consumables browser, own options window

Design document, 2026-11-08. Builds on the 1.0 design (`2026-11-07-forever-buffs-design.md`), which stays authoritative for everything not changed here. Items marked **(my call)** are the designer's decisions; Colin (the player) can override any of them.

## Intent

1.0 works in game. Colin wants: buffs that are not his own to look different (smaller) by default; a browsable list of every consumable so he can pick a cheaper one than the recommendation; a standalone, modern, translucent options window instead of a page inside Blizzard's AddOns settings; more settings rather than fewer, including a High/Normal/Low priority per buff; more sounds; and an About tab with version, author and a bug-report link, ready for a CurseForge upload. Also "optimize it".

## Goals

- Per-entry **priority** (High / Normal / Low) that controls icon size and alerting; sensible defaults that make other people's buffs and consumables visibly secondary.
- A **consumables browser** listing every flask, elixir, food and weapon oil/stone the addon knows, grouped, with the recommendation marked and a per-character pick that replaces the recommendation.
- A **standalone options window** (`/fbuffs`), tabs down the left, translucent with adjustable opacity, modern controls (dropdowns, sliders, scrolling lists, checkboxes, copyable text), ESC closes it, draggable.
- **More sounds**, chosen per priority.
- **About** tab: version, author, links, diagnostics tip.
- **Less work per second**: the 1 s ticker only re-checks what has no event (weapon enchants); nothing re-renders when nothing changed.
- Saved settings from 1.0 keep working.

## Non-goals

- No change to what counts as "present": any elixir still satisfies the Elixir entry, any flask the Flask entry, etc. (player's decision).
- No minimap button **(my call)**; the addon registers in the addon compartment (the minimap addon list) instead, see below.
- No CurseForge upload automation in this version; the TOC and README are made ready for a manual first upload.
- No new tracked buffs.

## Anti-goals

- Settings that are hard to find: every control lives in the window under a tab whose name says what it holds.
- A window that blocks play: ESC closes it, it never opens on its own, it remembers its position.
- Regressions in the 1.0 anti-goals (nagging about things the player cannot have, noise while dead/mounted/in combat, Lua errors under restrictions, heaviness).

## Priority

Each tracked entry has a priority: `"high" | "normal" | "low"`, stored per character in `ForeverBuffsCharDB.priority[key]`. Default when unset:

| Entry tracked because... | Default |
|---|---|
| the player knows the spell (own buff) | Normal |
| a group member can cast it (reason "group") | Low |
| it is a consumable | Low |

So the same entry (e.g. Fortitude) is Normal on a priest and Low on a mage standing next to a priest, unless the player sets it explicitly. An explicit setting applies regardless of reason. The 1.0 `quietFromOthers` flag is removed: Battle Shout from another warrior is simply Low by default **(my call)**.

What priority does:

| | Size | Border | Flash | Sound |
|---|---|---|---|---|
| High | `iconSize × highScale` (default 115%, slider 100–150%) | gold | always pulses when missing | plays `soundHigh` on present→missing (unless `soundHigh` is "none") |
| Normal | `iconSize` | red | per alert style (flash / both) | per alert style (sound / both), using `soundNormal` |
| Low | `iconSize × lowScale` (default 70%, slider 40–100%) | red, thinner | never | never |

Low icons still light up (full colour, red border) when missing and dim when present; they are just smaller and silent. Low wins over the "Flashing with names" style too: a Low icon never pulses, whatever the style **(my call)**. Display order stays data order **(my call)**: priority does not reorder icons. Layout uses a compact per-icon pitch (each icon advances by its own size plus spacing), so Low icons pull the row tighter; icons of different sizes align along their bottom edge for horizontal growth and their left edge for vertical growth **(my call)**. Rows wrap after `perRow` icons as before.

The priority dropdown offers a fourth choice, "Default", which clears the stored value so the reason-based default applies again **(my call)**.

The alert-style dropdown keeps its four values and now describes itself as applying to Normal priority.

## Sounds

`FB.Alerts.SOUNDS` grows to a list of Blizzard sound kits, each `{ key, name, kit }`, plus a `none` entry:

Verified against Blizzard's Mainline `SoundKitConstants.lua` (2026-11-08):

| key | name | SOUNDKIT constant | kit ID |
|---|---|---|---|
| raid_warning | Raid Warning | RAID_WARNING | 8959 |
| ready_check | Ready Check | READY_CHECK | 8960 |
| alarm1 | Alarm Clock 1 | ALARM_CLOCK_WARNING_1 | 18871 |
| alarm2 | Alarm Clock 2 | ALARM_CLOCK_WARNING_2 | 12867 |
| alarm3 | Alarm Clock 3 | ALARM_CLOCK_WARNING_3 | 12889 |
| boss_whisper | Boss Whisper | UI_RAID_BOSS_WHISPER_WARNING | 37666 |
| quest_complete | Quest Complete | IG_QUEST_LIST_COMPLETE | 878 |
| auto_quest | Auto Quest Complete | UI_AUTO_QUEST_COMPLETE | 23404 |
| pvp_queue | PvP Queue Horn | PVP_THROUGH_QUEUE | 8459 |
| whisper | Whisper | TELL_MESSAGE | 3081 |
| map_ping | Map Ping | MAP_PING | 3175 |
| invite | Player Invite | IG_PLAYER_INVITE | 880 |
| bnet_toast | Toast | UI_BNET_TOAST | 18019 |
| epic_loot | Epic Loot | UI_EPICLOOT_TOAST | 31578 |
| legendary_loot | Legendary Loot | UI_LEGENDARY_LOOT_TOAST | 63971 |
| group_application | Group Application | UI_GROUP_FINDER_RECEIVE_APPLICATION | 47615 |
| coins | Loot Coins | LOOT_WINDOW_COIN_SOUND | 120 |
| none | No sound | – | – |

Rule for the builder: define each as `{ key=, name=, constant="RAID_WARNING", kit=8959 }` and play `SOUNDKIT[constant] or kit`; the Alerts tab has a Play button beside each sound dropdown.

Settings: `soundNormal` (default `raid_warning`), `soundHigh` (default `alarm3`), both account-wide. The 1.0 `sound` key migrates into `soundNormal` once.

## Consumables browser

A catalogue, `FB.Data.CATALOGUE`, of every consumable the addon knows, grouped by category `flask | elixir | well_fed | weapon`:

`{ itemID=, name=, level=, summary= (short effect text, e.g. "+25 Intellect"), roles= set|nil (which roles it is recommended for; nil = never recommended, just listed), classes= set|nil, weapon= "edged"|"blunt"|"oil"|nil, auraIDs= {…} }`

The recommendation table from 1.0 is derived from this catalogue (rows with `roles`), so there is one source of truth. The catalogue adds the cheaper and lower-level items players actually use while levelling: at least Elixir of Minor Agility, Minor Defense, Lesser Agility, Defense, Wisdom, Greater Defense, Minor Fortitude, Frost Power, Firepower; Flask of Chromatic Resistance; the common Well Fed foods (Blessed Sunfruit, Blessed Sunfruit Juice, Runn Tum Tuber Surprise, Tender Wolf Steak, Monster Omelet, Dirge's, Grilled Squid, Nightfin, Sagefish Delight, Smoked Desert Dumplings); all sharpening stones, weightstones, wizard and mana oils. Only items whose buff is the category's buff belong in the catalogue: alcohol such as Rumsey Rum gives its own stamina buff, not Well Fed, and is excluded **(my call)**. Every catalogue item's aura ID(s) go into the category entry's `ids`, so presence detection covers everything listed (builder verifies IDs via Wowhead Forever and the player via `/fbuffs report`). Weapon oils and stones have no aura (they are temporary enchants), so their `auraIDs` is empty and the completeness test skips the `weapon` category.

**Pick**: `ForeverBuffsCharDB.pick[category] = itemID | nil`, with categories `flask | elixir | well_fed | weapon` (one weapon pick shared by main and off hand) **(my call)**. When set, the pick replaces the recommendation for the icon and tooltip ("Your pick: Lesser Wizard Oil"). The list shows a radio per item; the recommended one is marked in green; "Use recommendation" clears the pick. Presence is unchanged: any item in the category counts.

**Browser UI** (Consumables tab): role dropdown; "Show consumables" dropdown (`Raids only` / `Everywhere`); "Remind when it wears off" checkbox; a filter edit box (substring match on name, case-insensitive); then one collapsible section per category with its tracked checkbox and priority dropdown in the header, and a scrolling list of rows: radio, icon, name, level, summary, "recommended" / "your pick" tag. Items above the player's level are shown greyed but still pickable **(my call)**.

## The options window

A single frame `ForeverBuffsOptions`, 720×480 **(my call)**, parented to UIParent, strata DIALOG, movable by its title bar, position saved account-wide (`ForeverBuffsDB.windowPosition`), closed by its ✕ button and by ESC (registered in `UISpecialFrames`). Opened by `/fbuffs`, `/forbuffs`, and from the addon compartment (`## AddonCompartmentFunc` in the TOC) **(my call)**. The Blizzard Settings category from 1.0 is removed.

Look: dark translucent backdrop, default alpha 70% (`ForeverBuffsDB.windowAlpha`, slider 30–100% on the About tab and the Display tab; the alpha applies to the backdrop and borders only, never to text or icons, so the window stays readable **(my call)**), 1 px border, gold accent for the active tab and selected controls, Blizzard fonts (`GameFontNormal`, `GameFontHighlightSmall`), 6 px corner radius look via the standard backdrop edge. Tabs down the left (130 px): Display, Alerts, Buffs, Consumables, Position, About. One panel visible at a time; panels that can overflow (Buffs, Consumables) scroll with a mouse-wheel scroll frame.

Widget kit **(my call)**: the builder writes a small set of frame factories in `UI.lua`: `Checkbox(parent, label, get, set)`, `Slider(parent, label, min, max, step, get, set, formatter)`, `Dropdown(parent, label, choices, get, set)` (built on the modern `MenuUtil.CreateContextMenu`/`DropdownButton` if present on this client, else a simple custom list), `Button(parent, text, onClick)`, `EditBox(parent, text, readOnly)` for copyable links, `ScrollList(parent)` with a row pool, `SectionHeader(parent, text)`. No libraries.

Tab contents:

- **Display**: style; icon size; spacing; grow direction; icons per row; show names; **High size %**; **Low size %**; window opacity.
- **Alerts**: alert style (for Normal); Normal sound + Play; High sound + Play; combat behaviour; hide when mounted; hide when resting.
- **Buffs**: "Your buffs" section (entries whose class is the player's, including group-castable ones they know) and "From other classes" section (group entries of other classes), each row: tick, icon, name, priority dropdown, a short grey note of the effect of that priority. Entries the player has not learned yet are shown greyed with "learned at level N" **(my call)**.
- **Consumables**: as above.
- **Position**: Unlock/Lock, Reset position, Test mode, plus a live preview text of the current anchor point and offsets.
- **About**: name and version (from `C_AddOns.GetAddOnMetadata(ADDON, "Version")`), author line "colinzmulan (Claude AI assisted)" (player's decision), "Report a bug" copyable link `https://github.com/colinz-severed/ForeverBuffs/issues`, "Downloads" copyable link `https://github.com/colinz-severed/ForeverBuffs/releases`, diagnostics tip (`/fbuffs report`, then `/reload`, then send the saved-variables file), window opacity slider.

Every control change applies immediately and calls `FB.Core.Refresh()`.

## Performance

- The 1 s ticker re-checks only `weaponEnchant` entries; all aura entries are driven by `UNIT_AURA`. `State:Evaluate(opts)` gains `opts.onlyKinds = { weaponEnchant = true }`. Two exceptions keep 1.0 behaviour intact **(my call)**: the ticker still re-evaluates hide conditions (so landing from a taxi or dismounting shows the display again), and while `state.stale` is true (restricted out of combat) it does a full evaluate so the display recovers as soon as restriction lifts.
- `Display.Update` skips all frame work when a cheap signature (visible keys, their status, their priority, stale flag, hidden, unlocked, testMode, settings version counter) is unchanged since the last call **(my call)**.
- Group scan and known-spell caches from the 1.0 review stay.

## TOC and publishing readiness

- `## Author: colinzmulan`, `## X-Credits: Claude AI assisted`, `## X-Website: https://github.com/colinz-severed/ForeverBuffs`, `## X-BugReport: https://github.com/colinz-severed/ForeverBuffs/issues`, `## AddonCompartmentFunc: ForeverBuffs_OpenOptions`, `## Version: 1.1.0`.
- README gains a "Publishing to CurseForge" section: create the project on CurseForge for game version "Forever", upload the release zip from GitHub, and (optional) the `## X-Curse-Project-ID` line once the project exists.

## Saved data and migration

- `ForeverBuffsDB` adds `highScale=1.15`, `lowScale=0.7`, `soundNormal`, `soundHigh`, `windowAlpha=0.7`, `windowPosition`, `settingsVersion=2`. On first load with `settingsVersion` nil: copy `sound` into `soundNormal` if set, then set `settingsVersion=2`.
- `ForeverBuffsCharDB` adds `priority={}` and `pick={}`. Existing `enabled`, `role`, `consumablesRaidsOnly`, `consumablesRemindDrop` keep their meaning.

## Left to the builder

- Exact widget construction, textures, paddings; scroll frame mechanics.
- Which dropdown implementation the client supports (`MenuUtil` vs custom list).
- Verifying sound kit IDs and catalogue item/aura IDs (Wowhead Forever + `/fbuffs report`).
- The Display signature used to skip redundant updates.

## Testing

Unit tests as in 1.0 (fake API). New tests: priority defaults and overrides; size/border/flash/sound per priority; pick overriding recommendation; catalogue completeness (every catalogue aura ID present in its category `ids`, every recommended row present in the catalogue); migration of `sound`; `Evaluate` with `onlyKinds`; `Display.Update` no-op when unchanged; window opens/closes/tabs switch under the stub; ESC registration. In-game: Colin runs `/fbuffs report` after opening every tab and the builder reads the saved file.
