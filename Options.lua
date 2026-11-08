local ADDON, FB = ...
FB.Options = FB.Options or {}
local Options = FB.Options
local UI = FB.UI

-------------------------------------------------------------------------------
-- Standalone options window: /fbuffs, the addon compartment, ESC closes.
-------------------------------------------------------------------------------

Options.TAB_NAMES = { "Display", "Alerts", "Buffs", "Consumables", "Position", "About" }
Options.WIDTH, Options.HEIGHT = 800, 500
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
local function mmss(v)
  v = math.floor(v + 0.5)
  if v >= 60 then
    local m, sec = math.floor(v / 60), v % 60
    if sec == 0 then return string.format("%d min", m) end
    return string.format("%d:%02d", m, sec)
  end
  return v .. " s"
end

local function buildDisplay(panel)
  local put = stacker(panel)
  put(register("look", UI.Dropdown(panel, "Look", choices({
    { value = "icons", text = "Icons" },
    { value = "names_beside", text = "Icons with names beside" },
    { value = "names_below", text = "Icons with names below" },
  }), dbGet("look", "icons"), dbSet("look"), 270)))
  put(register("visibility", UI.Dropdown(panel, "Show icons", choices({
    { value = "always", text = "Always (dim when buffed)" },
    { value = "missing", text = "Only when missing" },
    { value = "expiring", text = "When missing or running out" },
  }), dbGet("visibility", "always"), dbSet("visibility"), 270)))
  put(register("iconSize", UI.Slider(panel, "Icon size", 20, 80, 2, dbGet("iconSize", 40), dbSet("iconSize"), px)))
  put(register("spacing", UI.Slider(panel, "Spacing", 0, 20, 1, dbGet("spacing", 6), dbSet("spacing"), px)))
  put(register("direction", UI.Dropdown(panel, "Grow direction", choices({
    { value = "RIGHT", text = "Right" }, { value = "LEFT", text = "Left" }, { value = "DOWN", text = "Down" }, { value = "UP", text = "Up" },
  }), dbGet("direction", "RIGHT"), dbSet("direction"), 270)))
  put(register("perRow", UI.Slider(panel, "Icons per row", 1, 20, 1, dbGet("perRow", 8), dbSet("perRow"), plain)))

  put(register("expireLongSeconds", UI.Slider(panel, "Long buffs: show when this much is left", 60, 900, 30,
    dbGet("expireLongSeconds", 300), dbSet("expireLongSeconds"), mmss)), 2)
  put(register("expireShortSeconds", UI.Slider(panel, "Short buffs: show when this much is left", 10, 300, 10,
    dbGet("expireShortSeconds", 60), dbSet("expireShortSeconds"), mmss)), 2)
  put(register("longBuffSeconds", UI.Slider(panel, "A buff counts as long from", 300, 3600, 60,
    dbGet("longBuffSeconds", 900), dbSet("longBuffSeconds"), mmss)), 2)
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

local REPEAT_CHOICES = {
  { value = 0, text = "Off (once)" }, { value = 15, text = "Every 15 s" }, { value = 30, text = "Every 30 s" },
  { value = 60, text = "Every minute" }, { value = 120, text = "Every 2 min" }, { value = 300, text = "Every 5 min" },
}
local PRIORITY_LABEL = { high = "High", normal = "Normal", low = "Low" }

local function alertGet(prio, field, default)
  return function()
    local c = FB.db and FB.db.alert and FB.db.alert[prio]
    local v = c and c[field]
    if v == nil then return default end
    return v
  end
end
local function alertSet(prio, field)
  return function(v)
    FB.db.alert = FB.db.alert or {}
    FB.db.alert[prio] = FB.db.alert[prio] or {}
    FB.db.alert[prio][field] = v
    changed()
  end
end

