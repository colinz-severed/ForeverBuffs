local ADDON, FB = ...
FB.API = FB.API or {}
local API = FB.API

-------------------------------------------------------------------------------
-- Every Blizzard call the addon makes goes through here. Each wrapper resolves
-- the function at call time, pcall-wraps it, and treats secret or errored
-- results as "unknown" (nil) rather than "missing" (false).
-------------------------------------------------------------------------------

local function resolve(path)
  local cur = _G
  for part in path:gmatch("[^%.]+") do
    if type(cur) ~= "table" then return nil end
    cur = cur[part]
  end
  if type(cur) == "function" then return cur end
  return nil
end

function API.IsSecret(v)
  local f = _G.issecretvalue
  if not f then return false end
  return f(v) == true
end
local IsSecret = API.IsSecret

-- Calls path(...) safely. Returns ok, result. ok is false when the function is
-- missing, errored, or returned a secret value.
local function safeCall(path, ...)
  local fn = resolve(path)
  if not fn then return false, nil end
  local ok, result = pcall(fn, ...)
  if not ok or IsSecret(result) then return false, nil end
  return true, result
end

-------------------------------------------------------------------------------
-- Spells and known spells
-------------------------------------------------------------------------------
function API.KnowsSpell(id)
  local ok, known = safeCall("C_SpellBook.IsSpellKnown", id)
  if ok and known == true then return true end
  local bank = _G.Enum and _G.Enum.SpellBookSpellBank and _G.Enum.SpellBookSpellBank.Player or 0
  ok, known = safeCall("C_SpellBook.IsSpellInSpellBook", id, bank, false)
  return ok and known == true
end

function API.SpellName(id)
  local ok, name = safeCall("C_Spell.GetSpellName", id)
  if ok and type(name) == "string" then return name end
  return nil
end

function API.SpellIcon(id)
  local ok, icon = safeCall("C_Spell.GetSpellTexture", id)
  if ok and icon then return icon end
  return nil
end

function API.SpellNeverSecret(id)
  local ok, secret = safeCall("C_Secrets.ShouldSpellAuraBeSecret", id)
  return ok and secret == false
end

-------------------------------------------------------------------------------
-- Auras on the player
-------------------------------------------------------------------------------
local function playerAuraData(id)
  local fn = resolve("C_UnitAuras.GetPlayerAuraBySpellID")
  if not fn then return false, nil end
  local ok, aura = pcall(fn, id)
  if not ok or IsSecret(aura) then return false, nil end
  return true, aura
end

-- Spell IDs whose lookup errored while auras were NOT restricted: the client
-- has no such spell. They read as "absent" from then on instead of freezing
-- their entry in its last state forever.
API.deadIDs = {}

function API.PlayerAura(id)
  if API.deadIDs[id] then return false end
  local fn = resolve("C_UnitAuras.GetPlayerAuraBySpellID")
  if not fn then return nil end
  local ok, aura = pcall(fn, id)
  if not ok then
    if not API.AurasRestricted() then
      API.deadIDs[id] = true
      return false
    end
    return nil
  end
  if IsSecret(aura) then return nil end
  return aura ~= nil
end

function API.PlayerAuraSource(id)
  local ok, aura = playerAuraData(id)
  if not ok or aura == nil then return nil end
  local src = aura.sourceUnit
  if src == nil or IsSecret(src) then return nil end
  if src == "player" then return "player" end
  local isUnit = resolve("UnitIsUnit")
  if isUnit then
    local okU, same = pcall(isUnit, src, "player")
    if okU and not IsSecret(same) and same == true then return "player" end
  end
  return "other"
end

function API.PlayerAuraByName(name)
  local fn = resolve("C_UnitAuras.GetAuraDataBySpellName")
  if not fn then return nil end
  local ok, aura = pcall(fn, "player", name, "HELPFUL")
  if not ok or IsSecret(aura) then return nil end
  return aura ~= nil
end

function API.AurasRestricted()
  local fn = resolve("C_Secrets.ShouldAurasBeSecret")
  if fn then
    local ok, secret = pcall(fn)
    if ok and not IsSecret(secret) then return secret == true end
  end
  local probe = resolve("C_UnitAuras.GetAuraDataByIndex")
  if not probe then return false end
  local ok = pcall(probe, "player", 1, "HELPFUL")
  return not ok
end

-------------------------------------------------------------------------------
-- Weapons
-------------------------------------------------------------------------------
local function temporaryEnchant(slot)
  local fn = resolve("C_PaperDollInfo.GetTemporaryEnchantmentInfo")
  if fn then
    local ok, info = pcall(fn, slot)
    if ok and not IsSecret(info) then return info ~= nil, true end
    return false, true
  end
  local legacy = resolve("GetWeaponEnchantInfo")
  if legacy then
    local ok, hasMH, _, _, _, hasOH = pcall(legacy)
    if ok then
      if slot == (_G.INVSLOT_OFFHAND or 17) then return hasOH == true, true end
      return hasMH == true, true
    end
  end
  return false, false
