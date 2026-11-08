local ADDON, FB = ...
FB.Options = FB.Options or {}
local Options = FB.Options
local UI = FB.UI

-------------------------------------------------------------------------------
-- Standalone options window: /fbuffs, the addon compartment, ESC closes.
-------------------------------------------------------------------------------

Options.TAB_NAMES = { "Display", "Alerts", "Buffs", "Consumables", "Position", "About" }
Options.WIDTH, Options.HEIGHT = 720, 480
Options.TABS_WIDTH = 130
Options.controls = {}
Options.panels = {}
Options.allWidgets = {}

local function addonVersion()
  local ok, v = pcall(function() return C_AddOns.GetAddOnMetadata(ADDON, "Version") end)
  if ok and v then return v end
  return FB.Core and FB.Core.VERSION or "?"
end

Options.about = {
  author = "colinzmulan (Claude AI assisted)",
  bugs = "https://github.com/colinz-severed/ForeverBuffs/issues",
  downloads = "https://github.com/colinz-severed/ForeverBuffs/releases",
  description = "Missing-buff reminder for World of Warcraft: Forever",
}

local function changed()
  if FB.Core and FB.Core.SettingChanged then FB.Core.SettingChanged() end
end

local function dbGet(key, default)
  return function() local v = FB.db and FB.db[key]; if v == nil then return default end; return v end
end
local function dbSet(key, after)
  return function(v) FB.db[key] = v; if after then after(v) end; changed() end
end
local function cdbGet(key, default)
  return function() local v = FB.cdb and FB.cdb[key]; if v == nil then return default end; return v end
end
local function cdbSet(key, after)
  return function(v) FB.cdb[key] = v; if after then after(v) end; changed() end
end

