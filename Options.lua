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
