# ForeverBuffs 1.2: visibility modes, per-buff toggles, intrusive alerts, snap grid, consumable sources and spell ranks

Design document, 2026-11-08. Builds on 1.0 (`2026-11-07-forever-buffs-design.md`) and 1.1 (`2026-11-08-forever-buffs-v1.1-design.md`); those stay authoritative for anything not changed here. **(my call)** marks the designer's decisions; Colin can override any of them.

## Intent

Colin used 1.1 in game. He ticked an elixir, food and oil pick and they never appeared: the consumables rule was "Raids only" and he was not in a raid. He wants:

- every buff and consumable to have its own clear "show in the bar" and "play a sound" toggles;
- control over when icons are visible, e.g. hidden until a long buff is about to run out;
- more intrusive alarms: repeating reminders (interval set per priority) and an optional raid-warning style text on screen;
- a grid with optional snapping while moving the display;
- consumables data that matches Forever (guides and Wowhead Forever show many changed and new items), plus where to get each consumable and its recipe;
- spell levels and ranks shown for buffs.

## Goals

1. Per-entry **Show** and **Sound** toggles; consumable groups get a **Show in** scope.
2. **Visibility modes**: Always / When missing / When missing or running out, globally with per-entry override, with configurable running-out thresholds.
3. **Running-out tracking** from buff end times, which keeps counting in combat from values cached before the fight.
4. **Repeat reminders** per priority, and an optional **screen warning** per priority.
5. **Snap grid** overlay while unlocked.
6. **Corrected consumables catalogue** for Forever, with sources (crafted / vendor / drop / quest), recipes, and buff IDs resolved from the game at runtime.
7. **Ranks**: each buff shows its ranks, the level each rank is learned, the player's current rank and when the next one is available.

## Non-goals

- No auto-buying, no crafting automation, no trainer automation.
- No reading of aura data in combat (still impossible); only the end times already known before the fight are used.
- No new tracked buff families.

## Anti-goals

- A setting that silently overrides another: picking an item must not change where it shows; turning Sound off must also silence the screen warning and repeats for that entry.
- Alarms during situations where they are noise: dead, ghost, taxi, mounted (if hidden while mounted), loading/grace, in combat. Repeats never fire in combat.
- Breaking a 1.1 user's settings on upgrade.

## Data model changes

### Per-character (`ForeverBuffsCharDB`)

- `show[key]` (bool, default true) and `sound[key]` (bool, default true). An entry is **tracked** only if `show or sound` and the 1.0/1.1 tracking rules allow it. Migration: an existing `enabled[key] == false` becomes `show[key] = false, sound[key] = false`; `enabled[key] == true` becomes both true. `enabled` is then dropped from use (left in the file).
- `visibility[key]` (nil = use global; else `"always" | "missing" | "expiring"`).
- `consumableWhere[category]` for `elixir | flask | well_fed | weapon` = `"everywhere" | "instances" | "raids" | "never"`. Defaults **(my call)**: elixir, well_fed, weapon `"instances"` (dungeons and raids); flask `"raids"`. Migration from 1.1: `consumablesRaidsOnly == false` → all four `"everywhere"`; otherwise defaults. `consumablesRemindDrop` keeps its meaning: a consumable seen this session that wore off is tracked anywhere unless its scope is `"never"`.
- `priority`, `pick`, `role` unchanged.

### Account-wide (`ForeverBuffsDB`)

- `look = "icons" | "names"` and `visibility = "always" | "missing" | "expiring"` replace 1.1's `style`. Migration: `grid` → icons + always; `row` → icons + missing; `names` → names + missing. Default for new installs: icons + always (the 1.1 default look).
- `expireLongSeconds = 300`, `expireShortSeconds = 60`, `longBuffSeconds = 900` (a buff whose full duration is at least `longBuffSeconds` uses the long threshold, else the short one). Sliders: long 60–900 s, short 10–300 s.
- `repeatHigh = 30`, `repeatNormal = 0` seconds (0 = off) **(my call)**; choices Off, 15, 30, 60, 120, 300.
- `screenTextHigh = true`, `screenTextNormal = false` **(my call)**.
- `alertOnExpiring = true`: an entry entering its running-out window plays its priority's sound once and shows its screen text once (if enabled), but never repeats.
- `snapToGrid = true`, `gridSize = 16` (slider 4–64), `showGridWhileUnlocked = true`.
- `settingsVersion = 3`.

