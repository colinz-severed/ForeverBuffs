local ADDON, FB = ...
FB.Options = FB.Options or {}
local Options = FB.Options

-------------------------------------------------------------------------------
-- Native Blizzard settings panel (Settings API, no libraries).
-------------------------------------------------------------------------------

Options.settings = {}
Options.buffSettings = {}
Options.buffKeys = {}

local function refresh()
  if FB.Core and FB.Core.Refresh then FB.Core.Refresh() end
  if FB.Core and FB.Core.Render then FB.Core.Render() end
end

local function hasSettingsAPI()
  return type(Settings) == "table"
    and type(Settings.RegisterVerticalLayoutCategory) == "function"
    and type(Settings.RegisterAddOnCategory) == "function"
    and type(Settings.RegisterProxySetting) == "function"
    and type(Settings.CreateCheckbox) == "function"
    and type(Settings.CreateSlider) == "function"
    and type(Settings.CreateDropdown) == "function"
end

local function header(layout, text)
  if CreateSettingsListSectionHeaderInitializer then
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
  end
end

local function button(layout, name, buttonText, onClick, tooltip)
  if CreateSettingsButtonInitializer then
    layout:AddInitializer(CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, true))
  end
end

local function proxy(category, variable, varType, name, default, getter, setter)
  return Settings.RegisterProxySetting(category, "FB_" .. variable, varType, name, default, getter, setter)
end

local function dbSetting(category, key, varType, name, default)
  return proxy(category, key, varType, name, default,
    function() local v = FB.db[key]; if v == nil then return default end; return v end,
    function(v) FB.db[key] = v; refresh() end)
end

local function checkbox(category, key, name, tooltip)
  local s = dbSetting(category, key, Settings.VarType.Boolean, name, FB.Core.DEFAULTS[key])
  Settings.CreateCheckbox(category, s, tooltip)
  Options.settings[key] = s
  return s
end

local function slider(category, key, name, min, max, step, tooltip)
  local s = dbSetting(category, key, Settings.VarType.Number, name, FB.Core.DEFAULTS[key])
  local opts = Settings.CreateSliderOptions(min, max, step)
  if opts.SetLabelFormatter and MinimalSliderWithSteppersMixin then
    opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  end
  Settings.CreateSlider(category, s, opts, tooltip)
  Options.settings[key] = s
  return s
end

local function dropdown(category, key, name, choices, tooltip)
  local s = dbSetting(category, key, Settings.VarType.String, name, FB.Core.DEFAULTS[key])
  local function getOptions()
    local c = Settings.CreateControlTextContainer()
    for _, choice in ipairs(choices) do c:Add(choice[1], choice[2]) end
    return c:GetData()
  end
  Settings.CreateDropdown(category, s, getOptions, tooltip)
  Options.settings[key] = s
  return s
end

local function buffDefault(entry, class)
  local byClass = entry.defaultEnabledByClass and entry.defaultEnabledByClass[class]
  if byClass ~= nil then return byClass end
  return entry.defaultEnabled
end

