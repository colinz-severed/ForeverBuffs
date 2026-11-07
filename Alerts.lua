local ADDON, FB = ...
FB.Alerts = FB.Alerts or {}
local Alerts = FB.Alerts

-------------------------------------------------------------------------------
-- Alert decisions: which transitions get a sound, which icons flash.
-------------------------------------------------------------------------------

Alerts.SOUNDS = {
  { key = "raid_warning", name = "Raid Warning", kit = 8959 },
  { key = "ready_check",  name = "Ready Check",  kit = 8960 },
  { key = "alarm",        name = "Alarm Clock",  kit = 12889 },
  { key = "boss_whisper", name = "Boss Whisper", kit = 37666 },
}
Alerts.THROTTLE_SECONDS = 30

local function styleHasSound(style) return style == "sound" or style == "both" end
local function styleHasFlash(style) return style == "flash" or style == "both" end

local AlertsMT = {}
AlertsMT.__index = AlertsMT

function Alerts.New()
  return setmetatable({ lastSound = {} }, AlertsMT)
end

-- transitions: array of { key=, from=, to= }
-- state: has .tracked[key] = { quiet=bool }
-- ctx: { alertStyle=, hidden=, inGrace=, now= }
-- Returns the ordered array of keys that should sound now.
function AlertsMT:Decide(transitions, state, ctx)
  local out = {}
  if not styleHasSound(ctx.alertStyle) or ctx.hidden or ctx.inGrace then return out end
  local now = ctx.now or 0
  for _, t in ipairs(transitions or {}) do
    if t.from == "present" and t.to == "missing" then
      local tracked = state.tracked and state.tracked[t.key]
      local quiet = tracked and tracked.quiet
      local last = self.lastSound[t.key]
      if not quiet and (not last or now - last >= Alerts.THROTTLE_SECONDS) then
        self.lastSound[t.key] = now
        out[#out + 1] = t.key
      end
    end
  end
  return out
end

function Alerts.Play(soundKey)
  local kit
  for _, s in ipairs(Alerts.SOUNDS) do
    if s.key == soundKey then kit = s.kit end
  end
  kit = kit or Alerts.SOUNDS[1].kit
  local play = _G.PlaySound
  if play then pcall(play, kit, "Master") end
end

function Alerts.ShouldFlash(state, key, alertStyle)
  if not styleHasFlash(alertStyle) then return false end
  if state.status[key] ~= "missing" then return false end
  local tracked = state.tracked[key]
  if tracked and tracked.quiet then return false end
  return true
end
