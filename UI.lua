local ADDON, FB = ...
FB.UI = FB.UI or {}
local UI = FB.UI

-------------------------------------------------------------------------------
-- A small widget kit for the options window. No libraries. Every factory
-- returns its root frame and sets frame.Refresh() to re-read the getter.
-------------------------------------------------------------------------------

local WHITE = "Interface\\Buttons\\WHITE8x8"
UI.COLORS = {
  bg       = { 0.06, 0.07, 0.09 },
  panel    = { 0.10, 0.11, 0.14 },
  border   = { 0.25, 0.27, 0.32 },
  control  = { 0.14, 0.16, 0.20 },
  hover    = { 0.20, 0.23, 0.29 },
  accent   = { 0.83, 0.69, 0.22 },   -- gold
  text     = { 0.84, 0.85, 0.88 },
  muted    = { 0.55, 0.58, 0.65 },
}
local C = UI.COLORS

local BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 } }

local function backdropFrame(kind, parent, name)
  local f = CreateFrame(kind or "Frame", name, parent, "BackdropTemplate")
  if f.SetBackdrop then f:SetBackdrop(BACKDROP) end
  return f
end

local function setBackdrop(f, color, alpha, borderColor, borderAlpha)
  if f.SetBackdropColor then f:SetBackdropColor(color[1], color[2], color[3], alpha or 1) end
  local b = borderColor or C.border
  if f.SetBackdropBorderColor then f:SetBackdropBorderColor(b[1], b[2], b[3], borderAlpha or 1) end
end

local function fontString(parent, font, text, color)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  if text then fs:SetText(text) end
  local c = color or C.text
  fs:SetTextColor(c[1], c[2], c[3], 1)
  return fs
end

-------------------------------------------------------------------------------
-- Panel: translucent backdrop; alpha applies to the backdrop only.
-------------------------------------------------------------------------------
function UI.Panel(parent, width, height, name)
  local f = backdropFrame("Frame", parent, name)
  f:SetSize(width, height)
  f.backdropAlpha = 1
  function f:SetAlphaBackdrop(a)
    self.backdropAlpha = a
    setBackdrop(self, C.bg, a, C.border, math.min(1, a + 0.25))
  end
  f:SetAlphaBackdrop(1)
  function f.Refresh() end
  return f
end

-------------------------------------------------------------------------------
-- Checkbox
-------------------------------------------------------------------------------
function UI.Checkbox(parent, label, get, set, tooltip)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(220, 24)
  local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  check:SetSize(24, 24)
  check:SetPoint("LEFT", f, "LEFT", 0, 0)
  f.check = check
  f.label = fontString(f, "GameFontHighlightSmall", label)
  f.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
  f.tooltip = tooltip
  check:SetScript("OnClick", function(self)
    local nv = not get()
    set(nv)
    self:SetChecked(nv)
  end)
  function f.Refresh() check:SetChecked(get() and true or false) end
  f.Refresh()
  return f
end

-------------------------------------------------------------------------------
-- Slider
-------------------------------------------------------------------------------
function UI.Slider(parent, label, min, max, step, get, set, formatter)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(260, 40)
  f.label = fontString(f, "GameFontHighlightSmall", label)
  f.label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  f.valueText = fontString(f, "GameFontHighlightSmall", "", C.accent)
  f.valueText:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  local slider = CreateFrame("Slider", nil, f, "UISliderTemplate")
  slider:SetOrientation("HORIZONTAL")
  slider:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 4)
  slider:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 4)
  slider:SetHeight(16)
  slider:SetMinMaxValues(min, max)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  f.slider = slider
  formatter = formatter or function(v) return tostring(v) end
  local function snap(v)
    v = math.floor((v - min) / step + 0.5) * step + min
    v = math.floor(v * 10000 + 0.5) / 10000   -- kill float drift (0.30000000000000004)
    if v < min then v = min elseif v > max then v = max end
    return v
  end
  slider:SetScript("OnValueChanged", function(self, value)
    local v = snap(value)
    f.valueText:SetText(formatter(v))
    if v ~= get() then set(v) end
  end)
  function f.Refresh()
    local v = get()
    slider:SetValue(v)
    f.valueText:SetText(formatter(v))
  end
  f.Refresh()
  return f
end

-------------------------------------------------------------------------------
-- Dropdown: a button that opens a list of choices.
-------------------------------------------------------------------------------
local openList
local function closeOpenList()
  if openList then openList:Hide(); openList = nil end
end
UI.CloseDropdowns = closeOpenList

