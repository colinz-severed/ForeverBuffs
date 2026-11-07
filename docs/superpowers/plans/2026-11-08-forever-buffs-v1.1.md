# ForeverBuffs 1.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-buff priority (size + alerts), a consumables catalogue with a per-character pick, a standalone translucent options window with tabs, more sounds, an About tab, and cheaper per-second work, on top of the working 1.0 addon.

**Architecture:** Same layering as 1.0: `Data.lua` (static tables, now with a consumables catalogue that the recommendation table is derived from), `State.lua` (pure evaluation; gains priority and pick), `Alerts.lua` (priority-aware sound/flash decisions, bigger sound list), `Display.lua` (variable icon sizes, border per priority, no-op when unchanged), `Core.lua` (defaults, migration, lighter ticker). A new `UI.lua` holds a small widget kit; `Options.lua` is rewritten as a standalone window built from it, and the Blizzard Settings category goes away.

**Tech Stack:** WoW Lua 5.1 on Forever 1.60.1 (Interface 16001), no libraries. Tests: `python tests/run_tests.py` (Lua 5.1 via `lupa`, fake API in `tests/wow_stub.lua`).

**Spec:** `docs/superpowers/specs/2026-11-08-forever-buffs-v1.1-design.md` (and, for everything it does not change, `docs/superpowers/specs/2026-11-07-forever-buffs-design.md`). Paths below are relative to the addon folder `D:\World of Warcraft\_forever_\Interface\AddOns\ForeverBuffs\`.

## Global Constraints

- Everything in the 1.0 plan's Global Constraints still applies (pcall discipline, no deprecated globals, no evaluation in combat or under restriction, `local ADDON, FB = ...` file header, commit per task).
- TOC: `## Version: 1.1.0`, `## Author: colinzmulan`, `## X-Credits: Claude AI assisted`, `## X-Website: https://github.com/colinz-severed/ForeverBuffs`, `## X-BugReport: https://github.com/colinz-severed/ForeverBuffs/issues`, `## AddonCompartmentFunc: ForeverBuffs_OpenOptions`; file order `Data.lua, API.lua, State.lua, Alerts.lua, Display.lua, Core.lua, UI.lua, Options.lua`.
- Saved variables from 1.0 keep working: new keys get defaults, `sound` migrates to `soundNormal` once, `settingsVersion = 2`.
- Priority values are the strings `"high" | "normal" | "low"`; defaults by tracked reason: known → normal, group → low, consumable → low.
- Sound table entries are `{ key=, name=, constant=, kit= }` with the exact keys/IDs from the spec's table; `none` plays nothing.
- Window: 720×480, strata DIALOG, default alpha 0.70 applied to backdrop and borders only, tabs Display / Alerts / Buffs / Consumables / Position / About in that order, closes on ESC via `UISpecialFrames`.
- Author line in About: `colinzmulan (Claude AI assisted)`.

## Review Focus

1. **A 1.0 user upgrading** keeps position, style, toggles and sound; the old `sound` value becomes `soundNormal`, nothing is reset. Test in Task 5.
2. **A Low icon in "Flashing with names" style** does not pulse, but still appears with its name. Test in Task 4.
3. **A picked consumable above the player's level** (e.g. pick Brilliant Wizard Oil at level 30) is still shown as the pick; the tooltip says "Your pick". Test in Task 2.
4. **Landing from a taxi with no aura change** shows the display again within a second (ticker still evaluates hide rules). Test in Task 5.
5. **Opening the window in combat** works (it is not a secure frame) and changing a setting in combat does not evaluate auras (freeze stays). Test in Task 7.

---

### Task 1: Data: catalogue, derived recommendations, priorities

**Files:**
- Modify: `Data.lua`
- Test: `tests/test_data.lua` (extend), `tests/test_state_tracked.lua` (remove the `quiet` assertions in "quiet flag: battle shout..."; the test is replaced in Task 2)

**Interfaces:**
- Produces: `FB.Data.PRIORITIES = { "high", "normal", "low" }`, `FB.Data.DefaultPriority(reason) -> "normal" | "low"` (`"known"` → normal, anything else → low).
- Produces: `FB.Data.CATALOGUE = { flask = {rows}, elixir = {rows}, well_fed = {rows}, weapon = {rows} }`, row = `{ itemID=, name=, level=, summary=, roles=set|nil, classes=set|nil, weapon="edged"|"blunt"|"oil"|nil, auraIDs={...} }`, each category sorted by level then name.
- Produces: `FB.Data.CategoryOf(key) -> "flask"|"elixir"|"well_fed"|"weapon"|nil` (`weapon_mh`/`weapon_oh` → `"weapon"`).
- Produces: `FB.Data.RECOMMEND` is now built from `CATALOGUE` rows that have `roles`, keeping the 1.0 shape and the 1.0 `Recommend()` semantics (highest level ≤ player level, later row wins ties, `weapon` rows filtered by weapon kind with `"oil"` rows valid for Caster/Healer regardless of weapon kind).
- Produces: `FB.Data.CatalogueItem(category, itemID) -> row|nil`.
- Removes: `quietFromOthers` field (no entry sets it; `E()` no longer defaults it).

- [ ] **Step 1: Add tests to `tests/test_data.lua`**