local function register(name, widget)
  if name then Options.controls[name] = widget end
  Options.allWidgets[#Options.allWidgets + 1] = widget
  return widget
end

-- Two-column stacker for a panel.
local function stacker(panel)
  local y = { 0, 0 }
  local colX = { 0, 290 }
  return function(widget, col, gap)
    col = col or 1
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", panel, "TOPLEFT", colX[col], -y[col])
    y[col] = y[col] + (widget:GetHeight() or 24) + (gap or 10)
    return widget
  end
end

local function choices(list)
  return function() return list end
end

local pct = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
local px = function(v) return v .. " px" end
local plain = function(v) return tostring(v) end

-------------------------------------------------------------------------------
-- Tabs
-------------------------------------------------------------------------------
local function buildDisplay(panel)
  local put = stacker(panel)
  put(register("style", UI.Dropdown(panel, "Display style", choices({
    { value = "row", text = "Plain row (missing only)" },
    { value = "names", text = "Flashing with names (missing only)" },
    { value = "grid", text = "Always-on grid (dims when buffed)" },
  }), dbGet("style", "grid"), dbSet("style"), 270)))
  put(register("iconSize", UI.Slider(panel, "Icon size", 20, 80, 2, dbGet("iconSize", 40), dbSet("iconSize"), px)))
  put(register("spacing", UI.Slider(panel, "Spacing", 0, 20, 1, dbGet("spacing", 6), dbSet("spacing"), px)))
  put(register("direction", UI.Dropdown(panel, "Grow direction", choices({
    { value = "RIGHT", text = "Right" }, { value = "LEFT", text = "Left" }, { value = "DOWN", text = "Down" }, { value = "UP", text = "Up" },
  }), dbGet("direction", "RIGHT"), dbSet("direction"), 270)))
  put(register("perRow", UI.Slider(panel, "Icons per row", 1, 20, 1, dbGet("perRow", 8), dbSet("perRow"), plain)))

  put(register("showNames", UI.Checkbox(panel, "Show buff names under icons", dbGet("showNames", false), dbSet("showNames"))), 2)
  put(register("highScale", UI.Slider(panel, "High priority size", 1.0, 1.5, 0.05, dbGet("highScale", 1.15), dbSet("highScale"), pct)), 2)
  put(register("lowScale", UI.Slider(panel, "Low priority size", 0.4, 1.0, 0.05, dbGet("lowScale", 0.7), dbSet("lowScale"), pct)), 2)
  put(register("windowAlpha", UI.Slider(panel, "Window opacity", 0.3, 1.0, 0.05, dbGet("windowAlpha", 0.7),
    dbSet("windowAlpha", function(v) if Options.frame then Options.frame:SetAlphaBackdrop(v) end end), pct)), 2)
end

local function soundChoices()
  local out = {}
  for _, s in ipairs(FB.Alerts.SOUNDS) do out[#out + 1] = { value = s.key, text = s.name } end
  return out
end

local function buildAlerts(panel)
  local put = stacker(panel)
  put(register("alertStyle", UI.Dropdown(panel, "Alert style (Normal priority)", choices({
    { value = "icon", text = "Icon only" }, { value = "flash", text = "Flash" }, { value = "sound", text = "Sound" }, { value = "both", text = "Flash + sound" },
  }), dbGet("alertStyle", "flash"), dbSet("alertStyle"), 270)))
  local sn = put(register("soundNormal", UI.Dropdown(panel, "Normal sound", soundChoices, dbGet("soundNormal", "raid_warning"), dbSet("soundNormal"), 200)))
  local pn = register("playNormal", UI.Button(panel, "Play", function() FB.Alerts.Play(FB.db.soundNormal) end, 60))
  pn:SetPoint("BOTTOMLEFT", sn, "BOTTOMRIGHT", 8, 0)
  local sh = put(register("soundHigh", UI.Dropdown(panel, "High sound (always plays)", soundChoices, dbGet("soundHigh", "alarm3"), dbSet("soundHigh"), 200)))
  local ph = register("playHigh", UI.Button(panel, "Play", function() FB.Alerts.Play(FB.db.soundHigh) end, 60))
  ph:SetPoint("BOTTOMLEFT", sh, "BOTTOMRIGHT", 8, 0)
  local note = UI.SectionHeader(panel, "")
  note:SetText("High: full size, gold border, flashes and sounds. Normal: follows the alert style. Low: smaller, never flashes or sounds.")
  note:SetWidth(270); note:SetJustifyH("LEFT"); note:SetWordWrap(true)
  put(note)

  put(register("combat", UI.Dropdown(panel, "In combat", choices({
    { value = "freeze", text = "Freeze (keep last state)" }, { value = "hide", text = "Hide" },
  }), dbGet("combat", "freeze"), dbSet("combat"), 270)), 2)
  put(register("hideMounted", UI.Checkbox(panel, "Hide while mounted", dbGet("hideMounted", true), dbSet("hideMounted"))), 2)
  put(register("hideResting", UI.Checkbox(panel, "Hide while resting (inns, cities)", dbGet("hideResting", false), dbSet("hideResting"))), 2)
end

local function buildPosition(panel)
  local put = stacker(panel)
  local lockBtn = register("lockToggle", UI.Button(panel, "Unlock", function()
    FB.Core.Slash(FB.Core.unlocked and "lock" or "unlock")
    Options.Refresh()
  end, 160))
  lockBtn.Refresh = function() lockBtn:SetText(FB.Core and FB.Core.unlocked and "Lock" or "Unlock") end
  put(lockBtn)
  put(register("resetPosition", UI.Button(panel, "Reset position", function() FB.Core.Slash("reset"); Options.Refresh() end, 160)))
  local testBtn = register("testMode", UI.Button(panel, "Test mode", function() FB.Core.Slash("test"); Options.Refresh() end, 160))
  testBtn.Refresh = function() testBtn:SetText(FB.Core and FB.Core.testMode and "Test mode: on" or "Test mode: off") end
  put(testBtn)
  local info = UI.SectionHeader(panel, "")
  info:SetWidth(270); info:SetJustifyH("LEFT"); info:SetWordWrap(true)
  info.Refresh = function()
    local p = FB.db and FB.db.position or {}
    info:SetText(string.format("Anchor: %s  x %d  y %d", tostring(p.point or "CENTER"), p.x or 0, p.y or 0))
  end
  info.Refresh()
  Options.allWidgets[#Options.allWidgets + 1] = info
  put(info, 2)
  local tip = UI.SectionHeader(panel, "")
  tip:SetText("Unlock, drag the icons anywhere, then lock. Test mode shows every tracked buff as missing so you can see the layout and hear the sounds.")
  tip:SetWidth(270); tip:SetJustifyH("LEFT"); tip:SetWordWrap(true)
  put(tip, 2)
end

local function buildAbout(panel)
  local put = stacker(panel)
  Options.about.version = addonVersion()
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetText("ForeverBuffs  |cff8b93a5v" .. tostring(Options.about.version) .. "|r")
  title:SetHeight(24)
  put(title)
  local desc = UI.SectionHeader(panel, ""); desc:SetText(Options.about.description); desc:SetHeight(16)
  put(desc)
  local author = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  author:SetText("Author: " .. Options.about.author); author:SetHeight(16)
  put(author)
  local l1 = UI.SectionHeader(panel, "Report a bug"); l1:SetHeight(14); put(l1, 1, 2)
  put(register("bugsLink", UI.EditBox(panel, Options.about.bugs, 420)))
  local l2 = UI.SectionHeader(panel, "Downloads"); l2:SetHeight(14); put(l2, 1, 2)
  put(register("downloadsLink", UI.EditBox(panel, Options.about.downloads, 420)))
  local diag = UI.SectionHeader(panel, "")
  diag:SetText("Diagnostics: type /fbuffs report, then /reload, and send the file WTF\\Account\\<account>\\SavedVariables\\ForeverBuffs.lua with your bug report.")
  diag:SetWidth(420); diag:SetJustifyH("LEFT"); diag:SetWordWrap(true); diag:SetHeight(30)
  put(diag)
  put(register("windowAlphaAbout", UI.Slider(panel, "Window opacity", 0.3, 1.0, 0.05, dbGet("windowAlpha", 0.7),
    dbSet("windowAlpha", function(v) if Options.frame then Options.frame:SetAlphaBackdrop(v) end end), pct)))
end

local BUILDERS = {
  Display = buildDisplay,
  Alerts = buildAlerts,
  Position = buildPosition,
  About = buildAbout,
  -- Buffs and Consumables are filled by Options.BuildBuffs / BuildConsumables (if defined)
}

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
local function saveWindowPosition()
  local f = Options.frame
  if not f or not FB.db then return end
  local point, _, relPoint, x, y = f:GetPoint()
  if not point then return end
  FB.db.windowPosition = { point = point, relPoint = relPoint or point, x = math.floor((x or 0) + 0.5), y = math.floor((y or 0) + 0.5) }
end

local function applyWindowPosition()
  local f = Options.frame
  local p = FB.db and FB.db.windowPosition or {}
  f:ClearAllPoints()
  f:SetPoint(p.point or "CENTER", UIParent, p.relPoint or p.point or "CENTER", p.x or 0, p.y or 0)
end

function Options.Build()
  if Options.frame then return Options.frame end
  local frame = UI.Panel(UIParent, Options.WIDTH, Options.HEIGHT, "ForeverBuffsOptions")
  Options.frame = frame
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:Hide()
  tinsert(UISpecialFrames, "ForeverBuffsOptions")

  -- Title bar (drag handle)
  local title = CreateFrame("Frame", nil, frame)
  frame.title = title
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  title:SetHeight(32)
  title:EnableMouse(true)
  title:RegisterForDrag("LeftButton")
  title:SetScript("OnDragStart", function() frame:StartMoving() end)
  title:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); saveWindowPosition() end)
  local titleBg = title:CreateTexture(nil, "BACKGROUND")
  titleBg:SetAllPoints(title)
  titleBg:SetColorTexture(1, 1, 1, 0.04)
  local titleText = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleText:SetPoint("LEFT", title, "LEFT", 12, 0)
  titleText:SetText("ForeverBuffs")
  frame.titleText = titleText
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() Options.Close() end)
  frame.close = close

  -- Tabs
  Options.tabs = UI.Tabs(frame, Options.TAB_NAMES, function(name)
    for n, p in pairs(Options.panels) do if n == name then p:Show() else p:Hide() end end
    UI.CloseDropdowns()
    Options.Refresh()
  end, Options.TABS_WIDTH)
  Options.tabs:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -40)
  local divider = frame:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(UI.COLORS.border[1], UI.COLORS.border[2], UI.COLORS.border[3], 0.8)
  divider:SetWidth(1)
  divider:SetPoint("TOPLEFT", frame, "TOPLEFT", Options.TABS_WIDTH, -32)
  divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", Options.TABS_WIDTH, 0)

  -- Panels
  for _, name in ipairs(Options.TAB_NAMES) do
    local p = CreateFrame("Frame", nil, frame)
    p:SetPoint("TOPLEFT", frame, "TOPLEFT", Options.TABS_WIDTH + 16, -44)
    p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    p:Hide()
    Options.panels[name] = p
    local builder = BUILDERS[name]
    if builder then builder(p) end
  end
  if Options.BuildBuffs then Options.BuildBuffs(Options.panels.Buffs) end
  if Options.BuildConsumables then Options.BuildConsumables(Options.panels.Consumables) end

  frame:SetScript("OnHide", function() UI.CloseDropdowns() end)
  frame:SetAlphaBackdrop(FB.db and FB.db.windowAlpha or 0.7)
  applyWindowPosition()
  Options.tabs:Select(Options.TAB_NAMES[1])
  return frame
