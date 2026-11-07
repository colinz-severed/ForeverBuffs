local ADDON, FB = ...
FB.Alerts = FB.Alerts or {}
local Alerts = FB.Alerts

-------------------------------------------------------------------------------
-- Alert decisions: which transitions get a sound, which icons flash.
-- Priority rules (spec 1.1): high always flashes and sounds (soundHigh unless
-- "none"); normal follows the alert style with soundNormal; low never does
-- either.
-------------------------------------------------------------------------------

-- Verified against Blizzard's Mainline SoundKitConstants.lua (2026-11-08).
Alerts.SOUNDS = {
  { key = "raid_warning",      name = "Raid Warning",        constant = "RAID_WARNING",                        kit = 8959 },
  { key = "ready_check",       name = "Ready Check",         constant = "READY_CHECK",                         kit = 8960 },
  { key = "alarm1",            name = "Alarm Clock 1",       constant = "ALARM_CLOCK_WARNING_1",               kit = 18871 },
  { key = "alarm2",            name = "Alarm Clock 2",       constant = "ALARM_CLOCK_WARNING_2",               kit = 12867 },
  { key = "alarm3",            name = "Alarm Clock 3",       constant = "ALARM_CLOCK_WARNING_3",               kit = 12889 },
  { key = "boss_whisper",      name = "Boss Whisper",        constant = "UI_RAID_BOSS_WHISPER_WARNING",        kit = 37666 },
  { key = "quest_complete",    name = "Quest Complete",      constant = "IG_QUEST_LIST_COMPLETE",              kit = 878 },
  { key = "auto_quest",        name = "Auto Quest Complete", constant = "UI_AUTO_QUEST_COMPLETE",              kit = 23404 },
  { key = "pvp_queue",         name = "PvP Queue Horn",      constant = "PVP_THROUGH_QUEUE",                   kit = 8459 },
  { key = "whisper",           name = "Whisper",             constant = "TELL_MESSAGE",                        kit = 3081 },
  { key = "map_ping",          name = "Map Ping",            constant = "MAP_PING",                            kit = 3175 },
  { key = "invite",            name = "Player Invite",       constant = "IG_PLAYER_INVITE",                    kit = 880 },
  { key = "bnet_toast",        name = "Toast",               constant = "UI_BNET_TOAST",                       kit = 18019 },
  { key = "epic_loot",         name = "Epic Loot",           constant = "UI_EPICLOOT_TOAST",                   kit = 31578 },
  { key = "legendary_loot",    name = "Legendary Loot",      constant = "UI_LEGENDARY_LOOT_TOAST",             kit = 63971 },
  { key = "group_application", name = "Group Application",   constant = "UI_GROUP_FINDER_RECEIVE_APPLICATION", kit = 47615 },
  { key = "coins",             name = "Loot Coins",          constant = "LOOT_WINDOW_COIN_SOUND",              kit = 120 },
  { key = "none",              name = "No sound" },
}
Alerts.THROTTLE_SECONDS = 30

local BY_KEY = {}
for _, s in ipairs(Alerts.SOUNDS) do BY_KEY[s.key] = s end
function Alerts.SoundByKey(key) return BY_KEY[key] end

local function styleHasSound(style) return style == "sound" or style == "both" end
local function styleHasFlash(style) return style == "flash" or style == "both" end

local function priorityOf(state, key)
  if state.Priority then return state:Priority(key) end
  return "normal"
end

local AlertsMT = {}
AlertsMT.__index = AlertsMT

function Alerts.New()
  return setmetatable({ lastSound = {} }, AlertsMT)
end

-- Which sound (key) a present→missing transition of this priority gets, or nil.
local function soundFor(priority, ctx)
  if priority == "high" then
    if ctx.soundHigh and ctx.soundHigh ~= "none" then return ctx.soundHigh end
    return nil
  elseif priority == "normal" then
    if styleHasSound(ctx.alertStyle) and ctx.soundNormal and ctx.soundNormal ~= "none" then return ctx.soundNormal end
    return nil
  end
  return nil
end

-- transitions: array of { key=, from=, to= }
-- ctx: { alertStyle=, soundNormal=, soundHigh=, hidden=, inGrace=, now= }
-- Returns the ordered array of { key=, sound= } that should sound now.
function AlertsMT:Decide(transitions, state, ctx)
  local out = {}
  if ctx.hidden or ctx.inGrace then return out end
  local now = ctx.now or 0
  for _, t in ipairs(transitions or {}) do
    if t.from == "present" and t.to == "missing" then
      local sound = soundFor(priorityOf(state, t.key), ctx)
      local last = self.lastSound[t.key]
      if sound and (not last or now - last >= Alerts.THROTTLE_SECONDS) then
        self.lastSound[t.key] = now
        out[#out + 1] = { key = t.key, sound = sound }
      end
    end
  end
  return out
end

function Alerts.Play(soundKey)
  local entry = BY_KEY[soundKey]
  if not entry or not entry.kit then return end
  local kit = (_G.SOUNDKIT and entry.constant and _G.SOUNDKIT[entry.constant]) or entry.kit
  local play = _G.PlaySound
  if play then pcall(play, kit, "Master") end
end

-- style: the display style ("names" pulses normal-priority missing icons
-- whatever the alert style). Low never flashes; high always does.
function Alerts.ShouldFlash(state, key, alertStyle, style)
  if state.status[key] ~= "missing" then return false end
  local priority = priorityOf(state, key)
  if priority == "high" then return true end
  if priority == "low" then return false end
  return styleHasFlash(alertStyle) or style == "names"
end
