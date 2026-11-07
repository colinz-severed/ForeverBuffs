# ForeverBuffs: missing-buff reminder for World of Warcraft: Forever

Design document, 2026-11-07. Written from a conversation with Colin (the player who asked for it). Items marked **(my call)** are the designer's decisions, not the player's; the player can override any of them.

## Intent

A small, WeakAura-like addon for WoW: Forever that shows an icon for each important long-duration buff the player is missing. The main job is "don't let me forget to put my own buffs on myself" (Inner Fire, Demon Armor, Aspect, weapon imbue, poisons, etc.). The second job is "somebody in my group can give me this and hasn't" (Fortitude, Intellect, Mark, Blessing, Battle Shout), but only when someone present actually has that spell at their level. Third, optional: flasks, elixirs and Well Fed.

The player currently runs EllesmereUI, whose buff-reminder module on Forever covers only four group buffs and nothing self-cast. This addon is standalone and must not depend on EllesmereUI or any library.

## Goals

- Show, at a glance, which tracked buffs are missing from the player right now.
- Track the player's own self-buffs per class, only once the spell has been learned.
- Track group buffs only when a party/raid member of the right class and level is present.
- Optionally track consumables (flask, elixir, Well Fed).
- Movable, resizable, with a choice of display style and alert style (flash, sound, both, none).
- Zero Lua errors, including in combat under Forever's secret-value restrictions.
- Works on a fresh install with sensible defaults; options for everything the player asked for.

## Non-goals

