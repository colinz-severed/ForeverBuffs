-- Fake of the World of Warcraft (Mainline 12.1.5 / Forever 1.60.1) API surface
-- that ForeverBuffs uses. Everything configurable lives on the global STUB.
STUB = {}

local function noop() end

-------------------------------------------------------------------------------
-- Secret values
-------------------------------------------------------------------------------
STUB.secretValues = setmetatable({}, { __mode = "k" })
function STUB.secret(v)
  local s = setmetatable({}, { __tostring = function() return "<secret>" end })
  STUB.secretValues[s] = true
  s.__value = v
  return s
end
function issecretvalue(v) return type(v) == "table" and STUB.secretValues[v] == true end

-------------------------------------------------------------------------------
-- Frames / regions
-------------------------------------------------------------------------------
STUB.frames = {}
local regionMT
local function newRegion(kind, name, parent)
  local r = {
    _kind = kind, _name = name, _parent = parent, _shown = true, _alpha = 1,
    _points = {}, _scripts = {}, _events = {}, _w = 0, _h = 0, _text = "",
    _children = {}, texture = nil, desaturated = false, _playing = false,
  }
  return setmetatable(r, regionMT)
end

local methods = {}
function methods:SetScript(k, fn) self._scripts[k] = fn end
function methods:GetScript(k) return self._scripts[k] end
function methods:HookScript(k, fn) local old = self._scripts[k]; self._scripts[k] = function(...) if old then old(...) end; fn(...) end end
function methods:RegisterEvent(e) self._events[e] = true end
function methods:RegisterUnitEvent(e) self._events[e] = true end
function methods:UnregisterEvent(e) self._events[e] = nil end
function methods:UnregisterAllEvents() self._events = {} end
function methods:IsEventRegistered(e) return self._events[e] == true end
function methods:Show() self._shown = true end
function methods:Hide() self._shown = false end
function methods:SetShown(b) self._shown = b and true or false end
function methods:IsShown() return self._shown end
function methods:IsVisible() return self._shown end
function methods:SetPoint(point, a, b, c, d)
  local p
  if type(a) == "number" then p = { point = point, rel = UIParent, relPoint = point, x = a, y = b or 0 }
  elseif a == nil then p = { point = point, rel = UIParent, relPoint = point, x = 0, y = 0 }
  else p = { point = point, rel = a, relPoint = b or point, x = c or 0, y = d or 0 } end
  self._points[1] = p