function UI.Dropdown(parent, label, choicesFn, get, set, width)
  local f = CreateFrame("Frame", nil, parent)
  width = width or 180
  f:SetSize(width, label and 40 or 24)
  if label then
    f.label = fontString(f, "GameFontHighlightSmall", label)
    f.label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  end
  local button = backdropFrame("Button", f)
  button:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  button:SetSize(width, 22)
  setBackdrop(button, C.control, 1)
  f.button = button
  f.text = fontString(button, "GameFontHighlightSmall", "")
  f.text:SetPoint("LEFT", button, "LEFT", 8, 0)
  f.text:SetPoint("RIGHT", button, "RIGHT", -18, 0)
  f.text:SetJustifyH("LEFT")
  f.arrow = fontString(button, "GameFontHighlightSmall", "v", C.muted)
  f.arrow:SetPoint("RIGHT", button, "RIGHT", -6, 0)

  local list = backdropFrame("Frame", UIParent)
  list:SetFrameStrata("FULLSCREEN_DIALOG")
  list:SetClampedToScreen(true)
  setBackdrop(list, C.panel, 0.97)
  list:Hide()
  list.buttons = {}
  f.list = list

  local function currentText()
    local v = get()
    for _, c in ipairs(choicesFn() or {}) do
      if c.value == v then return c.text end
    end
    return v ~= nil and tostring(v) or ""
  end

  function f:Close() list:Hide(); if openList == list then openList = nil end end

  function f:Open()
    closeOpenList()
    local choices = choicesFn() or {}
    local rowH = 20
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    list:SetSize(width, rowH * #choices + 8)
    for i, c in ipairs(choices) do
      local b = list.buttons[i]
      if not b then
        b = backdropFrame("Button", list)
        b:SetHeight(rowH)
        b.text = fontString(b, "GameFontHighlightSmall", "")
        b.text:SetPoint("LEFT", b, "LEFT", 8, 0)
        b.text:SetJustifyH("LEFT")
        b:SetScript("OnEnter", function(self) setBackdrop(self, C.hover, 1, C.hover) end)
        b:SetScript("OnLeave", function(self) setBackdrop(self, C.panel, 0, C.panel, 0) end)
        list.buttons[i] = b
      end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4 - (i - 1) * rowH)
      b:SetPoint("RIGHT", list, "RIGHT", -4, 0)
      b.text:SetText(c.text)
      setBackdrop(b, C.panel, 0, C.panel, 0)
      b.value = c.value
      b:SetScript("OnClick", function()
        set(c.value)
        f:Close()
        f.Refresh()
      end)
      b:Show()
    end
    for i = #choices + 1, #list.buttons do list.buttons[i]:Hide() end
    list:Show()
    openList = list
  end

  button:SetScript("OnClick", function()
    if list:IsShown() then f:Close() else f:Open() end
  end)
  button:SetScript("OnEnter", function(self) setBackdrop(self, C.hover, 1) end)
  button:SetScript("OnLeave", function(self) setBackdrop(self, C.control, 1) end)

  function f.Refresh() f.text:SetText(currentText()) end
  f.Refresh()
  return f
end

-------------------------------------------------------------------------------
-- Button
-------------------------------------------------------------------------------
function UI.Button(parent, text, onClick, width)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 120, 22)
  b:SetText(text)
  b:SetScript("OnClick", function() onClick() end)
  function b.Refresh() end
  return b
end