```lua
T.test("priorities and default by reason", function()
  T.eq(#FB.Data.PRIORITIES, 3); T.eq(FB.Data.DefaultPriority("known"), "normal")
  T.eq(FB.Data.DefaultPriority("group"), "low"); T.eq(FB.Data.DefaultPriority("consumable"), "low")
end)
T.test("catalogue rows are well-formed, sorted, and cover the recommendations", function()
  local C = FB.Data.CATALOGUE
  for _, cat in ipairs({"flask","elixir","well_fed","weapon"}) do
    local rows = C[cat]; T.truthy(rows and #rows > 0, cat)
    local lastLevel = -1
    for _, r in ipairs(rows) do
      T.truthy(r.itemID and r.name and r.level and r.summary, cat .. " row"); T.truthy(r.level >= lastLevel, "sorted " .. cat); lastLevel = r.level
      if cat ~= "weapon" then T.truthy(r.auraIDs and #r.auraIDs > 0, r.name .. " auraIDs") end
    end
  end
  for key, byRole in pairs(FB.Data.RECOMMEND) do
    local cat = FB.Data.CategoryOf(key)
    for _, rows in pairs(byRole) do for _, rec in ipairs(rows) do T.truthy(FB.Data.CatalogueItem(cat, rec.itemID), rec.name .. " in catalogue") end end
  end
end)
T.test("every catalogue aura id is in its category entry ids", function()
  for _, cat in ipairs({"flask","elixir","well_fed"}) do
    local ids = {}; for _, id in ipairs(FB.Data.byKey[cat].ids) do ids[id] = true end
    for _, r in ipairs(FB.Data.CATALOGUE[cat]) do for _, a in ipairs(r.auraIDs) do T.truthy(ids[a], r.name .. " aura " .. a) end end
  end
end)
T.test("catalogue includes the cheaper levelling items and excludes alcohol", function()
  T.truthy(FB.Data.CatalogueItem("elixir", 2457))   -- Elixir of Minor Agility
  T.truthy(FB.Data.CatalogueItem("elixir", 3390))   -- Elixir of Lesser Agility
  T.truthy(FB.Data.CatalogueItem("flask", 13513))   -- Flask of Chromatic Resistance
  T.truthy(FB.Data.CatalogueItem("well_fed", 12218)) -- Monster Omelet
  T.falsy(FB.Data.CatalogueItem("well_fed", 21151)) -- Rumsey Rum Black Label
  T.eq(FB.Data.CategoryOf("weapon_oh"), "weapon"); T.eq(FB.Data.CategoryOf("inner_fire"), nil)
end)
T.test("1.0 recommendations still hold after deriving from the catalogue", function()
  T.eq(FB.Data.Recommend("elixir", "MAGE", "Caster", 60).itemID, 21546)
  T.eq(FB.Data.Recommend("weapon_mh", "WARRIOR", "Melee", 60, "blunt").itemID, 12643)
  T.eq(FB.Data.Recommend("weapon_mh", "PRIEST", "Healer", 60, "blunt").itemID, 20748)   -- oils ignore weapon kind
  T.eq(FB.Data.Recommend("well_fed", "ROGUE", "Melee", 60).itemID, 13928)
end)
T.test("quietFromOthers is gone", function()
  for _, e in ipairs(FB.Data.entries) do T.eq(e.quietFromOthers, nil, e.key) end
end)
```

- [ ] **Step 2: Run** `python tests/run_tests.py test_data` → new tests FAIL.
- [ ] **Step 3: Implement in `Data.lua`.** Build `CATALOGUE` with the 1.0 recommended items (now carrying `roles`) plus the spec's levelling items; aura IDs from Wowhead Forever (builder verifies: e.g. Minor Agility 2374, Lesser Agility 3160, Agility 11328, Greater Agility 11334, Minor Defense 673, Defense 3220, Greater Defense 11349, Minor Fortitude 2378, Wisdom 3166, Frost Power 21920, Firepower 7844; Chromatic Resistance 17629; foods: Monster Omelet 19710, Tender Wolf Steak 18194? builder checks each on `wowhead.com/forever/item=<id>`). Merge every catalogue aura ID into the category entry `ids`. Derive `RECOMMEND` at load. Remove `quietFromOthers`.
- [ ] **Step 4: Run** `python tests/run_tests.py` → all pass except the Task 2-owned `quiet` assertions in `test_state_tracked.lua`; delete those three `quiet` assertions now (the behaviour moves to priority in Task 2) and re-run → all pass.
- [ ] **Step 5: Commit** `git commit -am "feat: consumables catalogue, derived recommendations, priority defaults"`

---

### Task 2: State: priority, pick, partial evaluation

**Files:**
- Modify: `State.lua`
- Test: `tests/test_state_tracked.lua`, `tests/test_state_eval.lua`, `tests/helpers.lua` (env gains `o.settings.priority`, `o.settings.pick`)

**Interfaces:**
- Consumes: `FB.Data.DefaultPriority`, `FB.Data.CategoryOf`, `FB.Data.CatalogueItem`.
- Produces: `state:Priority(key) -> "high"|"normal"|"low"` = `charSettings().priority[key]` if set, else `Data.DefaultPriority(tracked[key].reason)` (untracked keys use `"normal"`).
- Produces: `state:Pick(key) -> itemID|nil` from `charSettings().pick[Data.CategoryOf(key)]`.
- Produces: `state:Recommendation(key)` now returns `{ itemID=, name=, level=, picked=true }` when a pick exists (looked up in the catalogue; a pick not in the catalogue is ignored), else the 1.0 recommendation (with `picked=false`), else nil.
- Produces: `state:Evaluate(opts)`; `opts.onlyKinds` (set of kinds) limits presence checks to entries of those kinds; tracked-set recomputation and untracked transitions still run. `state.tracked[key].quiet` is removed.

- [ ] **Step 1: Tests** (in `test_state_tracked.lua`, replacing the old quiet test; and in `test_state_eval.lua`):