end
function methods:GetPoint(i) local p = self._points[i or 1]; if not p then return nil end; return p.point, p.rel, p.relPoint, p.x, p.y end
function methods:GetNumPoints() return #self._points end
function methods:ClearAllPoints() self._points = {} end
function methods:SetAllPoints() end
function methods:SetSize(w, h) self._w = w; self._h = h end
function methods:SetWidth(w) self._w = w end
function methods:SetHeight(h) self._h = h end
function methods:GetWidth() return self._w end
function methods:GetHeight() return self._h end
function methods:GetSize() return self._w, self._h end
function methods:SetAlpha(a) self._alpha = a end
function methods:GetAlpha() return self._alpha end
function methods:SetText(t) self._text = t end
function methods:GetText() return self._text end
function methods:SetTexture(t) self.texture = t end
function methods:SetColorTexture(r, g, b, a) self.texture = { r, g, b, a } end
function methods:GetTexture() return self.texture end
function methods:SetDesaturated(d) self.desaturated = d end
function methods:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
function methods:GetParent() return self._parent end
function methods:SetParent(p) self._parent = p end
function methods:GetName() return self._name end
function methods:GetObjectType() return self._kind end
function methods:CreateTexture(name, layer) local t = newRegion("Texture", name, self); table.insert(self._children, t); return t end
function methods:CreateFontString(name, layer, template) local t = newRegion("FontString", name, self); table.insert(self._children, t); return t end
function methods:CreateAnimationGroup() local g = newRegion("AnimationGroup", nil, self); return g end
function methods:CreateAnimation(kind) local a = newRegion(kind or "Animation", nil, self); return a end
function methods:Play() self._playing = true end
function methods:Stop() self._playing = false end
function methods:IsPlaying() return self._playing end
function methods:SetLooping() end
function methods:SetOwner() end
function methods:AddLine(t) self._lines = self._lines or {}; table.insert(self._lines, t) end
function methods:ClearLines() self._lines = {} end
function methods:StartMoving() self._moving = true end
function methods:StopMovingOrSizing() self._moving = false end
function methods:GetID() return self._id or 1 end
function methods:GetEffectiveScale() return 1 end
function methods:GetCenter() return 0, 0 end
function methods:SetBackdrop(b) self._backdrop = b end
function methods:SetBackdropColor(r, g, b, a) self._backdropColor = { r, g, b, a } end
function methods:SetBackdropBorderColor(r, g, b, a) self._backdropBorderColor = { r, g, b, a } end
function methods:SetFrameStrata(s) self._strata = s end
function methods:GetFrameStrata() return self._strata end
function methods:SetFrameLevel(l) self._level = l end
function methods:GetFrameLevel() return self._level or 1 end
function methods:SetScrollChild(c) self._scrollChild = c end
function methods:GetScrollChild() return self._scrollChild end
function methods:SetVerticalScroll(v) self._scroll = v end
function methods:GetVerticalScroll() return self._scroll or 0 end
function methods:EnableMouseWheel() end
function methods:SetAutoFocus() end
function methods:ClearFocus() end
function methods:HighlightText() end
function methods:SetCursorPosition() end
function methods:SetJustifyH() end
function methods:SetJustifyV() end
function methods:SetFontObject() end
function methods:SetTextColor(r, g, b, a) self._textColor = { r, g, b, a } end
function methods:SetMinMaxValues(a, b) self._min, self._max = a, b end
function methods:GetMinMaxValues() return self._min or 0, self._max or 1 end
function methods:SetValue(v) self._value = v end
function methods:GetValue() return self._value or 0 end
function methods:SetValueStep(s) self._step = s end
function methods:SetObeyStepOnDrag() end
function methods:SetOrientation() end
function methods:SetChecked(b) self._checked = b and true or false end
function methods:GetChecked() return self._checked == true end
function methods:SetNormalFontObject() end
function methods:SetHighlightFontObject() end
function methods:SetDisabledFontObject() end
function methods:SetNormalTexture() end
function methods:SetPushedTexture() end
function methods:SetHighlightTexture() end
function methods:SetCheckedTexture() end
function methods:GetNormalTexture() return newRegion("Texture", nil, self) end
function methods:GetHighlightTexture() return newRegion("Texture", nil, self) end
function methods:RegisterForClicks() end
function methods:Click() local f = self._scripts.OnClick; if f then f(self, "LeftButton") end end
function methods:SetEnabled(e) self._enabled = e end
function methods:IsEnabled() return self._enabled ~= false end
function methods:Enable() self._enabled = true end
function methods:Disable() self._enabled = false end
function methods:SetToplevel() end
function methods:Raise() end
function methods:SetResizeBounds() end
function methods:SetClampedToScreen() end
function methods:SetMultiLine() end
function methods:SetMaxLetters() end
function methods:SetTextInsets() end
function methods:SetWordWrap(b) self._wordWrap = b end
function methods:SetMaxLines(n) self._maxLines = n end
function methods:SetNonSpaceWrap() end
function methods:GetStringWidth() return #tostring(self._text or "") * 6 end
function methods:SetHitRectInsets() end
function methods:SetPropagateKeyboardInput() end

regionMT = { __index = function(t, k) local m = methods[k]; if m then return m end; return noop end }

function CreateFrame(kind, name, parent, template)
  local f = newRegion(kind or "Frame", name, parent)
  if name then _G[name] = f end
  table.insert(STUB.frames, f)
  return f
end