local function buffDisplayName(entry)
  if entry.consumable then return entry.name end
  local id = entry.iconSpells and entry.iconSpells[#entry.iconSpells]
  return (id and FB.API.SpellName(id)) or entry.name
end

function Options.Build()
  if Options.category then return Options.category end
  if not hasSettingsAPI() then
    if not Options.warned then
      Options.warned = true
      print("|cff33ff99ForeverBuffs|r: options panel unavailable on this client, use /fbuffs commands")
    end
    return nil
  end

  local category, layout = Settings.RegisterVerticalLayoutCategory("ForeverBuffs")
  Options.category, Options.layout = category, layout
  local class = FB.API.PlayerClass()

  -- Display -----------------------------------------------------------------
  header(layout, "Display")
  dropdown(category, "style", "Display style", {
    { "row", "Plain row (missing only)" }, { "names", "Flashing with names (missing only)" }, { "grid", "Always-on grid (dims when buffed)" },
  }, "How missing buffs are shown.")
  slider(category, "iconSize", "Icon size", 20, 80, 2, "Size of each icon in pixels.")
  slider(category, "spacing", "Spacing", 0, 20, 1, "Gap between icons in pixels.")
  dropdown(category, "direction", "Grow direction", {
    { "RIGHT", "Right" }, { "LEFT", "Left" }, { "DOWN", "Down" }, { "UP", "Up" },
  }, "Direction the icons grow from the anchor.")
  slider(category, "perRow", "Icons per row", 1, 20, 1, "Wrap after this many icons.")
  checkbox(category, "showNames", "Show buff names", "Write the buff name under each icon (the names style always shows them beside the icon).")

  -- Alerts ------------------------------------------------------------------
  header(layout, "Alerts")
  dropdown(category, "alertStyle", "Alert style", {
    { "icon", "Icon only" }, { "flash", "Flash" }, { "sound", "Sound" }, { "both", "Flash + sound" },
  }, "Flash pulses missing icons. Sound plays once when a buff you had drops off.")
  local soundChoices = {}
  for _, s in ipairs(FB.Alerts.SOUNDS) do soundChoices[#soundChoices + 1] = { s.key, s.name } end
  dropdown(category, "sound", "Sound", soundChoices, "Which sound to play.")
  button(layout, "Test sound", "Play", function() FB.Alerts.Play(FB.db.sound) end, "Play the selected sound.")

  -- Visibility --------------------------------------------------------------
  header(layout, "Visibility")
  dropdown(category, "combat", "In combat", {
    { "freeze", "Freeze (keep last state)" }, { "hide", "Hide" },
  }, "Forever hides buff data from addons in combat, so the display cannot update until combat ends.")
  checkbox(category, "hideMounted", "Hide while mounted", nil)
  checkbox(category, "hideResting", "Hide while resting (inns, cities)", nil)

  -- Buffs -------------------------------------------------------------------
  header(layout, "Buffs")
  Options.buffKeys = {}
  Options.buffSettings = {}
  local groupKeys, consumableKeys = {}, {}
  for _, entry in ipairs(FB.Data.entries) do
    local include
    if entry.consumable then
      include = not (entry.excludeClasses and entry.excludeClasses[class])
      if include then consumableKeys[#consumableKeys + 1] = entry.key end
    elseif entry.class == class then
      include = true
    elseif not entry.selfOnly then
      include = true
      groupKeys[#groupKeys + 1] = entry.key
    end
    if include and not entry.consumable and entry.class == class then
      Options.buffKeys[#Options.buffKeys + 1] = entry.key
    end
  end
  for _, key in ipairs(groupKeys) do
    local dup = false
    for _, k in ipairs(Options.buffKeys) do if k == key then dup = true end end
    if not dup then Options.buffKeys[#Options.buffKeys + 1] = key end
  end
  for _, key in ipairs(consumableKeys) do Options.buffKeys[#Options.buffKeys + 1] = key end

  local function addBuffCheckbox(key)
    local entry = FB.Data.byKey[key]
    local default = buffDefault(entry, class)
    local label = buffDisplayName(entry)
    if entry.class and entry.class ~= class then label = label .. " (from group)" end
    local s = proxy(category, "buff_" .. key, Settings.VarType.Boolean, label, default,
      function() local v = FB.cdb.enabled[key]; if v == nil then return default end; return v end,
      function(v) FB.cdb.enabled[key] = v; refresh() end)
    Settings.CreateCheckbox(category, s, entry.consumable and "Consumable reminder." or "Track this buff.")
    Options.buffSettings[key] = s
  end
  for _, key in ipairs(Options.buffKeys) do
    if not FB.Data.byKey[key].consumable then addBuffCheckbox(key) end
  end

  -- Consumables -------------------------------------------------------------
  header(layout, "Consumables")
  local roleDefault = FB.Data.DefaultRole(class)
  Options.roleSetting = proxy(category, "role", Settings.VarType.String, "Role", roleDefault,
    function() return FB.cdb.role or roleDefault end,
    function(v) FB.cdb.role = v; refresh() end)
  Settings.CreateDropdown(category, Options.roleSetting, function()
    local c = Settings.CreateControlTextContainer()
    for _, r in ipairs(FB.Data.ROLES) do c:Add(r, r) end
    return c:GetData()
  end, "Picks which elixir, flask, food and weapon oil or stone get recommended.")
  for _, key in ipairs(consumableKeys) do addBuffCheckbox(key) end
  local raidsOnly = proxy(category, "consumablesRaidsOnly", Settings.VarType.Boolean, "Raids only", true,
    function() local v = FB.cdb.consumablesRaidsOnly; if v == nil then return true end; return v end,
    function(v) FB.cdb.consumablesRaidsOnly = v; refresh() end)
  Settings.CreateCheckbox(category, raidsOnly, "Only remind about consumables inside raid instances.")
  Options.settings.consumablesRaidsOnly = raidsOnly
  local remindDrop = proxy(category, "consumablesRemindDrop", Settings.VarType.Boolean, "Remind when it wears off", true,
    function() local v = FB.cdb.consumablesRemindDrop; if v == nil then return true end; return v end,
    function(v) FB.cdb.consumablesRemindDrop = v; refresh() end)
  Settings.CreateCheckbox(category, remindDrop, "Anywhere: once you have used a consumable this session, remind you when it drops.")
  Options.settings.consumablesRemindDrop = remindDrop

  -- Position ----------------------------------------------------------------
  header(layout, "Position")
  button(layout, "Move the display", "Unlock / Lock", function()
    FB.Core.Slash(FB.Core.unlocked and "lock" or "unlock")
  end, "Unlock to drag the icons anywhere, then lock.")
  button(layout, "Reset position", "Reset", function() FB.Core.Slash("reset") end, "Put the display back in the default spot.")
  button(layout, "Test mode", "Toggle", function() FB.Core.Slash("test") end, "Show every tracked buff as missing.")

  Settings.RegisterAddOnCategory(category)
  return category
end

function Options.Open()
  if not Options.category then Options.Build() end
  if Options.category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(Options.category:GetID())
  end
end