end

-- On Forever a shaman imbue is its own enchant type (Enum.ItemEnchantType.Imbue)
-- that GetTemporaryEnchantmentInfo does not report; C_Item.GetWeaponEnchantInfo
-- lists every enchant on a weapon slot. Returns the list (or nil).
local function weaponEnchantList(slot)
  local fn = resolve("C_Item.GetWeaponEnchantInfo")
  if not fn then return nil end
  local WS = _G.Enum and _G.Enum.WeaponSlot or {}
  local ws
  if slot == (_G.INVSLOT_OFFHAND or 17) then ws = WS.OffHand ~= nil and WS.OffHand or 1
  else ws = WS.MainHand ~= nil and WS.MainHand or 0 end
  local ok, list = pcall(fn, ws)
  if not ok or type(list) ~= "table" or IsSecret(list) then return nil end
  return list
end

local function listHasEnchant(list)
  if not list then return false end
  for _, e in ipairs(list) do
    if type(e) == "table" and not IsSecret(e) then
      local has = e.hasEnchant
      if has ~= nil and not IsSecret(has) and has == true then return true end
    end
  end
  return false
end

function API.TempEnchant(slot)
  local present = temporaryEnchant(slot)
  if present then return true end
  return listHasEnchant(weaponEnchantList(slot))
end