local function alertBlock(panel, put, col, prio)
  local d = FB.Core.DEFAULTS.alert[prio]
  local h = UI.SectionHeader(panel, PRIORITY_LABEL[prio] .. " priority"); h:SetHeight(16)
  put(h, col, 4)
  local snd = put(register("sound_" .. prio, UI.Dropdown(panel, "Sound", soundChoices, alertGet(prio, "sound", d.sound), alertSet(prio, "sound"), 190)), col)
  local play = register("play_" .. prio, UI.Button(panel, "Play", function() FB.Alerts.Play(alertGet(prio, "sound", d.sound)()) end, 56))
  play:SetPoint("BOTTOMLEFT", snd, "BOTTOMRIGHT", 6, 0)
  put(register("repeat_" .. prio, UI.Dropdown(panel, "Repeat while missing", choices(REPEAT_CHOICES),
    alertGet(prio, "repeat", d["repeat"]), alertSet(prio, "repeat"), 190)), col)
  put(register("text_" .. prio, UI.Checkbox(panel, "Raid-warning text on screen", alertGet(prio, "text", d.text), alertSet(prio, "text"))), col, 2)
  local fl = put(register("flash_" .. prio, UI.Checkbox(panel, "Flash the icon", alertGet(prio, "flash", d.flash), alertSet(prio, "flash"))), col, 2)
  local test = register("test_" .. prio, UI.Button(panel, "Test", function()
    FB.Alerts.Deliver({ sounds = { alertGet(prio, "sound", d.sound)() },
      texts = { { text = "ForeverBuffs: test alert (" .. PRIORITY_LABEL[prio] .. ")", priority = prio } } })
  end, 56))
  test:SetPoint("LEFT", fl.label, "RIGHT", 12, 0)
end

local function buildAlerts(panel)
  local put = stacker(panel)
  alertBlock(panel, put, 1, "high")
  alertBlock(panel, put, 1, "normal")
  alertBlock(panel, put, 2, "low")
  local note = UI.SectionHeader(panel, "")
  note:SetText("A buff only makes noise if its Sound tick is on (Buffs and Consumables tabs). Repeats and alerts never play in combat.")
  note:SetWidth(270); note:SetJustifyH("LEFT"); note:SetWordWrap(true); note:SetHeight(42)
  put(note, 2)
  put(register("alertOnExpiring", UI.Checkbox(panel, "Alert once when a buff is running out",
    dbGet("alertOnExpiring", true), dbSet("alertOnExpiring"))), 2)
  put(register("combat", UI.Dropdown(panel, "In combat", choices({
    { value = "freeze", text = "Freeze (keep last state)" }, { value = "hide", text = "Hide" },
  }), dbGet("combat", "freeze"), dbSet("combat"), 270)), 2)
  put(register("hideMounted", UI.Checkbox(panel, "Hide while mounted", dbGet("hideMounted", true), dbSet("hideMounted"))), 2, 2)
  put(register("hideResting", UI.Checkbox(panel, "Hide while resting (inns, cities)", dbGet("hideResting", false), dbSet("hideResting"))), 2, 2)
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
  put(register("snapToGrid", UI.Checkbox(panel, "Snap to grid when moving", dbGet("snapToGrid", true), dbSet("snapToGrid"))), 1, 2)
  put(register("showGridWhileUnlocked", UI.Checkbox(panel, "Show the grid while unlocked", dbGet("showGridWhileUnlocked", true),
    dbSet("showGridWhileUnlocked", function(v)
      if FB.Core and FB.Core.unlocked then if v then FB.Display.ShowGrid(FB.db.gridSize) else FB.Display.HideGrid() end end
    end))), 1, 2)
  put(register("gridSize", UI.Slider(panel, "Grid size", 4, 64, 4, dbGet("gridSize", 16),
    dbSet("gridSize", function(v)
      if FB.Core and FB.Core.unlocked and FB.db.showGridWhileUnlocked ~= false then FB.Display.ShowGrid(v) end
    end), px)))
  local info = UI.SectionHeader(panel, "")
  info:SetWidth(270); info:SetJustifyH("LEFT"); info:SetWordWrap(true)
  info.Refresh = function()
    local p = FB.db and FB.db.position or {}
    info:SetText(string.format("Anchor: %s  x %d  y %d", tostring(p.point or "CENTER"), p.x or 0, p.y or 0))
  end
  info.Refresh()
  register("anchorInfo", info)
  put(info, 2)
  FB.Display.onPositionSaved = function() info.Refresh() end
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
-- Shared helpers for the Buffs and Consumables lists
-------------------------------------------------------------------------------
local PRIORITY_TEXT = { high = "High", normal = "Normal", low = "Low" }
local VISIBILITY_TEXT = { always = "Always", missing = "When missing", expiring = "Running out" }