- Not a raid-leader tool: no "who in the raid is missing what" report, no whispering people.
- No buff *casting* or automation of any kind. Display only.
- No tracking of short combat buffs, procs, cooldowns, debuffs or enemy auras.
- No retail / Classic Era / Mists support. Forever only.
- No localisation beyond English spell names supplied by the game itself (icons and names come from spell IDs, so other locales still display correctly; only the addon's own option labels are English).

## Anti-goals (what makes it a failure even if it "works")

- Nagging about a buff the player cannot have: a spell they haven't learned, a group buff nobody present can cast, a consumable in the open world when they never use them.
- Flashing or playing sounds in situations where it is noise: dead, on a flight path, mounted, mid-combat.
- Throwing Lua errors in combat (Forever hides aura data from addons in combat; the addon must cope silently).
- Being heavy. It is a handful of icons; it must not poll aggressively or allocate every frame.

## Constraints and facts about the target

- Client: World of Warcraft: Forever, version 1.60.1 (build 70862 at launch). Installed at `D:\World of Warcraft\_forever_`. Addons go in `D:\World of Warcraft\_forever_\Interface\AddOns\`.
- TOC: `## Interface: 16001`. Forever uses the Mainline (retail 12.1.5 "Midnight") UI framework and API, not the Classic one. Flavor-specific TOC suffix is `_Forever` if ever needed; a single plain `.toc` is enough here.
- Secret values: in combat (and in some restricted instances), aura data on units is "secret". Single-aura lookups such as `C_UnitAuras.GetPlayerAuraBySpellID` may error or return nil, index scans hard-error, and secret fields cannot be compared or used in `if`. Group members' `UnitClass`/`UnitLevel` first returns can also be secret in combat. Consequence: **all evaluation happens out of combat**; on `PLAYER_REGEN_DISABLED` the addon freezes its last known state and does nothing until `PLAYER_REGEN_ENABLED`.
- Spell IDs on Forever are the Classic spell IDs (spot-checked on Wowhead's Forever database: 588 Inner Fire, 1243 Power Word: Fortitude, 20217 Blessing of Kings, 8232 Windfury Weapon, 17626 Flask of the Titans). Each buff exists as several ranks with different IDs; every rank must count.
- Forever differences from Classic that matter here (source: wowhandbook.com Forever spellbook from client 1.60.1, wowforevertalent.com, Wowhead Forever):
  - Blessing of Kings is a trainer spell at level 20. Divine Spirit is a trainer spell at level 30. Omen of Clarity and Nature's Grasp are trainable (not tracked here).
  - Blessing of Salvation, Light and Sanctuary are not in the Forever spellbook. Their old spell IDs may still exist in the client; counting them as "a blessing" is harmless.
  - Paladins and Shamans exist on both factions.
  - Shaman weapon imbues last 60 minutes.
  - Rogue poisons are learned spells (Crippling and Instant at 20, Mind-numbing 24, Deadly 30, Wound 32, Occult Poison II 60) and are applied to weapons as temporary enchants.
  - Blessing of Kings lasts 1 hour.
- Icons: the game supplies the icon for any spell ID at runtime via `C_Spell.GetSpellTexture(spellID)`. No icon files ship with the addon.

## How it decides what to show

### Buff definitions

A static data table of **buff entries**. Each entry has:

- `key` (stable string), `name` (fallback label; the real label is `C_Spell.GetSpellName(iconSpell)`)
- `iconSpell`: a spell ID used for the icon and label (rank 1, or see "icon choice" below)
- `class`: the class that casts it (`PRIEST`, `MAGE`, ...), or `nil` for consumables
- `learnLevel`: level at which that class first learns it
- `selfOnly` (bool): true for buffs only castable on oneself (Inner Fire, armors, Aspects, shields, imbues, poisons). Group members never satisfy the "someone can cast it" test for these.
- `kind`: `aura` (default), `weaponEnchant`, or `anyOf` (satisfied by any one of several aura families, e.g. "any Aspect")
- `ids`: list of every aura spell ID that counts as "have it" (all ranks, the group/greater version, other casters' versions)
- `defaultEnabled` (bool)
- `quietFromOthers` (bool): when the entry is tracked only because a group member can cast it (not because the player knows it), suppress flash and sound; the icon still lights up. Used for Battle Shout.
- `slots` for `weaponEnchant`: `{INVSLOT_MAINHAND}` or both hands

### When is an entry tracked for this character?

An entry is **tracked** when the player has it enabled in options **and** at least one of:

1. The player knows the spell: `C_SpellBook.IsSpellKnown(id) or C_SpellBook.IsSpellInSpellBook(id, Enum.SpellBookSpellBank.Player, false)` on any ID in the entry's cast list. (The old globals `IsPlayerSpell` / `IsSpellKnown` exist on this client only while the deprecation-fallback CVar is on; do not use them.) This covers self-buffs and a priest's own Fortitude alike. Talents such as Trueshot Aura work the same way, since the player's own talents are known spells.
2. The entry is not `selfOnly`, and a connected party/raid member (not a pet, not the player) has `class == entry.class` and `UnitLevel >= learnLevel`. Unknown level (0 or -1) counts as eligible. Dead members still count (they can be resurrected). Range is not considered.
3. For consumables: see below.

### When is a tracked entry "missing"?

- `aura`: none of `ids` is present on the player. Presence test: `pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)`; `ok and result ~= nil` means present. Never read `result.duration` or other fields for decisions (they may be secret). Builder may additionally use `C_UnitAuras.GetAuraDataBySpellName` for name-based consumable checks, with the same pcall discipline.
- `mustBeOwn` entries **(my call)**: Paladin Aura, Hunter Aspect and Trueshot Aura are party-wide, so another paladin's Devotion Aura or another hunter's Aspect of the Pack on you must not count as "I am running mine". For these, presence additionally requires `result.sourceUnit` to be `"player"` (guard: if `sourceUnit` is nil or `issecretvalue(sourceUnit)`, fall back to plain presence rather than claiming missing). Evaluation only runs out of combat, where the field is normally readable. All other entries use plain presence: Thorns or Fortitude from anyone is the buff.
- `weaponEnchant`: `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)` returns nil for the slot. (This is the 12.1 API; the old global `GetWeaponEnchantInfo` is a deprecation shim on this client. Keep it as a fallback only if the new function is absent.) Off-hand slot only counts if an off-hand *weapon* is equipped (not a shield or held item).
- `anyOf`: missing only if every family in the group is absent.

### Consumables

Four entries, each its own toggle: **Flask** (any flask aura), **Elixir** (any elixir aura; Classic has no battle/guardian split, so one entry), **Well Fed** (any Well Fed aura), and **Weapon oil / stone** (any temporary enchant on the main hand, for classes that do not use imbues or poisons; see "Weapon enhancements" below). Builder populates the ID lists from Wowhead's Forever database (flasks: 17626, 17627, 17628, 17629; elixirs and food: the Classic lists, verified against `wowhead.com/forever/spell=<id>`).

Rule **(my call)**: a consumable entry is tracked when **either** the player is inside a raid instance, **or** that consumable was seen on the player earlier this session and has since worn off ("remind me when it drops"). The session memory clears on logout. Both halves are toggles in options ("Raids only" on by default; "Remind when it wears off" on by default). Consumables are never tracked in battlegrounds **(my call)**. Flask is additionally never tracked below level 50, since no flask can be used before then **(my call)**.

### Recommended consumables (player's request)

"Having an elixir" satisfies the Elixir entry, but the addon also tells the player *which* one it would recommend for their class, role and level. The recommendation drives the entry's icon (the recommended item's icon) and its tooltip ("Recommended: Elixir of the Mongoose"). It never changes whether the entry counts as present: any elixir, flask, food or weapon enhancement satisfies its entry.

**Role**: a per-character option with four values, `Caster`, `Melee`, `Healer`, `Tank`, defaulted by class **(my call)**: Mage, Warlock → Caster; Rogue, Hunter, Warrior → Melee; Priest, Paladin, Shaman, Druid → Healer. The player changes it in options.

**Recommendation table** (Classic item IDs; builder verifies each at `wowhead.com/forever/item=<id>` and in game with `/fbuffs ids`). For each entry and role, the list is ordered by required level; the recommendation is the highest-level item whose required level is at or below the player's level. If none qualifies (e.g. flask below 50), the generic icon is used and the tooltip says "No recommendation at your level".

| Entry | Role | Items (required level → item) |
|---|---|---|
| Elixir | Caster | 37 → Arcane Elixir 9155; 47 → Greater Arcane Elixir 13454. Mage adds 33 → Elixir of Firepower 6373, 50 → Elixir of Greater Firepower 21546. Warlock and Priest add 40 → Elixir of Shadow Power 9264. |
| Elixir | Melee | 5 → Elixir of Lion's Strength 2454; 20 → Elixir of Ogre's Strength 3391; 27 → Elixir of Agility 8949; 38 → Elixir of Greater Agility 9187; 46 → Elixir of the Mongoose 13452 (Giants 9206 at 46 for Warrior/Paladin). |
| Elixir | Healer | 37 → Elixir of Greater Intellect 9179; 50 → Mageblood Potion 20007. |
| Elixir | Tank | 25 → Elixir of Fortitude 3825; 43 → Elixir of Superior Defense 13445. |
| Flask | Caster | 50 → Flask of Supreme Power 13512 |
| Flask | Healer | 50 → Flask of Distilled Wisdom 13511 |
| Flask | Melee, Tank | 50 → Flask of the Titans 13510 |
| Well Fed | Caster | 35 → Nightfin Soup 13931 |
| Well Fed | Healer | 30 → Sagefish Delight 21217; 35 → Nightfin Soup 13931 |
| Well Fed | Melee | 45 → Grilled Squid 13928 (agility: Rogue, Hunter); 45 → Smoked Desert Dumplings 20452 (strength: Warrior, Paladin) |
| Well Fed | Tank | 55 → Dirge's Kickin' Chimaerok Chops 21023 |
| Weapon | Caster, Healer | 5 → Minor Wizard Oil 20744; 20 → Minor Mana Oil 20745; 30 → Lesser Wizard Oil 20746; 35 → Lesser Mana Oil 20747; 40 → Wizard Oil 20750; 45 → Brilliant Wizard Oil 20749 (Caster) / Brilliant Mana Oil 20748 (Healer) |
| Weapon | Melee, Tank, edged weapon | 1 → Rough Sharpening Stone 2862; 10 → Coarse 2863; 20 → Heavy 2871; 35 → Solid 7964; 45 → Dense 12404; 50 → Elemental Sharpening Stone 18262 |
| Weapon | Melee, Tank, blunt weapon | 1 → Rough Weightstone 3239; 10 → Coarse 3240; 20 → Heavy 3241; 35 → Solid 7965; 45 → Dense 12643 |

Edged vs blunt is read from the main-hand weapon's item subclass (sword, axe, dagger, polearm, fist → edged; mace, staff → blunt). Below level 5 the Well Fed entry recommends "any food that gives Well Fed".

### Weapon enhancements

All "something on my weapon" reminders share the `weaponEnchant` kind: present when `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)` returns a table, **or** when `C_Item.GetWeaponEnchantInfo(weaponSlot)` lists an entry with `hasEnchant == true`. (Correction found in review: on Forever a shaman imbue is its own enchant type, `Enum.ItemEnchantType.Imbue`, which the temporary-enchant API does not report; the per-weapon list does. Rogue poisons may behave the same way, so the list is consulted for every weapon entry.) Which entry a character gets:

- Shaman: **Weapon imbue** (own spell, see class table). No oil/stone entry.
- Rogue: **Poison** main hand and off hand (own spells). No oil/stone entry.
- Everyone else: the **Weapon oil / stone** consumable entry on the main hand, recommended by role as above. A second off-hand entry appears only when an off-hand *weapon* is equipped (Warriors and Hunters dual-wielding) **(my call)**. Default enabled for all classes except Hunter, where it is off by default **(my call)**: hunters rarely enhance their melee weapon.

### Hide conditions (whole display)

Hidden, with no sounds, when any of: dead or ghost, on a taxi, mounted, in a vehicle/possess state, during loading. Optional (off by default): hide while resting in an inn/city. A grace period of 3 seconds **(my call)** after entering the world or after the group roster changes before anything shows, so it does not flash while data loads.

### Combat behaviour

Default **(my call)**: on entering combat, freeze the display exactly as it was. Nothing re-evaluates, no sounds. On leaving combat, re-evaluate immediately. Option: "Hide in combat" instead of freezing.

### Restricted while out of combat **(my call)**

On retail 12.1, aura data can also be secret out of combat inside restricted maps (Mythic+ keys, some raids). Whether Forever flags its dungeons or raids this way is unknown at design time, so the addon must not assume combat is the only restricted window:

- Before each evaluation, ask `C_Secrets.ShouldAurasBeSecret()` (fall back to `pcall(C_UnitAuras.GetAuraDataByIndex, "player", 1, "HELPFUL")` failing) to learn whether auras are restricted right now. The same combat-freeze behaviour applies whenever this says restricted, out of combat or not.
- Per-entry exception: `C_Secrets.ShouldSpellAuraBeSecret(id)` returning `false` means that spell is never secret; such entries keep evaluating under restrictions.
- When the display is frozen for longer than a combat (i.e. restricted out of combat), it shows a small "?" badge on the frame corner so the player knows it is stale, and `/fbuffs debug` says "auras restricted here". The display is never blanked by restriction alone.

If, in testing, Forever turns out never to restrict out of combat, the badge simply never appears.

## Buff table (what the builder ships, per class)

Spell IDs below are the Classic/Forever rank-1 IDs the designer believes are correct; the builder verifies every ID list against `https://www.wowhead.com/forever/spell=<id>` and in-game via `C_Spell.GetSpellName` during testing. Learn levels are from the Forever 1.60.1 spellbook.

**Shared group buffs (tracked if the player knows them or an eligible group member is present):**

| Entry | Class | Learn | Icon spell | Counts (all ranks + group version) |
|---|---|---|---|---|
| Power Word: Fortitude | Priest | 1 | 1243 | 1243, 1244, 1245, 2791, 10937, 10938; Prayer of Fortitude 21562, 21564 |
| Divine Spirit | Priest | 30 | 14752 | 14752, 14818, 14819, 27841; Prayer of Spirit 27681 |
| Shadow Protection | Priest | 30 | 976 | 976, 10957, 10958; Prayer of Shadow Protection 27683. **Default off** (situational). |
| Arcane Intellect | Mage | 1 | 1459 | 1459, 1460, 1461, 10156, 10157; Arcane Brilliance 23028 |
| Mark of the Wild | Druid | 1 | 1126 | 1126, 5232, 6756, 5234, 8907, 9884, 9885; Gift of the Wild 21849, 21850 |
| Blessing (any) | Paladin | 4 | 19740 (Might) or 20217 (Kings) if the player knows Kings | Might 19740, 19834–19838, 25291 + Greater 25782, 25916; Wisdom 19742, 19850, 19852–19854, 25290 + Greater 25894, 25918; Kings 20217 + Greater 25898; Salvation 1038, 25895; Light 19977–19979, 25890. Any one blessing satisfies. |
| Battle Shout | Warrior | 1 | 6673 | 6673, 5242, 6192, 11549, 11550, 11551, 25289. **Quiet unless you are the warrior** (player's decision): when tracked because of another warrior in the group, the entry is `quiet`: it shows lit when missing but never flashes and never plays a sound. When the player is a warrior who knows the spell, it alerts like any other buff. |

**Self-only buffs (tracked only once the player knows the spell):**

| Class | Entry | Learn | Icon spell | Counts | Default |
|---|---|---|---|---|---|
| Priest | Inner Fire | 12 | 588 | 588, 7128, 602, 1006, 10951, 10952 | on |
| Mage | Armor (any) | 1 | highest armor known: Frost 168 → Ice 7302 (30) → Mage Armor 6117 (34) | Frost 168, 7300, 7301; Ice 7302, 7320, 10219, 10220; Mage Armor 6117, 22782, 22783 | on |
| Warlock | Demon Skin / Demon Armor | 1 | Demon Skin 687, or Demon Armor 706 once known (20) | 687, 696; 706, 1086, 11733, 11734, 11735 | on |
| Druid | Thorns | 6 | 467 | 467, 782, 1075, 8914, 9756, 9910 | on |
| Paladin | Aura (any) | 1 | 465 (Devotion) | Devotion 465, 10290, 643, 10291, 1032, 10292; Retribution 7294, 10298–10301; Concentration 19746; Shadow Res 19876, 19895, 19896; Frost Res 19888, 19897, 19898; Fire Res 19891, 19899, 19900 | on |
| Paladin | Righteous Fury | 10 | 25780 | 25780 | **off** (tanks turn it on) |
| Hunter | Aspect (any) | 4 | 13165 (Hawk) once known, else 13163 (Monkey) | Monkey 13163; Hawk 13165, 14318–14322, 25296; Cheetah 5118; Beast 13161; Pack 13159; Wild 20043, 20190 | on |
| Hunter | Trueshot Aura | talent | 19506 | 19506, 20905, 20906 | on (only tracked if known) |
| Shaman | Lightning Shield | 8 | 324 | 324, 325, 905, 945, 8134, 10431, 10432 | on |
| Shaman | Weapon imbue (main hand) | 1 | highest imbue known: Rockbiter 8017 → Flametongue 8024 (10) → Frostbrand 8033 (20) → Windfury 8232 (30) | `weaponEnchant`, main hand | on |
| Rogue | Poison, main hand | 20 | Instant Poison 8681 | `weaponEnchant`, main hand | on |
| Rogue | Poison, off hand | 20 | Instant Poison 8681 | `weaponEnchant`, off hand, only when an off-hand weapon is equipped | on |

Deliberately **not** tracked **(my call)**: Seals (30 s), stances and forms, Dampen/Amplify Magic, Unending Breath, Detect Invisibility, pet buffs such as Blood Pact, Soulstone, scrolls, potions with instant effects. Warriors and Rogues have no self-aura entries beyond the above; their weapon reminders are covered under "Weapon enhancements".

## What the player sees

### Display styles (chosen in options; player picked C as default)

- **A. Plain row**: only missing buffs, red border, no text. Empty when fully buffed.
- **B. Flashing with names**: only missing buffs; each pulses red and shows the buff name beside the icon.
- **C. Always-on grid (default)**: every tracked buff stays on screen. Ones the player has are desaturated and dimmed (about 35% alpha, grey); missing ones are full colour with a red border (and pulse if "Flash" alert style is on).

All styles share: icon size (default 40 px), spacing (default 6 px), grow direction (right / left / down / up), icons per row before wrapping (default 8, grid style only), optional buff name under or beside the icon, a 1 px dark border, frame strata MEDIUM. Hovering an icon shows a tooltip with the buff name, and for group buffs the names of group members who can cast it **(my call)**.

### Alert styles

`Icon only`, `Flash`, `Sound`, `Flash + sound`. Default **Flash** **(my call)**. Sound plays once when an entry transitions from present to missing (not on login, not while hidden, not in combat), throttled to once per entry per 30 seconds **(my call)**. An entry that becomes newly *tracked* and is already missing (a mage joins the party, you learn Inner Fire, you zone into a raid without a flask) appears and flashes but plays **no sound** **(my call)**; the state machine is three-state (untracked / present / missing) and only the present-to-missing edge is audible. The 3-second grace period suppresses sounds as well as display. Three or four built-in Blizzard sound kits to choose from (e.g. raid warning, ready check, quest complete). Sound channel: Master.

### Moving and sizing

- "Unlock" button in options and `/fbuffs unlock`: the display shows every tracked entry (even present ones) on a translucent backdrop labelled "ForeverBuffs - drag to move, /fbuffs lock to lock". Drag anywhere. Lock saves the position.
- "Reset position" button returns it to the default spot: centred horizontally, about 180 px above screen centre **(my call)**.
- Size is the icon-size slider (20–80 px). Also a global scale slider is not needed **(my call)**.
- `/fbuffs test` toggles a test mode that shows every tracked entry as missing so the player can see the layout and hear the sound.

### Options panel

Native Blizzard settings panel (`Settings.RegisterCanvasLayoutCategory` or the vertical layout with `Settings.RegisterAddOnCategory`), reachable from Game Menu > Options > AddOns > ForeverBuffs and `/fbuffs` (also `/forbuffs`). No Ace libraries.

Sections:

1. **Display**: style (A/B/C), icon size, spacing, grow direction, icons per row, show names.
2. **Alerts**: alert style, sound choice, "Play test sound" button.
3. **Visibility**: combat behaviour (freeze / hide), hide when mounted, hide when resting, hide on taxi (always on; not a setting).
4. **Buffs**: checkbox per entry relevant to this character's class, plus the shared group-buff list with its own checkboxes. Consumables sub-section: **Role** dropdown (Caster / Melee / Healer / Tank), Flask, Elixir, Well Fed, Weapon oil/stone toggles; "Raids only"; "Remind when it wears off".
5. **Position**: Unlock / Lock, Reset position.

### Saved data

- `ForeverBuffsDB` (account-wide): display, alerts, visibility, position.
- `ForeverBuffsCharDB` (per character): per-entry enabled toggles, role, and consumable settings.

## Technical shape the builder should follow

- Files: `ForeverBuffs.toc`, `Core.lua` (events, evaluation), `Data.lua` (buff table), `Display.lua` (frames, styles, drag), `Options.lua` (settings panel), `Sounds` none shipped. Plain Lua, no libraries, no XML needed.
- Events: `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `GROUP_ROSTER_UPDATE`, `UNIT_AURA` (player only; ignored in combat), `UNIT_INVENTORY_CHANGED` (player), `SPELLS_CHANGED` / `LEARNED_SPELL_IN_TAB` (re-derive the tracked set), `PLAYER_REGEN_DISABLED/ENABLED`, `PLAYER_DEAD`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`, `PLAYER_MOUNT_DISPLAY_CHANGED`, `UNIT_LEVEL` (party/raid), `PLAYER_UPDATE_RESTING`, `ZONE_CHANGED_NEW_AREA`.
- A single throttled re-evaluate (at most every 0.25 s) is scheduled by events; plus a 1 s ticker out of combat because temporary weapon enchants expiring fire no event.
- Every aura or unit lookup is wrapped in `pcall` and treats any secret or errored result as "unknown, keep previous state". `issecretvalue` guards before any comparison on a returned value. Test under `/console secretAurasForced 1` and `/console addonCombatRestrictionsForced 1` (not persisted across restarts).
- Group scan runs only out of combat and caches "eligible casters per entry" until the next roster/level change.
- The icon for entries whose icon depends on what the player knows (mage armor, warlock armor, shaman imbue, hunter aspect, paladin blessing) is resolved whenever the known-spell set changes.
- Version 1.0.0 in the TOC; `## SavedVariables: ForeverBuffsDB`, `## SavedVariablesPerCharacter: ForeverBuffsCharDB`, `## IconTexture:` a spell icon file ID (Inner Fire's).

## Where it lives

- Project and git repository: `D:\World of Warcraft\_forever_\Interface\AddOns\ForeverBuffs\` **(my call: developing directly in the AddOns folder means no copy step between edits and in-game testing)**. The game loads it from there on next `/reload` or login.
- This document: `docs/superpowers/specs/` inside that folder.

## Left to the builder

- Exact UI construction of the options panel and icon frames, fonts, pulse animation timing.
- Which Blizzard sound kits to offer.
- Verifying and completing every spell-ID list (ranks, consumables) against Wowhead's Forever database; building a tiny `/fbuffs ids` debug command that prints which IDs resolve to a name in-game to catch wrong ones.
- The tooltip wording.
- How "an off-hand weapon is equipped" is detected (item class of the off-hand slot).

## API reference available to the builder

The builder cannot run the game, and there is no Blizzard API documentation export on this machine. Two resources exist:

1. **Working code on this exact client.** `D:\World of Warcraft\_forever_\Interface\AddOns\EllesmereUI\` and `EllesmereUIAuraBuffReminders\` load on Forever 1.60.1 today. They show the live spellings in use: `C_SpellBook.IsSpellKnown`, `C_SpellBook.IsSpellInSpellBook`, `C_PaperDollInfo.GetTemporaryEnchantmentInfo`, `C_UnitAuras.GetPlayerAuraBySpellID`, `C_UnitAuras.GetAuraDataByIndex`, `C_UnitAuras.GetAuraDataBySpellName`, `C_Secrets.ShouldAurasBeSecret`, `C_Secrets.ShouldSpellAuraBeSecret`, `C_Spell.GetSpellTexture`, `C_Spell.GetSpellName`, `issecretvalue`. Read them for API shape only; do not copy code or depend on them.
2. **The player runs probes.** The first deliverable is `/fbuffs api`, which prints for each function the addon relies on whether it exists, and `/fbuffs ids`, which prints each configured spell ID with the name the client resolves it to (or "unknown"). The player pastes the output back. Every function call is behind a small feature-detection layer so that a missing function degrades to "entry disabled, reported by /fbuffs api" rather than silent failure.

Warcraft Wiki (`warcraft.wiki.gg`) documents the 12.1.5 API and lists Forever 1.60.1 as sharing it.

## Testing

The builder cannot run the game. Deliverables for testing by the player: `/fbuffs test`, `/fbuffs unlock`, `/fbuffs debug` (prints tracked entries, eligible casters and present/missing state). Enable `/console scriptErrors 1` while testing. The player tests on at least one character of their own class, in a party, and in a short combat.
