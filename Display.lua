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
function Display.LayoutPositions(count, size, spacing, direction, perRow)
  local out = {}
  local step = size + spacing
  perRow = math.max(1, perRow or 8)
  for i = 1, count do
    local along = (i - 1) % perRow
    local across = math.floor((i - 1) / perRow)
    local x, y
    if direction == "LEFT" then x, y = -along * step, -across * step
    elseif direction == "DOWN" then x, y = across * step, -along * step
    elseif direction == "UP" then x, y = across * step, along * step
    else x, y = along * step, -across * step end
    out[i] = { x = x, y = y }
  end
  return out
end

-------------------------------------------------------------------------------
-- Frames
-------------------------------------------------------------------------------
local function styleHasFlash(style) return style == "flash" or style == "both" end

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
    if rec then
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

  icon.pulse = icon:CreateAnimationGroup()
  icon.pulse:SetLooping("BOUNCE")
  local alpha = icon.pulse:CreateAnimation("Alpha")
  alpha:SetFromAlpha(1)
  alpha:SetToAlpha(0.4)
  alpha:SetDuration(0.55)
  alpha:SetOrder(1)

  return icon
end

function Display.Init(settings)
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

function Display.Update(state, settings, opts)
  opts = opts or {}
  local anchor = Display.anchor or Display.Init(settings)
  Display.state = state
  Display.casters = opts.casters
  Display.unlocked = opts.unlocked == true

  if opts.hidden then
    anchor:Hide()
    return
  end
  anchor:Show()

  local style = settings.style or "grid"
  local showAll = opts.unlocked or opts.testMode or style == "grid"
  local keys = showAll and state:TrackedKeys() or state:Missing()
  local size = settings.iconSize or 40
  local spacing = settings.spacing or 6
  local positions = Display.LayoutPositions(#keys, size, spacing, settings.direction or "RIGHT", settings.perRow or 8)

  local minX, minY, maxX, maxY = 0, 0, size, size
  for i, key in ipairs(keys) do
    local icon = Display.icons[i]
    if not icon then icon = createIcon(i); Display.icons[i] = icon end
    icon.key = key
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    local p = positions[i]
    icon:SetPoint("TOPLEFT", anchor, "TOPLEFT", p.x, p.y)
    minX, maxX = math.min(minX, p.x), math.max(maxX, p.x + size)
    minY, maxY = math.min(minY, p.y - size), math.max(maxY, p.y)

    icon.tex:SetTexture(iconTexture(state, key))

    local missing = opts.testMode or state.status[key] == "missing"
    if missing then
      icon.tex:SetDesaturated(false)
      icon:SetAlpha(1)
      icon.border:Show()
    else
      icon.tex:SetDesaturated(true)
      icon:SetAlpha(PRESENT_ALPHA)
      icon.border:Hide()
    end

    -- The "names" style is "flashing with names": it pulses missing icons
    -- whatever the alert style; other styles follow the alert style.
    local flash
    if opts.testMode then flash = styleHasFlash(settings.alertStyle) or style == "names"
    elseif style == "names" then flash = missing
    else flash = FB.Alerts.ShouldFlash(state, key, settings.alertStyle) end
    if flash then
      if not icon.pulse:IsPlaying() then icon.pulse:Play() end
    else
      if icon.pulse:IsPlaying() then icon.pulse:Stop() end
    end

    if style == "names" then
      icon.label:ClearAllPoints()
      icon.label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
      icon.label:SetText(entryDisplayName(state, key))
      icon.label:Show()
    elseif settings.showNames then
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

  anchor:SetSize(math.max(size, maxX - minX), math.max(size, maxY - minY))

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
end
