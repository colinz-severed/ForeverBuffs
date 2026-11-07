local ADDON, FB = ...
FB.Core = FB.Core or {}
local Core = FB.Core

-------------------------------------------------------------------------------
-- Saved variables, events, hide rules, combat freeze, slash commands.
-------------------------------------------------------------------------------

Core.VERSION = "1.0.0"
Core.GRACE_SECONDS = 3
Core.THROTTLE_SECONDS = 0.25
Core.TICK_SECONDS = 1

Core.DEFAULTS = {
  style = "grid", iconSize = 40, spacing = 6, direction = "RIGHT", perRow = 8, showNames = false,
  alertStyle = "flash", sound = "raid_warning", combat = "freeze",
  hideMounted = true, hideResting = false, locked = true,
  position = { point = "CENTER", relPoint = "CENTER", x = 0, y = 180 },
}
Core.CHAR_DEFAULTS = {
  enabled = {}, consumablesRaidsOnly = true, consumablesRemindDrop = true,
  -- role = nil means "use FB.Data.DefaultRole(class)"
}

Core.inCombat = false
Core.inGrace = false
Core.unlocked = false
Core.testMode = false
Core.casters = {}

local PREFIX = "|cff33ff99ForeverBuffs|r: "
local function say(msg) print(PREFIX .. tostring(msg)) end

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

function Core.InitDB()
  ForeverBuffsDB = copyDefaults(type(ForeverBuffsDB) == "table" and ForeverBuffsDB or {}, Core.DEFAULTS)
  ForeverBuffsCharDB = copyDefaults(type(ForeverBuffsCharDB) == "table" and ForeverBuffsCharDB or {}, Core.CHAR_DEFAULTS)
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

function Core.Run()
  if not Core.state then return end
  if Core.inCombat or InCombatLockdown() then
    Core.Render()
    return
  end
  -- Group and known-spell caches are invalidated by events, not per run.
  local transitions = Core.state:Evaluate()
  local hidden = Core.ShouldHide()
  local toSound = Core.alerts:Decide(transitions, Core.state, {
    alertStyle = FB.db.alertStyle, hidden = hidden, inGrace = Core.inGrace, now = GetTime(),
  })
  if #toSound > 0 then FB.Alerts.Play(FB.db.sound) end
  Core.Render()
end

function Core.Refresh()
  if Core._pending then return end
  Core._pending = true
  C_Timer.After(Core.THROTTLE_SECONDS, function()
    Core._pending = false
    Core.Run()
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
  if FB.Options and FB.Options.Build then FB.Options.Build() end

  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterUnitEvent("UNIT_AURA", "player")
  frame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
  for _, e in ipairs(REFRESH_EVENTS) do pcall(frame.RegisterEvent, frame, e) end

  Core.ticker = C_Timer.NewTicker(Core.TICK_SECONDS, function()
    if not Core.inCombat and not InCombatLockdown() then Core.Refresh() end
  end)
end

frame:SetScript("OnEvent", function(self, event, arg1)
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
    Core.Refresh()
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
    say(string.format("  %-18s %-10s %-8s %s%s", key, t.reason, tostring(s.status[key] or "unknown"),
      t.quiet and "quiet " or "", casters and ("casters: " .. table.concat(casters, ", ")) or ""))
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

local function cmdHelp()
  say("commands: /fbuffs [lock | unlock | test | reset | debug | api | ids | help]")
  say("  (no argument) opens the options panel")
end

function Core.Slash(msg)
  msg = strtrim(string.lower(msg or ""))
  if msg == "unlock" then
    Core.unlocked = true
    Core.Render()
    say("unlocked: drag the frame, then /fbuffs lock")
  elseif msg == "lock" then
    Core.unlocked = false
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
    cmdDebug()
  elseif msg == "api" then
    cmdApi()
  elseif msg == "ids" then
    cmdIds()
  elseif msg == "" then
    if FB.Options and FB.Options.Open then FB.Options.Open() else cmdHelp() end
  else
    cmdHelp()
  end
end

SLASH_FOREVERBUFFS1 = "/fbuffs"
SLASH_FOREVERBUFFS2 = "/forbuffs"
SlashCmdList.FOREVERBUFFS = Core.Slash
