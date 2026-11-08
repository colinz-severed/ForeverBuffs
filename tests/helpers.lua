-- Shared test helpers. Loaded with dofile("tests/helpers.lua"); returns a table.
local H = {}

-- Builds a State env from a plain options table:
--   o.known       set of spell IDs the player knows
--   o.group       list of { class=, level= }
--   o.instance    "none" | "party" | "raid" | "pvp" | "arena"   (default "none")
--   o.enabled     map key -> bool|nil
--   o.settings    { consumablesRaidsOnly=, consumablesRemindDrop=, role= }
--   o.class       default "PRIEST";  o.level default 60;  o.weaponKind default nil
--   o.offhandWeapon default false
--   o.auras       map spellID -> "player" | "<unit>" | "secret"   (present auras)
--   o.auraNames   set of aura names present
--   o.auraErrors  set of spell IDs whose lookup returns nil (unknown)
--   o.tempEnchant map slot -> bool
--   o.restricted  bool;  o.neverSecret set of spell IDs
--   o.now         number
function H.env(o)
  o = o or {}
  o.known = o.known or {}
  o.group = o.group or {}
  o.enabled = o.enabled or {}
  o.settings = o.settings or {}
  o.auras = o.auras or {}
  o.auraNames = o.auraNames or {}
  o.auraErrors = o.auraErrors or {}
  o.tempEnchant = o.tempEnchant or {}
  o.neverSecret = o.neverSecret or {}
  if o.settings.consumablesRaidsOnly == nil then o.settings.consumablesRaidsOnly = true end
  if o.settings.consumablesRemindDrop == nil then o.settings.consumablesRemindDrop = true end
  o.settings.priority = o.settings.priority or {}
  o.settings.pick = o.settings.pick or {}
  o.settings.show = o.settings.show or {}
  o.settings.sound = o.settings.sound or {}
  o.settings.visibility = o.settings.visibility or {}
  o.settings.consumableWhere = o.settings.consumableWhere or {}
  o.auraTimes = o.auraTimes or {}
  o.weaponRemaining = o.weaponRemaining or {}
  o.calls = o.calls or 0
  return {
    auraTimes = function(id)
      o.calls = o.calls + 1
      if o.auraErrors[id] then return nil end
      local t = o.auraTimes[id]; if not t then return nil end
      return t[1], t[2]
    end,
    auraTimesByName = function(name) return nil end,
    weaponRemaining = function(slot) return o.weaponRemaining[slot] end,
    inCombat = function() return o.combat == true end,
    thresholds = function() return o.thresholds or { long = 300, short = 60, longBuff = 900 } end,
    globalVisibility = function() return o.visibility or "always" end,
    knows = function(id) return o.known[id] == true end,
    aura = function(id)
      o.calls = o.calls + 1
      if o.auraErrors[id] then return nil end
      return o.auras[id] ~= nil
    end,
    auraSource = function(id)
      local src = o.auras[id]
      if src == nil or src == "secret" then return nil end
      if src == "player" then return "player" end
      return "other"
    end,
    auraByName = function(name)
      if o.restricted then return nil end
      return o.auraNames[name] == true
    end,
    tempEnchant = function(slot) return o.tempEnchant[slot] == true end,
    offhandWeapon = function() return o.offhandWeapon == true end,
    groupMembers = function() return o.group end,
    instanceType = function() return o.instance or "none" end,
    restricted = function() return o.restricted == true end,
    neverSecret = function(id) return o.neverSecret[id] == true end,
    enabled = function(key) return o.enabled[key] end,
    charSettings = function() return o.settings end,
    playerClass = function() return o.class or "PRIEST" end,
    playerLevel = function() return o.level or 60 end,
    weaponKind = function() return o.weaponKind end,
    now = function() return o.now or 0 end,
  }
end

return H