## Behaviour

### Status

Entry statuses become `present | expiring | missing` (plus untracked). `expiring` = present and `expiresAt - now <= threshold`, where threshold is the long or short value chosen from the buff's full duration. Buffs without a duration (Paladin auras, Aspects, Trueshot, Righteous Fury, and anything whose duration reads 0 or secret) never become `expiring`.

End times:
- Auras: `expirationTime` and `duration` from `C_UnitAuras.GetPlayerAuraBySpellID` for the matching ID, read out of combat only, skipped if either value is secret or nil. If several matching auras exist (e.g. a rank and a group version), use the latest end time.
- Weapon enchants: remaining milliseconds from `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot).remainingTimeMs`, else the `timeLeft` of the enchant entry from `C_Item.GetWeaponEnchantInfo`; full duration from the catalogue/known value (imbues and poisons 60 min, oils and stones 30 min) **(my call)**, used only to choose long vs short threshold.
- `state.expiresAt[key]` and `state.fullDuration[key]` are cached at each evaluation. A 1 s timer updates `present ↔ expiring` from the cache in and out of combat without calling any aura API. When `expiresAt` passes in combat, the entry is shown as `expiring` with "0s" until combat ends (it cannot be confirmed missing until then) **(my call)**.

### Visibility

Per entry (override, else global):
- `always`: shown when tracked; present = dim/grey, expiring = full colour with an amber border and a countdown text, missing = full colour, red (or gold for High) border.
- `missing`: shown only when missing.
- `expiring`: shown when missing or expiring.

Test mode and unlocked mode still show every tracked entry. Priority size rules from 1.1 are unchanged.

Countdown text **(my call)**: on expiring icons, `"4m"` above 60 s, `"45s"` below, bottom-centre, updated each second.

### Alerts

Per entry, only if `sound[key]` is true:
- **present → missing**: High always alerts; Normal follows the alert style (sound / both); Low never (1.1 rules). Alert = sound (`soundHigh` / `soundNormal`) plus screen text if `screenTextHigh` / `screenTextNormal`.
- **present → expiring**: same, if `alertOnExpiring`; text "Inner Fire runs out in 5 min".
- **repeat**: while an entry stays `missing`, it alerts again every `repeatHigh` / `repeatNormal` seconds (0 = never). Repeats are suppressed in combat, while hidden, in grace, and are throttled per entry so no entry alerts more than once per 10 s **(my call)**. Several entries due in the same second produce one sound and one combined text ("Inner Fire, Fortitude missing!") **(my call)**.

Screen text: `RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])` when available, else `UIErrorsFrame:AddMessage(text, 1, 0.3, 0.1)`. Text colour from priority: High gold, Normal red.

### Snap grid

While unlocked and `showGridWhileUnlocked`, draw a full-screen grid overlay (thin lines every `gridSize` px, the centre lines brighter). On drag stop, if `snapToGrid`, round the anchor's offsets to the nearest multiple of `gridSize` before saving. Also fixes the deferred 1.1 minor: the anchor's rectangle must exactly enclose the icons for all four grow directions, so the backdrop, clamping and snapping use the real bounds.

## Consumables catalogue (Forever data)

Rebuild `Data.CATALOGUE` from Wowhead's Forever item data (`https://nether.wowhead.com/forever/tooltip/item/<id>` and `https://www.wowhead.com/forever/item=<id>`) and Method's Forever consumables list (`https://www.method.gg/wow-forever/list-of-all-consumables-and-enchants-in-wow-forever`):