UISpecialFrames = {}
RaidWarningFrame = { _name = "RaidWarningFrame" }
function RaidNotice_AddMessage(frame, text, color) table.insert(STUB.raidNotices, { frame = frame, text = text, color = color }) end
UIErrorsFrame = { AddMessage = function(self, text, r, g, b) table.insert(STUB.errorsFrame, { text = text, r = r, g = g, b = b }) end }
ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.28, b = 0 } }
BackdropTemplateMixin = {}
GameFontNormal, GameFontHighlight, GameFontHighlightSmall, GameFontNormalSmall = {}, {}, {}, {}
GameFontNormalLarge, GameFontDisableSmall, GameFontDisable, ChatFontNormal, GameFontHighlightLarge = {}, {}, {}, {}, {}
UIParent = newRegion("Frame", "UIParent")
UIParent._w, UIParent._h = 1920, 1080
GameTooltip = newRegion("GameTooltip", "GameTooltip")
GameTooltip._lines = {}

function STUB.fire(event, ...)
  for _, f in ipairs(STUB.frames) do
    if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
  end
end

-------------------------------------------------------------------------------
-- Time
-------------------------------------------------------------------------------
STUB.now = 0
STUB.timers = {}
function GetTime() return STUB.now end
C_Timer = {}
function C_Timer.After(d, fn) table.insert(STUB.timers, { at = STUB.now + d, fn = fn }) end
function C_Timer.NewTicker(d, fn, iterations)
  local t = { at = STUB.now + d, fn = fn, period = d, ticker = true, left = iterations }
  function t:Cancel() self.cancelled = true end
  function t:IsCancelled() return self.cancelled == true end
  table.insert(STUB.timers, t)
  return t
end
C_Timer.NewTimer = function(d, fn) local t = { at = STUB.now + d, fn = fn }; function t:Cancel() self.cancelled = true end; table.insert(STUB.timers, t); return t end
function STUB.advance(seconds)
  local target = STUB.now + seconds
  while true do
    local best, bi
    for i, t in ipairs(STUB.timers) do
      if not t.cancelled and t.at <= target and (not best or t.at < best.at) then best, bi = t, i end
    end
    if not best then break end
    STUB.now = best.at
    if best.ticker then
      best.at = best.at + best.period
      if best.left then best.left = best.left - 1; if best.left <= 0 then best.cancelled = true end end
    else
      table.remove(STUB.timers, bi)
    end
    best.fn(best)
  end
  STUB.now = target
end

-------------------------------------------------------------------------------
-- Units
-------------------------------------------------------------------------------
local CLASS_NAMES = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
local function unitRecord(unit)
  if unit == "player" then return STUB.player, "player" end
  local n = tostring(unit):match("^party(%d+)$")
  if n then return STUB.group[tonumber(n)], "group" .. n end
  n = tostring(unit):match("^raid(%d+)$")
  if n then
    n = tonumber(n)
    if n == #STUB.group + 1 then return STUB.player, "player" end
    return STUB.group[n], "group" .. n
  end
  return nil, nil
end
function UnitExists(unit) return unitRecord(unit) ~= nil end
function UnitIsUnit(a, b) local _, ka = unitRecord(a); local _, kb = unitRecord(b); return ka ~= nil and ka == kb end
function UnitClass(unit)
  local r = unitRecord(unit); if not r then return nil end
  local c = r.class
  if issecretvalue(c) then return c, c, 0 end
  return CLASS_NAMES[c] or c, c, 0