end

function Options.Refresh()
  if not Options.frame then return end
  for _, w in ipairs(Options.allWidgets) do
    if w.Refresh then w.Refresh() end
  end
  if FB.db then Options.frame:SetAlphaBackdrop(FB.db.windowAlpha or 0.7) end
  if Options.RefreshBuffs then Options.RefreshBuffs() end
  if Options.RefreshConsumables then Options.RefreshConsumables() end
end

function Options.Show(tabName)
  Options.Build()
  Options.frame:Show()
  Options.tabs:Select(tabName or Options.tabs.active or Options.TAB_NAMES[1])
end

function Options.Open() Options.Show(nil) end

function Options.Close()
  if Options.frame then Options.frame:Hide() end
end

function Options.Toggle()
  Options.Build()
  if Options.frame:IsShown() then Options.Close() else Options.Open() end
end

-------------------------------------------------------------------------------
-- Buffs tab
-------------------------------------------------------------------------------
local PRIORITY_CHOICES = {
  { value = "default", text = "Default" }, { value = "high", text = "High" },
  { value = "normal", text = "Normal" }, { value = "low", text = "Low" },
}
local PRIORITY_NOTE = { high = "flash + sound", normal = "alert style", low = "small, quiet" }

local function playerClass() return FB.API.PlayerClass() end
local function playerLevel() return FB.API.PlayerLevel() end