local function playerClass() return FB.API.PlayerClass() end
local function playerLevel() return FB.API.PlayerLevel() end

local function state() return FB.Core and FB.Core.state end

local function shows(key)
  local s = state(); if s then return s:Shows(key) end
  return true
end
local function sounds(key)
  local s = state(); if s then return s:Sounds(key) end
  return false
end

local function knowsEntry(entry)
  for _, id in ipairs(entry.castIDs or {}) do if FB.API.KnowsSpell(id) then return true end end
  return false
end

-- The priority an entry gets when nothing is set: own class or known → normal,
-- other classes → low, consumables → low.
local function defaultPriority(entry)
  local reason
  if entry.consumable then reason = "consumable"
  elseif knowsEntry(entry) or entry.class == playerClass() then reason = "known"
  else reason = "group" end
  return FB.Data.DefaultPriority(reason)
end

local function singleLine(fs, height)
  fs:SetWordWrap(false)
  fs:SetMaxLines(1)
  fs:SetHeight(height)
end

local function muted(fs) fs:SetTextColor(UI.COLORS.muted[1], UI.COLORS.muted[2], UI.COLORS.muted[3], 1) end

local function checkButton(parent, onClick)
  local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  b:SetSize(22, 22)
  b:SetScript("OnClick", onClick)
  return b
end

-- Priority dropdown for a set of keys (first key is read).
local function priorityDropdown(parent, keysFn, entryFn, onChange)
  return UI.Dropdown(parent, nil, function()
    local entry = entryFn()
    local d = entry and PRIORITY_TEXT[defaultPriority(entry)] or "?"
    return { { value = "default", text = "Default (" .. d .. ")" }, { value = "high", text = "High" },
             { value = "normal", text = "Normal" }, { value = "low", text = "Low" } }
  end, function()
    local keys = keysFn(); local k = keys and keys[1]
    return k and FB.cdb.priority[k] or "default"
  end, function(v)
    for _, k in ipairs(keysFn() or {}) do
      if v == "default" then FB.cdb.priority[k] = nil else FB.cdb.priority[k] = v end
    end
    changed()
    if onChange then onChange() end
  end, 100)
end

local function visibilityDropdown(parent, keysFn, onChange)
  return UI.Dropdown(parent, nil, function()
    local g = VISIBILITY_TEXT[FB.db and FB.db.visibility or "always"] or "Always"
    return { { value = "default", text = "Default (" .. g .. ")" }, { value = "always", text = "Always" },
             { value = "missing", text = "When missing" }, { value = "expiring", text = "Running out" } }
  end, function()
    local keys = keysFn(); local k = keys and keys[1]
    return k and FB.cdb.visibility[k] or "default"
  end, function(v)
    for _, k in ipairs(keysFn() or {}) do
      if v == "default" then FB.cdb.visibility[k] = nil else FB.cdb.visibility[k] = v end
    end
    changed()
    if onChange then onChange() end
  end, 120)
end