-------------------------------------------------------------------------------
-- EditBox: read-only by default (copyable link); editable=true for a filter.
-------------------------------------------------------------------------------
function UI.EditBox(parent, text, width, editable, onChange)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width or 300, 22)
  local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  box:SetPoint("TOPLEFT", f, "TOPLEFT", 6, 0)
  box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  box:SetAutoFocus(false)
  box:SetFontObject(ChatFontNormal)
  f.box = box
  f.value = text or ""
  box:SetText(f.value)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  if editable then
    box:SetScript("OnTextChanged", function(self, userInput)
      f.value = self:GetText()
      if userInput and onChange then onChange(f.value) end
    end)
  else
    box:SetScript("OnTextChanged", function(self, userInput)
      if self:GetText() ~= f.value then self:SetText(f.value) end
    end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  end
  function f:SetValue(v) f.value = v or ""; box:SetText(f.value) end
  function f.Refresh() end
  return f
end

-------------------------------------------------------------------------------
-- ScrollList: fixed-height rows, row pool, mouse-wheel scrolling.
-------------------------------------------------------------------------------
-- opts.virtual (default true): only visible rows get frames. With
-- virtual=false every item gets its own row frame (scrolling just moves them),
-- which keeps rows addressable for lists of a few dozen items.
function UI.ScrollList(parent, rowHeight, buildRow, fillRow, opts)
  local f = CreateFrame("Frame", nil, parent)
  f:SetClipsChildren(true)
  f.rows = {}
  f.items = {}
  f.offset = 0
  f.rowHeight = rowHeight
  f.virtual = not (opts and opts.virtual == false)

  local track = f:CreateTexture(nil, "ARTWORK")
  track:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
  track:SetWidth(4)
  track:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
  track:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
  local thumb = f:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
  thumb:SetWidth(4)
  f.thumb = thumb

  local function visibleCount()
    local h = f:GetHeight() or 0
    return math.floor(h / rowHeight) + 1
  end

  function f:MaxOffset()
    local h = self:GetHeight() or 0
    return math.max(0, #self.items - math.floor(h / rowHeight))
  end

  function f:Render()
    local maxOffset = self:MaxOffset()
    if self.offset > maxOffset then self.offset = maxOffset end
    if self.offset < 0 then self.offset = 0 end
    local n
    if self.virtual then
      n = visibleCount()
      for i = 1, n do
        local item = self.items[self.offset + i]
        local row = self.rows[i]
        if item ~= nil then
          if not row then
            row = buildRow(self)
            row:SetHeight(rowHeight)
            self.rows[i] = row
          end
          row:ClearAllPoints()
          row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(i - 1) * rowHeight)
          row:SetPoint("RIGHT", self, "RIGHT", -8, 0)
          fillRow(row, item, self.offset + i)
          row:Show()
        elseif row then
          row:Hide()
        end
      end
    else
      n = #self.items
      for i = 1, n do
        local row = self.rows[i]
        if not row then
          row = buildRow(self)
          row:SetHeight(rowHeight)
          self.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(i - 1 - self.offset) * rowHeight)
        row:SetPoint("RIGHT", self, "RIGHT", -8, 0)
        fillRow(row, self.items[i], i)
        row:Show()
      end
    end
    for i = n + 1, #self.rows do self.rows[i]:Hide() end
    -- scrollbar thumb
    local total = #self.items
    if total > 0 and maxOffset > 0 then
      local h = self:GetHeight() or 0
      local frac = math.min(1, (h / rowHeight) / total)
      thumb:SetHeight(math.max(12, h * frac))
      thumb:ClearAllPoints()
      thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", -1, -1 - (h - thumb:GetHeight()) * (self.offset / maxOffset))
      thumb:Show(); track:Show()
    else
      thumb:Hide(); track:Hide()
    end
  end

  function f:SetItems(items)
    self.items = items or {}
    self:Render()
  end

  function f:ScrollTo(offset)
    self.offset = offset
    self:Render()
  end

  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(self, delta)
    self:ScrollTo(self.offset - delta * 3)
  end)
  f:SetScript("OnSizeChanged", function(self) self:Render() end)
  function f.Refresh() f:Render() end
  return f
end

-------------------------------------------------------------------------------
-- SectionHeader
-------------------------------------------------------------------------------
function UI.SectionHeader(parent, text)
  local fs = fontString(parent, "GameFontNormal", string.upper(text or ""), C.muted)
  return fs
end

-------------------------------------------------------------------------------
-- Tabs: a vertical strip of tab buttons.
-------------------------------------------------------------------------------
function UI.Tabs(parent, names, onSelect, width)
  local f = CreateFrame("Frame", nil, parent)
  width = width or 130
  f:SetWidth(width)
  f.buttons = {}
  f.names = names
  local rowH = 30
  for i, name in ipairs(names) do
    local b = backdropFrame("Button", f)
    b:SetSize(width, rowH)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(i - 1) * (rowH + 2))
    b.text = fontString(b, "GameFontHighlightSmall", name)
    b.text:SetPoint("LEFT", b, "LEFT", 14, 0)
    b.accent = b:CreateTexture(nil, "OVERLAY")
    b.accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    b.accent:SetWidth(3)
    b.accent:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.accent:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.accent:Hide()
    setBackdrop(b, C.panel, 0, C.panel, 0)
    b:SetScript("OnClick", function() f:Select(name) end)
    b:SetScript("OnEnter", function(self) if f.active ~= name then setBackdrop(self, C.hover, 0.6, C.hover, 0) end end)
    b:SetScript("OnLeave", function(self) if f.active ~= name then setBackdrop(self, C.panel, 0, C.panel, 0) end end)
    f.buttons[name] = b
  end
  f:SetHeight(#names * (rowH + 2))

  function f:Select(name)
    self.active = name
    for n, b in pairs(self.buttons) do
      if n == name then
        setBackdrop(b, C.control, 0.9, C.control, 0)
        b.accent:Show()
        b.text:SetTextColor(1, 1, 1, 1)
      else
        setBackdrop(b, C.panel, 0, C.panel, 0)
        b.accent:Hide()
        b.text:SetTextColor(C.text[1], C.text[2], C.text[3], 0.75)
      end
    end
    if onSelect then onSelect(name) end
  end
  function f.Refresh() end
  return f
end