- Correct names, required levels and effects per the research notes in the 1.2 plan (e.g. 21546 is Elixir of Holy Power; stones Coarse 5, Heavy 15, Solid 25, Dense 35; Lesser Mana Oil 40; all Well Fed foods changed).
- Add the Forever level 55 elixirs (Grizzly, Ferocity, Cunning, Owl, Sages, Whale, Nature Power, Greater Cleric's, Greater Mageblood, Phalanx, Greater Fortitude, Wicked Regeneration, Greater Spirit), Minor Arcane Elixir, the new Forever foods and drinks (Sage's Tea, Sunny Tea, Swiftstrike Steak, Steaming Stag Steak, Savory Turtle Stew, Savory Stag Sliders, Raptor Rouladen, Prehistoric Pulled Raptor, Mightfish Steak, Poached Sunscale Salmon, Baked Salmon), the four Hyjal flasks (marked zone-limited in the summary), and Consecrated Sharpening Stone / Blessed Wizard Oil (marked "vs undead").
- Recompute role recommendations from effects. With no Forever class guides published, the ranking is inferred from effects and the builder documents that in the data file header.
- Wizard oils are recommended to healers as well (they now add healing).

**Row additions**: `source = { kind = "crafted", profession = "Alchemy" | "Cooking" | "Blacksmithing" | "Enchanting", skill = <number>, reagents = { { itemID =, count = }, ... } }`, or `{ kind = "vendor", note = "<where>" }`, `{ kind = "drop", note = }`, `{ kind = "quest", note = }`. Rows the builder cannot source confidently get `source = nil` and show "Source: unknown".

**Runtime buff IDs**: at login and on `ITEM_DATA_LOAD_RESULT`, for each catalogue item call `C_Item.GetItemSpell(itemID)` (requesting item data first with `C_Item.RequestLoadItemDataByID` when not cached) and add the returned spell ID to the row's `auraIDs` and its category entry's `ids`. Static `auraIDs` stay as a fallback. Well Fed keeps its name match. `/fbuffs report` lists each catalogue item with its resolved spell (or "unresolved").

**UI**: the Consumables tab sections become collapsible (header click) **(my call: elixir and flask expanded, others collapsed by default)**; each item row gets a short "where" column ("Alchemy 165", "Vendor", "Drop") and a tooltip with the full source and the recipe reagents (names resolved via `C_Item.GetItemNameByID`).

## Ranks

Each non-consumable entry gets `ranks = { { id = <spellID>, rank = n, level = L }, ... }` for its main cast spell (e.g. Power Word: Fortitude ranks 1–6; Inner Fire 1–6; Arcane Intellect 1–5; Mark of the Wild 1–7; Blessings of Might/Wisdom/Kings; Battle Shout 1–7; armors, Thorns, Lightning Shield, Aspect of the Hawk, imbue spells). Levels from Wowhead Forever spell pages and the Forever spellbook data (client 1.60.1); the builder verifies IDs with `/fbuffs report`.

Buffs tab, per row **(my call)**: a "Rank" column: for own-class spells "Rank 3 / 6" (highest known), followed by "next at 24" or "rank 4 available!" (green) when the player's level already allows an unlearned rank; for other classes "6 ranks (1–54)". Hover shows a tooltip listing every rank with its level, known ranks ticked. Nothing appears in the icon bar for ranks.

## Options window changes

- **Display**: Look (Icons / Icons with names), Visibility (Always / When missing / When missing or running out), running-out thresholds (long, short, long-buff cut-off), plus the 1.1 sliders.
- **Alerts**: per priority (High, Normal): sound + Play, repeat interval, screen warning tick; Normal also keeps the alert-style dropdown; "Alert when running out" tick; a "Test alert" button per priority that plays the sound and shows the screen text.
- **Buffs**: columns Show tick, Sound tick, icon, name, Rank, Priority, Visibility (Default / Always / When missing / Running out).
- **Consumables**: per-category header with Show tick, Sound tick, **Show in** dropdown (Everywhere / Dungeons and raids / Raids only / Never), Priority, Visibility; collapsible; item rows with where-column and tooltip.
- **Position**: Snap to grid tick, grid size slider, show grid while unlocked tick; the anchor text updates live while dragging (deferred 1.1 minor).
- Dropdowns close on a click outside them (deferred 1.1 minor).