-- Human-readable description of both weapon-enchant sources, for /fbuffs debug.
function API.TempEnchantDetail(slot)
  local present, available = temporaryEnchant(slot)
  local list = weaponEnchantList(slot)
  local types = {}
  for _, e in ipairs(list or {}) do
    if type(e) == "table" and not IsSecret(e) then
      local t = e.enchantType
      types[#types + 1] = (IsSecret(t) and "secret") or tostring(t)
    end
  end
  return string.format("slot %d: temp=%s%s list=%s%s", slot,
    present and "yes" or "no", available and "" or " (no API)",
    list and tostring(#list) or "n/a",
    #types > 0 and (" types=" .. table.concat(types, ",")) or "")
end

local function slotItemInfo(slot)
  local getID = resolve("GetInventoryItemID")
  if not getID then return nil end
  local ok, itemID = pcall(getID, "player", slot)
  if not ok or not itemID or IsSecret(itemID) then return nil end
  local info = resolve("C_Item.GetItemInfoInstant")
  if not info then return nil end
  local okI, _, _, _, _, _, classID, subclassID = pcall(info, itemID)
  if not okI then return nil end
  return itemID, classID, subclassID
end

function API.OffhandIsWeapon()
  local itemID, classID = slotItemInfo(_G.INVSLOT_OFFHAND or 17)
  if not itemID then return false end
  local weaponClass = _G.Enum and _G.Enum.ItemClass and _G.Enum.ItemClass.Weapon or 2
  return classID == weaponClass
end

local EDGED, BLUNT = {}, {}
do
  local W = _G.Enum and _G.Enum.ItemWeaponSubclass or {}
  local function mark(set, name, fallback) set[W[name] ~= nil and W[name] or fallback] = true end
  mark(EDGED, "Axe1H", 0); mark(EDGED, "Axe2H", 1); mark(EDGED, "Polearm", 6); mark(EDGED, "Sword1H", 7)
  mark(EDGED, "Sword2H", 8); mark(EDGED, "Unarmed", 13); mark(EDGED, "Dagger", 15)
  mark(BLUNT, "Mace1H", 4); mark(BLUNT, "Mace2H", 5); mark(BLUNT, "Staff", 10)
end

function API.MainhandWeaponKind()
  local itemID, classID, subclassID = slotItemInfo(_G.INVSLOT_MAINHAND or 16)
  if not itemID then return nil end
  local weaponClass = _G.Enum and _G.Enum.ItemClass and _G.Enum.ItemClass.Weapon or 2
  if classID ~= weaponClass then return nil end
  if EDGED[subclassID] then return "edged" end
  if BLUNT[subclassID] then return "blunt" end
  return nil
end

function API.ItemName(itemID)
  local ok, name = safeCall("C_Item.GetItemNameByID", itemID)
  if ok and type(name) == "string" then return name end
  return nil
end

function API.ItemIcon(itemID)
  local ok, icon = safeCall("C_Item.GetItemIconByID", itemID)
  if ok and icon then return icon end
  return nil
end

-------------------------------------------------------------------------------
-- Units
-------------------------------------------------------------------------------
function API.UnitClassLevel(unit)
  local classFn, levelFn = resolve("UnitClass"), resolve("UnitLevel")
  if not classFn or not levelFn then return nil, nil end
  local ok, _, token = pcall(classFn, unit)
  if not ok or token == nil or IsSecret(token) then return nil, nil end
  local okL, level = pcall(levelFn, unit)
  if not okL or IsSecret(level) then level = nil end
  return token, level
end

function API.PlayerClass()
  local token = API.UnitClassLevel("player")
  return token
end

function API.PlayerLevel()
  local fn = resolve("UnitLevel")
  if not fn then return 0 end
  local ok, level = pcall(fn, "player")
  if not ok or IsSecret(level) or type(level) ~= "number" then return 0 end
  return level
end

-------------------------------------------------------------------------------
-- Probe: which Blizzard functions exist on this client
-------------------------------------------------------------------------------
local PROBED = {
  "C_SpellBook.IsSpellKnown", "C_SpellBook.IsSpellInSpellBook",
  "C_UnitAuras.GetPlayerAuraBySpellID", "C_UnitAuras.GetAuraDataBySpellName", "C_UnitAuras.GetAuraDataByIndex",
  "C_PaperDollInfo.GetTemporaryEnchantmentInfo", "C_Item.GetWeaponEnchantInfo",
  "C_Secrets.ShouldAurasBeSecret", "C_Secrets.ShouldSpellAuraBeSecret",
  "C_Spell.GetSpellTexture", "C_Spell.GetSpellName",
  "C_Item.GetItemInfoInstant", "C_Item.GetItemNameByID", "C_Item.GetItemIconByID",
  "issecretvalue",
  "Settings.RegisterVerticalLayoutCategory", "Settings.RegisterAddOnCategory", "Settings.RegisterProxySetting",
  "Settings.CreateCheckbox", "Settings.CreateSlider", "Settings.CreateDropdown",
}
function API.Probe()
  local out = {}
  for _, path in ipairs(PROBED) do out[#out + 1] = { name = path, ok = resolve(path) ~= nil } end
  return out
end

-------------------------------------------------------------------------------
-- 1.2: end times, weapon remaining time, item spells, screen text
-------------------------------------------------------------------------------
local function readable(v) return v ~= nil and not IsSecret(v) end

-- expirationTime, duration of the player's aura, or nil when absent, errored,
-- secret, or permanent (duration 0).
function API.PlayerAuraTimes(id)
  local ok, aura = playerAuraData(id)
  if not ok or aura == nil then return nil end
  local exp, dur = aura.expirationTime, aura.duration
  if not readable(exp) or not readable(dur) then return nil end
  if type(dur) ~= "number" or dur <= 0 or type(exp) ~= "number" or exp <= 0 then return nil end
  return exp, dur
end

function API.PlayerAuraTimesByName(name)
  local fn = resolve("C_UnitAuras.GetAuraDataBySpellName")
  if not fn then return nil end
  local ok, aura = pcall(fn, "player", name, "HELPFUL")
  if not ok or aura == nil or IsSecret(aura) then return nil end
  local exp, dur = aura.expirationTime, aura.duration
  if not readable(exp) or not readable(dur) then return nil end
  if type(dur) ~= "number" or dur <= 0 or type(exp) ~= "number" or exp <= 0 then return nil end
  return exp, dur
end

-- Seconds left on a weapon slot's enchant (temporary enchant or imbue), or nil.
function API.WeaponRemaining(slot)
  local fn = resolve("C_PaperDollInfo.GetTemporaryEnchantmentInfo")
  if fn then
    local ok, info = pcall(fn, slot)
    if ok and type(info) == "table" and not IsSecret(info) then
      local ms = info.remainingTimeMs
      if readable(ms) and type(ms) == "number" then return ms / 1000 end
    end
  end
  for _, e in ipairs(weaponEnchantList(slot) or {}) do
    if type(e) == "table" and not IsSecret(e) and readable(e.hasEnchant) and e.hasEnchant == true then
      local left = e.timeLeft
      if readable(left) and type(left) == "number" then return left / 1000 end
      return nil
    end
  end
  return nil
end

-- The spell an item casts (for a consumable: the buff it gives), or nil.
-- Requests item data when the client has not cached the item yet.
API.ItemSpellPending = {}
function API.ItemSpell(itemID)
  local fn = resolve("C_Item.GetItemSpell")
  if not fn then return nil end
  local ok, _, spellID = pcall(fn, itemID)
  if ok and readable(spellID) and type(spellID) == "number" then
    API.ItemSpellPending[itemID] = nil
    return spellID
  end
  local req = resolve("C_Item.RequestLoadItemDataByID")
  if req then pcall(req, itemID); API.ItemSpellPending[itemID] = true end
  return nil
end

-- A raid-warning style message in the middle of the screen.
function API.ScreenText(text, r, g, b)
  local add = resolve("RaidNotice_AddMessage")
  if add and _G.RaidWarningFrame then
    local ok = pcall(add, _G.RaidWarningFrame, text, { r = r or 1, g = g or 0.3, b = b or 0.1 })
    if ok then return end
  end
  local frame = _G.UIErrorsFrame
  if frame and frame.AddMessage then pcall(frame.AddMessage, frame, text, r or 1, g or 0.3, b or 0.1) end
end

for _, path in ipairs({ "C_Item.GetItemSpell", "C_Item.RequestLoadItemDataByID", "RaidNotice_AddMessage" }) do
  PROBED[#PROBED + 1] = path
end
