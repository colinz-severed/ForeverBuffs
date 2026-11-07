# ForeverBuffs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A standalone WoW: Forever addon that shows an icon per tracked buff the player is missing (own self-buffs, group buffs someone present can cast, optional consumables), movable and configurable, safe under combat secret-value restrictions.

**Architecture:** Pure-Lua evaluation core (`State.lua`) that takes an `env` table of callbacks and returns tracked/missing status plus transitions, so it is unit-tested with a fake WoW API outside the game. Thin wrappers (`API.lua`) isolate every real Blizzard call behind pcall and feature detection. `Core.lua` wires events, saved variables, hide rules and slash commands; `Display.lua`, `Alerts.lua`, `Options.lua` render, sound and configure.

**Tech Stack:** WoW Lua 5.1 (Mainline 12.1.5 API as shipped on Forever 1.60.1, Interface 16001), no libraries. Tests: Lua 5.1 via Python `lupa` (`python -m pip install lupa` already done), runner `tests/run_tests.py`, fake API `tests/wow_stub.lua`.

**Spec:** `docs/superpowers/specs/2026-11-07-forever-buffs-design.md` (relative to the addon folder `D:\World of Warcraft\_forever_\Interface\AddOns\ForeverBuffs\`). All paths below are relative to that folder.

## Global Constraints

- TOC `## Interface: 16001`; `## SavedVariables: ForeverBuffsDB`; `## SavedVariablesPerCharacter: ForeverBuffsCharDB`; `## Version: 1.0.0`.
- No libraries, no XML, no shipped media. Icons via `C_Spell.GetSpellTexture`, names via `C_Spell.GetSpellName`.
- Never call `IsPlayerSpell`, `IsSpellKnown`, `GetWeaponEnchantInfo`, `UnitAura` directly; use the `FB.API` wrappers, which prefer `C_SpellBook.IsSpellKnown`/`IsSpellInSpellBook`, `C_PaperDollInfo.GetTemporaryEnchantmentInfo`, `C_UnitAuras.*`.
- Every Blizzard call that can return secret data is wrapped in `pcall`; a secret or errored result means "unknown, keep previous state", never "missing".
- No evaluation while `InCombatLockdown()` or while `FB.API.AurasRestricted()`; display freezes.
- Files receive the addon namespace through varargs: every file begins `local ADDON, FB = ...`.
- Slash commands: `/fbuffs` and `/forbuffs`.
- Commit after each task with a conventional message; the repo is the addon folder itself.

## Review Focus

1. **Player at level 1 of any class**: nothing is tracked except group buffs from eligible party members; display is empty (style A/B) or empty grid (style C) with no errors. Test in Task 4.
2. **Group member whose level reads 0 or -1 (not yet loaded, or much higher)**: counts as eligible, not ignored. Test in Task 4.
3. **Aura lookup errors (pcall false) out of combat**, e.g. a buff ID that does not exist on this client: entry stays in its previous state and no transition fires. Test in Task 5.
4. **Logging in already missing a buff**: the icon appears but no sound plays (untracked→missing is silent). Test in Task 6.
5. **Off-hand slot holds a shield or an empty slot**: the Rogue off-hand poison entry is not tracked rather than permanently "missing". Test in Task 5.

---

### Task 1: Scaffold, TOC and test harness

**Files:**
- Create: `ForeverBuffs.toc`, `Data.lua`, `API.lua`, `State.lua`, `Alerts.lua`, `Display.lua`, `Core.lua`, `Options.lua` (each initially just `local ADDON, FB = ...` and a module table, e.g. `FB.Data = FB.Data or {}`)
- Create: `tests/run_tests.py`, `tests/wow_stub.lua`, `tests/test_smoke.lua`, `.gitignore` (`tests/__pycache__/`)

**Interfaces:**
- Produces: `python tests/run_tests.py` runs every `tests/test_*.lua`; exit code 0 only if all pass. Inside tests, global `T` with `T.test(name, fn)`, `T.eq(a, b, msg)`, `T.truthy(v, msg)`, `T.falsy(v, msg)`, `T.raises(fn)`. Global `STUB` (from `wow_stub.lua`) with fields and helpers listed in Step 2. Global `FB` is the loaded addon namespace; `STUB.reload()` re-executes all addon files from the TOC into a fresh `FB`.

- [ ] **Step 1: Write `ForeverBuffs.toc`**

Header lines from Global Constraints plus `## Title: ForeverBuffs`, `## Notes: Reminds you of missing self, group and consumable buffs.`, `## Author: Colin`, `## IconTexture: 135926` (Inner Fire icon file ID; verify in game later). File order: `Data.lua`, `API.lua`, `State.lua`, `Alerts.lua`, `Display.lua`, `Core.lua`, `Options.lua`.

- [ ] **Step 2: Write `tests/wow_stub.lua`**

A fake of the API surface the addon uses. Everything configurable lives on global `STUB`:

- `STUB.auras = {}` keyed by spellID → `{ name=, sourceUnit=, secret=bool }`; `STUB.aurasByName` derived on demand.
- `STUB.known = {}` set of spell IDs the player knows.
- `STUB.group = {}` list of `{ class="PRIEST", level=30, connected=true, dead=false }`; `STUB.inRaid` bool controls `IsInRaid`/unit tokens (`raidN` vs `partyN`).
- `STUB.restricted = false` → `C_Secrets.ShouldAurasBeSecret()`, and when true `C_UnitAuras.GetPlayerAuraBySpellID`/`GetAuraDataByIndex` raise errors.
- `STUB.neverSecret = {}` set → `C_Secrets.ShouldSpellAuraBeSecret(id)` returns `not STUB.neverSecret[id]`.
- `STUB.tempEnchant = { [16]=nil, [17]=nil }` → `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)` returns a table or nil.
- `STUB.offhandItem = { id=, classID=, subclassID= }` and `STUB.mainhandItem` → `GetInventoryItemID("player", 16|17)`, `C_Item.GetItemInfoInstant` (returns `itemID, itemType, itemSubType, equipLoc, icon, classID, subclassID`).
- `STUB.items = { [itemID] = { name=, icon= } }` → `C_Item.GetItemNameByID`, `C_Item.GetItemIconByID`; unknown IDs return nil.
- `STUB.player = { class="PRIEST", level=60, dead=false, mounted=false, taxi=false, resting=false, combat=false, instanceType="none" }` → `UnitClass("player")`, `UnitLevel`, `UnitIsDeadOrGhost`, `IsMounted`, `UnitOnTaxi`, `IsResting`, `InCombatLockdown`, `IsInInstance` (returns `inInstance, instanceType`), `UnitInVehicle` false, `UnitIsConnected`.
- `STUB.spells = { [588]={name="Inner Fire", icon=135926}, ... }` → `C_Spell.GetSpellName`, `C_Spell.GetSpellTexture`; unknown IDs return nil.
- `STUB.secretValues = setmetatable({}, {__mode="k"})`; `issecretvalue(v)` returns true for values registered via `STUB.secret(v)`.
- `STUB.sounds = {}`; `PlaySound(kit, channel)` appends `{kit, channel}`.
- `STUB.now = 0`; `GetTime()` returns it; `C_Timer.After(d, fn)` and `C_Timer.NewTicker(d, fn)` queue; `STUB.advance(seconds)` fires due timers in order.
- `STUB.events`: `CreateFrame` returns a table whose unknown methods are no-ops (metatable `__index` returning `function() end`), but which records `RegisterEvent`/`RegisterUnitEvent`, `SetScript("OnEvent"|"OnUpdate"|...)`, `Show/Hide/IsShown`, `SetPoint/GetPoint`, `SetSize/GetWidth/GetHeight`, `SetAlpha/GetAlpha`, `EnableMouse`, `SetMovable`, `RegisterForDrag`, `CreateTexture`/`CreateFontString` (return the same kind of table with `SetTexture`, `SetDesaturated`, `SetVertexColor`, `SetText`). `STUB.fire(event, ...)` calls OnEvent on every frame registered for it. `STUB.frames` lists created frames.
- Globals: `UIParent`, `GameTooltip` (records `SetText`/`AddLine`), `SlashCmdList`, `SLASH_*` assignment works through `_G`, `SOUNDKIT = { RAID_WARNING=8959, READY_CHECK=8960, ALARM_CLOCK_WARNING_3=12889, UI_RAID_BOSS_WHISPER_WARNING=37666 }`, `INVSLOT_MAINHAND=16`, `INVSLOT_OFFHAND=17`, `Enum = { SpellBookSpellBank={Player=0}, ItemClass={Weapon=2, Armor=4} }`, `wipe`, `tinsert`, `tremove`, `strsplit`, `format=string.format`, `print` (appends to `STUB.printed`), `Settings` stub (every function returns a table with no-op methods; `Settings.RegisterAddOnCategory` records the category in `STUB.settingsCategories`), `CreateSettingsListSectionHeaderInitializer`, `Settings.VarType = {Boolean="boolean", Number="number", String="string"}`, `Settings.Default = {True=true,False=false}`.
- `STUB.reset()` restores every field above to defaults. `STUB.loadAddon()` reads `ForeverBuffs.toc`, loads each listed `.lua` with `loadstring(src, "@"..path)` and calls it with `("ForeverBuffs", FB)` where `FB` is a fresh global table; `STUB.reload()` = `reset()` + `loadAddon()` + `STUB.fire("PLAYER_LOGIN")`.

- [ ] **Step 3: Write `tests/run_tests.py`**

Uses `lupa.lua51.LuaRuntime(unpack_returned_tuples=True)`; sets `package.path` to include `tests/?.lua`; defines `T` in Lua (collect tests, run each in `pcall`, print `PASS name` / `FAIL name: err`, summary line `N passed, M failed`); executes `wow_stub.lua`, then `STUB.reload()`, then every `tests/test_*.lua` sorted; exits 1 if any failed. Accept an optional filename filter argument.

- [ ] **Step 4: Write `tests/test_smoke.lua`**

```lua
T.test("addon files load and define modules", function()
  for _, m in ipairs({"Data","API","State","Alerts","Display","Core","Options"}) do
    T.truthy(FB[m], m .. " module missing")
  end
end)
T.test("TOC interface is 16001", function()
  local toc = io.open("ForeverBuffs.toc"):read("*a")
  T.truthy(toc:find("## Interface: 16001", 1, true))
end)
```

- [ ] **Step 5: Run the harness**

Run (from the addon folder): `python tests/run_tests.py`
Expected: `2 passed, 0 failed`, exit code 0.

- [ ] **Step 6: Init repo and commit**

```bash
git init -b main && git add -A && git commit -m "chore: scaffold ForeverBuffs addon with Lua test harness"
```

---

### Task 2: Buff data table

**Files:**
- Create/replace: `Data.lua`
- Test: `tests/test_data.lua`

**Interfaces:**
- Produces: `FB.Data.entries` (ordered array) and `FB.Data.byKey[key]`. Entry fields: `key` string, `name` string, `class` class token or `nil` (consumables), `learnLevel` number or `nil`, `selfOnly` bool, `kind` `"aura"|"weaponEnchant"`, `castIDs` array (spell IDs that mean "player knows it"; same as `ids` when not given), `ids` array (aura IDs that mean "have it"), `nameMatch` optional string (aura name that also counts, used by Well Fed), `iconSpells` ordered array (first known wins, else last), `defaultEnabled` bool, `quietFromOthers` bool, `mustBeOwn` bool, `slot` number for `weaponEnchant`, `requiresOffhandWeapon` bool, `consumable` bool.
- Produces: `FB.Data.CLASSES = {"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK","DRUID"}`.
- Produces: `FB.Data.AllSpellIDs() -> array` of every distinct ID in `ids`, `castIDs`, `iconSpells` (for `/fbuffs ids`).
- Produces: extra entry fields for consumables: `excludeClasses` set (weapon oil/stone entries exclude `SHAMAN` and `ROGUE`), `defaultEnabledByClass` map overriding `defaultEnabled` (weapon entries: `HUNTER=false`), `minLevel` (flask: 50).
- Produces: `FB.Data.ROLES = {"Caster","Melee","Healer","Tank"}`, `FB.Data.DefaultRole(class) -> role` (MAGE/WARLOCK Caster; ROGUE/HUNTER/WARRIOR Melee; PRIEST/PALADIN/SHAMAN/DRUID Healer).
- Produces: `FB.Data.Recommend(key, class, role, level, weaponKind) -> { itemID=, name= } | nil` for keys `elixir`, `flask`, `well_fed`, `weapon_mh`, `weapon_oh`; `weaponKind` is `"edged"|"blunt"|nil`. Picks the highest-required-level item at or below `level` from the spec's recommendation table (`FB.Data.RECOMMEND`, a table keyed by entry → role → ordered array of `{ level=, itemID=, name=, classes=set|nil, weapon="edged"|"blunt"|nil }`).
- Produces: `FB.Data.AllItemIDs() -> array` of every distinct item ID in `RECOMMEND` (for `/fbuffs ids`).

- [ ] **Step 1: Write `tests/test_data.lua`**

```lua
T.test("every entry is well-formed and keys are unique", function()
  local seen = {}
  for _, e in ipairs(FB.Data.entries) do
    T.truthy(e.key and not seen[e.key], "dup/missing key " .. tostring(e.key)); seen[e.key] = true
    T.truthy(e.name and e.ids and #e.ids > 0 or e.kind == "weaponEnchant", e.key)
    T.truthy(e.kind == "aura" or e.kind == "weaponEnchant", e.key)
    T.truthy(#e.iconSpells >= 1, e.key)
    if e.kind == "weaponEnchant" then T.truthy(e.slot == 16 or e.slot == 17, e.key) end
    if e.class then T.truthy(e.learnLevel, e.key) else T.truthy(e.consumable, e.key) end
    T.eq(FB.Data.byKey[e.key], e)
  end
end)
T.test("spec entries exist with spec values", function()
  local d = FB.Data.byKey
  T.eq(d.inner_fire.learnLevel, 12); T.eq(d.inner_fire.class, "PRIEST"); T.truthy(d.inner_fire.selfOnly)
  T.eq(d.fortitude.learnLevel, 1);   T.falsy(d.fortitude.selfOnly)
  T.eq(d.divine_spirit.learnLevel, 30); T.eq(d.shadow_protection.defaultEnabled, false)
  T.eq(d.blessing.learnLevel, 4);    T.eq(d.blessing.iconSpells[1], 20217); T.eq(d.blessing.iconSpells[2], 19740)
  T.truthy(d.battle_shout.quietFromOthers); T.falsy(d.fortitude.quietFromOthers)
  T.truthy(d.paladin_aura.mustBeOwn and d.hunter_aspect.mustBeOwn and d.trueshot_aura.mustBeOwn)
  T.eq(d.righteous_fury.defaultEnabled, false)
  T.eq(d.mage_armor.iconSpells[1], 6117); T.eq(d.mage_armor.iconSpells[3], 168)
  T.eq(d.shaman_imbue.kind, "weaponEnchant"); T.eq(d.shaman_imbue.slot, 16); T.eq(d.shaman_imbue.iconSpells[1], 8232)
  T.eq(d.rogue_poison_oh.slot, 17); T.truthy(d.rogue_poison_oh.requiresOffhandWeapon); T.eq(d.rogue_poison_oh.learnLevel, 20)
  T.truthy(d.flask.consumable and d.elixir.consumable and d.well_fed.consumable)
  T.eq(d.well_fed.nameMatch, "Well Fed"); T.eq(d.flask.ids[1], 17626); T.eq(d.flask.minLevel, 50)
  T.eq(d.weapon_mh.kind, "weaponEnchant"); T.eq(d.weapon_mh.slot, 16); T.truthy(d.weapon_mh.consumable)
  T.truthy(d.weapon_mh.excludeClasses.SHAMAN and d.weapon_mh.excludeClasses.ROGUE); T.eq(d.weapon_mh.defaultEnabledByClass.HUNTER, false)
  T.eq(d.weapon_oh.slot, 17); T.truthy(d.weapon_oh.requiresOffhandWeapon)
end)
T.test("DefaultRole and Recommend", function()
  T.eq(FB.Data.DefaultRole("MAGE"), "Caster"); T.eq(FB.Data.DefaultRole("WARRIOR"), "Melee"); T.eq(FB.Data.DefaultRole("PALADIN"), "Healer")
  T.eq(FB.Data.Recommend("elixir", "MAGE", "Caster", 60).itemID, 21546)       -- Greater Firepower beats Greater Arcane at 50
  T.eq(FB.Data.Recommend("elixir", "WARLOCK", "Caster", 60).itemID, 13454)    -- no Firepower for warlocks
  T.eq(FB.Data.Recommend("elixir", "WARLOCK", "Caster", 45).itemID, 9264)     -- Shadow Power at 40
  T.eq(FB.Data.Recommend("elixir", "ROGUE", "Melee", 60).itemID, 13452)
  T.eq(FB.Data.Recommend("elixir", "WARRIOR", "Melee", 60).itemID, 9206)
  T.eq(FB.Data.Recommend("elixir", "WARRIOR", "Tank", 30).itemID, 3825)
  T.eq(FB.Data.Recommend("flask", "PRIEST", "Healer", 60).itemID, 13511); T.eq(FB.Data.Recommend("flask", "PRIEST", "Healer", 49), nil)
  T.eq(FB.Data.Recommend("well_fed", "WARRIOR", "Melee", 60).itemID, 20452); T.eq(FB.Data.Recommend("well_fed", "ROGUE", "Melee", 60).itemID, 13928)
  T.eq(FB.Data.Recommend("weapon_mh", "MAGE", "Caster", 60).itemID, 20749); T.eq(FB.Data.Recommend("weapon_mh", "PRIEST", "Healer", 60).itemID, 20748)
  T.eq(FB.Data.Recommend("weapon_mh", "WARRIOR", "Melee", 60, "edged").itemID, 18262)
  T.eq(FB.Data.Recommend("weapon_mh", "WARRIOR", "Melee", 60, "blunt").itemID, 12643)
  T.eq(FB.Data.Recommend("weapon_mh", "WARRIOR", "Melee", 3, nil).itemID, 2862)   -- unknown weapon kind defaults to edged
  T.eq(FB.Data.Recommend("inner_fire", "PRIEST", "Healer", 60), nil)
  T.truthy(#FB.Data.AllItemIDs() > 30)
end)
T.test("display order: self buffs, then group buffs, then consumables", function()
  local order = {}
  for i, e in ipairs(FB.Data.entries) do order[e.key] = i end
  T.truthy(order.inner_fire < order.fortitude and order.fortitude < order.flask)
end)
T.test("AllSpellIDs is distinct and covers ids", function()
  local all, set = FB.Data.AllSpellIDs(), {}
  for _, id in ipairs(all) do T.falsy(set[id], "dup " .. id); set[id] = true end
  T.truthy(set[588] and set[1243] and set[17626] and set[8681])
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `python tests/run_tests.py test_data`
Expected: FAIL (entries nil).

- [ ] **Step 3: Write `Data.lua`**

Entries, in this order and with these keys. IDs from the spec's two tables; `castIDs` defaults to `ids`, override where the cast spell differs from the aura (imbues, poisons, consumables have no castIDs).

Self-only (`selfOnly=true`): `inner_fire` (PRIEST 12), `mage_armor` (MAGE 1; ids Frost+Ice+Mage Armor; iconSpells `{6117, 7302, 168}`), `warlock_armor` (WARLOCK 1; iconSpells `{706, 687}`), `thorns` (DRUID 6), `paladin_aura` (PALADIN 1; mustBeOwn; iconSpells `{465}`), `righteous_fury` (PALADIN 10; defaultEnabled false), `hunter_aspect` (HUNTER 4; mustBeOwn; iconSpells `{13165, 13163}`), `trueshot_aura` (HUNTER learnLevel 60 as a stand-in since it is a talent, mustBeOwn; castIDs `{19506, 20905, 20906}`), `lightning_shield` (SHAMAN 8), `shaman_imbue` (SHAMAN 1; weaponEnchant slot 16; castIDs `{8017, 8024, 8033, 8232}`; iconSpells `{8232, 8033, 8024, 8017}`), `rogue_poison_mh` (ROGUE 20; slot 16; castIDs `{8681, 3408, 5761, 2823, 13219}`; iconSpells `{8681}`), `rogue_poison_oh` (same, slot 17, requiresOffhandWeapon).

Group (`selfOnly=false`): `fortitude`, `divine_spirit`, `shadow_protection` (defaultEnabled false), `arcane_intellect`, `mark_of_the_wild`, `blessing` (ids = all blessing families; castIDs = `{19740, 19742, 20217}`; iconSpells `{20217, 19740}`), `battle_shout` (quietFromOthers).

Consumables (`consumable=true`, `class=nil`, defaultEnabled true): `flask` (ids `{17626, 17627, 17628, 17629}`, iconSpells `{17626}`, minLevel 50), `elixir` (Classic elixir aura IDs: 17538 Mongoose, 17539 Greater Arcane, 11474 Shadow Power, 26276 Greater Firepower, 11390 Arcane Elixir, 3593 Fortitude, 11348 Superior Defense, 11349 Greater Defense, 11405 Giants, 11334 Greater Agility, 11406 Demonslaying, 21920 Frost Power, 17535 Strength, 11396 Greater Intellect, 24363 Mageblood, 24361 Nature Power, 17537 Brute Force; iconSpells `{17538}`), `well_fed` (ids `{19705, 19706, 19708, 19709, 19710, 19711, 24799, 24870, 25661, 18192, 18194, 18222, 22730, 25941}`, nameMatch `"Well Fed"`, iconSpells `{19705}`), `weapon_mh` (weaponEnchant slot 16, iconSpells `{8017}` as generic fallback icon, excludeClasses `{SHAMAN=true, ROGUE=true}`, defaultEnabledByClass `{HUNTER=false}`), `weapon_oh` (same, slot 17, requiresOffhandWeapon).

`FB.Data.RECOMMEND` from the spec's recommendation table, with `classes` sets where the spec names classes (Firepower → MAGE; Shadow Power → WARLOCK, PRIEST; Giants → WARRIOR, PALADIN; Grilled Squid → ROGUE, HUNTER; Dumplings → WARRIOR, PALADIN; Brilliant Wizard Oil → Caster role only, Brilliant Mana Oil → Healer role only). `Recommend` filters rows by role, by `classes` when present, by `weapon` when present (treating nil `weaponKind` as `"edged"`), keeps rows with `level <= playerLevel`, and returns the one with the highest level (ties: later row wins).

Mark the file header: "IDs verified against wowhead.com/forever and in-game /fbuffs ids on <date>" to be filled in Task 10.

- [ ] **Step 4: Run tests**

Run: `python tests/run_tests.py`
Expected: all pass.

- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: buff data table for all nine Forever classes and consumables"`

---

### Task 3: API wrappers with feature detection

**Files:**
- Create/replace: `API.lua`
- Test: `tests/test_api.lua`

**Interfaces:**
- Produces (all on `FB.API`):
  - `KnowsSpell(id) -> bool`
  - `PlayerAura(id) -> true | false | nil` (nil = call failed or value secret)
  - `PlayerAuraSource(id) -> "player" | "other" | nil`
  - `PlayerAuraByName(name) -> true | false | nil`
  - `TempEnchant(slot) -> bool`
  - `OffhandIsWeapon() -> bool`
  - `AurasRestricted() -> bool`
  - `SpellNeverSecret(id) -> bool`
  - `SpellName(id) -> string|nil`, `SpellIcon(id) -> number|nil`
  - `ItemName(itemID) -> string|nil` (`C_Item.GetItemNameByID`), `ItemIcon(itemID) -> number|nil` (`C_Item.GetItemIconByID`)
  - `MainhandWeaponKind() -> "edged" | "blunt" | nil` from `C_Item.GetItemInfoInstant` subclassID of the main-hand item (`Enum.ItemWeaponSubclass`: Axe1H 0, Axe2H 1, Sword1H 7, Sword2H 8, Polearm 6, Dagger 15, Unarmed 13 → edged; Mace1H 4, Mace2H 5, Staff 10 → blunt; anything else nil)
  - `PlayerLevel() -> number`, `PlayerClass() -> classToken`
  - `UnitClassLevel(unit) -> classToken|nil, level|nil` (nil when secret/unavailable)
  - `IsSecret(v) -> bool` (false when `issecretvalue` is absent)
  - `Probe() -> array of { name=string, ok=bool }` covering every Blizzard function the module touches.

- [ ] **Step 1: Write `tests/test_api.lua`**

```lua
T.test("KnowsSpell uses C_SpellBook", function()
  STUB.reset(); STUB.known[588] = true
  T.truthy(FB.API.KnowsSpell(588)); T.falsy(FB.API.KnowsSpell(1243))
end)
T.test("PlayerAura: present, absent, errored, secret", function()
  STUB.reset(); STUB.auras[588] = { name="Inner Fire", sourceUnit="player" }
  T.eq(FB.API.PlayerAura(588), true); T.eq(FB.API.PlayerAura(1243), false)
  STUB.restricted = true; T.eq(FB.API.PlayerAura(588), nil)
  STUB.restricted = false; STUB.auras[588].secret = true; T.eq(FB.API.PlayerAura(588), nil)
end)
T.test("PlayerAuraSource distinguishes own cast", function()
  STUB.reset(); STUB.auras[465] = { sourceUnit="party1" }
  T.eq(FB.API.PlayerAuraSource(465), "other")
  STUB.auras[465].sourceUnit = "player"; T.eq(FB.API.PlayerAuraSource(465), "player")
  STUB.auras[465].sourceUnit = STUB.secret("party1"); T.eq(FB.API.PlayerAuraSource(465), nil)
end)
T.test("TempEnchant and OffhandIsWeapon", function()
  STUB.reset(); T.falsy(FB.API.TempEnchant(16))
  STUB.tempEnchant[16] = { enchantID=1 }; T.truthy(FB.API.TempEnchant(16))
  STUB.offhandItem = nil; T.falsy(FB.API.OffhandIsWeapon())
  STUB.offhandItem = { id=1, classID=4 }; T.falsy(FB.API.OffhandIsWeapon())
  STUB.offhandItem = { id=2, classID=2 }; T.truthy(FB.API.OffhandIsWeapon())
end)
T.test("MainhandWeaponKind and item helpers", function()
  STUB.reset(); STUB.mainhandItem = nil; T.eq(FB.API.MainhandWeaponKind(), nil)
  STUB.mainhandItem = { id=10, classID=2, subclassID=7 }; T.eq(FB.API.MainhandWeaponKind(), "edged")
  STUB.mainhandItem = { id=11, classID=2, subclassID=4 }; T.eq(FB.API.MainhandWeaponKind(), "blunt")
  STUB.items[13452] = { name="Elixir of the Mongoose", icon=134873 }
  T.eq(FB.API.ItemName(13452), "Elixir of the Mongoose"); T.eq(FB.API.ItemIcon(13452), 134873); T.eq(FB.API.ItemName(1), nil)
  T.eq(FB.API.PlayerLevel(), 60); T.eq(FB.API.PlayerClass(), "PRIEST")
end)
T.test("AurasRestricted and SpellNeverSecret", function()
  STUB.reset(); T.falsy(FB.API.AurasRestricted())
  STUB.restricted = true; T.truthy(FB.API.AurasRestricted())
  STUB.neverSecret[1243] = true; T.truthy(FB.API.SpellNeverSecret(1243)); T.falsy(FB.API.SpellNeverSecret(588))
end)
T.test("UnitClassLevel returns nil when secret", function()
  STUB.reset(); STUB.group = { { class="PRIEST", level=30 } }
  local c, l = FB.API.UnitClassLevel("party1"); T.eq(c, "PRIEST"); T.eq(l, 30)
  STUB.group[1].class = STUB.secret("PRIEST"); c = FB.API.UnitClassLevel("party1"); T.eq(c, nil)
end)
T.test("Probe lists functions and all exist in stub", function()
  STUB.reset(); local p = FB.API.Probe(); T.truthy(#p >= 10)
  for _, r in ipairs(p) do T.truthy(r.ok, r.name) end
end)
T.test("missing C_PaperDollInfo degrades, not errors", function()
  STUB.reset(); local saved = C_PaperDollInfo; C_PaperDollInfo = nil
  T.eq(FB.API.TempEnchant(16), false); C_PaperDollInfo = saved
end)
```

- [ ] **Step 2: Run to verify it fails** — `python tests/run_tests.py test_api` → FAIL.

- [ ] **Step 3: Write `API.lua`**

Each wrapper resolves the Blizzard function at call time (so the stub can swap it), pcall-wraps, and runs results through `IsSecret`. `PlayerAura` returns nil if the call errors or `issecretvalue(result)`; otherwise `result ~= nil`. `PlayerAuraSource` returns nil when `result.sourceUnit` is nil or secret; `"player"` when `UnitIsUnit(src, "player")` or `src == "player"`. `OffhandIsWeapon`: `GetInventoryItemID("player", INVSLOT_OFFHAND)` then `select(6, C_Item.GetItemInfoInstant(itemID)) == Enum.ItemClass.Weapon`. `AurasRestricted`: `C_Secrets.ShouldAurasBeSecret()` if present, else `not pcall(C_UnitAuras.GetAuraDataByIndex, "player", 1, "HELPFUL")`. `Probe` checks: `C_SpellBook.IsSpellKnown`, `C_SpellBook.IsSpellInSpellBook`, `C_UnitAuras.GetPlayerAuraBySpellID`, `C_UnitAuras.GetAuraDataBySpellName`, `C_UnitAuras.GetAuraDataByIndex`, `C_PaperDollInfo.GetTemporaryEnchantmentInfo`, `C_Secrets.ShouldAurasBeSecret`, `C_Secrets.ShouldSpellAuraBeSecret`, `C_Spell.GetSpellTexture`, `C_Spell.GetSpellName`, `C_Item.GetItemInfoInstant`, `C_Item.GetItemNameByID`, `C_Item.GetItemIconByID`, `issecretvalue`, `Settings.RegisterVerticalLayoutCategory`, `Settings.RegisterAddOnCategory`, `Settings.CreateCheckbox`, `Settings.CreateSlider`, `Settings.CreateDropdown`.

- [ ] **Step 4: Run tests** → all pass.
- [ ] **Step 5: Commit** `git commit -am "feat: pcall-guarded API wrappers with feature probe"`

---

### Task 4: State: which entries are tracked

**Files:**
- Create/replace: `State.lua`
- Test: `tests/test_state_tracked.lua`

**Interfaces:**
- Produces: `FB.State.New(data, env) -> state`. `env` callbacks: `knows(id)`, `aura(id)`, `auraSource(id)`, `auraByName(name)`, `tempEnchant(slot)`, `offhandWeapon()`, `groupMembers() -> array of {class=, level=}` (excludes player and pets; disconnected excluded), `instanceType() -> "none"|"party"|"raid"|"pvp"|"arena"`, `restricted()`, `neverSecret(id)`, `enabled(key) -> bool|nil` (nil = use default), `charSettings() -> { consumablesRaidsOnly=bool, consumablesRemindDrop=bool, role=string|nil }`, `playerClass()`, `playerLevel()`, `weaponKind()`, `now()`.
- Produces: `state:ComputeTracked()` fills `state.tracked[key] = { reason = "known"|"group"|"consumable", quiet = bool }` or nil. Returns nothing. Consumable entries also respect `excludeClasses` (never tracked for those classes), `minLevel` (never tracked below it), and `defaultEnabledByClass[playerClass]` overriding `defaultEnabled` when `enabled(key)` is nil.
- Produces: `state:IconSpell(key) -> spellID` (first `iconSpells` entry the player knows, else the last).
- Produces: `state:Role() -> role` (`charSettings().role` or `FB.Data.DefaultRole(playerClass())`) and `state:Recommendation(key) -> { itemID=, name= } | nil` via `FB.Data.Recommend(key, playerClass(), Role(), playerLevel(), weaponKind())`.
- Produces: `state.seenConsumable[key] = true` once a consumable was present (set in Task 5's Evaluate).

- [ ] **Step 1: Write `tests/test_state_tracked.lua`**

Helper at top of file (also reused by Task 5's test file via `dofile("tests/helpers.lua")`, so put it in `tests/helpers.lua`): `local function env(o) ... end` returning an env whose callbacks read from table `o` (`o.known` set, `o.group` list, `o.instance`, `o.enabled`, `o.settings`, `o.class` default `"PRIEST"`, `o.level` default 60, `o.weaponKind` default nil, `o.offhandWeapon` default false), defaulting to empty/none/true.

```lua
T.test("self buff tracked only when known", function()
  local s = FB.State.New(FB.Data, env({ known={} })); s:ComputeTracked(); T.falsy(s.tracked.inner_fire)
  s = FB.State.New(FB.Data, env({ known={[588]=true} })); s:ComputeTracked(); T.eq(s.tracked.inner_fire.reason, "known")
end)
T.test("level-1 character with no group tracks nothing", function()
  local s = FB.State.New(FB.Data, env({})); s:ComputeTracked(); T.eq(next(s.tracked), nil)
end)
T.test("group buff tracked by eligible member class and level", function()
  local s = FB.State.New(FB.Data, env({ group={{class="PRIEST", level=29}} })); s:ComputeTracked()
  T.eq(s.tracked.fortitude.reason, "group"); T.falsy(s.tracked.divine_spirit)
  s = FB.State.New(FB.Data, env({ group={{class="PRIEST", level=30}} })); s:ComputeTracked(); T.truthy(s.tracked.divine_spirit)
end)
T.test("unknown member level 0 or -1 counts as eligible", function()
  for _, lvl in ipairs({0, -1}) do
    local s = FB.State.New(FB.Data, env({ group={{class="PRIEST", level=lvl}} })); s:ComputeTracked(); T.truthy(s.tracked.divine_spirit)
  end
end)
T.test("selfOnly entries never tracked via group", function()
  local s = FB.State.New(FB.Data, env({ group={{class="PRIEST", level=60}} })); s:ComputeTracked(); T.falsy(s.tracked.inner_fire)
end)
T.test("quiet flag: battle shout from others quiet, own loud", function()
  local s = FB.State.New(FB.Data, env({ group={{class="WARRIOR", level=10}} })); s:ComputeTracked(); T.truthy(s.tracked.battle_shout.quiet)
  s = FB.State.New(FB.Data, env({ known={[6673]=true}, group={{class="WARRIOR", level=10}} })); s:ComputeTracked(); T.falsy(s.tracked.battle_shout.quiet)
  s = FB.State.New(FB.Data, env({ group={{class="PRIEST", level=10}} })); s:ComputeTracked(); T.falsy(s.tracked.fortitude.quiet)
end)
T.test("disabled entries and default-off entries", function()
  local s = FB.State.New(FB.Data, env({ known={[588]=true}, enabled={inner_fire=false} })); s:ComputeTracked(); T.falsy(s.tracked.inner_fire)
  s = FB.State.New(FB.Data, env({ group={{class="PRIEST", level=60}} })); s:ComputeTracked(); T.falsy(s.tracked.shadow_protection)
  s = FB.State.New(FB.Data, env({ group={{class="PRIEST", level=60}}, enabled={shadow_protection=true} })); s:ComputeTracked(); T.truthy(s.tracked.shadow_protection)
end)
T.test("rogue off-hand poison requires an off-hand weapon", function()
  local o = { known={[8681]=true}, offhandWeapon=false }
  local s = FB.State.New(FB.Data, env(o)); s:ComputeTracked(); T.truthy(s.tracked.rogue_poison_mh); T.falsy(s.tracked.rogue_poison_oh)
  o.offhandWeapon = true; s:ComputeTracked(); T.truthy(s.tracked.rogue_poison_oh)
end)
T.test("consumables: raids only, remind on drop, never in battlegrounds", function()
  local s = FB.State.New(FB.Data, env({ instance="none" })); s:ComputeTracked(); T.falsy(s.tracked.flask)
  s = FB.State.New(FB.Data, env({ instance="raid" })); s:ComputeTracked(); T.eq(s.tracked.flask.reason, "consumable")
  s = FB.State.New(FB.Data, env({ instance="none" })); s.seenConsumable.flask = true; s:ComputeTracked(); T.truthy(s.tracked.flask)
  s = FB.State.New(FB.Data, env({ instance="none", settings={consumablesRaidsOnly=true, consumablesRemindDrop=false} })); s.seenConsumable.flask = true; s:ComputeTracked(); T.falsy(s.tracked.flask)
  s = FB.State.New(FB.Data, env({ instance="none", settings={consumablesRaidsOnly=false, consumablesRemindDrop=true} })); s:ComputeTracked(); T.truthy(s.tracked.flask)
  s = FB.State.New(FB.Data, env({ instance="pvp", settings={consumablesRaidsOnly=false, consumablesRemindDrop=true} })); s.seenConsumable.flask = true; s:ComputeTracked(); T.falsy(s.tracked.flask)
end)
T.test("weapon oil/stone entry: class exclusions, hunter default off, off-hand weapon", function()
  local s = FB.State.New(FB.Data, env({ class="WARRIOR", instance="raid", offhandWeapon=false })); s:ComputeTracked(); T.truthy(s.tracked.weapon_mh); T.falsy(s.tracked.weapon_oh)
  s = FB.State.New(FB.Data, env({ class="WARRIOR", instance="raid", offhandWeapon=true })); s:ComputeTracked(); T.truthy(s.tracked.weapon_oh)
  s = FB.State.New(FB.Data, env({ class="SHAMAN", instance="raid" })); s:ComputeTracked(); T.falsy(s.tracked.weapon_mh)
  s = FB.State.New(FB.Data, env({ class="ROGUE", instance="raid" })); s:ComputeTracked(); T.falsy(s.tracked.weapon_mh)
  s = FB.State.New(FB.Data, env({ class="HUNTER", instance="raid" })); s:ComputeTracked(); T.falsy(s.tracked.weapon_mh)
  s = FB.State.New(FB.Data, env({ class="HUNTER", instance="raid", enabled={weapon_mh=true} })); s:ComputeTracked(); T.truthy(s.tracked.weapon_mh)
end)
T.test("flask not tracked below level 50", function()
  local s = FB.State.New(FB.Data, env({ instance="raid", level=49 })); s:ComputeTracked(); T.falsy(s.tracked.flask); T.truthy(s.tracked.elixir)
  s = FB.State.New(FB.Data, env({ instance="raid", level=50 })); s:ComputeTracked(); T.truthy(s.tracked.flask)
end)
T.test("Role and Recommendation", function()
  local s = FB.State.New(FB.Data, env({ class="MAGE", level=60 })); T.eq(s:Role(), "Caster"); T.eq(s:Recommendation("elixir").itemID, 21546)
  s = FB.State.New(FB.Data, env({ class="MAGE", level=60, settings={ role="Healer" } })); T.eq(s:Role(), "Healer"); T.eq(s:Recommendation("flask").itemID, 13511)
  s = FB.State.New(FB.Data, env({ class="WARRIOR", level=60, weaponKind="blunt" })); T.eq(s:Recommendation("weapon_mh").itemID, 12643)
end)
T.test("IconSpell picks first known icon, else last", function()
  local s = FB.State.New(FB.Data, env({ known={[168]=true} })); T.eq(s:IconSpell("mage_armor"), 168)
  s = FB.State.New(FB.Data, env({ known={[168]=true, [7302]=true} })); T.eq(s:IconSpell("mage_armor"), 7302)
  s = FB.State.New(FB.Data, env({})); T.eq(s:IconSpell("blessing"), 19740)
end)
```

- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement `FB.State.New`, `state:ComputeTracked`, `state:IconSpell` in `State.lua`**

`ComputeTracked` iterates `data.entries`; enabled = `env.enabled(key)` if not nil else `entry.defaultEnabled`. Known = any `castIDs` known. Group-eligible = not selfOnly and some member with `class == entry.class` and `(level <= 0 or level >= learnLevel)`. `requiresOffhandWeapon` entries need `env.offhandWeapon()`. Consumables: `instanceType ~= "pvp" and ~= "arena"` and (`raidsOnly and instanceType == "raid"` or `not raidsOnly` or `(remindDrop and seenConsumable[key])`). `quiet = entry.quietFromOthers and not known`.

- [ ] **Step 4: Run tests** → pass. **Step 5: Commit** `git commit -am "feat: tracked-entry computation"`

---

### Task 5: State: presence evaluation and transitions

**Files:**
- Modify: `State.lua`
- Test: `tests/test_state_eval.lua`

**Interfaces:**
- Produces: `state:Evaluate() -> transitions` where `transitions` is an array of `{ key=, from=, to= }` with states `"untracked"|"present"|"missing"`; `state.status[key]` holds the current state for tracked entries (absent = untracked); `state.stale` bool set true when evaluation was skipped because `env.restricted()`; `state.lastEvaluated = env.now()` on a full evaluation. `Evaluate` calls `ComputeTracked` first.
- Produces: `state:Missing() -> ordered array of keys` currently missing; `state:TrackedKeys() -> ordered array` in data order.

- [ ] **Step 1: Write `tests/test_state_eval.lua`** (same `env` helper, extended with `o.auras` map id→source, `o.auraNames` set, `o.tempEnchant` map slot→bool, `o.restricted`, `o.neverSecret`, `o.auraErrors` set of ids whose `aura()` returns nil)

```lua
T.test("missing then present yields transitions", function()
  local o = { known={[588]=true} }; local s = FB.State.New(FB.Data, env(o))
  local t = s:Evaluate(); T.eq(#t, 1); T.eq(t[1].key, "inner_fire"); T.eq(t[1].from, "untracked"); T.eq(t[1].to, "missing")
  o.auras = { [7128]="player" }; t = s:Evaluate(); T.eq(t[1].to, "present")   -- rank 2 counts
  T.eq(#s:Evaluate(), 0)
  o.auras = {}; t = s:Evaluate(); T.eq(t[1].from, "present"); T.eq(t[1].to, "missing")
end)
T.test("any rank or group version satisfies", function()
  local o = { group={{class="PRIEST", level=60}}, auras={ [21562]="party1" } }
  local s = FB.State.New(FB.Data, env(o)); s:Evaluate(); T.eq(s.status.fortitude, "present")
end)
T.test("mustBeOwn: another paladin's aura does not count; secret source falls back to presence", function()
  local o = { known={[465]=true}, auras={ [465]="party1" } }; local s = FB.State.New(FB.Data, env(o)); s:Evaluate()
  T.eq(s.status.paladin_aura, "missing")
  o.auras[465] = "player"; s:Evaluate(); T.eq(s.status.paladin_aura, "present")
  o.auras[465] = "secret"; s:Evaluate(); T.eq(s.status.paladin_aura, "present")
end)
T.test("weapon enchant entries", function()
  local o = { known={[8017]=true}, tempEnchant={} }; local s = FB.State.New(FB.Data, env(o)); s:Evaluate()
  T.eq(s.status.shaman_imbue, "missing"); o.tempEnchant[16] = true; s:Evaluate(); T.eq(s.status.shaman_imbue, "present")
end)
T.test("well fed matches by name too", function()
  local o = { instance="raid", auraNames={ ["Well Fed"]=true } }; local s = FB.State.New(FB.Data, env(o)); s:Evaluate(); T.eq(s.status.well_fed, "present")
end)
T.test("consumable seen then dropped becomes tracked outside raids", function()
  local o = { instance="none", settings={consumablesRaidsOnly=false, consumablesRemindDrop=true}, auras={ [17626]="player" } }
  local s = FB.State.New(FB.Data, env(o)); s:Evaluate(); T.truthy(s.seenConsumable.flask)
  o.settings.consumablesRaidsOnly = true; o.auras = {}; local t = s:Evaluate(); T.eq(s.status.flask, "missing")
end)
T.test("errored lookup keeps previous state and fires nothing", function()
  local o = { known={[588]=true}, auras={ [588]="player" } }; local s = FB.State.New(FB.Data, env(o)); s:Evaluate()
  o.auraErrors = { [588]=true, [7128]=true, [602]=true, [1006]=true, [10951]=true, [10952]=true }; o.auras = {}
  local t = s:Evaluate(); T.eq(#t, 0); T.eq(s.status.inner_fire, "present")
end)
T.test("restricted: no evaluation, stale flag, unless every id never secret", function()
  local o = { known={[588]=true, [1243]=true}, restricted=true }; local s = FB.State.New(FB.Data, env(o))
  local t = s:Evaluate(); T.truthy(s.stale); T.eq(#t, 0)
  o.neverSecret = {}; for _, id in ipairs(FB.Data.byKey.fortitude.ids) do o.neverSecret[id] = true end
  t = s:Evaluate(); T.eq(s.status.fortitude, "missing"); T.eq(s.status.inner_fire, nil); T.truthy(s.stale)
  o.restricted = false; s:Evaluate(); T.falsy(s.stale)
end)
T.test("entry leaving tracked set transitions to untracked", function()
  local o = { group={{class="MAGE", level=1}} }; local s = FB.State.New(FB.Data, env(o)); s:Evaluate(); T.eq(s.status.arcane_intellect, "missing")
  o.group = {}; local t = s:Evaluate(); T.eq(t[1].to, "untracked"); T.eq(s.status.arcane_intellect, nil)
end)
T.test("Missing and TrackedKeys follow data order", function()
  local o = { known={[588]=true}, group={{class="MAGE", level=1}} }; local s = FB.State.New(FB.Data, env(o)); s:Evaluate()
  T.eq(s:Missing()[1], "inner_fire"); T.eq(s:Missing()[2], "arcane_intellect"); T.eq(#s:TrackedKeys(), 2)
end)
```

- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement `Evaluate`, `Missing`, `TrackedKeys` in `State.lua`**

Per entry presence: `aura` kind → for each id, `env.aura(id)`; if any true → present (then if `mustBeOwn`, require `env.auraSource(id) == "player"` or `== nil`); if all false → missing; if any nil and none true → unknown (keep previous; if no previous, treat as missing only when entry was untracked before? No: unknown with no previous status stays out of `status` and fires no transition). `nameMatch` → `env.auraByName(name)` true counts as present. `weaponEnchant` → `env.tempEnchant(slot)`. Consumable present → `seenConsumable[key] = true`. Restricted: evaluate only entries where every id passes `env.neverSecret`; set `stale = true`; untracked transitions still apply for entries no longer tracked.

- [ ] **Step 4: Run tests** → pass. **Step 5: Commit** `git commit -am "feat: presence evaluation with three-state transitions"`

---

### Task 6: Alerts: sound decisions

**Files:**
- Create/replace: `Alerts.lua`
- Test: `tests/test_alerts.lua`

**Interfaces:**
- Produces: `FB.Alerts.SOUNDS = { {key="raid_warning", name="Raid Warning", kit=8959}, {key="ready_check", name="Ready Check", kit=8960}, {key="alarm", name="Alarm Clock", kit=12889}, {key="boss_whisper", name="Boss Whisper", kit=37666} }`.
- Produces: `FB.Alerts.New() -> alerts`; `alerts:Decide(transitions, state, ctx) -> array of keys to sound` where `ctx = { alertStyle="icon"|"flash"|"sound"|"both", hidden=bool, inGrace=bool, now=number }`. Throttle: 30 s per key. Only `present→missing`; never when `state.tracked[key].quiet`, `hidden`, `inGrace`, or `alertStyle` without sound.
- Produces: `FB.Alerts.Play(soundKey)` → `PlaySound(kit, "Master")`; unknown key falls back to `raid_warning`.
- Produces: `FB.Alerts.ShouldFlash(state, key, alertStyle) -> bool` (missing, style flash/both, not quiet).

- [ ] **Step 1: Write `tests/test_alerts.lua`**

```lua
local function st(quiet) return { tracked={ inner_fire={quiet=quiet or false} } } end
local PM = { {key="inner_fire", from="present", to="missing"} }
T.test("present→missing sounds once per 30s", function()
  local a = FB.Alerts.New(); local ctx = { alertStyle="both", now=100 }
  T.eq(#a:Decide(PM, st(), ctx), 1); ctx.now = 120; T.eq(#a:Decide(PM, st(), ctx), 0); ctx.now = 131; T.eq(#a:Decide(PM, st(), ctx), 1)
end)
T.test("untracked→missing is silent", function()
  local a = FB.Alerts.New(); T.eq(#a:Decide({{key="inner_fire", from="untracked", to="missing"}}, st(), {alertStyle="sound", now=0}), 0)
end)
T.test("quiet, hidden, grace and icon/flash styles are silent", function()
  local a = FB.Alerts.New()
  T.eq(#a:Decide(PM, st(true), {alertStyle="sound", now=0}), 0)
  T.eq(#a:Decide(PM, st(), {alertStyle="sound", hidden=true, now=0}), 0)
  T.eq(#a:Decide(PM, st(), {alertStyle="sound", inGrace=true, now=0}), 0)
  T.eq(#a:Decide(PM, st(), {alertStyle="flash", now=0}), 0); T.eq(#a:Decide(PM, st(), {alertStyle="icon", now=0}), 0)
end)
T.test("Play uses PlaySound on Master with fallback", function()
  STUB.reset(); FB.Alerts.Play("ready_check"); T.eq(STUB.sounds[1][1], 8960); T.eq(STUB.sounds[1][2], "Master")
  FB.Alerts.Play("nope"); T.eq(STUB.sounds[2][1], 8959)
end)
T.test("ShouldFlash", function()
  local s = { tracked={ a={quiet=false}, b={quiet=true} }, status={ a="missing", b="missing" } }
  T.truthy(FB.Alerts.ShouldFlash(s, "a", "flash")); T.truthy(FB.Alerts.ShouldFlash(s, "a", "both"))
  T.falsy(FB.Alerts.ShouldFlash(s, "a", "icon")); T.falsy(FB.Alerts.ShouldFlash(s, "b", "flash"))
  s.status.a = "present"; T.falsy(FB.Alerts.ShouldFlash(s, "a", "flash"))
end)
```

- [ ] **Step 2: Run to verify it fails.** **Step 3: Implement `Alerts.lua`.** **Step 4: Run tests → pass.**
- [ ] **Step 5: Commit** `git commit -am "feat: alert decisions with throttle and quiet rules"`

---

### Task 7: Display: layout, styles, drag, test mode, tooltip

**Files:**
- Create/replace: `Display.lua`
- Test: `tests/test_display.lua`

**Interfaces:**
- Consumes: `state` from Task 5 (`tracked`, `status`, `stale`, `IconSpell`, `TrackedKeys`, `Missing`), `FB.Alerts.ShouldFlash`, `FB.API.SpellIcon/SpellName`.
- Produces: `FB.Display.LayoutPositions(count, size, spacing, direction, perRow) -> array of {x=, y=}` offsets from the anchor's TOPLEFT; `direction` in `"RIGHT"|"LEFT"|"DOWN"|"UP"`; wrapping after `perRow` (rows stack downward for RIGHT/LEFT, columns stack rightward for DOWN/UP).
- Produces: `FB.Display.Init(settings)` creates `FB.Display.anchor` (frame named `ForeverBuffsAnchor`, parent UIParent, strata MEDIUM, movable, clamped); `FB.Display.Update(state, settings, opts)` with `opts = { hidden=bool, unlocked=bool, testMode=bool }`; `FB.Display.ApplyPosition(settings.position)`; `FB.Display.SavePosition(settings)` writes `{point, x, y}` from `anchor:GetPoint()`; `FB.Display.icons` pool (array of button-like frames with `.key`, `.tex`, `.border`, `.label`).
- Visible set: style `"row"` and `"names"` show `state:Missing()`; style `"grid"` shows `state:TrackedKeys()`; unlocked or testMode show `TrackedKeys()` and testMode treats all as missing. Grid present-icons: `SetDesaturated(true)`, alpha 0.35, border hidden. Missing: desaturated false, alpha 1, red border `(0.8, 0.15, 0.15)`. Flashing: an `AnimationGroup` alpha pulse 1.0↔0.4 over 0.55 s each way, looping, started when `ShouldFlash`, stopped otherwise (stub frames return no-op animation objects). Names: `"names"` style puts the label to the right of the icon; `settings.showNames` in other styles puts it below. Stale: `FB.Display.badge` fontstring "?" at the anchor's TOPRIGHT shown when `state.stale`. Tooltip: `GameTooltip:SetText(name)`; for `tracked.reason == "group"` add line "Can be cast by: <names>" from `opts.casters[key]` when provided; for consumable entries add "Recommended: <item name>" from `state:Recommendation(key)` (or "No recommendation at your level" when nil). Icon texture for consumable entries: `FB.API.ItemIcon(rec.itemID)` when a recommendation exists, else `FB.API.SpellIcon(state:IconSpell(key))`. Icon textures are re-resolved on every `Update` (cheap: a few table lookups), so level-ups and weapon swaps change the icon without extra wiring.

- [ ] **Step 1: Write `tests/test_display.lua`**

```lua
T.test("LayoutPositions RIGHT wraps after perRow", function()
  local p = FB.Display.LayoutPositions(3, 40, 6, "RIGHT", 2)
  T.eq(p[1].x, 0); T.eq(p[1].y, 0); T.eq(p[2].x, 46); T.eq(p[2].y, 0); T.eq(p[3].x, 0); T.eq(p[3].y, -46)
end)
T.test("LayoutPositions LEFT, DOWN, UP", function()
  T.eq(FB.Display.LayoutPositions(2, 40, 6, "LEFT", 8)[2].x, -46)
  T.eq(FB.Display.LayoutPositions(2, 40, 6, "DOWN", 8)[2].y, -46)
  T.eq(FB.Display.LayoutPositions(2, 40, 6, "UP", 8)[2].y, 46)
  T.eq(FB.Display.LayoutPositions(3, 40, 6, "DOWN", 2)[3].x, 46)
end)
local function settings(over) local s = { style="grid", iconSize=40, spacing=6, direction="RIGHT", perRow=8, showNames=false, alertStyle="flash", position={point="CENTER", x=0, y=180} }; for k,v in pairs(over or {}) do s[k]=v end; return s end
local function fakeState(tracked, status, stale)
  local s = { tracked=tracked, status=status, stale=stale or false }
  function s:TrackedKeys() local r = {}; for _, e in ipairs(FB.Data.entries) do if tracked[e.key] then r[#r+1] = e.key end end; return r end
  function s:Missing() local r = {}; for _, k in ipairs(self:TrackedKeys()) do if status[k] == "missing" then r[#r+1] = k end end; return r end
  function s:IconSpell(k) return FB.Data.byKey[k].iconSpells[#FB.Data.byKey[k].iconSpells] end
  function s:Recommendation(k) return s.rec and s.rec[k] or nil end
  return s
end
T.test("consumable icon uses recommended item icon", function()
  STUB.reset(); STUB.items[13452] = { name="Elixir of the Mongoose", icon=134873 }; FB.Display.Init(settings())
  local st = fakeState({ elixir={} }, { elixir="missing" }); st.rec = { elixir={ itemID=13452, name="Elixir of the Mongoose" } }
  FB.Display.Update(st, settings(), {}); local ic
  for _, f in ipairs(FB.Display.icons) do if f:IsShown() then ic = f end end
  T.eq(ic.tex.texture, 134873)
end)
T.test("grid shows all tracked, dims present", function()
  STUB.reset(); FB.Display.Init(settings())
  local st = fakeState({ inner_fire={}, fortitude={} }, { inner_fire="present", fortitude="missing" })
  FB.Display.Update(st, settings(), {}); local shown = {}
  for _, ic in ipairs(FB.Display.icons) do if ic:IsShown() then shown[ic.key] = ic end end
  T.truthy(shown.inner_fire and shown.fortitude); T.eq(shown.inner_fire:GetAlpha(), 0.35); T.eq(shown.fortitude:GetAlpha(), 1)
end)
T.test("row style shows only missing; hidden hides anchor", function()
  STUB.reset(); FB.Display.Init(settings({style="row"}))
  local st = fakeState({ inner_fire={}, fortitude={} }, { inner_fire="present", fortitude="missing" })
  FB.Display.Update(st, settings({style="row"}), {}); local n = 0
  for _, ic in ipairs(FB.Display.icons) do if ic:IsShown() then n = n + 1; T.eq(ic.key, "fortitude") end end; T.eq(n, 1)
  FB.Display.Update(st, settings({style="row"}), { hidden=true }); T.falsy(FB.Display.anchor:IsShown())
end)
T.test("test mode shows everything as missing; stale shows badge", function()
  STUB.reset(); FB.Display.Init(settings({style="row"}))
  local st = fakeState({ inner_fire={}, fortitude={} }, { inner_fire="present", fortitude="present" }, true)
  FB.Display.Update(st, settings({style="row"}), { testMode=true }); local n = 0
  for _, ic in ipairs(FB.Display.icons) do if ic:IsShown() then n = n + 1 end end; T.eq(n, 2); T.truthy(FB.Display.badge:IsShown())
end)
T.test("SavePosition round-trips", function()
  STUB.reset(); local s = settings(); FB.Display.Init(s); FB.Display.anchor:SetPoint("CENTER", UIParent, "CENTER", 12, -34)
  FB.Display.SavePosition(s); T.eq(s.position.x, 12); T.eq(s.position.y, -34); T.eq(s.position.point, "CENTER")
end)
```

- [ ] **Step 2: Run to verify it fails.** **Step 3: Implement `Display.lua`.** Icon frames are `CreateFrame("Button", nil, anchor)` with `tex` (`SetAllPoints`), `border` texture (1 px inset via `SetPoint` offsets, solid colour `SetColorTexture`), `label` fontstring `GameFontNormalSmall`. Anchor `SetSize` to the bounding box of the layout. Drag: `anchor:SetScript("OnDragStart", StartMoving)` only when `opts.unlocked`; `OnDragStop` → `StopMovingOrSizing` + `FB.Display.SavePosition` via a callback `FB.Display.onMoved` set by Core. Unlocked shows a backdrop texture (black, alpha 0.4) and label "ForeverBuffs - drag to move, /fbuffs lock to lock".
- [ ] **Step 4: Run tests → pass.** **Step 5: Commit** `git commit -am "feat: icon display with three styles, drag, test mode"`

---

### Task 8: Core: saved variables, events, hide rules, combat freeze, slash commands

**Files:**
- Create/replace: `Core.lua`
- Test: `tests/test_core.lua`

**Interfaces:**
- Consumes: everything above.
- Produces: `FB.Core.DEFAULTS = { style="grid", iconSize=40, spacing=6, direction="RIGHT", perRow=8, showNames=false, alertStyle="flash", sound="raid_warning", combat="freeze", hideMounted=true, hideResting=false, locked=true, position={point="CENTER", x=0, y=180} }` and `FB.Core.CHAR_DEFAULTS = { enabled={}, consumablesRaidsOnly=true, consumablesRemindDrop=true, role=nil }` (`role` nil means "use `FB.Data.DefaultRole`").
- Produces: `FB.Core.InitDB()` fills missing keys in `ForeverBuffsDB`/`ForeverBuffsCharDB` from defaults (never overwrites existing values); `FB.db`, `FB.cdb` references.
- Produces: `FB.Core.BuildEnv() -> env` for `FB.State.New` using `FB.API` (group members via `IsInRaid()`/`GetNumGroupMembers()` → `raidN` excluding the player, else `party1..N-1`; skip `not UnitIsConnected`; `UnitClassLevel` nil class → skip; `playerClass`/`playerLevel`/`weaponKind` from `FB.API.PlayerClass/PlayerLevel/MainhandWeaponKind`; `charSettings` returns `FB.cdb`). `PLAYER_LEVEL_UP` and `UNIT_INVENTORY_CHANGED` trigger `Refresh` so recommendations follow level and weapon.
- Produces: `FB.Core.Casters() -> map key → array of unit names` (group members eligible for each group entry; built during `BuildEnv`'s group scan and passed to `Display.Update` as `opts.casters` for tooltips).
- Produces: `FB.Core.ShouldHide() -> bool, reason` with reasons `"dead"|"taxi"|"mounted"|"vehicle"|"resting"|"combat"` (`"combat"` only when `FB.db.combat == "hide"`).
- Produces: `FB.Core.Refresh()` (throttled to 0.25 s via `C_Timer.After`; no-op while `InCombatLockdown()`; otherwise `state:Evaluate()`, `Alerts:Decide`, `Alerts.Play` for each, `Display.Update`). `FB.Core.state`, `FB.Core.alerts`, `FB.Core.inGrace` (true for 3 s after `PLAYER_ENTERING_WORLD` and `GROUP_ROSTER_UPDATE`), `FB.Core.testMode`, `FB.Core.unlocked`.
- Produces: events registered on `FB.Core.frame`: list from spec "Technical shape"; `UNIT_AURA` registered for `"player"` only via `RegisterUnitEvent`; `PLAYER_REGEN_DISABLED` sets `FB.Core.inCombat = true` and calls `Display.Update` with hidden if `combat == "hide"`; `PLAYER_REGEN_ENABLED` clears and refreshes. 1 s ticker (`C_Timer.NewTicker`) calls `Refresh` when not in combat.
- Produces: `FB.Core.Slash(msg)` handling `""` (open options via `FB.Options.Open()`), `lock`, `unlock`, `test`, `reset` (position), `debug`, `api`, `ids`, `help`. `debug` prints each tracked key with reason/quiet/status and the restricted/stale flags; `api` prints `FB.API.Probe()` rows as `OK name` / `MISSING name`; `ids` prints `spell id -> name` or `spell id -> UNKNOWN` for `FB.Data.AllSpellIDs()`, then `item id -> name` / `UNKNOWN` for `FB.Data.AllItemIDs()` (item names may be nil until the client caches the item; the command says so in its header line).

- [ ] **Step 1: Write `tests/test_core.lua`**

```lua
T.test("InitDB fills defaults without clobbering", function()
  STUB.reload(); ForeverBuffsDB = { iconSize=50 }; ForeverBuffsCharDB = nil; FB.Core.InitDB()
  T.eq(FB.db.iconSize, 50); T.eq(FB.db.style, "grid"); T.eq(FB.db.position.y, 180); T.eq(FB.cdb.consumablesRaidsOnly, true)
end)
T.test("ShouldHide reasons", function()
  STUB.reload(); T.falsy(FB.Core.ShouldHide())
  STUB.player.dead = true; T.eq(select(2, FB.Core.ShouldHide()), "dead"); STUB.player.dead = false
  STUB.player.mounted = true; T.eq(select(2, FB.Core.ShouldHide()), "mounted"); FB.db.hideMounted = false; T.falsy(FB.Core.ShouldHide()); STUB.player.mounted = false
  STUB.player.resting = true; T.falsy(FB.Core.ShouldHide()); FB.db.hideResting = true; T.eq(select(2, FB.Core.ShouldHide()), "resting"); STUB.player.resting = false
  STUB.player.combat = true; T.falsy(FB.Core.ShouldHide()); FB.db.combat = "hide"; T.eq(select(2, FB.Core.ShouldHide()), "combat")
end)
T.test("login flow: grace, then evaluate, icon shown, no sound", function()
  STUB.reload(); STUB.known[588] = true; FB.db.alertStyle = "both"
  STUB.fire("PLAYER_ENTERING_WORLD"); T.truthy(FB.Core.inGrace); STUB.advance(3.1); STUB.advance(0.3)
  T.eq(FB.Core.state.status.inner_fire, "missing"); T.eq(#STUB.sounds, 0); T.truthy(FB.Display.anchor:IsShown())
end)
T.test("buff dropping out of combat plays sound once", function()
  STUB.reload(); STUB.known[588] = true; FB.db.alertStyle = "sound"; STUB.auras[588] = { sourceUnit="player" }
  STUB.fire("PLAYER_ENTERING_WORLD"); STUB.advance(3.5); T.eq(FB.Core.state.status.inner_fire, "present")
  STUB.auras[588] = nil; STUB.fire("UNIT_AURA", "player"); STUB.advance(0.3); T.eq(#STUB.sounds, 1)
  STUB.fire("UNIT_AURA", "player"); STUB.advance(0.3); T.eq(#STUB.sounds, 1)
end)
T.test("combat freezes evaluation; leaving combat re-evaluates", function()
  STUB.reload(); STUB.known[588] = true; STUB.auras[588] = { sourceUnit="player" }
  STUB.fire("PLAYER_ENTERING_WORLD"); STUB.advance(3.5); T.eq(FB.Core.state.status.inner_fire, "present")
  STUB.player.combat = true; STUB.fire("PLAYER_REGEN_DISABLED"); STUB.auras[588] = nil; STUB.restricted = true
  STUB.fire("UNIT_AURA", "player"); STUB.advance(2); T.eq(FB.Core.state.status.inner_fire, "present")
  STUB.player.combat = false; STUB.restricted = false; STUB.fire("PLAYER_REGEN_ENABLED"); STUB.advance(0.3); T.eq(FB.Core.state.status.inner_fire, "missing")
end)
T.test("group roster builds eligible casters", function()
  STUB.reload(); STUB.group = { {class="PRIEST", level=60}, {class="MAGE", level=5, connected=false} }
  STUB.fire("PLAYER_ENTERING_WORLD"); STUB.advance(3.5)
  T.eq(FB.Core.state.status.fortitude, "missing"); T.eq(FB.Core.state.status.arcane_intellect, nil)
end)
T.test("slash commands", function()
  STUB.reload(); STUB.printed = {}
  FB.Core.Slash("unlock"); T.truthy(FB.Core.unlocked); FB.Core.Slash("lock"); T.falsy(FB.Core.unlocked)
  FB.Core.Slash("test"); T.truthy(FB.Core.testMode); FB.Core.Slash("test"); T.falsy(FB.Core.testMode)
  FB.Core.Slash("api"); T.truthy(#STUB.printed > 5)
  STUB.spells[588] = { name="Inner Fire" }; STUB.printed = {}; FB.Core.Slash("ids")
  local joined = table.concat(STUB.printed, "\n"); T.truthy(joined:find("588") and joined:find("Inner Fire") and joined:find("UNKNOWN"))
  FB.db.position.x = 99; FB.Core.Slash("reset"); T.eq(FB.db.position.x, 0)
  T.truthy(SlashCmdList.FOREVERBUFFS); T.eq(SLASH_FOREVERBUFFS1, "/fbuffs"); T.eq(SLASH_FOREVERBUFFS2, "/forbuffs")
end)
```

- [ ] **Step 2: Run to verify it fails.** **Step 3: Implement `Core.lua`.** `PLAYER_LOGIN` → `InitDB`, `Display.Init(FB.db)`, `Display.ApplyPosition`, create state/alerts, register remaining events, start ticker, `Display.onMoved = function() Display.SavePosition(FB.db) end`. Group-change grace uses the same 3 s timer as entering world.
- [ ] **Step 4: Run tests → pass.** **Step 5: Commit** `git commit -am "feat: core event wiring, saved variables, slash commands"`

---

### Task 9: Options panel

**Files:**
- Create/replace: `Options.lua`
- Test: `tests/test_options.lua`

**Interfaces:**
- Consumes: `FB.db`, `FB.cdb`, `FB.Data.entries`, `FB.Alerts.SOUNDS`, `FB.Core.Refresh`, `FB.Core.Slash`.
- Produces: `FB.Options.Build()` (idempotent; called from `PLAYER_LOGIN` after `InitDB`) registers a vertical-layout category "ForeverBuffs" via `Settings.RegisterVerticalLayoutCategory` + `Settings.RegisterAddOnCategory`, storing `FB.Options.category`; `FB.Options.Open()` → `Settings.OpenToCategory(FB.Options.category:GetID())`.
- Sections and controls (each change calls `FB.Core.Refresh()`): **Display**: style dropdown (`row`="Plain row", `names`="Flashing with names", `grid`="Always-on grid"), iconSize slider 20–80 step 2, spacing slider 0–20, direction dropdown, perRow slider 1–20, showNames checkbox. **Alerts**: alertStyle dropdown (`icon`,`flash`,`sound`,`both`), sound dropdown from `FB.Alerts.SOUNDS`, "Play test sound" button. **Visibility**: combat dropdown (`freeze`,`hide`), hideMounted, hideResting checkboxes. **Buffs**: one checkbox per entry whose `class == player class` or `class == nil` (skipping entries whose `excludeClasses` contains the player class) or `selfOnly == false`, bound to `FB.cdb.enabled[key]` with default `entry.defaultEnabledByClass[class]` if set else `entry.defaultEnabled`; consumable sub-controls: `role` dropdown from `FB.Data.ROLES` (default `FB.Data.DefaultRole(class)`), `consumablesRaidsOnly`, `consumablesRemindDrop`. `FB.Options.buffKeys` holds the ordered keys shown. **Position**: buttons Unlock/Lock (toggle), Reset position.
- Settings are proxy settings: `Settings.RegisterProxySetting(category, "FB_"..key, type, name, default, getter, setter)` with getters/setters on `FB.db`/`FB.cdb`. Buttons via `CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, addSearchTags)` added through `layout:AddInitializer`. If a Settings function is missing (`Probe` says so), `Build` prints one line "ForeverBuffs: options panel unavailable on this client, use /fbuffs commands" and returns.

- [ ] **Step 1: Write `tests/test_options.lua`**

```lua
T.test("Build registers category once and Open works", function()
  STUB.reload(); FB.Options.Build(); FB.Options.Build()
  T.eq(#STUB.settingsCategories, 1); T.truthy(FB.Options.category); FB.Options.Open()
end)
T.test("Buffs section lists class self-buffs, all group buffs and consumables", function()
  STUB.reload(); STUB.player.class = "PRIEST"; FB.Options.Build()
  local keys = FB.Options.buffKeys; local set = {}; for _, k in ipairs(keys) do set[k] = true end
  T.truthy(set.inner_fire and set.fortitude and set.battle_shout and set.flask and set.weapon_mh); T.falsy(set.mage_armor)
  STUB.reload(); STUB.player.class = "SHAMAN"; FB.Options.Build(); set = {}; for _, k in ipairs(FB.Options.buffKeys) do set[k] = true end
  T.truthy(set.shaman_imbue); T.falsy(set.weapon_mh)
end)
T.test("missing Settings API degrades to a printed notice", function()
  STUB.reload(); local saved = Settings.RegisterVerticalLayoutCategory; Settings.RegisterVerticalLayoutCategory = nil; STUB.printed = {}
  FB.Options.Build(); T.truthy(#STUB.printed == 1); Settings.RegisterVerticalLayoutCategory = saved
end)
```

- [ ] **Step 2: Run to verify it fails.** **Step 3: Implement `Options.lua`** (extend `wow_stub.lua` `Settings` stub as needed: `RegisterVerticalLayoutCategory` returns `{ GetID=function() return 1 end }` and a layout with `AddInitializer`; `RegisterProxySetting`, `CreateCheckbox`, `CreateSlider`, `CreateDropdown`, `CreateControlTextContainer`, `CreateSliderOptions`, `OpenToCategory`, `RegisterAddOnCategory` records). **Step 4: Run tests → pass.**
- [ ] **Step 5: Commit** `git commit -am "feat: native settings panel"`

---

### Task 10: In-game verification and ID audit

**Files:**
- Modify: `Data.lua` (header date, any corrected IDs), `README.md` (create: what it does, commands, options)

**Interfaces:** none new.

- [ ] **Step 1: Write `README.md`** — one screen: purpose, install location, `/fbuffs` commands table, the three styles, how combat freezing works.
- [ ] **Step 2: Hand the player this checklist** (the game must be running; the builder cannot do these):

```
1. /reload, then /console scriptErrors 1
2. /fbuffs api      -> paste output (every line should be OK)
3. /fbuffs ids      -> paste output (look for UNKNOWN lines; run it twice, item names fill in after the first run)
4. /fbuffs test     -> every tracked icon shows; /fbuffs unlock, drag, /fbuffs lock; /reload; position kept
5. /fbuffs          -> options panel opens; change style to each of the three
6. Cast your self-buff; icon dims (grid) or disappears (row). Let it expire or cancel it; icon lights up; with alert style "Sound" a sound plays once
6b. Hover the Elixir / Well Fed / Weapon icons in test mode: tooltip names the recommended item for your class, role and level; change Role in options and the recommendation changes
7. Join a party with another class; the group buff icon appears only for classes present
8. Enter combat briefly; no errors; display frozen; leave combat; display updates
9. /fbuffs debug    -> paste output
```

- [ ] **Step 3: Fix anything the output shows** (UNKNOWN IDs → correct against `https://www.wowhead.com/forever/spell=<id>`, missing API → adjust wrapper), re-run `python tests/run_tests.py`, update the `Data.lua` header date.
- [ ] **Step 4: Commit** `git commit -am "fix: in-game verified spell IDs and API probe results"` and tag `git tag v1.0.0`.