end
function UnitLevel(unit) local r = unitRecord(unit); return r and r.level or 0 end
function UnitName(unit) local r, key = unitRecord(unit); if not r then return nil end; return r.name or (key == "player" and "Tester" or ("Member" .. key:match("%d+"))) end
function UnitIsConnected(unit) local r = unitRecord(unit); return r ~= nil and r.connected ~= false end
function UnitIsDeadOrGhost(unit) local r = unitRecord(unit); return r ~= nil and r.dead == true end
function UnitIsDead(unit) return UnitIsDeadOrGhost(unit) end
function UnitIsGhost(unit) return false end
function UnitOnTaxi(unit) return STUB.player.taxi == true end
function UnitInVehicle(unit) return STUB.player.vehicle == true end
function UnitHasVehicleUI(unit) return STUB.player.vehicle == true end
function UnitIsPlayer(unit) return unitRecord(unit) ~= nil end
function IsMounted() return STUB.player.mounted == true end
function IsResting() return STUB.player.resting == true end
function InCombatLockdown() return STUB.player.combat == true end
function UnitAffectingCombat(unit) return STUB.player.combat == true end
function IsInInstance() local t = STUB.player.instanceType or "none"; return t ~= "none", t end
function IsInRaid() return STUB.inRaid == true end
function IsInGroup() return #STUB.group > 0 end
function GetNumGroupMembers() if #STUB.group == 0 then return 0 end; return #STUB.group + 1 end
function GetNumSubgroupMembers() return #STUB.group end
function GetInventoryItemID(unit, slot)
  if slot == 16 then return STUB.mainhandItem and STUB.mainhandItem.id end
  if slot == 17 then return STUB.offhandItem and STUB.offhandItem.id end
  return nil
end
function GetBuildInfo() return "1.60.1", "70862", "Nov 4 2026", 16001 end
function GetRealmName() return "TestRealm" end
function GetLocale() return "enUS" end

-------------------------------------------------------------------------------
-- C_* namespaces
-------------------------------------------------------------------------------
local function auraTable(id, a)
  return { spellId = id, name = a.name, sourceUnit = a.sourceUnit, icon = a.icon, duration = a.duration or 0,
    expirationTime = a.expirationTime or 0, isHelpful = true, isHarmful = false }
end
C_UnitAuras = {}
function C_UnitAuras.GetPlayerAuraBySpellID(id)
  if STUB.restricted then error("aura access restricted") end
  if STUB.auraErrors[id] then error("no such spell " .. tostring(id)) end
  local a = STUB.auras[id]; if not a then return nil end
  if a.secret then return STUB.secret(a) end
  return auraTable(id, a)
end
function C_UnitAuras.GetUnitAuraBySpellID(unit, id) return C_UnitAuras.GetPlayerAuraBySpellID(id) end
function C_UnitAuras.GetAuraDataBySpellName(unit, name, filter)
  if STUB.restricted then error("aura access restricted") end
  for id, a in pairs(STUB.auras) do if a.name == name then return auraTable(id, a) end end
  return nil