local function entryDefaultEnabled(entry)
  local byClass = entry.defaultEnabledByClass and entry.defaultEnabledByClass[playerClass()]
  if byClass ~= nil then return byClass end
  return entry.defaultEnabled
end

local function entryEnabled(entry)
  local v = FB.cdb and FB.cdb.enabled and FB.cdb.enabled[entry.key]
  if v == nil then return entryDefaultEnabled(entry) end
  return v
end

local function entryName(entry)
  if entry.consumable then return entry.name end
  local id = entry.iconSpells and entry.iconSpells[#entry.iconSpells]
  if FB.Core and FB.Core.state then id = FB.Core.state:IconSpell(entry.key) or id end
  return (id and FB.API.SpellName(id)) or entry.name
end

local function entryIcon(entry)
  local id = entry.iconSpells and entry.iconSpells[#entry.iconSpells]
  if FB.Core and FB.Core.state then id = FB.Core.state:IconSpell(entry.key) or id end
  return (id and FB.API.SpellIcon(id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function effectivePriority(key)
  local explicit = FB.cdb and FB.cdb.priority and FB.cdb.priority[key]
  if explicit then return explicit end
  if FB.Core and FB.Core.state then return FB.Core.state:Priority(key) end
  return "normal"
end

local function knowsEntry(entry)
  for _, id in ipairs(entry.castIDs or {}) do if FB.API.KnowsSpell(id) then return true end end
  return false
end

local function buildBuffRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row.header = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.header:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.header:SetTextColor(UI.COLORS.muted[1], UI.COLORS.muted[2], UI.COLORS.muted[3], 1)
  row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  row.check:SetSize(22, 22)
  row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.check:SetScript("OnClick", function(self)
    local entry = row.entry; if not entry then return end
    local nv = not entryEnabled(entry)
    FB.cdb.enabled[entry.key] = nv
    self:SetChecked(nv)
    changed()
  end)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(20, 20)
  row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetWidth(190); row.name:SetJustifyH("LEFT")
  row.priority = UI.Dropdown(row, nil, choices(PRIORITY_CHOICES),
    function() return row.key and FB.cdb.priority[row.key] or "default" end,
    function(v)
      if not row.key then return end
      if v == "default" then FB.cdb.priority[row.key] = nil else FB.cdb.priority[row.key] = v end
      changed()
      if Options.RefreshBuffs then Options.RefreshBuffs() end
    end, 100)
  row.priority:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
  row.note = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.note:SetPoint("LEFT", row.priority, "RIGHT", 10, 0)
  row.note:SetTextColor(UI.COLORS.muted[1], UI.COLORS.muted[2], UI.COLORS.muted[3], 1)
  return row
end

local function fillBuffRow(row, item)
  if item.kind == "header" then
    row.entry, row.key = nil, nil
    row.header:SetText(string.upper(item.text)); row.header:Show()
    row.check:Hide(); row.icon:Hide(); row.name:Hide(); row.priority:Hide(); row.note:Hide()
    return
  end
  local entry = FB.Data.byKey[item.key]
  row.entry, row.key = entry, item.key
  row.header:Hide()
  row.check:Show(); row.icon:Show(); row.name:Show(); row.priority:Show(); row.note:Show()
  row.check:SetChecked(entryEnabled(entry))
  row.icon:SetTexture(entryIcon(entry))
  row.name:SetText(entryName(entry))
  row.priority.Refresh()
  local known = knowsEntry(entry)
  if entry.class == playerClass() and not known and (playerLevel() < (entry.learnLevel or 1)) then
    row.note:SetText("learned at level " .. tostring(entry.learnLevel))
    row.name:SetTextColor(0.6, 0.6, 0.6, 1)
  else
    row.note:SetText(PRIORITY_NOTE[effectivePriority(item.key)] or "")
    row.name:SetTextColor(1, 1, 1, 1)
  end
  Options.buffRows[item.key] = row
end

local function buffItems()
  local class = playerClass()
  local own, others = {}, {}
  for _, entry in ipairs(FB.Data.entries) do
    if not entry.consumable then
      if entry.class == class then own[#own + 1] = { kind = "entry", key = entry.key }
      elseif not entry.selfOnly then others[#others + 1] = { kind = "entry", key = entry.key } end
    end
  end
  local items = { { kind = "header", text = "Your buffs" } }
  for _, it in ipairs(own) do items[#items + 1] = it end
  items[#items + 1] = { kind = "header", text = "From other classes (shown only when someone can cast it)" }
  for _, it in ipairs(others) do items[#items + 1] = it end
  return items
end

function Options.BuildBuffs(panel)
  Options.buffRows = {}
  local hint = UI.SectionHeader(panel, "")
  hint:SetText("Priority sets icon size and alerts. High: bigger, gold, flashes and sounds. Normal: follows the alert style. Low: smaller and silent.")
  hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0); hint:SetWidth(540); hint:SetJustifyH("LEFT"); hint:SetWordWrap(true); hint:SetHeight(28)
  local list = UI.ScrollList(panel, 28, buildBuffRow, fillBuffRow, { virtual = false })
  list:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -34)
  list:SetSize(Options.WIDTH - Options.TABS_WIDTH - 30, Options.HEIGHT - 44 - 12 - 34)
  Options.buffList = list
  function Options.RefreshBuffs()
    Options.buffRows = {}
    list:SetItems(buffItems())
  end
  Options.RefreshBuffs()
end

-------------------------------------------------------------------------------
-- Consumables tab
-------------------------------------------------------------------------------
local CATEGORY_LABEL = { elixir = "Elixir", flask = "Flask", well_fed = "Well Fed", weapon = "Weapon oil / stone" }
local CATEGORY_ORDER = { "elixir", "flask", "well_fed", "weapon" }
local CATEGORY_KEYS = { elixir = { "elixir" }, flask = { "flask" }, well_fed = { "well_fed" }, weapon = { "weapon_mh", "weapon_oh" } }
local CATEGORY_MAIN_KEY = { elixir = "elixir", flask = "flask", well_fed = "well_fed", weapon = "weapon_mh" }

Options.filterText = ""

local function categoryVisible(cat)
  local entry = FB.Data.byKey[CATEGORY_MAIN_KEY[cat]]
  return not (entry.excludeClasses and entry.excludeClasses[playerClass()])
end

local function pureRecommendation(cat)
  local state = FB.Core and FB.Core.state
  if not state then return nil end
  return FB.Data.Recommend(CATEGORY_MAIN_KEY[cat], state.env.playerClass(), state:Role(), state.env.playerLevel(), state.env.weaponKind())
end

local function buildConsumableRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  -- header widgets
  row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  row.check:SetSize(22, 22)
  row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.check:SetScript("OnClick", function(self)
    local cat = row.category; if not cat then return end
    local main = FB.Data.byKey[CATEGORY_MAIN_KEY[cat]]
    local nv = not entryEnabled(main)
    for _, key in ipairs(CATEGORY_KEYS[cat]) do FB.cdb.enabled[key] = nv end
    self:SetChecked(nv)
    changed()
  end)
  row.header = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.header:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
  row.priority = UI.Dropdown(row, nil, choices(PRIORITY_CHOICES),
    function() local k = row.category and CATEGORY_MAIN_KEY[row.category]; return k and FB.cdb.priority[k] or "default" end,
    function(v)
      local cat = row.category; if not cat then return end
      for _, key in ipairs(CATEGORY_KEYS[cat]) do
        if v == "default" then FB.cdb.priority[key] = nil else FB.cdb.priority[key] = v end
      end
      changed()
    end, 100)
  row.priority:SetPoint("RIGHT", row, "RIGHT", -4, 0)
  -- "use recommendation" widgets
  row.useRecommendation = UI.Button(row, "Use recommendation", function()
    local cat = row.category; if not cat then return end
    FB.cdb.pick[cat] = nil
    changed()
    if Options.RefreshConsumables then Options.RefreshConsumables() end
  end, 150)
  row.useRecommendation:SetPoint("LEFT", row, "LEFT", 26, 0)
  -- item widgets
  row.radio = CreateFrame("CheckButton", nil, row, "UIRadioButtonTemplate")
  row.radio:SetSize(16, 16)
  row.radio:SetPoint("LEFT", row, "LEFT", 6, 0)
  row.radio:SetScript("OnClick", function(self)
    local cat, item = row.category, row.item; if not (cat and item) then return end
    FB.cdb.pick[cat] = item.itemID
    changed()
    if Options.RefreshConsumables then Options.RefreshConsumables() end
  end)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(18, 18)
  row.icon:SetPoint("LEFT", row.radio, "RIGHT", 6, 0)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetWidth(230); row.name:SetJustifyH("LEFT")
  row.summary = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.summary:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
  row.summary:SetWidth(150); row.summary:SetJustifyH("LEFT")
  row.summary:SetTextColor(UI.COLORS.muted[1], UI.COLORS.muted[2], UI.COLORS.muted[3], 1)
  row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.tag:SetPoint("RIGHT", row, "RIGHT", -8, 0)
  return row
end

local ROW_WIDGETS = { "check", "header", "priority", "useRecommendation", "radio", "icon", "name", "summary", "tag" }
local function showOnly(row, ...)
  local on = {}
  for i = 1, select("#", ...) do on[select(i, ...)] = true end
  for _, name in ipairs(ROW_WIDGETS) do
    if on[name] then row[name]:Show() else row[name]:Hide() end
  end
end

local function fillConsumableRow(row, item)
  row.category = item.category
  row.item = nil
  if item.kind == "header" then
    showOnly(row, "check", "header", "priority")
    row.check:SetChecked(entryEnabled(FB.Data.byKey[CATEGORY_MAIN_KEY[item.category]]))
    row.header:SetText(CATEGORY_LABEL[item.category])
    row.priority.Refresh()
    Options.consumableHeaders[item.category] = Options.consumableHeaders[item.category] or {}
    local h = Options.consumableHeaders[item.category]
    h.check, h.priority, h.row = row.check, row.priority, row
  elseif item.kind == "use" then
    showOnly(row, "useRecommendation")
    Options.consumableHeaders[item.category] = Options.consumableHeaders[item.category] or {}
    Options.consumableHeaders[item.category].useRecommendation = row.useRecommendation
  else
    showOnly(row, "radio", "icon", "name", "summary", "tag")
    local r = item.row
    row.item = r
    local pick = FB.cdb.pick[item.category]
    local rec = item.recommended
    row.radio:SetChecked(pick == r.itemID)
    row.icon:SetTexture(FB.API.ItemIcon(r.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.name:SetText(string.format("%s  |cff8b93a5lvl %d|r", FB.API.ItemName(r.itemID) or r.name, r.level))
    row.summary:SetText(r.summary or "")
    if pick == r.itemID then
      row.tag:SetText("your pick"); row.tag:SetTextColor(1, 0.9, 0.5, 1)
    elseif rec and rec.itemID == r.itemID then
      row.tag:SetText("recommended"); row.tag:SetTextColor(0.56, 0.82, 0.56, 1)
    else
      row.tag:SetText("")
    end
    local tooHigh = r.level > playerLevel()
    local shade = tooHigh and 0.55 or 1
    row.name:SetTextColor(shade, shade, shade, 1)
    Options.consumableRows[r.itemID] = row
  end
end

local function consumableItems()
  local items = {}
  local filter = string.lower(Options.filterText or "")
  for _, cat in ipairs(CATEGORY_ORDER) do
    if categoryVisible(cat) then
      items[#items + 1] = { kind = "header", category = cat }
      items[#items + 1] = { kind = "use", category = cat }
      local rec = pureRecommendation(cat)
      for _, r in ipairs(FB.Data.CATALOGUE[cat]) do
        if filter == "" or string.find(string.lower(r.name), filter, 1, true) then
          items[#items + 1] = { kind = "item", category = cat, row = r, recommended = rec }
        end
      end
    end
  end
  return items
end

function Options.BuildConsumables(panel)
  Options.consumableRows = {}
  Options.consumableHeaders = {}
  local roleChoices = function()
    local out = {}
    for _, r in ipairs(FB.Data.ROLES) do out[#out + 1] = { value = r, text = r } end
    return out
  end
  local role = register("role", UI.Dropdown(panel, "Role", roleChoices,
    function() return (FB.cdb and FB.cdb.role) or FB.Data.DefaultRole(playerClass()) end,
    cdbSet("role", function() if Options.RefreshConsumables then Options.RefreshConsumables() end end), 110))
  role:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  local where = register("consumablesWhere", UI.Dropdown(panel, "Show consumables", choices({
    { value = "raids", text = "Raids only" }, { value = "everywhere", text = "Everywhere" },
  }), function() if FB.cdb and FB.cdb.consumablesRaidsOnly == false then return "everywhere" end; return "raids" end,
    function(v) FB.cdb.consumablesRaidsOnly = (v ~= "everywhere"); changed() end, 130))
  where:SetPoint("TOPLEFT", role, "TOPRIGHT", 10, 0)
  local remind = register("consumablesRemindDrop", UI.Checkbox(panel, "Remind when it wears off",
    cdbGet("consumablesRemindDrop", true), cdbSet("consumablesRemindDrop")))
  remind:SetPoint("BOTTOMLEFT", where, "BOTTOMRIGHT", 10, 0)
  local filter = register("filter", UI.EditBox(panel, "", 160, true, function(text)
    Options.filterText = text or ""
    if Options.RefreshConsumables then Options.RefreshConsumables() end
  end))
  filter:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -18)
  local filterLabel = UI.SectionHeader(panel, "Filter")
  filterLabel:SetPoint("BOTTOMLEFT", filter, "TOPLEFT", 0, 2)

  local list = UI.ScrollList(panel, 24, buildConsumableRow, fillConsumableRow, { virtual = false })
  list:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -50)
  list:SetSize(Options.WIDTH - Options.TABS_WIDTH - 30, Options.HEIGHT - 44 - 12 - 50)
  Options.consumableList = list
  function Options.RefreshConsumables()
    Options.consumableRows = {}
    Options.consumableHeaders = {}
    list:SetItems(consumableItems())
  end
  Options.RefreshConsumables()
end
