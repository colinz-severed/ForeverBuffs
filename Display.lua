local ADDON, FB = ...
FB.Display = FB.Display or {}
local Display = FB.Display

-------------------------------------------------------------------------------
-- Icon display: three styles, drag to move, test mode, stale badge, tooltips.
-------------------------------------------------------------------------------

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PRESENT_ALPHA = 0.35
local BORDER_COLOR = { 0.8, 0.15, 0.15, 1 }
local UNLOCK_TEXT = "ForeverBuffs - drag to move, /fbuffs lock to lock"

Display.icons = {}
Display.unlocked = false

-------------------------------------------------------------------------------
-- Layout (pure)
-------------------------------------------------------------------------------
-- sizes: array of per-icon pixel sizes. Icons advance by their own size plus
-- spacing; lines (rows for RIGHT/LEFT, columns for DOWN/UP) wrap after perRow
-- and are pitched by the largest icon in the line. Horizontal lines align
-- bottom edges; vertical lines align left edges. Offsets are from TOPLEFT.
function Display.LayoutPositions(sizes, spacing, direction, perRow)
  local out = {}
  perRow = math.max(1, perRow or 8)
  local horizontal = direction ~= "DOWN" and direction ~= "UP"
  local count = #sizes
  local lineOffset = 0          -- cumulative pitch of previous lines
  local i = 1
  while i <= count do
    local last = math.min(i + perRow - 1, count)
    local lineMax = 0
    for j = i, last do lineMax = math.max(lineMax, sizes[j]) end
    local along = 0
    for j = i, last do
      local size = sizes[j]
      local x, y
      if horizontal then
        local baseline = -lineOffset - (lineMax - size)   -- bottom edges level
        x = (direction == "LEFT") and -along or along
        y = baseline
      else
        x = lineOffset
        y = (direction == "UP") and along or -along
      end
      out[j] = { x = x, y = y }
      along = along + size + spacing
    end
    lineOffset = lineOffset + lineMax + spacing
    i = last + 1
  end
  return out
end

local SCALE_BY_PRIORITY = { high = "highScale", low = "lowScale" }
function Display.IconSize(settings, priority)
  local base = settings.iconSize or 40
  local field = SCALE_BY_PRIORITY[priority]
  local scale = field and settings[field] or 1
  if field == "highScale" and not settings.highScale then scale = 1.15 end
  if field == "lowScale" and not settings.lowScale then scale = 0.7 end
  return math.floor(base * scale + 0.5)
end

local BORDER_HIGH = { 0.85, 0.65, 0.13, 1 }
local BORDER_EXPIRING = { 1, 0.6, 0.1, 1 }
local function applyBorder(icon, priority, status)
  local inset = (priority == "low") and 1 or 2
  local c = (priority == "high") and BORDER_HIGH or BORDER_COLOR
  if status == "expiring" then c = BORDER_EXPIRING end
  icon.border:SetColorTexture(c[1], c[2], c[3], c[4])
  icon.border:ClearAllPoints()
  icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -inset, inset)
  icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", inset, -inset)
  icon.borderInset = inset
end

-------------------------------------------------------------------------------
-- Frames
-------------------------------------------------------------------------------

local function entryDisplayName(state, key)
  local entry = FB.Data.byKey[key]
  if not entry then return key end
  if entry.consumable then return entry.name end
  return FB.API.SpellName(state:IconSpell(key)) or entry.name
end

local function onIconEnter(icon)
  local state = Display.state
  if not state or not icon.key then return end
  local key = icon.key
  local entry = FB.Data.byKey[key]
  GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
  GameTooltip:SetText(entryDisplayName(state, key))
  local tracked = state.tracked and state.tracked[key]
  if tracked and tracked.reason == "group" and Display.casters and Display.casters[key] and #Display.casters[key] > 0 then
    GameTooltip:AddLine("Can be cast by: " .. table.concat(Display.casters[key], ", "), 1, 1, 1, true)
  end
  if entry and entry.consumable then
    local rec = state.Recommendation and state:Recommendation(key)
    if rec and rec.picked then
      GameTooltip:AddLine("Your pick: " .. (FB.API.ItemName(rec.itemID) or rec.name), 1, 0.9, 0.5, true)
    elseif rec then
      GameTooltip:AddLine("Recommended: " .. (FB.API.ItemName(rec.itemID) or rec.name), 0.6, 1, 0.6, true)
    else
      GameTooltip:AddLine("No recommendation at your level", 0.7, 0.7, 0.7, true)
    end
  end
  GameTooltip:Show()
end

local function onIconLeave() GameTooltip:Hide() end

