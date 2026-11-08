# ForeverBuffs 1.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-entry Show/Sound toggles, per-category consumable scope, visibility modes with running-out tracking, per-priority alert channels with repeats and screen text, snap grid, a Forever-accurate consumables catalogue with sources and runtime buff IDs, and spell rank info.

**Architecture:** Same layers as 1.1. `State.lua` gains end-time caching, an `expiring` status, show/sound/visibility/scope logic (all pure, via env). `Alerts.lua` becomes a per-priority channel scheduler with repeats. `Display.lua` gains looks, visibility modes, the amber running-out border with countdown, exact anchor bounds, and the snap grid overlay. `API.lua` gains aura end times, weapon remaining time, item→spell resolution and screen text. `Data.lua` is rebuilt from the research files. `Options.lua` grows the new controls.

**Tech Stack:** WoW Lua 5.1 on Forever 1.60.1 (Interface 16001); tests `python tests/run_tests.py` (lupa, fake API `tests/wow_stub.lua`).

**Spec:** `docs/superpowers/specs/2026-11-08-forever-buffs-v1.2-design.md` (its final "Resolutions" section overrides the body where they differ), with 1.1 and 1.0 specs for everything unchanged. Data: `docs/superpowers/research/2026-11-08-forever-consumables.md` and `docs/superpowers/research/2026-11-08-sources-and-ranks.md`.

## Global Constraints

- All 1.0/1.1 constraints still apply (pcall + `issecretvalue` discipline, no aura reads in combat or under restriction, `local ADDON, FB = ...`, commit per task).
- `## Version: 1.2.0`; `settingsVersion = 3` after migration.
- Statuses: `"present" | "expiring" | "missing"`; visibility values `"always" | "missing" | "expiring"`; look values `"icons" | "names_beside" | "names_below"`; scope values `"everywhere" | "instances" | "raids" | "never"`.
- Per-priority settings keys: `alert.<prio>.sound` (sound key or `"none"`), `alert.<prio>.repeat` (seconds, 0 = off), `alert.<prio>.text` (bool), `alert.<prio>.flash` (bool), stored as `FB.db.alert = { high = {...}, normal = {...}, low = {...} }`. Defaults: high `{ sound="alarm3", ["repeat"]=30, text=true, flash=true }`, normal `{ sound="raid_warning", ["repeat"]=0, text=false, flash=true }`, low `{ sound="none", ["repeat"]=0, text=false, flash=false }`.
- Thresholds: `expireLongSeconds=300`, `expireShortSeconds=60`, `longBuffSeconds=900`; per-entry repeat floor 10 s.
- Grid: `snapToGrid=true`, `gridSize=16`, `showGridWhileUnlocked=true`.

## Review Focus

