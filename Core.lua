local ADDON, FB = ...
FB.Core = FB.Core or {}
local Core = FB.Core

-------------------------------------------------------------------------------
-- Saved variables, events, hide rules, combat freeze, slash commands.
-------------------------------------------------------------------------------

Core.VERSION = "1.2.0"
Core.GRACE_SECONDS = 3
Core.THROTTLE_SECONDS = 0.25
Core.TICK_SECONDS = 1

Core.DEFAULTS = {
  style = "grid", iconSize = 40, spacing = 6, direction = "RIGHT", perRow = 8, showNames = false,
  alertStyle = "flash", soundNormal = "raid_warning", soundHigh = "alarm3", combat = "freeze",
  hideMounted = true, hideResting = false, locked = true,
  highScale = 1.15, lowScale = 0.7,
  windowAlpha = 0.7,
  windowPosition = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
  position = { point = "CENTER", relPoint = "CENTER", x = 0, y = 180 },
  -- 1.2
  look = "icons", visibility = "always",
  expireLongSeconds = 300, expireShortSeconds = 60, longBuffSeconds = 900,
  alert = {
    high   = { sound = "alarm3",       ["repeat"] = 30, text = true,  flash = true },
    normal = { sound = "raid_warning", ["repeat"] = 0,  text = false, flash = true },
    low    = { sound = "none",         ["repeat"] = 0,  text = false, flash = false },
  },
  alertOnExpiring = true,
  snapToGrid = true, gridSize = 16, showGridWhileUnlocked = true,
  settingsVersion = 3,
  revision = 0,
}
Core.SETTINGS_VERSION = 3
Core.CHAR_DEFAULTS = {
  enabled = {}, priority = {}, pick = {}, consumablesRaidsOnly = true, consumablesRemindDrop = true,
  show = {}, sound = {}, visibility = {}, consumableWhere = {},
  -- role = nil means "use FB.Data.DefaultRole(class)"
}
Core.CHAR_SETTINGS_VERSION = 3

local WEAPON_ONLY = { onlyKinds = { weaponEnchant = true } }

Core.inCombat = false
Core.inGrace = false
Core.unlocked = false
Core.testMode = false
Core.casters = {}