## Performance

- The 1 s timer does no API calls for aura entries: only the cached expiring update, weapon-enchant checks, and due repeats.
- The display's no-op check gets a cached per-key texture so it is not resolved twice per run (deferred 1.1 minor).

## Testing

Unit tests (fake API) for: migrations (1.1 style → look + visibility; enabled → show/sound; raidsOnly → consumableWhere); show/sound gating; consumableWhere per instance type; expiring status from durations (long vs short thresholds, no-duration buffs, secret durations ignored, in-combat countdown from cache); visibility per mode and override; repeat timing per priority, combat suppression, combined text; screen text API and fallback; snap rounding and anchor bounds for all four directions; runtime spell resolution merging into ids; ranks: current rank, next rank level, "available" flag; catalogue invariants (sorted, every recommended item present, IDs unique). In game: `/fbuffs report` after visiting every tab; the report gains catalogue spell resolution and rank checks.

## Resolutions after the builder check (all **(my call)**, following the anti-goals)

1. **Data source.** The consumables research (Wowhead Forever tooltip API + Method's Forever list, 2026-11-08) is saved in `docs/superpowers/research/2026-11-08-forever-consumables.md`. The plan has a research task for what it lacks (recipes/sources, rank IDs and levels), done with web access before the data task. Rows the research cannot source ship with `source = nil` ("Source: unknown"). `/fbuffs report` is the in-game verification round.
2. **The Sound tick is the master for anything audible or on-screen.** Priority no longer decides whether an entry makes noise; it decides which settings apply (sound, repeat, screen text, flash) and the icon size. Default of `sound[key]` when unset: **off for entries whose default priority is Low** (other classes' buffs, consumables), on otherwise. So defaults stay as quiet as 1.1, and ticking Sound always has an effect.
3. **Alert channels are independent, per priority**, replacing 1.1's single alert-style dropdown:
   - High, Normal and Low each get a sound (or "No sound"), repeat interval, screen text tick and flash tick.
   - Defaults: High = alarm3, repeat 30 s, text on, flash on. Normal = raid_warning, repeat off, text off, flash on. Low = no sound, repeat off, text off, flash off.
   - Migration from `alertStyle`: `icon` → Normal flash off and Normal sound none. `flash` → Normal sound none. `sound` → Normal flash off. `both` → unchanged. The Normal sound keeps 1.1's `soundNormal` unless it is set to none here.
   - "Alert when running out" stays one global tick.
4. **Ranks for multi-spell entries.** `ranks` is a list of ladders, one per spell family, each `{ family = "Mage Armor", spells = { { id, rank, level }, ... } }`. The Rank column shows the ladder of the best family the player knows: the first one in the entry's `iconSpells` order that is known, else the first ladder. The tooltip lists every ladder. "Rank N available!" appears if any ladder has an unlearned rank at or below the player's level.
5. **Look and names.** `look` has three values: `icons`, `names_beside` and `names_below`. It replaces both 1.1's `style = names` and `showNames`. Migration: `style = names` → `names_beside`, plus Normal flash on (keeps 1.1's always-pulse). `showNames = true` → `names_below`. Pulsing is then governed only by the per-priority flash ticks.
6. **Defaults for show/sound respect 1.0/1.1 defaults.** Unset `show[key]` falls back to `defaultEnabledByClass` / `defaultEnabled` as `enabled` did (Righteous Fury, Shadow Protection and hunter weapon oil stay off). Unset `sound[key]` follows rule 2 and is also off whenever show defaults off.