1. **1.1 user with `alertStyle="both"`, `soundNormal="group_application"`, `style="grid"`** (Colin's real file) upgrades to: Normal sound group_application, Normal flash on, look icons, visibility always; nothing else reset. Test in Task 1.
2. **A buff that runs out during combat** shows as expiring with a countdown reaching "0s" and stays visible until combat ends, without any aura API call in combat. Test in Task 3.
3. **A consumable with Sound ticked on but default Low priority** alerts (Sound tick is master). Test in Task 4.
4. **Two entries due to repeat in the same tick** produce one sound and one combined screen text. Test in Task 4.
5. **Snap rounding with negative offsets** (anchor left/below centre) rounds to the nearest grid multiple, not toward zero. Test in Task 6.

---

### Task 1: Settings v3: defaults and migration

**Files:** Modify `Core.lua`; Test `tests/test_core.lua`.

**Interfaces:**
- Produces: `FB.Core.DEFAULTS` gains `look="icons"`, `visibility="always"`, the thresholds, `alert` (per-priority table above), `alertOnExpiring=true`, grid keys, `settingsVersion=3`; `CHAR_DEFAULTS` gains `show={}`, `sound={}`, `visibility={}`, `consumableWhere={}`.
- Produces: `migrate(db)` (account) and `FB.Core.MigrateChar(cdb)` (character, guarded by `cdb.settingsVersion`). Account 1.1→3: `style`→`look`/`visibility` (grid→icons+always, row→icons+missing, names→names_beside+missing and `alert.normal.flash=true`); `showNames=true`→`names_below` (only when style was not names); `alertStyle` icon → normal flash off + normal sound none; flash → normal sound none; sound → normal flash off; both → unchanged; `soundNormal`→`alert.normal.sound` (unless set to none above); `soundHigh`→`alert.high.sound`. Character: `enabled[k]==false` → `show[k]=false, sound[k]=false`; `enabled[k]==true` → both true; `consumablesRaidsOnly==false` → all four scopes `"everywhere"`. Unknown sound keys reset to the default for that priority (1.1 guard generalised).
- `copyDefaults` must deep-copy nested defaults (the `alert` table) without overwriting existing values.

- [ ] **Step 1: Tests**
```lua
T.test("1.1 settings migrate to v3", function()
  STUB.reload(function() ForeverBuffsDB = { settingsVersion=2, style="grid", alertStyle="both", soundNormal="group_application", soundHigh="alarm3", iconSize=28 }
    ForeverBuffsCharDB = { enabled={ inner_fire=false }, consumablesRaidsOnly=true, pick={ elixir=3383 } } end)
  T.eq(FB.db.look, "icons"); T.eq(FB.db.visibility, "always"); T.eq(FB.db.alert.normal.sound, "group_application"); T.eq(FB.db.alert.normal.flash, true)
  T.eq(FB.db.alert.high.sound, "alarm3"); T.eq(FB.db.alert.high["repeat"], 30); T.eq(FB.db.iconSize, 28); T.eq(FB.db.settingsVersion, 3)
  T.eq(FB.cdb.show.inner_fire, false); T.eq(FB.cdb.sound.inner_fire, false); T.eq(FB.cdb.pick.elixir, 3383); T.eq(FB.cdb.consumableWhere.elixir, nil)
end)
T.test("style and alertStyle mappings", function()
  STUB.reload(function() ForeverBuffsDB = { settingsVersion=2, style="names", alertStyle="icon" } end)
  T.eq(FB.db.look, "names_beside"); T.eq(FB.db.visibility, "missing"); T.eq(FB.db.alert.normal.sound, "none"); T.eq(FB.db.alert.normal.flash, true)
  STUB.reload(function() ForeverBuffsDB = { settingsVersion=2, style="row", showNames=true, alertStyle="sound" } end)
  T.eq(FB.db.look, "names_below"); T.eq(FB.db.visibility, "missing"); T.eq(FB.db.alert.normal.flash, false)
  STUB.reload(function() ForeverBuffsCharDB = { consumablesRaidsOnly=false } end); T.eq(FB.cdb.consumableWhere.flask, "everywhere"); T.eq(FB.cdb.consumableWhere.weapon, "everywhere")
end)
T.test("fresh install defaults", function()
  STUB.reload(); T.eq(FB.db.look, "icons"); T.eq(FB.db.alert.low.sound, "none"); T.eq(FB.db.gridSize, 16); T.eq(FB.db.expireLongSeconds, 300)
end)
```
Update existing 1.1 migration tests to read `FB.db.alert.normal.sound` instead of `FB.db.soundNormal`.
- [ ] **Step 2:** run → FAIL. **Step 3:** implement. **Step 4:** run full suite → green (other modules still read old keys; keep `FB.db.soundNormal`/`soundHigh`/`alertStyle`/`style` readable until Tasks 4–5 switch, i.e. migration does not delete old keys). **Step 5:** commit `feat: settings v3 defaults and migration`.

---

### Task 2: API: end times, weapon remaining, item spells, screen text

**Files:** Modify `API.lua`, `tests/wow_stub.lua`; Test `tests/test_api.lua`.

**Interfaces:**
- `FB.API.PlayerAuraTimes(id) -> expirationTime|nil, duration|nil` (nil when absent, errored, secret, or duration 0).
- `FB.API.WeaponRemaining(slot) -> seconds|nil` from `GetTemporaryEnchantmentInfo(slot).remainingTimeMs`, else the first `hasEnchant` entry's `timeLeft` from `C_Item.GetWeaponEnchantInfo`, ms → s; nil when unknown/secret.
- `FB.API.ItemSpell(itemID) -> spellID|nil` via `C_Item.GetItemSpell(itemID)` (second return), calling `C_Item.RequestLoadItemDataByID(itemID)` when it returns nil; `FB.API.ItemSpellPending` set of itemIDs requested.
- `FB.API.ScreenText(text, r, g, b)`: `RaidNotice_AddMessage(RaidWarningFrame, text, { r=, g=, b= })` if both exist, else `UIErrorsFrame:AddMessage(text, r, g, b)`; pcall-wrapped.
- Stub: aura records gain `expirationTime`, `duration`; `STUB.tempEnchant[slot].remainingTimeMs`; `STUB.itemSpells[itemID] = spellID`; `C_Item.GetItemSpell`, `C_Item.RequestLoadItemDataByID` (records into `STUB.itemRequests`); `RaidNotice_AddMessage` and `RaidWarningFrame` recording into `STUB.raidNotices`; `UIErrorsFrame:AddMessage` recording into `STUB.errorsFrame`.
- Probe list adds `C_Item.GetItemSpell`, `C_Item.RequestLoadItemDataByID`, `RaidNotice_AddMessage`.

- [ ] Tests: present aura with times returns both; duration 0 → nil; secret expirationTime → nil; restricted → nil. `WeaponRemaining(16)` from `remainingTimeMs=125000` → 125; from list `timeLeft=60000` → 60. `ItemSpell` returns mapped spell, requests data when unmapped. `ScreenText` uses RaidNotice when present, UIErrorsFrame when `RaidNotice_AddMessage=nil`. → FAIL → implement → green → commit `feat: aura end times, weapon remaining, item spells, screen text`.

---

### Task 3: State: show/sound/scope/visibility and running-out

**Files:** Modify `State.lua`, `tests/helpers.lua`; Test `tests/test_state_tracked.lua`, `tests/test_state_eval.lua`.

**Interfaces:**
- env gains `auraTimes(id) -> exp, dur`, `weaponRemaining(slot) -> seconds|nil`, `inCombat() -> bool`, `thresholds() -> { long=, short=, longBuff= }`, `globalVisibility() -> mode`; `charSettings()` exposes `show`, `sound`, `visibility`, `consumableWhere`.
- `state:Shows(key) -> bool`, `state:Sounds(key) -> bool`: explicit setting, else defaults: show defaults to `defaultEnabledByClass`/`defaultEnabled`; sound defaults to false if show defaults false or `Data.DefaultPriority(reason)=="low"` (reason by would-be reason: own class or known → known, consumable → consumable, else group), else true.
- Tracking: entry tracked iff (`Shows` or `Sounds`) and the 1.1 rules; consumables use `consumableWhere[Data.CategoryOf(key)]` (defaults elixir/well_fed/weapon `instances`, flask `raids`): everywhere → any instance type except pvp/arena; instances → `party` or `raid`; raids → `raid`; never → never; remind-drop still tracks anywhere unless `never`. `consumablesRaidsOnly` is no longer read.
- `state:Visibility(key) -> mode` (per-entry override else global).
- `state.expiresAt[key]`, `state.fullDuration[key]` set during presence checks when known (latest end time among matching IDs; weapon: `now + remaining`, full 3600 for imbues/poisons, 1800 for oils/stones).
- `state:UpdateExpiring(now) -> transitions` (no env aura calls): for present/expiring entries with `expiresAt`, sets `expiring` when `expiresAt - now <= threshold` (long if `fullDuration >= longBuff`), back to `present` otherwise; returns transitions `present→expiring` etc. `Evaluate` calls it at the end. In combat `UpdateExpiring` may run; entries past `expiresAt` stay `expiring`.
- `state:Remaining(key, now) -> seconds|nil`.

- [ ] Tests (env helper: `o.auraTimes[id] = { exp, dur }`, `o.weaponRemaining[slot] = s`, `o.now`, `o.combat`):
  - `Shows/Sounds` defaults: inner_fire both true; fortitude via group: show true, sound false; righteous_fury both false; explicit `sound.flask=true` → true.
  - consumable scopes: elixir tracked in `party` by default, not in `none`; flask not in `party`, tracked in `raid`; `everywhere` tracks in `none`; `never` blocks remind-drop.
  - show false + sound true still tracks; both false untracks.
  - expiring: inner_fire dur 600 exp now+59 → expiring (short 60); dur 1800 exp now+299 → expiring (long 300); dur 1800 exp now+301 → present; Paladin aura dur 0 → never expiring.
  - **combat countdown** (Review Focus 2): evaluate out of combat at t=0 with exp 100/dur 600, then set `o.combat=true`, `o.auraErrors` for all ids, and call `UpdateExpiring(41)` → expiring; `UpdateExpiring(150)` → still expiring, `Remaining` 0 (clamped), no aura calls made (count calls in helper).
  - weapon: imbue remaining 250 s → expiring (short? full 3600 → long threshold 300) → expiring.
  - visibility override returns per-entry mode else global.
- [ ] → FAIL → implement → green → commit `feat: show/sound toggles, consumable scopes, running-out status`.

---

### Task 4: Alerts: per-priority channels, repeats, running-out alerts

**Files:** Rewrite parts of `Alerts.lua`; modify `Core.lua` call sites; Test `tests/test_alerts.lua`, `tests/test_core.lua`.

**Interfaces:**
- `alerts:Decide(transitions, state, ctx) -> { sounds = {soundKey...distinct}, texts = { {text=, priority=} ... } }`; `ctx = { channels = FB.db.alert, alertOnExpiring=, hidden=, inGrace=, inCombat=, now= }`. Rules: entry must `state:Sounds(key)`; priority from `state:Priority(key)`; channel = `ctx.channels[prio]`. present→missing: channel sound (unless none) and text (if `text`) "X missing!". present→expiring (if `alertOnExpiring`): same, text "X runs out in N min" (or "N s" under 60). Record `lastAlert[key]=now` and `missingSince[key]`.
- `alerts:DueRepeats(state, ctx) -> same shape`: for each key with status missing, `Sounds`, channel `repeat > 0`, and `now - lastAlert[key] >= max(10, repeat)`; skipped when `hidden`, `inGrace`, `inCombat`. Several due keys → distinct sounds once each and **one combined text** "A, B missing!" (Review Focus 4), coloured by the highest priority among them.
- Remove 1.1's 30 s throttle; keep a 10 s floor per key for transition alerts.
- `FB.Alerts.ShouldFlash(state, key)` → `status missing or expiring` and `channels[prio].flash` (reads `FB.db.alert`).
- `FB.Alerts.Deliver(result)` plays each sound and calls `FB.API.ScreenText` for each text (gold `1, 0.82, 0` for high, red `1, 0.25, 0.2` otherwise).
- Core: `Run` calls `Decide` then `Deliver`; the 1 s ticker calls `state:UpdateExpiring(now)` (always, also in combat) → `Decide` on those transitions (not in combat) → `DueRepeats` → `Deliver` → `Render`.

- [ ] Tests: default high entry missing → sound alarm3 + text "Inner Fire missing!"; `Sounds` false → nothing; Low-priority consumable with `sound.flask=true` and low channel sound "whisper" → whisper (Review Focus 3); normal channel sound none + text true → text only; expiring with alertOnExpiring → "runs out in 5 min"; repeats: high missing at t=0, `DueRepeats` at 20 → none, at 30 → one; in combat → none; normal repeat 0 → never; two high entries due → 1 sound, 1 text containing both names; Core integration: inner_fire high, drop at t=0 out of combat → 1 sound, advance 31 s → 2 sounds and 2 raid notices.
- [ ] → FAIL → implement → green → commit `feat: per-priority alert channels, repeats, running-out alerts`.

---

### Task 5: Display: looks, visibility, running-out border, exact bounds

**Files:** Modify `Display.lua`; Test `tests/test_display.lua`.

**Interfaces:**
- `Display.Update(state, settings, opts)` reads `settings.look` and per-key `state:Visibility(key)`: visible keys = tracked keys filtered by mode (`always` all; `missing` status missing; `expiring` missing or expiring); unlocked/testMode show all tracked.
- Border: missing → red (gold for high); expiring → amber `(1, 0.6, 0.1)`; present → hidden. Present icons dim (0.35, desaturated).
- `icon.timer` fontstring, bottom-centre: shown for expiring entries with `state:Remaining`, text `"4m"` (≥60 s, floor minutes) or `"45s"`; hidden otherwise. Timer text is part of the signature so it refreshes each second.
- Labels: `names_beside` right of icon, `names_below` under it, `icons` none.
- Flash via `FB.Alerts.ShouldFlash(state, key)` (testMode: flash per channel flash of the entry's priority).
- `Display.Bounds(positions, sizes) -> minX, maxY, maxX, minY` and icons offset so the anchor's TOPLEFT is the true top-left of all icons for every direction (LEFT/UP shift by `-minX` / `-maxY`); anchor size = exact extent (floor `iconSize`). Cache per-key texture within one Update (computed once, used by signature and render).
- [ ] Tests: visibility modes show the right keys; expiring icon has amber border and timer "4m" for 250 s, "45s" for 45 s; names_below vs names_beside label anchor point; LEFT growth with 3 icons → all icon x offsets ≥ 0 and anchor width = extent; horizontal anchor height = tallest icon (not double); signature changes when the timer text changes. → FAIL → implement → green → commit `feat: display looks, visibility modes, running-out border and timer, exact anchor bounds`.

---

### Task 6: Snap grid

**Files:** Modify `Display.lua`, `Core.lua`; Test `tests/test_display.lua`.

**Interfaces:**
- `Display.SnapOffset(v, size) -> number` rounding to nearest multiple (half away from zero; e.g. `SnapOffset(-23, 16) == -16`, `SnapOffset(-25, 16) == -32`, `SnapOffset(24, 16) == 32`).
- `Display.SavePosition(settings)` snaps x/y when `settings.snapToGrid`, then re-applies the position.
- `Display.ShowGrid(size)` / `Display.HideGrid()`: a full-screen frame `ForeverBuffsGrid` on UIParent (strata BACKGROUND) with vertical/horizontal 1 px line textures every `size` px from screen centre outward, centre lines brighter; lines reused between calls. Core shows it when unlocking (if `showGridWhileUnlocked`) and hides it on lock.
- [ ] Tests: SnapOffset cases above (Review Focus 5); drag stop with snap on saves multiples of 16; snap off keeps raw; unlock shows `ForeverBuffsGrid`, lock hides it; grid size change rebuilds line count (`#grid.lines` for 1920×1080 at 16 > 100). → FAIL → implement → green → commit `feat: snap grid while unlocked`.

---

### Task 7: Data: Forever catalogue, sources, runtime buff IDs, ranks

**Files:** Modify `Data.lua`, `Core.lua` (resolution), `API.lua` none; Test `tests/test_data.lua`, `tests/test_core.lua`.

**Interfaces:**
- `Data.CATALOGUE` rebuilt per the two research files (all corrections and new items; Hyjal flasks summary ends "(Hyjal only)"; Consecrated/Blessed "(vs undead)"). Rows gain `source` per spec. Recommendations recomputed from effects (documented in the header). Wizard oils recommended to Caster and Healer.
- `Data.ResolveItemSpells(resolveFn) -> count added`: for each catalogue row, `resolveFn(itemID)`; a returned spell ID not already in `row.auraIDs` is appended and merged into the category entry's `ids`. Core calls it at login with `FB.API.ItemSpell` and again on `ITEM_DATA_LOAD_RESULT` for pending items.
- Entries gain `ranks = { { family=, spells = { {id=, rank=, level=}, ... } }, ... }` from the research file (unconfirmed rows included only if the spell ID is confirmed).
- `Data.RankInfo(entry, knowsFn, playerLevel) -> { family=, known=n, total=m, nextLevel=L|nil, available=bool }` choosing the family per the spec resolution (first in `iconSpells` order known, else first ladder).
- [ ] Tests: catalogue invariants from 1.1 still pass; 21546 is "Elixir of Holy Power" for Priest/Paladin only; Coarse stone level 5, Dense 35; 250351 Grizzly present and recommended Melee Warrior at 60; `Recommend("elixir","MAGE","Caster",60)` is not 21546; `ResolveItemSpells` with a stub mapping adds a new aura to `byKey.elixir.ids` once (idempotent); `RankInfo` for fortitude knowing ranks 1–3 at level 21 with rank 4 at 24 → known 3, nextLevel 24, available false; at level 26 → available true; Core: login calls resolution for every catalogue item; `ITEM_DATA_LOAD_RESULT` for a pending item resolves it. → FAIL → implement → green → commit `feat: Forever consumables catalogue with sources, runtime buff IDs, spell ranks`.

---

### Task 8: Options: new controls

**Files:** Modify `Options.lua`, `UI.lua`; Test `tests/test_options.lua`, `tests/test_ui.lua`.

**Interfaces:**
- Display tab: `controls.look`, `controls.visibility`, `controls.expireLongSeconds`, `controls.expireShortSeconds`, `controls.longBuffSeconds`, plus 1.1 sliders (style/showNames controls removed).
- Alerts tab: per priority (`high`, `normal`, `low`): `controls["sound_"..p]` dropdown, `controls["play_"..p]` button, `controls["repeat_"..p]` dropdown (Off/15/30/60/120/300), `controls["text_"..p]` checkbox, `controls["flash_"..p]` checkbox, `controls["test_"..p]` button (plays sound + screen text "Test alert"); `controls.alertOnExpiring`; combat/mounted/resting as before. Alert style dropdown removed.
- Buffs tab rows: `row.show`, `row.sound` (CheckButtons), `row.rank` fontstring (`"Rank 3/6 · next at 24"`, `"Rank 4 available!"` green, other class `"6 ranks (1–54)"`), `row.priority`, `row.visibility` dropdown (Default/Always/When missing/Running out); hovering `row.rank` sets a tooltip listing every family and rank with levels.
- Consumables tab: header rows have `show`, `sound`, `where` dropdown (Everywhere/Dungeons and raids/Raids only/Never), `priority`, `visibility`, and a collapse toggle (`header.toggle`); `Options.collapsed[cat]` default elixir/flask false, well_fed/weapon true; item rows gain `row.where` text ("Alchemy 165", "Vendor", "Drop", "Quest", "Unknown") and a tooltip with the full source and reagent list (`"2x Wildvine"` names via `FB.API.ItemName`). The 1.1 `consumablesWhere` control is removed; `consumablesRemindDrop` stays.
- Position tab: `controls.snapToGrid`, `controls.gridSize` (4–64 step 4), `controls.showGridWhileUnlocked`; anchor text refreshes from `Display.onMoved`.
- UI: dropdown lists close on an outside click (`GLOBAL_MOUSE_DOWN` listener frame that closes the open list unless the mouse is over it or its button; stub fires the event).
- [ ] Tests: each listed control exists and writes the right db key (`FB.db.alert.high["repeat"]` etc.); show/sound ticks write `FB.cdb.show/sound`; where dropdown writes `FB.cdb.consumableWhere.weapon`; collapsing hides that category's item rows; rank text for priest level 21; item row where text "Alchemy" for a crafted elixir; outside click closes an open dropdown; test button records one raid notice and one sound. → FAIL → implement → green → commit `feat: options for toggles, visibility, alert channels, grid, sources and ranks`.

---

### Task 9: Report, README, release

**Files:** `Core.lua` (report), `README.md`, `ForeverBuffs.toc` (1.2.0).
- [ ] `/fbuffs report` adds a `catalogue` section: each item `itemID name -> spell N | unresolved` and a `ranks` section: each rank spell ID → name or UNKNOWN. Test: report contains both sections.
- [ ] README: new settings and behaviours. TOC version 1.2.0 (TOC test updated).
- [ ] Commit; whole-branch review; fix pass; merge, tag `v1.2.0-beta.1`, push; ask Colin for `/fbuffs report`; fix IDs from the report; tag `v1.2.0`.