local PREFIX = "|cff33ff99ForeverBuffs|r: "
local capture = nil   -- when set, say() also appends plain text here
local function say(msg)
  msg = tostring(msg)
  if capture then capture[#capture + 1] = msg end
  print(PREFIX .. msg)
end

-- Runs fn while capturing everything it says into FB.db.report[kind], so the
-- output can be read from the SavedVariables file after a /reload instead of
-- being pasted out of the chat frame.
local function captured(kind, fn, quiet)
  local lines = {}
  capture = lines
  local savedPrint = print
  if quiet then print = function() end end
  local ok, err = pcall(fn)
  print = savedPrint
  capture = nil
  if FB.db then
    FB.db.report = FB.db.report or {}
    FB.db.report[kind] = lines
    FB.db.report.savedAt = date and date("%Y-%m-%d %H:%M:%S") or tostring(GetTime())
    FB.db.report.version = Core.VERSION
  end
  if not ok then say("error while building " .. kind .. " report: " .. tostring(err)) end
  return lines
end

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------
local function copyDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      copyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

-- 1.0 sound keys that 1.1 renamed.
local LEGACY_SOUND_KEYS = { alarm = "alarm3" }

-- Upgrades a saved-variables table written by an older version, in place.
-- Old keys are left in the table (never read again after 1.2's switch-over).
local function migrate(db)
  local from = db.settingsVersion
  if from == nil then
    -- 1.0 → 1.1: the single sound became the Normal-priority sound.
    if db.sound ~= nil and db.soundNormal == nil then
      db.soundNormal = LEGACY_SOUND_KEYS[db.sound] or db.sound
    end
  end
  if (from or 0) < 3 then
    -- 1.1 → 1.2: style splits into look + visibility; alertStyle and the two
    -- sounds become per-priority alert channels.
    local alert = type(db.alert) == "table" and db.alert or {}
    db.alert = alert
    alert.high = alert.high or {}
    alert.normal = alert.normal or {}
    if db.soundHigh ~= nil and alert.high.sound == nil then alert.high.sound = db.soundHigh end
    if db.soundNormal ~= nil and alert.normal.sound == nil then alert.normal.sound = db.soundNormal end
    if db.style ~= nil and db.look == nil then
      if db.style == "names" then
        db.look, db.visibility = "names_beside", db.visibility or "missing"
        alert.normal.flash = true        -- 1.1's "flashing with names" always pulsed
      elseif db.style == "row" then
        db.look, db.visibility = (db.showNames and "names_below" or "icons"), db.visibility or "missing"
      else
        db.look, db.visibility = (db.showNames and "names_below" or "icons"), db.visibility or "always"
      end
    elseif db.showNames and db.look == nil then
      db.look = "names_below"
    end
    local style = db.alertStyle
    if style == "icon" then
      if db.style ~= "names" then alert.normal.flash = false end
      alert.normal.sound = "none"
    elseif style == "flash" then
      alert.normal.sound = "none"
    elseif style == "sound" then
      if db.style ~= "names" then alert.normal.flash = false end
    end
  end
  db.settingsVersion = Core.SETTINGS_VERSION
end

local CATEGORIES = { "elixir", "flask", "well_fed", "weapon" }

function Core.MigrateChar(cdb)
  if (cdb.settingsVersion or 0) < 3 then
    cdb.show = cdb.show or {}
    cdb.sound = cdb.sound or {}
    for key, on in pairs(cdb.enabled or {}) do
      if cdb.show[key] == nil then cdb.show[key] = on and true or false end
      if cdb.sound[key] == nil then cdb.sound[key] = on and true or false end
    end
    cdb.consumableWhere = cdb.consumableWhere or {}
    if cdb.consumablesRaidsOnly == false then
      for _, cat in ipairs(CATEGORIES) do
        if cdb.consumableWhere[cat] == nil then cdb.consumableWhere[cat] = "everywhere" end
      end
    end
  end
  cdb.settingsVersion = Core.CHAR_SETTINGS_VERSION
end

-- A sound key the current sound list does not know falls back to the default.
local function validateSounds(db)
  local byKey = FB.Alerts and FB.Alerts.SoundByKey
  if not byKey then return end
  for _, field in ipairs({ "soundNormal", "soundHigh" }) do
    if db[field] ~= nil and not byKey(db[field]) then db[field] = Core.DEFAULTS[field] end
  end
  if type(db.alert) == "table" then
    for prio, channel in pairs(db.alert) do
      local default = Core.DEFAULTS.alert[prio]
      if type(channel) == "table" and default and channel.sound ~= nil and not byKey(channel.sound) then
        channel.sound = default.sound
      end
    end
  end
end

function Core.InitDB()
  local db = type(ForeverBuffsDB) == "table" and ForeverBuffsDB or {}
  migrate(db)
  validateSounds(db)
  ForeverBuffsDB = copyDefaults(db, Core.DEFAULTS)
  local cdb = type(ForeverBuffsCharDB) == "table" and ForeverBuffsCharDB or {}
  Core.MigrateChar(cdb)
  ForeverBuffsCharDB = copyDefaults(cdb, Core.CHAR_DEFAULTS)
  FB.db = ForeverBuffsDB
  FB.cdb = ForeverBuffsCharDB
  return FB.db, FB.cdb
end

-------------------------------------------------------------------------------
-- Group scan and env
-------------------------------------------------------------------------------
local function groupUnits()
  local units = {}
  if IsInRaid and IsInRaid() then
    for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
  elseif IsInGroup and IsInGroup() then
    for i = 1, GetNumGroupMembers() - 1 do units[#units + 1] = "party" .. i end
  end
  return units
end

Core.scanCount = 0
Core.knownCache = {}

function Core.InvalidateGroup() Core._members = nil end
function Core.InvalidateKnown() Core.knownCache = {} end

local function scanGroup()
  Core.scanCount = Core.scanCount + 1
  local members, casters = {}, {}
  for _, unit in ipairs(groupUnits()) do
    local okExists, exists = pcall(UnitExists, unit)
    local okSelf, isSelf = pcall(UnitIsUnit, unit, "player")
    if okExists and exists and okSelf and not FB.API.IsSecret(isSelf) and not isSelf and UnitIsConnected(unit) then
      local class, level = FB.API.UnitClassLevel(unit)
      if class then
        level = level or 0
        members[#members + 1] = { class = class, level = level }
        local okName, name = pcall(UnitName, unit)
        if not okName or FB.API.IsSecret(name) or not name then name = unit end
        for _, entry in ipairs(FB.Data.entries) do
          if entry.class == class and not entry.selfOnly and not entry.consumable
             and (level <= 0 or level >= (entry.learnLevel or 1)) then
            casters[entry.key] = casters[entry.key] or {}
            table.insert(casters[entry.key], name)
          end
        end
      end
    end
  end
  return members, casters
end

function Core.Casters() return Core.casters or {} end

function Core.BuildEnv()
  local API = FB.API
  return {
    knows = function(id)
      local cached = Core.knownCache[id]
      if cached == nil then
        cached = API.KnowsSpell(id)
        Core.knownCache[id] = cached
      end
      return cached
    end,
    aura = API.PlayerAura,
    auraSource = API.PlayerAuraSource,
    auraByName = API.PlayerAuraByName,
    tempEnchant = API.TempEnchant,
    offhandWeapon = API.OffhandIsWeapon,
    groupMembers = function()
      if not Core._members then
        Core._members, Core.casters = scanGroup()
      end
      return Core._members
    end,
    instanceType = function()
      local _, kind = IsInInstance()
      return kind or "none"
    end,
    restricted = API.AurasRestricted,
    neverSecret = API.SpellNeverSecret,
    enabled = function(key) return FB.cdb and FB.cdb.enabled and FB.cdb.enabled[key] end,
    charSettings = function() return FB.cdb end,
    playerClass = API.PlayerClass,
    playerLevel = API.PlayerLevel,
    weaponKind = API.MainhandWeaponKind,
    now = GetTime,
    -- 1.2
    auraTimes = API.PlayerAuraTimes,
    auraTimesByName = API.PlayerAuraTimesByName,
    weaponRemaining = API.WeaponRemaining,
    spellName = API.SpellName,
    inCombat = function() return Core.inCombat or InCombatLockdown() end,
    thresholds = function()
      return { long = FB.db.expireLongSeconds or 300, short = FB.db.expireShortSeconds or 60, longBuff = FB.db.longBuffSeconds or 900 }
    end,
    globalVisibility = function() return FB.db.visibility or "always" end,
  }
end

-------------------------------------------------------------------------------
-- Hide rules
-------------------------------------------------------------------------------
function Core.ShouldHide()
  if UnitIsDeadOrGhost("player") then return true, "dead" end
  if UnitOnTaxi("player") then return true, "taxi" end
  if UnitInVehicle and UnitInVehicle("player") then return true, "vehicle" end
  if FB.db.hideMounted and IsMounted() then return true, "mounted" end
  if FB.db.hideResting and IsResting() then return true, "resting" end
  if FB.db.combat == "hide" and (Core.inCombat or InCombatLockdown()) then return true, "combat" end
  return false
end

-------------------------------------------------------------------------------
-- Evaluate / render
-------------------------------------------------------------------------------
function Core.Render()
  if not Core.state then return end
  local hidden = (Core.ShouldHide() or Core.inGrace) and not Core.unlocked and not Core.testMode
  FB.Display.Update(Core.state, FB.db, {
    hidden = hidden, unlocked = Core.unlocked, testMode = Core.testMode, casters = Core.casters,
  })
end

-- Any settings change: bump the revision the display keys its no-op check on.
function Core.SettingChanged()
  if FB.db then FB.db.revision = (FB.db.revision or 0) + 1 end
  if FB.Display and FB.Display.Invalidate then FB.Display.Invalidate() end
  Core.Refresh()
  Core.Render()
end

-- opts.onlyKinds limits the presence checks (the ticker passes weaponEnchant).
function Core.Run(opts)
  if not Core.state then return end
  if Core.inCombat or InCombatLockdown() then
    Core.Render()
    return
  end
  -- Group and known-spell caches are invalidated by events, not per run.
  local transitions = Core.state:Evaluate(opts)
  FB.Alerts.Deliver(Core.alerts:Decide(transitions, Core.state, Core.AlertContext()))
  Core.Render()
end

Core.deferredExpiring = {}

-- After combat: running-out alerts for buffs that crossed the threshold during
-- the fight and are still running out (a buff that dropped alerts as missing).
function Core.DeliverDeferredExpiring()
  if not Core.state then Core.deferredExpiring = {}; return end
  local transitions = {}
  for key in pairs(Core.deferredExpiring) do
    if Core.state.status[key] == "expiring" then
      transitions[#transitions + 1] = { key = key, from = "present", to = "expiring" }
    end
  end
  Core.deferredExpiring = {}
  if #transitions > 0 then
    local ctx = Core.AlertContext()
    ctx.inCombat = false
    FB.Alerts.Deliver(Core.alerts:Decide(transitions, Core.state, ctx))
  end
end

function Core.AlertContext()
  return {
    channels = FB.db.alert, alertOnExpiring = FB.db.alertOnExpiring ~= false,
    hidden = Core.ShouldHide(), inGrace = Core.inGrace,
    inCombat = Core.inCombat or InCombatLockdown(), now = GetTime(),
  }
end

-- Once a second: running-out countdown from cached end times (also in combat,
-- no aura calls), due repeat reminders, and the cheap re-checks.
function Core.Tick()
  if not Core.state then return end
  local inCombat = Core.inCombat or InCombatLockdown()
  local transitions = Core.state:UpdateExpiring(GetTime())
  if inCombat then
    -- Running-out alerts are not played in combat; keep them for afterwards.
    for _, t in ipairs(transitions) do
      if t.from == "present" and t.to == "expiring" then Core.deferredExpiring[t.key] = true end
    end
  else
    local ctx = Core.AlertContext()
    FB.Alerts.Deliver(Core.alerts:Decide(transitions, Core.state, ctx))
    FB.Alerts.Deliver(Core.alerts:DueRepeats(Core.state, ctx))
  end
  Core.Render()
  if inCombat then return end
  -- Weapon enchants expire without an event; everything else is event-driven.
  -- While restricted out of combat (stale) keep trying a full pass so the
  -- display recovers the moment restriction lifts.
  if Core.state.stale then Core.Refresh() else Core.Refresh(WEAPON_ONLY) end
end

-- Throttled full refresh. A full request supersedes a pending partial one.
function Core.Refresh(opts)
  if Core._pending then
    if opts == nil then Core._pendingOpts = nil end
    return
  end
  Core._pending = true
  Core._pendingOpts = opts
  C_Timer.After(Core.THROTTLE_SECONDS, function()
    Core._pending = false
    local o = Core._pendingOpts
    Core._pendingOpts = nil
    Core.Run(o)
  end)
end


local graceToken = 0
function Core.StartGrace()
  Core.inGrace = true
  graceToken = graceToken + 1
  local token = graceToken
  C_Timer.After(Core.GRACE_SECONDS, function()
    if token ~= graceToken then return end
    Core.inGrace = false
    Core.Refresh()
  end)
  Core.Render()
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local KNOWN_EVENTS = { SPELLS_CHANGED = true, LEARNED_SPELL_IN_TAB = true, PLAYER_LEVEL_UP = true }
local REFRESH_EVENTS = {
  "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP",
  "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
  "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_UPDATE_RESTING", "ZONE_CHANGED_NEW_AREA",
  "UNIT_LEVEL", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "PLAYER_EQUIPMENT_CHANGED",
}
local REFRESH_SET = {}
for _, e in ipairs(REFRESH_EVENTS) do REFRESH_SET[e] = true end

local function isGroupUnit(unit)
  return type(unit) == "string" and (unit:match("^party%d+$") or unit:match("^raid%d+$")) ~= nil
end

local frame = CreateFrame("Frame", "ForeverBuffsEventFrame")
Core.frame = frame
frame:RegisterEvent("PLAYER_LOGIN")

local function onLogin()
  Core.InitDB()
  Core.InvalidateKnown()
  Core.InvalidateGroup()
  FB.Display.Init(FB.db)
  FB.Display.onMoved = function() FB.Display.SavePosition(FB.db) end
  Core.state = FB.State.New(FB.Data, Core.BuildEnv())
  Core.alerts = FB.Alerts.New()
  -- The options window is built on first open (/fbuffs), not at login.
  -- Ask the game which buff each catalogue item gives; uncached items are
  -- requested and resolved on ITEM_DATA_LOAD_RESULT.
  FB.Data.ResolveItemSpells(FB.API.ItemSpell)
  pcall(frame.RegisterEvent, frame, "ITEM_DATA_LOAD_RESULT")

  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterUnitEvent("UNIT_AURA", "player")
  frame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
  for _, e in ipairs(REFRESH_EVENTS) do pcall(frame.RegisterEvent, frame, e) end

  Core.ticker = C_Timer.NewTicker(Core.TICK_SECONDS, function() Core.Tick() end)
end

frame:SetScript("OnEvent", function(self, event, arg1, arg2)
  if event == "PLAYER_LOGIN" then
    onLogin()
  elseif event == "PLAYER_ENTERING_WORLD" then
    Core.InvalidateKnown()
    Core.InvalidateGroup()
    Core.StartGrace()
  elseif event == "GROUP_ROSTER_UPDATE" then
    Core.InvalidateGroup()
    Core.StartGrace()
  elseif event == "UNIT_LEVEL" then
    if isGroupUnit(arg1) then
      Core.InvalidateGroup()
      Core.Refresh()
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    Core.inCombat = true
    Core.Render()
  elseif event == "PLAYER_REGEN_ENABLED" then
    Core.inCombat = false
    Core.DeliverDeferredExpiring()
    Core.Refresh()
  elseif event == "ITEM_DATA_LOAD_RESULT" then
    if arg1 and FB.API.ItemSpellPending[arg1] then
      FB.API.ItemSpellPending[arg1] = nil
      if arg2 then
        local added = FB.Data.ResolveItemSpells(function(id) return FB.API.ItemSpell(id, true) end, { [arg1] = true })
        if added > 0 then Core.Refresh() end
      end
    end
  elseif event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED" then
    if arg1 == "player" then Core.Refresh() end
  elseif REFRESH_SET[event] then
    if KNOWN_EVENTS[event] then Core.InvalidateKnown() end
    Core.Refresh()
  end
end)

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
local function cmdDebug()
  local s = Core.state
  if not s then say("not initialised yet"); return end
  Core.InvalidateGroup()
  Core.InvalidateKnown()
  local env = s.env
  say(string.format("v%s  class=%s level=%d role=%s", Core.VERSION, tostring(env.playerClass()), env.playerLevel(), s:Role()))
  local hidden, reason = Core.ShouldHide()
  say(string.format("inCombat=%s inGrace=%s restricted=%s stale=%s hidden=%s%s", tostring(Core.inCombat), tostring(Core.inGrace),
    tostring(env.restricted()), tostring(s.stale), tostring(hidden), reason and (" (" .. reason .. ")") or ""))
  if env.restricted() then say("auras restricted here") end
  local members = env.groupMembers()
  say(string.format("group members: %d", #members))
  say("weapon " .. FB.API.TempEnchantDetail(INVSLOT_MAINHAND or 16))
  say("weapon " .. FB.API.TempEnchantDetail(INVSLOT_OFFHAND or 17))
  local dead = {}
  for id in pairs(FB.API.deadIDs) do dead[#dead + 1] = tostring(id) end
  if #dead > 0 then table.sort(dead); say("spell IDs unknown to this client: " .. table.concat(dead, ", ")) end
  local keys = s:TrackedKeys()
  if #keys == 0 then say("nothing tracked") end
  for _, key in ipairs(keys) do
    local t = s.tracked[key]
    local casters = Core.casters[key]
    say(string.format("  %-18s %-10s %-8s %-6s %s", key, t.reason, tostring(s.status[key] or "unknown"),
      s:Priority(key), casters and ("casters: " .. table.concat(casters, ", ")) or ""))
  end
end

local function cmdApi()
  for _, row in ipairs(FB.API.Probe()) do
    say((row.ok and "OK      " or "MISSING ") .. row.name)
  end
end

local function cmdIds()
  say("spell IDs (UNKNOWN = this client has no such spell):")
  for _, id in ipairs(FB.Data.AllSpellIDs()) do
    say(string.format("  spell %d -> %s", id, FB.API.SpellName(id) or "UNKNOWN"))
  end
  say("item IDs (names may show UNKNOWN until the client has cached the item; run again):")
  for _, id in ipairs(FB.Data.AllItemIDs()) do
    say(string.format("  item %d -> %s", id, FB.API.ItemName(id) or "UNKNOWN"))
  end
end

local function cmdCatalogue()
  say("catalogue items and the buff spell the game reports for them:")
  local cats = { "elixir", "flask", "well_fed", "weapon" }
  for _, cat in ipairs(cats) do
    for _, r in ipairs(FB.Data.CATALOGUE[cat] or {}) do
      local spell = r.resolvedSpell or FB.API.ItemSpell(r.itemID)
      say(string.format("  %s %d %s -> %s", cat, r.itemID, r.name, spell and ("spell " .. spell) or "unresolved"))
    end
  end
end

local function cmdRanks()
  say("rank spells (UNKNOWN = this client has no such spell):")
  for _, entry in ipairs(FB.Data.entries) do
    for _, ladder in ipairs(entry.ranks or {}) do
      for _, sp in ipairs(ladder.spells) do
        say(string.format("  %s rank %d lvl %d: %d -> %s", ladder.family, sp.rank, sp.level, sp.id, FB.API.SpellName(sp.id) or "UNKNOWN"))
      end
    end
  end
end

local function cmdHelp()
  say("commands: /fbuffs [lock | unlock | test | reset | debug | api | ids | report | help]")
  say("  report: saves the api, ids and debug output to the addon's saved variables (then /reload)")
  say("  (no argument) opens the options panel")
end

function Core.Slash(msg)
  msg = strtrim(string.lower(msg or ""))
  if msg == "unlock" then
    Core.unlocked = true
    if FB.db.showGridWhileUnlocked ~= false then FB.Display.ShowGrid(FB.db.gridSize) else FB.Display.HideGrid() end
    Core.Render()
    say("unlocked: drag the frame, then /fbuffs lock")
  elseif msg == "lock" then
    Core.unlocked = false
    FB.Display.HideGrid()
    FB.Display.SavePosition(FB.db)
    Core.Render()
    say("locked")
  elseif msg == "test" then
    Core.testMode = not Core.testMode
    Core.Render()
    say("test mode " .. (Core.testMode and "on" or "off"))
  elseif msg == "reset" then
    FB.db.position = copyDefaults({}, Core.DEFAULTS.position)
    FB.Display.ApplyPosition(FB.db.position)
    Core.Render()
    say("position reset")
  elseif msg == "debug" then
    captured("debug", cmdDebug)
  elseif msg == "api" then
    captured("api", cmdApi)
  elseif msg == "ids" then
    captured("ids", cmdIds)
  elseif msg == "report" then
    captured("api", cmdApi, true)
    captured("ids", cmdIds, true)
    captured("debug", cmdDebug, true)
    captured("catalogue", cmdCatalogue, true)
    captured("ranks", cmdRanks, true)
    say("report saved. Type /reload now so it is written to disk.")
  elseif msg == "" then
    if FB.Options and FB.Options.Toggle then FB.Options.Toggle()
    elseif FB.Options and FB.Options.Open then FB.Options.Open()
    else cmdHelp() end
  else
    cmdHelp()
  end
end

-- Addon compartment (minimap addon list) entry point; see ## AddonCompartmentFunc.
function ForeverBuffs_OpenOptions()
  if FB.Options and FB.Options.Toggle then FB.Options.Toggle() end
end

SLASH_FOREVERBUFFS1 = "/fbuffs"
SLASH_FOREVERBUFFS2 = "/forbuffs"
SlashCmdList.FOREVERBUFFS = Core.Slash