end
function C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
  if STUB.restricted then error("aura access restricted") end
  local ids = {}
  for id in pairs(STUB.auras) do ids[#ids + 1] = id end
  table.sort(ids)
  local id = ids[i]; if not id then return nil end
  return auraTable(id, STUB.auras[id])
end

C_SpellBook = {}
function C_SpellBook.IsSpellKnown(id) return STUB.known[id] == true end
function C_SpellBook.IsSpellInSpellBook(id, bank, includeOverrides) return STUB.known[id] == true end

C_Spell = {}
function C_Spell.GetSpellName(id) local s = STUB.spells[id]; return s and s.name or nil end
function C_Spell.GetSpellTexture(id) local s = STUB.spells[id]; return s and s.icon or nil end
function C_Spell.GetSpellInfo(id) local s = STUB.spells[id]; if not s then return nil end; return { name = s.name, iconID = s.icon, spellID = id } end

C_Item = {}
function C_Item.GetItemNameByID(id) local it = STUB.items[id]; return it and it.name or nil end
function C_Item.GetItemIconByID(id) local it = STUB.items[id]; return it and it.icon or nil end
function C_Item.GetItemInfoInstant(id)
  local it
  if STUB.mainhandItem and STUB.mainhandItem.id == id then it = STUB.mainhandItem end
  if STUB.offhandItem and STUB.offhandItem.id == id then it = STUB.offhandItem end
  if not it then it = STUB.items[id] end
  if not it then return nil end
  return id, "Weapon", "Sub", "INVTYPE_WEAPON", it.icon or 0, it.classID or 0, it.subclassID or 0
end

function C_Item.GetWeaponEnchantInfo(weaponSlot) return STUB.weaponEnchants[weaponSlot] end

function C_Item.GetItemSpell(id) local sid = STUB.itemSpells[id]; if not sid then return nil end; return "Spell" .. sid, sid end
function C_Item.RequestLoadItemDataByID(id) STUB.itemRequests[#STUB.itemRequests + 1] = id end

C_PaperDollInfo = {}
function C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot) local e = STUB.tempEnchant[slot]; if e then return e end; return nil end

C_Secrets = {}
function C_Secrets.ShouldAurasBeSecret() return STUB.restricted == true end
function C_Secrets.ShouldSpellAuraBeSecret(id) return not STUB.neverSecret[id] end

C_AddOns = {}
function C_AddOns.GetAddOnMetadata(name, field) if field == "Version" then return "1.0.0" end; return nil end

-------------------------------------------------------------------------------
-- Misc globals
-------------------------------------------------------------------------------
SOUNDKIT = { RAID_WARNING = 8959, READY_CHECK = 8960, ALARM_CLOCK_WARNING_3 = 12889, UI_RAID_BOSS_WHISPER_WARNING = 37666 }
function PlaySound(kit, channel) table.insert(STUB.sounds, { kit, channel }) end
function PlaySoundFile(path, channel) table.insert(STUB.sounds, { path, channel }) end
INVSLOT_MAINHAND, INVSLOT_OFFHAND = 16, 17
Enum = {
  SpellBookSpellBank = { Player = 0, Pet = 1 },
  ItemClass = { Weapon = 2, Armor = 4 },
  WeaponSlot = { MainHand = 0, OffHand = 1, Ranged = 2 },
  ItemEnchantType = { Temporary = 1, Imbue = 2 },
  ItemWeaponSubclass = { Axe1H = 0, Axe2H = 1, Bows = 2, Guns = 3, Mace1H = 4, Mace2H = 5, Polearm = 6, Sword1H = 7, Sword2H = 8,
    Staff = 10, Unarmed = 13, Dagger = 15, Crossbow = 18, Wand = 19 },
}
RAID_CLASS_COLORS = {}
for token in pairs(CLASS_NAMES) do RAID_CLASS_COLORS[token] = { r = 1, g = 1, b = 1, colorStr = "ffffffff" } end
SlashCmdList = {}
function wipe(t) for k in pairs(t) do t[k] = nil end; return t end
tinsert, tremove, format = table.insert, table.remove, string.format
strlower, strupper = string.lower, string.upper
function strtrim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
function strsplit(delim, s, n)
  local out = {}
  for piece in (s .. delim):gmatch("(.-)" .. delim:gsub("%p", "%%%0")) do out[#out + 1] = piece end
  return unpack(out)
end
function hooksecurefunc() end
function GetCVar() return nil end
function SetCVar() end
function PlaySoundKitID() end
local realPrint = print
function print(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  table.insert(STUB.printed, table.concat(parts, " "))
end
STUB.realPrint = realPrint

-------------------------------------------------------------------------------
-- Settings API stub
-------------------------------------------------------------------------------
local function settingObject(variable, default, getter, setter)
  local s = { _variable = variable, _default = default }
  function s:GetValue() if getter then return getter() end; return self._value end
  function s:SetValue(v) if setter then setter(v) else self._value = v end end
  function s:GetVariable() return self._variable end
  function s:SetValueChangedCallback() end
  return s
end
Settings = {
  VarType = { Boolean = "boolean", Number = "number", String = "string" },
  Default = { True = true, False = false },
}
STUB.settingsCategories = {}
function Settings.RegisterVerticalLayoutCategory(name)
  local cat = { _name = name, _id = name }
  function cat:GetID() return self._id end
  function cat:GetName() return self._name end
  local layout = { _inits = {} }
  function layout:AddInitializer(init) table.insert(self._inits, init) end
  return cat, layout
end
function Settings.RegisterCanvasLayoutCategory(frame, name) return Settings.RegisterVerticalLayoutCategory(name) end
function Settings.RegisterAddOnCategory(cat) table.insert(STUB.settingsCategories, cat) end
function Settings.RegisterProxySetting(cat, variable, varType, name, default, getter, setter) return settingObject(variable, default, getter, setter) end
function Settings.RegisterAddOnSetting(cat, variable, key, tbl, varType, name, default) return settingObject(variable, default) end
function Settings.CreateCheckbox(cat, setting, tooltip) return { _kind = "checkbox", setting = setting } end
function Settings.CreateSlider(cat, setting, options, tooltip) return { _kind = "slider", setting = setting } end
function Settings.CreateDropdown(cat, setting, optionsFn, tooltip) return { _kind = "dropdown", setting = setting } end
function Settings.CreateSliderOptions(min, max, step) local o = { min = min, max = max, step = step }; function o:SetLabelFormatter() end; return o end
function Settings.CreateControlTextContainer() local c = { _items = {} }; function c:Add(v, l) table.insert(self._items, { v, l }) end; function c:GetData() return self._items end; return c end
function Settings.OpenToCategory(id) STUB.openedCategory = id end
function Settings.CreateElementInitializer(template, data) return { _kind = "element", template = template, data = data } end
function CreateSettingsListSectionHeaderInitializer(name) return { _kind = "header", name = name } end
function CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, addSearchTags) return { _kind = "button", name = name, buttonText = buttonText, onClick = onClick } end
MinimalSliderWithSteppersMixin = { Label = { Left = 1, Right = 2, Top = 3, Min = 4, Max = 5 } }

-------------------------------------------------------------------------------
-- Reset / load
-------------------------------------------------------------------------------
function STUB.reset()
  STUB.auras = {}
  STUB.known = {}
  STUB.group = {}
  STUB.inRaid = false
  STUB.restricted = false
  STUB.neverSecret = {}
  STUB.tempEnchant = {}
  STUB.weaponEnchants = {}
  STUB.itemSpells = {}
  STUB.itemRequests = {}
  STUB.raidNotices = {}
  STUB.errorsFrame = {}
  STUB.auraErrors = {}
  STUB.offhandItem = nil
  STUB.mainhandItem = nil
  STUB.player = { class = "PRIEST", level = 60, dead = false, mounted = false, taxi = false, resting = false, combat = false, vehicle = false, instanceType = "none", name = "Tester" }
  STUB.spells = {}
  STUB.items = {}
  STUB.sounds = {}
  STUB.printed = {}
  STUB.now = 0
  STUB.timers = {}
  STUB.settingsCategories = {}
  STUB.openedCategory = nil
  GameTooltip._lines = {}
  ForeverBuffsDB = nil
  ForeverBuffsCharDB = nil
end

function STUB.tocFiles()
  local files = {}
  local f = assert(io.open("ForeverBuffs.toc", "r"))
  for line in f:lines() do
    line = line:gsub("\r", "")
    if not line:match("^#") and line:match("%.lua%s*$") then files[#files + 1] = strtrim(line) end
  end
  f:close()
  return files
end

function STUB.loadAddon()
  FB = {}
  for _, path in ipairs(STUB.tocFiles()) do
    local fh = assert(io.open(path, "r"))
    local src = fh:read("*a"); fh:close()
    local chunk, err = loadstring(src, "@" .. path)
    if not chunk then error(err) end
    chunk("ForeverBuffs", FB)
  end
  return FB
end

-- setup: optional function run after reset and before the addon loads
-- (e.g. to set the player's class before PLAYER_LOGIN fires).
function STUB.reload(setup)
  STUB.frames = {}
  STUB.reset()
  if setup then setup() end
  STUB.loadAddon()
  STUB.fire("PLAYER_LOGIN")
  return FB
end

STUB.reset()