local function createIcon(index)
  local anchor = Display.anchor
  local icon = CreateFrame("Button", "ForeverBuffsIcon" .. index, anchor)
  icon:EnableMouse(true)
  icon:SetScript("OnEnter", onIconEnter)
  icon:SetScript("OnLeave", onIconLeave)
  -- Icons cover most of the unlocked area, so they forward drags to the anchor.
  icon:RegisterForDrag("LeftButton")
  icon:SetScript("OnDragStart", function()
    if Display.unlocked and Display.anchor then Display.anchor:StartMoving() end
  end)
  icon:SetScript("OnDragStop", function()
    if not Display.anchor then return end
    Display.anchor:StopMovingOrSizing()
    if Display.onMoved then Display.onMoved() end
  end)

  icon.border = icon:CreateTexture(nil, "BACKGROUND")
  icon.border:SetColorTexture(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
  icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
  icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)

  icon.tex = icon:CreateTexture(nil, "ARTWORK")
  icon.tex:SetAllPoints(icon)
  icon.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  icon.label = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  icon.label:Hide()

  icon.timer = icon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  icon.timer:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
  icon.timer:Hide()

  icon.pulse = icon:CreateAnimationGroup()
  icon.pulse:SetLooping("BOUNCE")
  local alpha = icon.pulse:CreateAnimation("Alpha")
  alpha:SetFromAlpha(1)
  alpha:SetToAlpha(0.4)
  alpha:SetDuration(0.55)
  alpha:SetOrder(1)

  return icon
end

function Display.Invalidate() Display.lastSignature = nil end

function Display.Init(settings)
  Display.Invalidate()
  if Display.anchor then
    Display.ApplyPosition(settings.position)
    return Display.anchor
  end
  local anchor = CreateFrame("Frame", "ForeverBuffsAnchor", UIParent)
  Display.anchor = anchor
  anchor:SetFrameStrata("MEDIUM")
  anchor:SetSize(settings.iconSize or 40, settings.iconSize or 40)
  anchor:SetMovable(true)
  anchor:SetClampedToScreen(true)
  anchor:EnableMouse(false)
  anchor:RegisterForDrag("LeftButton")
  anchor:SetScript("OnDragStart", function(self)
    if Display.unlocked then self:StartMoving() end
  end)
  anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if Display.onMoved then Display.onMoved() end
  end)

  Display.backdrop = anchor:CreateTexture(nil, "BACKGROUND")
  Display.backdrop:SetColorTexture(0, 0, 0, 0.4)
  Display.backdrop:SetPoint("TOPLEFT", anchor, "TOPLEFT", -6, 6)
  Display.backdrop:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 6, -6)
  Display.backdrop:Hide()

  Display.unlockLabel = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  Display.unlockLabel:SetPoint("BOTTOM", anchor, "TOP", 0, 10)
  Display.unlockLabel:SetText(UNLOCK_TEXT)
  Display.unlockLabel:Hide()

  Display.badge = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  Display.badge:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", 2, -2)
  Display.badge:SetText("?")
  Display.badge:Hide()

  Display.ApplyPosition(settings.position)
  return anchor
end

function Display.ApplyPosition(pos)
  local anchor = Display.anchor
  if not anchor or not pos then return end
  anchor:ClearAllPoints()
  anchor:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

function Display.SavePosition(settings)
  local anchor = Display.anchor
  if not anchor then return end
  local point, _, relPoint, x, y = anchor:GetPoint()
  if not point then return end
  settings.position = {
    point = point, relPoint = relPoint or point,
    x = math.floor((x or 0) + 0.5), y = math.floor((y or 0) + 0.5),
  }
end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------
local function iconTexture(state, key)
  local entry = FB.Data.byKey[key]
  if entry and entry.consumable and state.Recommendation then
    local rec = state:Recommendation(key)
    if rec then
      local tex = FB.API.ItemIcon(rec.itemID)
      if tex then return tex end
    end
  end
  return FB.API.SpellIcon(state:IconSpell(key)) or FALLBACK_ICON
end

local function priorityOf(state, key)
  if state.Priority then return state:Priority(key) end
  return "normal"
end

-- A cheap string describing everything the frames depend on; equal strings
-- mean Update can skip all frame work.
-- Countdown text for a running-out icon: "4m" from a minute up, else "45s".
function Display.FormatTimer(seconds)
  if not seconds then return nil end
  if seconds >= 60 then return string.format("%dm", math.floor(seconds / 60)) end
  return string.format("%ds", math.floor(seconds))
end

-- Look: 1.2 setting, else derived from 1.1's style / showNames.
local function lookOf(settings)
  if settings.look then return settings.look end
  if settings.style == "names" then return "names_beside" end
  if settings.showNames then return "names_below" end
  return "icons"
end

-- Visibility of one key: the state's per-entry/global mode, else from 1.1's style.
local function visibilityOf(state, settings, key)
  if state.Visibility then return state:Visibility(key) end
  if settings.visibility then return settings.visibility end
  if settings.style == nil or settings.style == "grid" then return "always" end
  return "missing"
end