-- Ticking Sound on an entry whose priority channel has neither a sound nor
-- screen text would do nothing; say so instead of failing silently.
local function warnIfSilent(key)
  local entry = FB.Data.byKey[key]; if not entry then return end
  local prio = (FB.cdb.priority and FB.cdb.priority[key]) or defaultPriority(entry)
  local c = FB.db.alert and FB.db.alert[prio] or {}
  if (c.sound == nil or c.sound == "none") and not c.text then
    print("|cff33ff99ForeverBuffs|r: " .. (PRIORITY_TEXT[prio] or prio) .. " priority has no sound or screen text set."
      .. " Pick one on the Alerts tab, or give this buff a higher priority.")
  end
end

local function setShows(keys, value)
  for _, k in ipairs(keys) do FB.cdb.show[k] = value end
  changed()
end
local function setSounds(keys, value)
  for _, k in ipairs(keys) do FB.cdb.sound[k] = value end
  changed()
  if value and keys[1] then warnIfSilent(keys[1]) end
end

-------------------------------------------------------------------------------
-- Buffs tab
-------------------------------------------------------------------------------
local function entryName(entry)
  local s = state()
  if s then return s:DisplayName(entry.key) end
  local id = entry.iconSpells and entry.iconSpells[#entry.iconSpells]
  return (id and FB.API.SpellName(id)) or entry.name
end

local function entryIcon(entry)
  local id = entry.iconSpells and entry.iconSpells[#entry.iconSpells]
  local s = state(); if s then id = s:IconSpell(entry.key) or id end
  return (id and FB.API.SpellIcon(id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function rankText(entry)
  local info = FB.Data.RankInfo(entry, FB.API.KnowsSpell, playerLevel())
  if entry.class ~= playerClass() then
    if not info then return "" end
    if info.minLevel == info.maxLevel then return string.format("%d rank (%d)", info.total, info.minLevel) end
    return string.format("%d ranks (%d-%d)", info.total, info.minLevel, info.maxLevel)
  end
  if not info then
    if not knowsEntry(entry) and playerLevel() < (entry.learnLevel or 1) then return "learned at " .. entry.learnLevel end
    return ""
  end
  if info.known == 0 then
    if playerLevel() < (info.minLevel or entry.learnLevel or 1) then return "learned at " .. (info.minLevel or entry.learnLevel) end
    return "|cff55ff55not learned, available!|r"
  end
  local text = string.format("Rank %d/%d", info.known, info.total)
  if info.available then return text .. "  |cff55ff55rank available!|r" end
  if info.nextLevel then return text .. "  next at " .. info.nextLevel end
  return text
end

local function rankTooltip(owner, entry)
  if not entry or not entry.ranks then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(entryName(entry))
  local level = playerLevel()
  for _, ladder in ipairs(entry.ranks) do
    GameTooltip:AddLine(ladder.family, 1, 0.82, 0)
    for _, sp in ipairs(ladder.spells) do
      local known = FB.API.KnowsSpell(sp.id)
      local mark = known and "  (known)" or ((sp.level <= level) and "  (available)" or "")
      local r, g, b = 0.8, 0.8, 0.8
      if known then r, g, b = 0.5, 1, 0.5 elseif sp.level <= level then r, g, b = 1, 1, 0.4 end
      GameTooltip:AddLine(string.format("Rank %d: level %d%s", sp.rank, sp.level, mark), r, g, b)
    end
  end
  GameTooltip:Show()
end

local function buildBuffRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row.header = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.header:SetPoint("LEFT", row, "LEFT", 0, 0)
  muted(row.header)
  row.show = checkButton(row, function(self)
    if not row.key then return end
    local nv = not shows(row.key); setShows({ row.key }, nv); self:SetChecked(nv)
  end)
  row.show:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.sound = checkButton(row, function(self)
    if not row.key then return end
    local nv = not sounds(row.key); setSounds({ row.key }, nv); self:SetChecked(nv)
  end)
  row.sound:SetPoint("LEFT", row.show, "RIGHT", 2, 0)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(20, 20)
  row.icon:SetPoint("LEFT", row.sound, "RIGHT", 4, 0)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetWidth(150); row.name:SetJustifyH("LEFT"); singleLine(row.name, 28)
  row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.rank:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
  row.rank:SetWidth(150); row.rank:SetJustifyH("LEFT"); singleLine(row.rank, 28)
  muted(row.rank)
  row.rankHover = CreateFrame("Frame", nil, row)
  row.rankHover:SetAllPoints(row.rank)
  row.rankHover:EnableMouse(true)
  row.rankHover:SetScript("OnEnter", function(self) rankTooltip(self, row.entry) end)
  row.rankHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row.priority = priorityDropdown(row, function() return row.key and { row.key } end, function() return row.entry end,
    function() if Options.RefreshBuffs then Options.RefreshBuffs() end end)
  row.priority:SetPoint("LEFT", row.rank, "RIGHT", 4, 0)
  row.visibility = visibilityDropdown(row, function() return row.key and { row.key } end)
  row.visibility:SetPoint("LEFT", row.priority, "RIGHT", 6, 0)
  return row
end

local BUFF_WIDGETS = { "show", "sound", "icon", "name", "rank", "rankHover", "priority", "visibility" }

local function fillBuffRow(row, item)
  if item.kind == "header" then
    row.entry, row.key = nil, nil
    row.header:SetText(string.upper(item.text)); row.header:Show()
    for _, w in ipairs(BUFF_WIDGETS) do row[w]:Hide() end
    return
  end
  local entry = FB.Data.byKey[item.key]
  row.entry, row.key = entry, item.key
  row.header:Hide()
  for _, w in ipairs(BUFF_WIDGETS) do row[w]:Show() end
  row.show:SetChecked(shows(item.key))
  row.sound:SetChecked(sounds(item.key))
  row.icon:SetTexture(entryIcon(entry))
  row.name:SetText(entryName(entry))
  local notLearned = entry.class == playerClass() and not knowsEntry(entry) and playerLevel() < (entry.learnLevel or 1)
  if notLearned then row.name:SetTextColor(0.6, 0.6, 0.6, 1) else row.name:SetTextColor(1, 1, 1, 1) end
  row.rank:SetText(rankText(entry))
  row.priority.Refresh()
  row.visibility.Refresh()
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
  hint:SetText("Show = icon in the bar.  Sound = alerts, repeats and screen text.  Priority sets size and which alert settings apply.  Hover a rank for every rank and its level.")
  hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0); hint:SetWidth(620); hint:SetJustifyH("LEFT"); hint:SetWordWrap(true); hint:SetHeight(28)
  local cols = { { "Show", 0 }, { "Sound", 22 }, { "Buff", 76 }, { "Rank", 232 }, { "Priority", 388 }, { "Visible", 494 } }
  for _, c in ipairs(cols) do
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", panel, "TOPLEFT", c[2], -30); fs:SetText(c[1]); muted(fs)
  end
  local list = UI.ScrollList(panel, 28, buildBuffRow, fillBuffRow, { virtual = false })
  list:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -46)
  list:SetSize(Options.WIDTH - Options.TABS_WIDTH - 30, Options.HEIGHT - 44 - 12 - 46)
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
local WHERE_CHOICES = {
  { value = "everywhere", text = "Everywhere" }, { value = "instances", text = "Dungeons and raids" },
  { value = "raids", text = "Raids only" }, { value = "never", text = "Never" },
}

Options.filterText = ""
Options.collapsed = Options.collapsed or { elixir = false, flask = false, well_fed = true, weapon = true }

local function categoryVisible(cat)
  local entry = FB.Data.byKey[CATEGORY_MAIN_KEY[cat]]
  return not (entry.excludeClasses and entry.excludeClasses[playerClass()])
end

local function pureRecommendation(cat)
  local s = state()
  if not s then return nil end
  return FB.Data.Recommend(CATEGORY_MAIN_KEY[cat], s.env.playerClass(), s:Role(), s.env.playerLevel(), s.env.weaponKind())
end

local function sourceShort(src)
  if not src then return "Unknown" end
  if src.kind == "crafted" then
    if src.profession and src.skill then return src.profession .. " " .. src.skill end
    return src.profession or "Crafted"
  end
  return (src.kind:gsub("^%l", string.upper))
end

local function itemTooltip(owner, r)
  if not r then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(FB.API.ItemName(r.itemID) or r.name)
  GameTooltip:AddLine(r.summary or "", 1, 1, 1, true)
  GameTooltip:AddLine("Requires level " .. tostring(r.level), 0.8, 0.8, 0.8)
  local src = r.source
  if not src then
    GameTooltip:AddLine("Source: unknown", 0.7, 0.7, 0.7)
  elseif src.kind == "crafted" then
    GameTooltip:AddLine("Crafted: " .. sourceShort(src) .. (src.skill and "" or " (trainer recipe)"), 1, 0.82, 0)
    for _, reg in ipairs(src.reagents or {}) do
      GameTooltip:AddLine(string.format("  %dx %s", reg.count, FB.API.ItemName(reg.itemID) or reg.name), 0.9, 0.9, 0.9)
    end
  else
    GameTooltip:AddLine("Source: " .. sourceShort(src), 1, 0.82, 0)
    if src.note then GameTooltip:AddLine(src.note, 0.8, 0.8, 0.8, true) end
  end
  if r.resolvedSpell then GameTooltip:AddLine("Buff spell " .. r.resolvedSpell, 0.5, 0.5, 0.5) end
  GameTooltip:Show()
end

local function buildConsumableRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:EnableMouse(true)
  row:SetScript("OnEnter", function(self) if row.item then itemTooltip(self, row.item) end end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local function keys() return row.category and CATEGORY_KEYS[row.category] end
  -- header widgets
  row.toggle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.toggle:SetSize(20, 20)
  row.toggle:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.toggle:SetScript("OnClick", function()
    local cat = row.category; if not cat then return end
    Options.collapsed[cat] = not Options.collapsed[cat]
    if Options.RefreshConsumables then Options.RefreshConsumables() end
  end)
  row.show = checkButton(row, function(self)
    local k = keys(); if not k then return end
    local nv = not shows(k[1]); setShows(k, nv); self:SetChecked(nv)
  end)
  row.show:SetPoint("LEFT", row.toggle, "RIGHT", 4, 0)
  row.sound = checkButton(row, function(self)
    local k = keys(); if not k then return end
    local nv = not sounds(k[1]); setSounds(k, nv); self:SetChecked(nv)
  end)
  row.sound:SetPoint("LEFT", row.show, "RIGHT", 2, 0)
  row.header = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.header:SetPoint("LEFT", row.sound, "RIGHT", 6, 0)
  row.header:SetWidth(130); row.header:SetJustifyH("LEFT")
  row.whereDropdown = UI.Dropdown(row, nil, choices(WHERE_CHOICES), function()
    local cat = row.category; if not cat then return "instances" end
    return FB.State.ScopeOf(FB.Data, FB.cdb or {}, CATEGORY_MAIN_KEY[cat])
  end, function(v)
    local cat = row.category; if not cat then return end
    FB.cdb.consumableWhere[cat] = v
    changed()
  end, 140)
  row.whereDropdown:SetPoint("LEFT", row.header, "RIGHT", 4, 0)
  row.priority = priorityDropdown(row, keys, function() return row.category and FB.Data.byKey[CATEGORY_MAIN_KEY[row.category]] end)
  row.priority:SetPoint("LEFT", row.whereDropdown, "RIGHT", 6, 0)
  row.visibility = visibilityDropdown(row, keys)
  row.visibility:SetPoint("LEFT", row.priority, "RIGHT", 6, 0)
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
  row.radio:SetPoint("LEFT", row, "LEFT", 26, 0)
  row.radio:SetScript("OnClick", function()
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
  row.name:SetWidth(200); row.name:SetJustifyH("LEFT"); singleLine(row.name, 24)
  row.where = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.where:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
  row.where:SetWidth(100); row.where:SetJustifyH("LEFT"); singleLine(row.where, 24)
  row.summary = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.summary:SetPoint("LEFT", row.where, "RIGHT", 6, 0)
  row.summary:SetWidth(170); row.summary:SetJustifyH("LEFT"); singleLine(row.summary, 24)
  muted(row.summary)
  row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.tag:SetPoint("RIGHT", row, "RIGHT", -8, 0)
  singleLine(row.tag, 24)
  return row
end

local ROW_WIDGETS = { "toggle", "show", "sound", "header", "whereDropdown", "priority", "visibility",
                      "useRecommendation", "radio", "icon", "name", "where", "summary", "tag" }
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
  local cat = item.category
  Options.consumableHeaders[cat] = Options.consumableHeaders[cat] or {}
  local h = Options.consumableHeaders[cat]
  if item.kind == "header" then
    showOnly(row, "toggle", "show", "sound", "header", "whereDropdown", "priority", "visibility")
    local main = CATEGORY_MAIN_KEY[cat]
    row.toggle:SetText(Options.collapsed[cat] and "+" or "-")
    row.show:SetChecked(shows(main))
    row.sound:SetChecked(sounds(main))
    row.header:SetText(CATEGORY_LABEL[cat])
    row.whereDropdown.Refresh(); row.priority.Refresh(); row.visibility.Refresh()
    h.toggle, h.show, h.sound, h.where, h.priority, h.visibility, h.row =
      row.toggle, row.show, row.sound, row.whereDropdown, row.priority, row.visibility, row
  elseif item.kind == "use" then
    showOnly(row, "useRecommendation")
    h.useRecommendation = row.useRecommendation
  else
    showOnly(row, "radio", "icon", "name", "where", "summary", "tag")
    local r = item.row
    row.item = r
    local pick = FB.cdb.pick[cat]
    local rec = item.recommended
    row.radio:SetChecked(pick == r.itemID)
    row.icon:SetTexture(FB.API.ItemIcon(r.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.name:SetText(string.format("%s  |cff8b93a5lvl %d|r", FB.API.ItemName(r.itemID) or r.name, r.level))
    row.where:SetText(sourceShort(r.source))
    row.summary:SetText(r.summary or "")
    if pick == r.itemID then
      row.tag:SetText("your pick"); row.tag:SetTextColor(1, 0.9, 0.5, 1)
    elseif rec and rec.itemID == r.itemID then
      row.tag:SetText("recommended"); row.tag:SetTextColor(0.56, 0.82, 0.56, 1)
    else
      row.tag:SetText("")
    end
    local shade = (r.level > playerLevel()) and 0.55 or 1
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
      local open = not Options.collapsed[cat] or filter ~= ""
      if open then
        items[#items + 1] = { kind = "use", category = cat }
        local rec = pureRecommendation(cat)
        for _, r in ipairs(FB.Data.CATALOGUE[cat]) do
          if filter == "" or string.find(string.lower(r.name), filter, 1, true) then
            items[#items + 1] = { kind = "item", category = cat, row = r, recommended = rec }
          end
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
  local remind = register("consumablesRemindDrop", UI.Checkbox(panel, "Remind anywhere once one wears off",
    cdbGet("consumablesRemindDrop", true), cdbSet("consumablesRemindDrop")))
  remind:SetPoint("BOTTOMLEFT", role, "BOTTOMRIGHT", 12, 0)
  local filter = register("filter", UI.EditBox(panel, "", 160, true, function(text)
    Options.filterText = text or ""
    if Options.RefreshConsumables then Options.RefreshConsumables() end
  end))
  filter:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -18)
  local filterLabel = UI.SectionHeader(panel, "Filter")
  filterLabel:SetPoint("BOTTOMLEFT", filter, "TOPLEFT", 0, 2)

  local list = UI.ScrollList(panel, 26, buildConsumableRow, fillConsumableRow, { virtual = false })
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