```lua
T.test("priority defaults by reason and can be overridden", function()
  local s = FB.State.New(FB.Data, env({ known={[6673]=true}, group={{class="WARRIOR", level=10}} })); s:ComputeTracked(); T.eq(s:Priority("battle_shout"), "normal")
  s = FB.State.New(FB.Data, env({ group={{class="WARRIOR", level=10}} })); s:ComputeTracked(); T.eq(s:Priority("battle_shout"), "low")
  s = FB.State.New(FB.Data, env({ instance="raid" })); s:ComputeTracked(); T.eq(s:Priority("flask"), "low")
  s = FB.State.New(FB.Data, env({ group={{class="PRIEST", level=10}}, settings={ priority={ fortitude="high" } } })); s:ComputeTracked(); T.eq(s:Priority("fortitude"), "high")
  T.eq(s:Priority("inner_fire"), "normal"); T.eq(s.tracked.battle_shout, nil)
end)
T.test("pick overrides recommendation, even above the player's level", function()
  local s = FB.State.New(FB.Data, env({ class="MAGE", level=30, settings={ pick={ weapon=20749 } } }))
  local r = s:Recommendation("weapon_mh"); T.eq(r.itemID, 20749); T.truthy(r.picked); T.eq(r.name, "Brilliant Wizard Oil")
  T.eq(s:Recommendation("weapon_oh").itemID, 20749)
  s = FB.State.New(FB.Data, env({ class="MAGE", level=60, settings={ pick={ elixir=999999 } } })); T.eq(s:Recommendation("elixir").itemID, 21546); T.falsy(s:Recommendation("elixir").picked)
end)
-- test_state_eval.lua
T.test("Evaluate with onlyKinds checks only weapon enchants", function()
  local o = { known={[588]=true, [8017]=true}, class="SHAMAN", tempEnchant={}, auras={ [588]="player" } }
  local s = FB.State.New(FB.Data, env(o)); s:Evaluate(); T.eq(s.status.inner_fire, "present"); T.eq(s.status.shaman_imbue, "missing")
  o.auras = {}; o.tempEnchant[16] = true
  local t = s:Evaluate({ onlyKinds = { weaponEnchant = true } }); T.eq(#t, 1); T.eq(t[1].key, "shaman_imbue"); T.eq(s.status.inner_fire, "present")
  s:Evaluate(); T.eq(s.status.inner_fire, "missing")
end)
T.test("tracked entries no longer carry quiet", function()
  local s = FB.State.New(FB.Data, env({ group={{class="WARRIOR", level=10}} })); s:ComputeTracked(); T.eq(s.tracked.battle_shout.quiet, nil)
end)
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** in `State.lua` (helpers.lua: `settings.priority` and `settings.pick` default to `{}`). **Step 4: Run** `python tests/run_tests.py` → all pass (Alerts tests still pass because `ShouldFlash` treats missing `quiet` as not quiet; they are rewritten in Task 3).
- [ ] **Step 5: Commit** `git commit -am "feat: per-entry priority, consumable pick, partial evaluation"`

---

### Task 3: Alerts: sound list and priority-aware decisions

**Files:**
- Modify: `Alerts.lua`
- Test: `tests/test_alerts.lua` (rewrite)

**Interfaces:**
- Consumes: `state:Priority(key)` (Task 2).
- Produces: `FB.Alerts.SOUNDS` = the spec's 17 entries plus `{ key="none", name="No sound" }` in that order; `FB.Alerts.SoundByKey(key) -> entry|nil`; `FB.Alerts.Play(key)` plays `SOUNDKIT[constant] or kit` on `"Master"`, nothing for `none` or unknown keys (no fallback sound any more).
- Produces: `alerts:Decide(transitions, state, ctx) -> array of { key=, sound= }`; `ctx = { alertStyle=, soundNormal=, soundHigh=, hidden=, inGrace=, now= }`. Rules: only present→missing; never when hidden/inGrace; per key: high → `soundHigh` (skip if `"none"`), normal → `soundNormal` if alertStyle is `sound`/`both` (skip if `"none"`), low → nothing; 30 s throttle per key.
- Produces: `FB.Alerts.ShouldFlash(state, key, alertStyle, style) -> bool`: missing and (high → true; low → false; normal → alertStyle flash/both or `style == "names"`).

- [ ] **Step 1: Rewrite `tests/test_alerts.lua`**

```lua
local function st(prio) local s = { tracked={ inner_fire={reason="known"} }, status={ inner_fire="missing" } }; function s:Priority(k) return prio or "normal" end; return s end
local PM = { {key="inner_fire", from="present", to="missing"} }
local CTX = function(o) o = o or {}; return { alertStyle=o.alertStyle or "both", soundNormal=o.soundNormal or "raid_warning", soundHigh=o.soundHigh or "alarm3", hidden=o.hidden, inGrace=o.inGrace, now=o.now or 0 } end
T.test("normal priority follows alert style and uses soundNormal", function()
  local a = FB.Alerts.New(); local r = a:Decide(PM, st("normal"), CTX({alertStyle="sound"})); T.eq(r[1].key, "inner_fire"); T.eq(r[1].sound, "raid_warning")
  a = FB.Alerts.New(); T.eq(#a:Decide(PM, st("normal"), CTX({alertStyle="flash"})), 0)
  a = FB.Alerts.New(); T.eq(#a:Decide(PM, st("normal"), CTX({alertStyle="icon"})), 0)
end)
T.test("high priority always sounds with soundHigh unless none; low never", function()
  local a = FB.Alerts.New(); T.eq(a:Decide(PM, st("high"), CTX({alertStyle="icon"}))[1].sound, "alarm3")
  a = FB.Alerts.New(); T.eq(#a:Decide(PM, st("high"), CTX({alertStyle="both", soundHigh="none"})), 0)
  a = FB.Alerts.New(); T.eq(#a:Decide(PM, st("low"), CTX({alertStyle="both"})), 0)
end)
T.test("throttle, hidden, grace, untracked→missing", function()
  local a = FB.Alerts.New(); T.eq(#a:Decide(PM, st(), CTX({now=100})), 1); T.eq(#a:Decide(PM, st(), CTX({now=120})), 0); T.eq(#a:Decide(PM, st(), CTX({now=131})), 1)
  a = FB.Alerts.New(); T.eq(#a:Decide(PM, st(), CTX({hidden=true})), 0); T.eq(#a:Decide(PM, st(), CTX({inGrace=true})), 0)
  T.eq(#a:Decide({{key="inner_fire", from="untracked", to="missing"}}, st(), CTX()), 0)
end)
T.test("sound table and Play", function()
  T.eq(#FB.Alerts.SOUNDS, 18); T.eq(FB.Alerts.SOUNDS[1].key, "raid_warning"); T.eq(FB.Alerts.SOUNDS[18].key, "none")
  T.eq(FB.Alerts.SoundByKey("alarm1").kit, 18871); T.eq(FB.Alerts.SoundByKey("alarm1").constant, "ALARM_CLOCK_WARNING_1")
  STUB.reset(); FB.Alerts.Play("ready_check"); T.eq(STUB.sounds[1][1], 8960); T.eq(STUB.sounds[1][2], "Master")
  FB.Alerts.Play("none"); FB.Alerts.Play("bogus"); T.eq(#STUB.sounds, 1)
  SOUNDKIT.READY_CHECK = 1234; FB.Alerts.Play("ready_check"); T.eq(STUB.sounds[2][1], 1234); SOUNDKIT.READY_CHECK = 8960
end)
T.test("ShouldFlash by priority and style", function()
  T.truthy(FB.Alerts.ShouldFlash(st("high"), "inner_fire", "icon", "grid")); T.falsy(FB.Alerts.ShouldFlash(st("low"), "inner_fire", "both", "names"))
  T.truthy(FB.Alerts.ShouldFlash(st("normal"), "inner_fire", "flash", "grid")); T.falsy(FB.Alerts.ShouldFlash(st("normal"), "inner_fire", "icon", "grid"))
  T.truthy(FB.Alerts.ShouldFlash(st("normal"), "inner_fire", "icon", "names"))
  local s = st("high"); s.status.inner_fire = "present"; T.falsy(FB.Alerts.ShouldFlash(s, "inner_fire", "both", "grid"))
end)
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement `Alerts.lua`.** **Step 4: Run** `python tests/run_tests.py` → everything passes except Display/Core tests that call the old signatures; fix call sites in `Display.lua` (`ShouldFlash(state, key, settings.alertStyle, style)`) and `Core.lua` (`Decide` ctx with `soundNormal = FB.db.soundNormal or FB.db.sound`, `soundHigh = FB.db.soundHigh`; play each returned `sound` once per distinct sound per run) minimally so the suite is green; Task 4/5 refine them.
- [ ] **Step 5: Commit** `git commit -am "feat: priority-aware alerts and verified sound list"`

---

### Task 4: Display: sizes per priority, borders, no-op updates

**Files:**
- Modify: `Display.lua`
- Test: `tests/test_display.lua`

**Interfaces:**
- Consumes: `state:Priority(key)`, `state:Recommendation(key).picked`, `FB.Alerts.ShouldFlash(state, key, alertStyle, style)`.
- Produces: `FB.Display.LayoutPositions(sizes, spacing, direction, perRow) -> array of {x=, y=}` where `sizes` is an array of per-icon pixel sizes; horizontal directions align bottom edges (y of a smaller icon = row baseline minus (rowMax − size)); vertical directions align left edges (x unchanged). Row/column pitch = that row's largest icon + spacing. The old `(count, size, ...)` call shape is gone.
- Produces: `FB.Display.IconSize(settings, priority) -> number` = `iconSize × (highScale | 1 | lowScale)` rounded.
- Produces: border colour gold `(0.85, 0.65, 0.13)` for high, red `(0.8, 0.15, 0.15)` otherwise; border inset 2 px (high/normal) or 1 px (low) (`icon.borderInset` field for tests).
- Produces: `FB.Display.Update` returns `true` when it did work and `false` when the signature was unchanged; signature covers visible keys + status + priority per key, stale, hidden, unlocked, testMode, `settings.revision` (a counter Core bumps on any settings change; Task 5) and the recommendation itemIDs. `FB.Display.Invalidate()` clears the signature.
- Tooltip second line for consumables: `"Your pick: <name>"` when `rec.picked`, else `"Recommended: <name>"`.

- [ ] **Step 1: Tests** (update `fakeState` to take a `prio` map and expose `:Priority(k)`; `settings()` gains `highScale=1.15, lowScale=0.7, revision=1`)

```lua
T.test("LayoutPositions with mixed sizes aligns bottoms horizontally and lefts vertically", function()
  local p = FB.Display.LayoutPositions({40, 28, 46}, 6, "RIGHT", 8)
  T.eq(p[1].x, 0); T.eq(p[1].y, -6); T.eq(p[2].x, 46); T.eq(p[2].y, -18); T.eq(p[3].x, 80); T.eq(p[3].y, 0)
  p = FB.Display.LayoutPositions({40, 28}, 6, "DOWN", 8); T.eq(p[2].x, 0); T.eq(p[2].y, -46)
  p = FB.Display.LayoutPositions({40, 28, 40}, 6, "RIGHT", 2); T.eq(p[3].y, -46)   -- second row pitch = 40 + 6
end)
T.test("IconSize by priority", function()
  local s = settings(); T.eq(FB.Display.IconSize(s, "high"), 46); T.eq(FB.Display.IconSize(s, "normal"), 40); T.eq(FB.Display.IconSize(s, "low"), 28)
end)
T.test("priority drives size, border colour and inset", function()
  STUB.reset(); FB.Display.Init(settings())
  local st = fakeState({ inner_fire={}, fortitude={}, battle_shout={} }, { inner_fire="missing", fortitude="missing", battle_shout="missing" }, false, { inner_fire="high", fortitude="normal", battle_shout="low" })
  FB.Display.Update(st, settings(), {}); local shown = shownIcons()
  T.eq(shown.inner_fire:GetWidth(), 46); T.eq(shown.fortitude:GetWidth(), 40); T.eq(shown.battle_shout:GetWidth(), 28)
  T.eq(shown.inner_fire.border.texture[1], 0.85); T.eq(shown.fortitude.border.texture[1], 0.8)
  T.eq(shown.inner_fire.borderInset, 2); T.eq(shown.battle_shout.borderInset, 1)
end)
T.test("low never pulses, even in names style; high pulses even with icon-only alerts", function()
  STUB.reset(); FB.Display.Init(settings({style="names"}))
  local st = fakeState({ inner_fire={}, battle_shout={} }, { inner_fire="missing", battle_shout="missing" }, false, { inner_fire="high", battle_shout="low" })
  FB.Display.Update(st, settings({style="names", alertStyle="icon"}), {}); local shown = shownIcons()
  T.truthy(shown.inner_fire.pulse:IsPlaying()); T.falsy(shown.battle_shout.pulse:IsPlaying()); T.truthy(shown.battle_shout.label:IsShown())
end)
T.test("Update is a no-op when nothing changed and resumes on change", function()
  STUB.reset(); FB.Display.Init(settings()); local s = settings()
  local st = fakeState({ inner_fire={} }, { inner_fire="missing" })
  T.truthy(FB.Display.Update(st, s, {})); T.falsy(FB.Display.Update(st, s, {}))
  st.status.inner_fire = "present"; T.truthy(FB.Display.Update(st, s, {}))
  s.revision = 2; T.truthy(FB.Display.Update(st, s, {})); FB.Display.Invalidate(); T.truthy(FB.Display.Update(st, s, {}))
end)
T.test("tooltip says Your pick for picked consumables", function()
  STUB.reset(); STUB.items[20746] = { name="Lesser Wizard Oil", icon=3 }; FB.Display.Init(settings())
  local st = fakeState({ weapon_mh={reason="consumable"} }, { weapon_mh="missing" }); st.rec = { weapon_mh={ itemID=20746, name="Lesser Wizard Oil", picked=true } }
  FB.Display.Update(st, settings(), {}); local ic = shownIcons().weapon_mh; GameTooltip._lines = {}; ic:GetScript("OnEnter")(ic)
  T.truthy(GameTooltip._lines[1]:find("Your pick: Lesser Wizard Oil", 1, true))
end)
```
Update the two existing `LayoutPositions` tests to the new `sizes` signature (`{40,40,40}` etc.) with the same expected numbers.

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `python tests/run_tests.py` → all pass (Core tests: `FB.db.revision` may be nil; treat nil as 0).
- [ ] **Step 5: Commit** `git commit -am "feat: priority-sized icons, gold high border, skip unchanged updates"`

---

### Task 5: Core: defaults, migration, lighter ticker, open hooks, TOC

**Files:**
- Modify: `Core.lua`, `ForeverBuffs.toc`
- Test: `tests/test_core.lua`

**Interfaces:**
- Produces: `FB.Core.DEFAULTS` adds `highScale=1.15, lowScale=0.7, soundNormal="raid_warning", soundHigh="alarm3", windowAlpha=0.7, windowPosition={point="CENTER", relPoint="CENTER", x=0, y=0}, settingsVersion=2, revision=0`; `FB.Core.CHAR_DEFAULTS` adds `priority={}, pick={}`.
- Produces: `FB.Core.InitDB()` migrates: if `db.settingsVersion == nil` and `db.sound` is set, `db.soundNormal = db.sound`; then `db.settingsVersion = 2` (the old `sound` key is left in place).
- Produces: `FB.Core.SettingChanged()` increments `FB.db.revision`, calls `FB.Display.Invalidate()` and `FB.Core.Refresh()` (Options calls this after every change).
- Produces: ticker calls `Core.Run({ onlyKinds = { weaponEnchant = true } })` normally, or a full `Core.Run()` when `Core.state.stale` is true; `Core.Run(opts)` passes `opts` to `state:Evaluate(opts)` and always re-renders (hide rules re-checked).
- Produces: global `ForeverBuffs_OpenOptions()` → `FB.Options.Toggle()`; `/fbuffs` with no argument also calls `FB.Options.Toggle()`.
- Produces: `Decide` ctx uses `FB.db.soundNormal` / `FB.db.soundHigh`; each distinct sound key returned is played once per run.
- TOC: metadata lines from Global Constraints; add `UI.lua` before `Options.lua`.

- [ ] **Step 1: Tests**

```lua
T.test("migration from 1.0 saved variables", function()
  STUB.reload(function() ForeverBuffsDB = { sound="ready_check", iconSize=48, position={point="TOPLEFT", relPoint="TOPLEFT", x=5, y=-5} } end)
  T.eq(FB.db.soundNormal, "ready_check"); T.eq(FB.db.soundHigh, "alarm3"); T.eq(FB.db.settingsVersion, 2); T.eq(FB.db.iconSize, 48); T.eq(FB.db.position.x, 5)
  T.eq(FB.db.highScale, 1.15); T.eq(FB.db.lowScale, 0.7); T.eq(FB.db.windowAlpha, 0.7); T.truthy(FB.cdb.priority and FB.cdb.pick)
  STUB.reload(function() ForeverBuffsDB = { settingsVersion=2, sound="ready_check", soundNormal="whisper" } end); T.eq(FB.db.soundNormal, "whisper")
end)
T.test("ticker only re-checks weapon enchants, but recovers hide rules and stale state", function()
  STUB.reload(); STUB.known[588] = true; STUB.auras[588] = { sourceUnit="player" }
  STUB.fire("PLAYER_ENTERING_WORLD"); STUB.advance(3.5); T.eq(FB.Core.state.status.inner_fire, "present")
  STUB.auras[588] = nil; STUB.advance(2); T.eq(FB.Core.state.status.inner_fire, "present")        -- no UNIT_AURA: ticker does not re-check auras
  STUB.player.taxi = true; STUB.advance(1.5); T.falsy(FB.Display.anchor:IsShown())
  STUB.player.taxi = false; STUB.advance(1.5); T.truthy(FB.Display.anchor:IsShown())               -- hide rules recover on the ticker
  STUB.restricted = true; STUB.fire("UNIT_AURA", "player"); STUB.advance(0.3); T.truthy(FB.Core.state.stale)
  STUB.restricted = false; STUB.advance(1.5); T.falsy(FB.Core.state.stale); T.eq(FB.Core.state.status.inner_fire, "missing")
end)
T.test("high priority sounds with soundHigh even when alert style is icon", function()
  STUB.reload(); STUB.known[588] = true; STUB.auras[588] = { sourceUnit="player" }; FB.db.alertStyle = "icon"; FB.cdb.priority.inner_fire = "high"
  STUB.fire("PLAYER_ENTERING_WORLD"); STUB.advance(3.5); STUB.auras[588] = nil; STUB.fire("UNIT_AURA", "player"); STUB.advance(0.3)
  T.eq(#STUB.sounds, 1); T.eq(STUB.sounds[1][1], 12889)
end)
T.test("SettingChanged bumps revision and re-renders; open hooks exist", function()
  STUB.reload(); local r = FB.db.revision; FB.Core.SettingChanged(); T.eq(FB.db.revision, r + 1)
  T.eq(type(ForeverBuffs_OpenOptions), "function")
end)
T.test("TOC metadata", function()
  local toc = io.open("ForeverBuffs.toc"):read("*a")
  for _, line in ipairs({"## Version: 1.1.0", "## Author: colinzmulan", "## X-Credits: Claude AI assisted", "## AddonCompartmentFunc: ForeverBuffs_OpenOptions", "## X-BugReport: https://github.com/colinz-severed/ForeverBuffs/issues"}) do T.truthy(toc:find(line, 1, true), line) end
  T.truthy(toc:find("UI.lua\nOptions.lua", 1, true) or toc:find("UI.lua\r\nOptions.lua", 1, true))
end)
```
Also update the existing "slash commands" test: `FB.Core.Slash("")` must not error when `FB.Options.Toggle` exists (stub `UI.lua`/`Options.lua` may still be the 1.0 versions at this point; guard with `if FB.Options and FB.Options.Toggle`).

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** (`Core.lua`, TOC; create an empty `UI.lua` with the module header so the TOC loads). **Step 4: Run** → all pass. **Step 5: Commit** `git commit -am "feat: settings migration, priority sounds, lighter ticker, TOC metadata"`

---

### Task 6: UI widget kit

**Files:**
- Create: `UI.lua`
- Modify: `tests/wow_stub.lua` (frame methods: `SetBackdrop`, `SetBackdropColor`, `SetBackdropBorderColor`, `SetFrameStrata`, `SetFrameLevel`, `SetScrollChild`, `SetVerticalScroll`, `GetVerticalScroll`, `EnableMouseWheel`, `SetAutoFocus`, `HighlightText`, `SetCursorPosition`, `SetJustifyH`, `SetFontObject`, `SetTextColor`, `SetMinMaxValues`, `SetValue`, `GetValue`, `SetValueStep`, `SetObeyStepOnDrag`, `SetOrientation`, `SetChecked`, `GetChecked`, `SetNormalFontObject`, `SetHighlightTexture`, `SetNormalTexture`, `SetPushedTexture`, `RegisterForClicks`, `Click` (calls `OnClick`), `SetEnabled`, `IsEnabled`, `SetToplevel`, `Raise`, `SetResizeBounds`; globals `UISpecialFrames = {}`, `BackdropTemplateMixin = {}`, `GameFontNormal/GameFontHighlight/GameFontHighlightSmall/GameFontNormalLarge/GameFontDisableSmall = {}`, `CreateFrame` honours a `template` containing `"BackdropTemplate"` by giving the frame the backdrop methods, `ChatFontNormal = {}`, `PlaySound` already present)
- Test: `tests/test_ui.lua`

**Interfaces:**
- Produces (all on `FB.UI`, every factory returns the root frame and sets `.Refresh()` on it to re-read its getter):
  - `Panel(parent, width, height) -> frame` with backdrop, `frame:SetAlphaBackdrop(a)` applying alpha to backdrop colours only.
  - `Checkbox(parent, label, get, set) -> frame` (`frame.check` CheckButton, `frame.label`); clicking calls `set(not get())`.
  - `Slider(parent, label, min, max, step, get, set, formatter) -> frame` (`frame.slider`, `frame.valueText`); `OnValueChanged` calls `set(value)` only when it differs from `get()`.
  - `Dropdown(parent, label, choicesFn, get, set) -> frame` (`frame.button`, `frame.text`); `choicesFn()` returns array of `{ value=, text= }`; `frame:Open()` shows a list frame `frame.list` with one button per choice; clicking a choice calls `set(value)` and closes; `frame.text` shows the text of the current value.
  - `Button(parent, text, onClick, width) -> frame`.
  - `EditBox(parent, text, width) -> frame` read-only copyable: `OnChar`/`OnTextChanged` reset the text, `OnEditFocusGained` highlights all.
  - `ScrollList(parent, rowHeight, buildRow(parent) -> rowFrame, fillRow(rowFrame, item)) -> frame` with `frame:SetItems(array)`; creates rows on demand (pool), shows only visible ones, mouse wheel scrolls by `rowHeight × 3`; `frame.rows` is the pool.
  - `SectionHeader(parent, text) -> fontstring`.
  - `Tabs(parent, names, onSelect) -> frame` with `frame:Select(name)`, `frame.buttons[name]`, highlighted active tab.
- Tests do not test pixels; they test wiring (getter/setter calls, lists filling, Select changing state).

- [ ] **Step 1: Write `tests/test_ui.lua`**

```lua
T.test("Checkbox reads getter and writes setter", function()
  STUB.reset(); local v = false; local cb = FB.UI.Checkbox(UIParent, "Test", function() return v end, function(x) v = x end)
  cb.Refresh(); T.falsy(cb.check:GetChecked()); cb.check:Click(); T.truthy(v); cb.Refresh(); T.truthy(cb.check:GetChecked())
end)
T.test("Slider formats and sets", function()
  STUB.reset(); local v = 40; local s = FB.UI.Slider(UIParent, "Size", 20, 80, 2, function() return v end, function(x) v = x end, function(x) return x .. " px" end)
  s.Refresh(); T.eq(s.valueText:GetText(), "40 px"); s.slider:SetValue(52); s.slider:GetScript("OnValueChanged")(s.slider, 52); T.eq(v, 52)
end)
T.test("Dropdown lists choices and applies a pick", function()
  STUB.reset(); local v = "grid"
  local d = FB.UI.Dropdown(UIParent, "Style", function() return { {value="row", text="Plain row"}, {value="grid", text="Grid"} } end, function() return v end, function(x) v = x end)
  d.Refresh(); T.eq(d.text:GetText(), "Grid"); d:Open(); T.truthy(d.list:IsShown()); T.eq(#d.list.buttons, 2)
  d.list.buttons[1]:Click(); T.eq(v, "row"); T.falsy(d.list:IsShown()); T.eq(d.text:GetText(), "Plain row")
end)
T.test("ScrollList fills rows from items", function()
  STUB.reset(); local filled = {}
  local l = FB.UI.ScrollList(UIParent, 20, function(p) return CreateFrame("Button", nil, p) end, function(row, item) row.item = item; filled[#filled+1] = item end)
  l:SetSize(300, 100); l:SetItems({ "a", "b", "c" }); T.truthy(#l.rows >= 3); T.eq(l.rows[2].item, "b")
end)
T.test("Tabs select and highlight", function()
  STUB.reset(); local sel; local t = FB.UI.Tabs(UIParent, { "Display", "About" }, function(n) sel = n end)
  t:Select("About"); T.eq(sel, "About"); T.eq(t.active, "About"); T.truthy(t.buttons.About and t.buttons.Display)
end)
T.test("EditBox is copyable but not editable", function()
  STUB.reset(); local e = FB.UI.EditBox(UIParent, "https://x", 200); e.box:SetText("changed"); e.box:GetScript("OnTextChanged")(e.box, true); T.eq(e.box:GetText(), "https://x")
end)
T.test("Panel alpha applies to backdrop only", function()
  STUB.reset(); local p = FB.UI.Panel(UIParent, 100, 100); p:SetAlphaBackdrop(0.5); T.eq(p.backdropAlpha, 0.5); T.eq(p:GetAlpha(), 1)
end)
```

- [ ] **Step 2: Run** → FAIL (and fix stub gaps the failures reveal). **Step 3: Implement `UI.lua`.** **Step 4: Run** `python tests/run_tests.py` → all pass. **Step 5: Commit** `git commit -am "feat: lightweight UI widget kit"`

---

### Task 7: Options window: frame, tabs, Display, Alerts, Position, About

**Files:**
- Rewrite: `Options.lua`
- Test: `tests/test_options.lua` (rewrite)

**Interfaces:**
- Consumes: `FB.UI.*` (Task 6), `FB.Core.SettingChanged()`, `FB.Alerts.SOUNDS`, `FB.Alerts.Play`, `FB.Core.Slash`, `FB.db`.
- Produces: `FB.Options.Build()` creates `FB.Options.frame` (`ForeverBuffsOptions`, 720×480, strata DIALOG, movable via `frame.title`), adds the name to `UISpecialFrames`, builds the six tabs (`FB.Options.tabs`), and panels in `FB.Options.panels[name]`; idempotent. `FB.Options.Open()`, `FB.Options.Close()`, `FB.Options.Toggle()`, `FB.Options.Show(tabName)`. `FB.Options.Refresh()` re-reads every control (called from `Build`, `Open`, and `Core.SettingChanged`). Window position saved to `FB.db.windowPosition` on drag stop. Window alpha from `FB.db.windowAlpha` via `Panel:SetAlphaBackdrop`.
- Produces: the 1.0 Settings-API registration is removed (`Settings.*` is no longer called anywhere).
- Tab contents per spec. About tab: `FB.Options.about = { version=, author="colinzmulan (Claude AI assisted)", bugs="https://github.com/colinz-severed/ForeverBuffs/issues", downloads="https://github.com/colinz-severed/ForeverBuffs/releases" }` rendered with `UI.EditBox` for the two links.
- Controls register themselves in `FB.Options.controls[settingKey]` (e.g. `controls.iconSize`, `controls.alertStyle`, `controls.soundHigh`, `controls.windowAlpha`, `controls.highScale`, `controls.lowScale`) so tests can drive them.

- [ ] **Step 1: Rewrite `tests/test_options.lua`**

```lua
T.test("window builds once, toggles, closes on ESC registration, tabs switch", function()
  STUB.reload(); FB.Options.Build(); FB.Options.Build(); T.truthy(FB.Options.frame); T.eq(FB.Options.frame:GetName(), "ForeverBuffsOptions")
  local found; for _, n in ipairs(UISpecialFrames) do if n == "ForeverBuffsOptions" then found = true end end; T.truthy(found)
  T.falsy(FB.Options.frame:IsShown()); FB.Options.Toggle(); T.truthy(FB.Options.frame:IsShown()); FB.Options.Toggle(); T.falsy(FB.Options.frame:IsShown())
  FB.Options.Show("About"); T.truthy(FB.Options.panels.About:IsShown()); T.falsy(FB.Options.panels.Display:IsShown()); T.eq(FB.Options.tabs.active, "About")
  T.eq(#STUB.settingsCategories, 0)
end)
T.test("display controls write the db and bump revision", function()
  STUB.reload(); FB.Options.Open(); local r = FB.db.revision
  FB.Options.controls.iconSize.slider:SetValue(52); FB.Options.controls.iconSize.slider:GetScript("OnValueChanged")(FB.Options.controls.iconSize.slider, 52)
  T.eq(FB.db.iconSize, 52); T.truthy(FB.db.revision > r)
  FB.Options.controls.style:Open(); FB.Options.controls.style.list.buttons[1]:Click(); T.eq(FB.db.style, "row")
  FB.Options.controls.windowAlpha.slider:GetScript("OnValueChanged")(FB.Options.controls.windowAlpha.slider, 0.5); T.eq(FB.db.windowAlpha, 0.5); T.eq(FB.Options.frame.backdropAlpha, 0.5)
end)
T.test("alerts tab offers every sound for both priorities and plays on demand", function()
  STUB.reload(); FB.Options.Open(); FB.Options.controls.soundHigh:Open(); T.eq(#FB.Options.controls.soundHigh.list.buttons, #FB.Alerts.SOUNDS)
  FB.Options.controls.soundHigh.list.buttons[2]:Click(); T.eq(FB.db.soundHigh, "ready_check")
  STUB.sounds = {}; FB.Options.controls.playHigh:Click(); T.eq(STUB.sounds[1][1], 8960)
end)
T.test("about tab content", function()
  STUB.reload(); FB.Options.Open(); FB.Options.Show("About")
  T.eq(FB.Options.about.author, "colinzmulan (Claude AI assisted)"); T.truthy(FB.Options.about.bugs:find("issues", 1, true)); T.eq(FB.Options.about.version, C_AddOns.GetAddOnMetadata("ForeverBuffs", "Version"))
  T.eq(FB.Options.controls.bugsLink.box:GetText(), FB.Options.about.bugs)
end)
T.test("window position is saved on drag stop", function()
  STUB.reload(); FB.Options.Open(); FB.Options.frame:SetPoint("CENTER", UIParent, "CENTER", 30, 40)
  FB.Options.frame.title:GetScript("OnDragStop")(FB.Options.frame.title); T.eq(FB.db.windowPosition.x, 30); T.eq(FB.db.windowPosition.y, 40)
end)
T.test("opening and changing settings in combat does not evaluate auras", function()
  STUB.reload(); STUB.known[588] = true; STUB.auras[588] = { sourceUnit="player" }; STUB.fire("PLAYER_ENTERING_WORLD"); STUB.advance(3.5)
  STUB.player.combat = true; STUB.fire("PLAYER_REGEN_DISABLED"); STUB.auras[588] = nil; STUB.restricted = true
  FB.Options.Open(); T.truthy(FB.Options.frame:IsShown()); FB.Options.controls.iconSize.slider:GetScript("OnValueChanged")(FB.Options.controls.iconSize.slider, 44); STUB.advance(0.5)
  T.eq(FB.Core.state.status.inner_fire, "present")
end)
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement `Options.lua`** (Display, Alerts, Position, About tabs; Buffs and Consumables panels are created empty here and filled in Task 8). **Step 4: Run** → all pass. **Step 5: Commit** `git commit -am "feat: standalone options window with Display, Alerts, Position and About tabs"`

---

### Task 8: Options window: Buffs and Consumables tabs

**Files:**
- Modify: `Options.lua`
- Test: `tests/test_options.lua` (append)

**Interfaces:**
- Consumes: `FB.Data.entries`, `FB.Data.CATALOGUE`, `FB.Data.CategoryOf`, `FB.Core.state` (`:Priority`, `:Recommendation`, `.tracked`), `FB.cdb.enabled/priority/pick/role/consumablesRaidsOnly/consumablesRemindDrop`, `FB.UI.ScrollList`, `FB.UI.Dropdown`.
- Produces: Buffs tab = one `ScrollList` whose items are section headers and entry rows: section "Your buffs" (entries with `class == player class`, including group-castable ones they can learn), section "From other classes" (non-selfOnly, non-consumable entries of other classes). Row: checkbox (`FB.cdb.enabled[key]`, default from `defaultEnabledByClass`/`defaultEnabled`), icon, name (`FB.API.SpellName(iconSpells[1 known or last])`), priority dropdown with choices `Default / High / Normal / Low` (`Default` sets `FB.cdb.priority[key] = nil`), grey note: `"learned at level N"` when the player's level is below `learnLevel` and the spell is not known, else the priority effect text (`"flash + sound"` / `"alert style"` / `"small, quiet"`). `FB.Options.buffRows[key]` exposes each built row (`row.check`, `row.priority`, `row.note`).
- Produces: Consumables tab = top bar (role dropdown `controls.role`, show dropdown `controls.consumablesWhere` with values `raids`/`everywhere` mapping to `consumablesRaidsOnly` true/false, checkbox `controls.consumablesRemindDrop`, filter `controls.filter` EditBox that *is* editable), then one `ScrollList` whose items are category headers (tracked checkbox + priority dropdown for the category entry: `flask`, `elixir`, `well_fed`, `weapon_mh`; the weapon header toggles/sets both `weapon_mh` and `weapon_oh`) and item rows (radio, icon, name + `lvl N`, summary, tag `recommended` (green) / `your pick` (gold) / none; greyed when `level > player level`). Clicking a radio sets `FB.cdb.pick[category] = itemID`; clicking the "Use recommendation" row (first row of each category) clears it. Filter: case-insensitive substring on item name; headers always shown. `FB.Options.consumableRows` exposes built rows by `itemID`.
- Both lists call `FB.Core.SettingChanged()` after every change and rebuild their items in `FB.Options.Refresh()`.

- [ ] **Step 1: Append tests**

```lua
T.test("buffs tab lists own and other-class entries with priority dropdowns", function()
  STUB.reload(function() STUB.player.class = "PRIEST"; STUB.player.level = 21; STUB.known[588] = true end); STUB.fire("PLAYER_ENTERING_WORLD"); STUB.advance(3.5)
  FB.Options.Open(); FB.Options.Show("Buffs"); local rows = FB.Options.buffRows
  T.truthy(rows.inner_fire and rows.fortitude and rows.arcane_intellect and rows.battle_shout); T.falsy(rows.mage_armor); T.falsy(rows.flask)
  T.truthy(rows.divine_spirit.note:GetText():find("learned at level 30", 1, true))
  rows.fortitude.priority:Open(); T.eq(#rows.fortitude.priority.list.buttons, 4); rows.fortitude.priority.list.buttons[2]:Click(); T.eq(FB.cdb.priority.fortitude, "high")
  rows.fortitude.priority:Open(); rows.fortitude.priority.list.buttons[1]:Click(); T.eq(FB.cdb.priority.fortitude, nil)
  rows.inner_fire.check:Click(); T.eq(FB.cdb.enabled.inner_fire, false)
end)
T.test("consumables tab: pick, use recommendation, filter, weapon header shared", function()
  STUB.reload(function() STUB.player.class = "MAGE"; STUB.player.level = 60 end); STUB.fire("PLAYER_ENTERING_WORLD"); STUB.advance(3.5)
  FB.Options.Open(); FB.Options.Show("Consumables"); local rows = FB.Options.consumableRows
  T.truthy(rows[21546] and rows[13454] and rows[20749] and rows[13512]); T.eq(rows[21546].tag:GetText(), "recommended")
  rows[13454].radio:Click(); T.eq(FB.cdb.pick.elixir, 13454); T.eq(FB.Options.consumableRows[13454].tag:GetText(), "your pick")
  FB.Options.consumableHeaders.elixir.useRecommendation:Click(); T.eq(FB.cdb.pick.elixir, nil)
  FB.Options.consumableHeaders.weapon.check:Click(); T.eq(FB.cdb.enabled.weapon_mh, false); T.eq(FB.cdb.enabled.weapon_oh, false)
  FB.Options.controls.filter.box:SetText("oil"); FB.Options.controls.filter.box:GetScript("OnTextChanged")(FB.Options.controls.filter.box, true)
  T.truthy(FB.Options.consumableRows[20749]); T.falsy(FB.Options.consumableRows[21546])
  FB.Options.controls.consumablesWhere:Open(); FB.Options.controls.consumablesWhere.list.buttons[2]:Click(); T.eq(FB.cdb.consumablesRaidsOnly, false)
end)
T.test("shaman and rogue see no weapon category", function()
  STUB.reload(function() STUB.player.class = "SHAMAN" end); STUB.fire("PLAYER_ENTERING_WORLD"); STUB.advance(3.5)
  FB.Options.Open(); FB.Options.Show("Consumables"); T.falsy(FB.Options.consumableHeaders.weapon); T.truthy(FB.Options.consumableHeaders.elixir)
end)
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → all pass. **Step 5: Commit** `git commit -am "feat: buffs and consumables tabs with priorities and picks"`

---

### Task 9: README, in-game verification, release 1.1.0

**Files:**
- Modify: `README.md` (new features: priority, consumables browser and picks, the window, sounds; "Publishing to CurseForge" section; update the command table: `/fbuffs` opens the window)
- Modify: `Data.lua` header date after verification

- [ ] **Step 1: Update `README.md`.**
- [ ] **Step 2: Commit and push `main`; tag `v1.1.0-beta.1`** (the workflow publishes a pre-release zip).
- [ ] **Step 3: Player check (game must be running):** `/reload`, open `/fbuffs`, visit every tab, change the style, set one buff to High and one to Low, pick a consumable, play both sounds, then `/fbuffs report` and `/reload`. Builder reads `D:\World of Warcraft\_forever_\WTF\Account\MUFFINSVARGEN3\SavedVariables\ForeverBuffs.lua`: `report.ids` must have no new UNKNOWN spell or item IDs, `report.debug` must show the chosen priorities, and `report.api` all OK.
- [ ] **Step 4: Fix anything found**, re-run `python tests/run_tests.py`, update the `Data.lua` header date, commit, tag `v1.1.0`, push the tag.