local function visibleKeys(state, settings, opts)
  if opts.hidden then return {} end
  local out = {}
  for _, key in ipairs(state:TrackedKeys()) do
    local status = state.status[key]
    local show
    if opts.unlocked or opts.testMode then show = true
    else
      local mode = visibilityOf(state, settings, key)
      if mode == "always" then show = true
      elseif mode == "expiring" then show = (status == "missing" or status == "expiring")
      else show = (status == "missing") end
    end
    if show then out[#out + 1] = key end
  end
  return out
end

local function timerText(state, key)
  if state.status[key] ~= "expiring" or not state.Remaining then return nil end
  return Display.FormatTimer(state:Remaining(key, GetTime()))
end

local function signature(state, settings, opts, keys, textures, timers)
  local parts = {
    opts.hidden and "H" or "-", opts.unlocked and "U" or "-", opts.testMode and "T" or "-", state.stale and "S" or "-",
    lookOf(settings), tostring(settings.iconSize), tostring(settings.spacing), tostring(settings.direction),
    tostring(settings.perRow), tostring(settings.highScale), tostring(settings.lowScale), tostring(settings.revision or 0),
  }
  for i, key in ipairs(keys) do
    parts[#parts + 1] = key .. ":" .. tostring(state.status[key]) .. ":" .. priorityOf(state, key) .. ":"
      .. tostring(textures[i]) .. ":" .. tostring(timers[i])
  end
  return table.concat(parts, "|")
end

function Display.Update(state, settings, opts)
  opts = opts or {}
  local anchor = Display.anchor or Display.Init(settings)
  Display.state = state
  Display.casters = opts.casters
  Display.unlocked = opts.unlocked == true

  local look = lookOf(settings)
  local keys = visibleKeys(state, settings, opts)
  local textures, timers = {}, {}
  for i, key in ipairs(keys) do
    textures[i] = iconTexture(state, key)
    timers[i] = timerText(state, key)
  end

  local sig = signature(state, settings, opts, keys, textures, timers)
  if sig == Display.lastSignature then return false end
  Display.lastSignature = sig

  if opts.hidden then
    anchor:Hide()
    return true
  end
  anchor:Show()

  local base = settings.iconSize or 40
  local spacing = settings.spacing or 6
  local sizes, priorities = {}, {}
  for i, key in ipairs(keys) do
    priorities[i] = priorityOf(state, key)
    sizes[i] = Display.IconSize(settings, priorities[i])
  end
  local positions = Display.LayoutPositions(sizes, spacing, settings.direction or "RIGHT", settings.perRow or 8)

  -- Exact bounds; shift so the anchor's TOPLEFT is the icons' top-left for
  -- every grow direction.
  local minX, maxY, maxX, minY = 0, 0, 0, 0
  if #keys > 0 then
    minX, maxY, maxX, minY = math.huge, -math.huge, -math.huge, math.huge
    for i, p in ipairs(positions) do
      minX = math.min(minX, p.x); maxX = math.max(maxX, p.x + sizes[i])
      maxY = math.max(maxY, p.y); minY = math.min(minY, p.y - sizes[i])
    end
  end

  local channels = settings.alert or (FB.db and FB.db.alert)
  for i, key in ipairs(keys) do
    local icon = Display.icons[i]
    if not icon then icon = createIcon(i); Display.icons[i] = icon end
    icon.key = key
    local size = sizes[i]
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    local p = positions[i]
    icon:SetPoint("TOPLEFT", anchor, "TOPLEFT", p.x - minX, p.y - maxY)

    icon.tex:SetTexture(textures[i])
    local status = opts.testMode and "missing" or state.status[key]
    applyBorder(icon, priorities[i], status)

    if status == "missing" or status == "expiring" then
      icon.tex:SetDesaturated(false)
      icon:SetAlpha(1)
      icon.border:Show()
    else
      icon.tex:SetDesaturated(true)
      icon:SetAlpha(PRESENT_ALPHA)
      icon.border:Hide()
    end

    if timers[i] and not opts.testMode then
      icon.timer:SetText(timers[i]); icon.timer:Show()
    else
      icon.timer:Hide()
    end

    local flash
    if opts.testMode then
      local c = channels and channels[priorities[i]]
      flash = c and c.flash == true
    else
      flash = FB.Alerts.ShouldFlash(state, key, channels)
    end
    if flash then
      if not icon.pulse:IsPlaying() then icon.pulse:Play() end
    else
      if icon.pulse:IsPlaying() then icon.pulse:Stop() end
    end

    if look == "names_beside" then
      icon.label:ClearAllPoints()
      icon.label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
      icon.label:SetText(entryDisplayName(state, key))
      icon.label:Show()
    elseif look == "names_below" then
      icon.label:ClearAllPoints()
      icon.label:SetPoint("TOP", icon, "BOTTOM", 0, -2)
      icon.label:SetText(entryDisplayName(state, key))
      icon.label:Show()
    else
      icon.label:Hide()
    end
    icon:Show()
  end
  for i = #keys + 1, #Display.icons do
    local icon = Display.icons[i]
    icon.key = nil
    if icon.pulse:IsPlaying() then icon.pulse:Stop() end
    icon:Hide()
  end

  if #keys > 0 then
    anchor:SetSize(maxX - minX, maxY - minY)
  else
    anchor:SetSize(base, base)
  end

  if opts.unlocked then
    Display.backdrop:Show()
    Display.unlockLabel:Show()
    anchor:EnableMouse(true)
  else
    Display.backdrop:Hide()
    Display.unlockLabel:Hide()
    anchor:EnableMouse(false)
  end

  if state.stale then Display.badge:Show() else Display.badge:Hide() end
  return true
end
