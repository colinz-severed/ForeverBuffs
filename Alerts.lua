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

local BY_KEY = {}
for _, s in ipairs(Alerts.SOUNDS) do BY_KEY[s.key] = s end
function Alerts.SoundByKey(key) return BY_KEY[key] end


local function priorityOf(state, key)
  if state.Priority then return state:Priority(key) end
  return "normal"
end

local function soundsOn(state, key)
  if state.Sounds then return state:Sounds(key) end
  return true
end

local function displayName(state, key)
  if state.DisplayName then return state:DisplayName(key) end
  local entry = FB.Data and FB.Data.byKey[key]
  return entry and entry.name or key
end

local function defaultChannels()
  return (FB.db and FB.db.alert) or {}
end

local PRIORITY_RANK = { high = 3, normal = 2, low = 1 }
Alerts.REPEAT_FLOOR = 10
Alerts.TEXT_COLORS = { high = { 1, 0.82, 0 }, normal = { 1, 0.25, 0.2 }, low = { 1, 0.25, 0.2 } }

local AlertsMT = {}
AlertsMT.__index = AlertsMT

function Alerts.New()
  return setmetatable({ lastAlert = {}, missingSince = {} }, AlertsMT)
end

local function channelFor(ctx, prio)
  local c = ctx.channels or defaultChannels()
  return c[prio] or {}
end

local function formatRemaining(seconds)
  seconds = math.max(0, math.floor((seconds or 0) + 0.5))
  if seconds >= 60 then return string.format("%d min", math.floor(seconds / 60 + 0.5)) end
  return string.format("%d s", seconds)
end

-- Collects alerts into result: distinct sounds, and texts grouped so that
-- several "missing" alerts in one pass become one combined line.
local function newResult() return { sounds = {}, texts = {}, _soundSeen = {}, _missing = {} } end

local function addSound(result, sound)
  if sound and sound ~= "none" and not result._soundSeen[sound] then
    result._soundSeen[sound] = true
    result.sounds[#result.sounds + 1] = sound
  end
end

local function finish(result)
  if #result._missing > 0 then
    local names, best = {}, "low"
    for _, m in ipairs(result._missing) do
      names[#names + 1] = m.name
      if PRIORITY_RANK[m.priority] > PRIORITY_RANK[best] then best = m.priority end
    end
    table.insert(result.texts, 1, { text = table.concat(names, ", ") .. " missing!", priority = best })
  end
  result._soundSeen, result._missing = nil, nil
  return result
end

-- One alert for key of kind "missing" or "expiring".
local function alertOne(self, result, state, key, kind, ctx)
  if not soundsOn(state, key) then return end
  local prio = priorityOf(state, key)
  local channel = channelFor(ctx, prio)
  addSound(result, channel.sound)
  if channel.text then
    if kind == "missing" then
      result._missing[#result._missing + 1] = { name = displayName(state, key), priority = prio }
    else
      local rem = state.Remaining and state:Remaining(key, ctx.now or 0)
      result.texts[#result.texts + 1] = { text = displayName(state, key) .. " runs out in " .. formatRemaining(rem), priority = prio }
    end
  end
  self.lastAlert[key] = ctx.now or 0
end

-- transitions: array of { key=, from=, to= }
-- ctx: { channels=, alertOnExpiring=, hidden=, inGrace=, inCombat=, now= }
-- Returns { sounds = { soundKey, ... }, texts = { { text=, priority= }, ... } }.
function AlertsMT:Decide(transitions, state, ctx)
  local result = newResult()
  local now = ctx.now or 0
  for _, t in ipairs(transitions or {}) do
    if t.to == "missing" then
      self.missingSince[t.key] = now
      if t.from ~= "missing" and t.from ~= "untracked" then
        local last = self.lastAlert[t.key]
        if not (ctx.hidden or ctx.inGrace or ctx.inCombat) and (not last or now - last >= Alerts.REPEAT_FLOOR) then
          alertOne(self, result, state, t.key, "missing", ctx)
        end
      end
    else
      self.missingSince[t.key] = nil
      if t.to == "expiring" and t.from == "present" and ctx.alertOnExpiring
         and not (ctx.hidden or ctx.inGrace or ctx.inCombat) then
        alertOne(self, result, state, t.key, "expiring", ctx)
      end
    end
  end
  return finish(result)
end

-- Repeated reminders for entries that stay missing.
function AlertsMT:DueRepeats(state, ctx)
  local result = newResult()
  if ctx.hidden or ctx.inGrace or ctx.inCombat then return finish(result) end
  local now = ctx.now or 0
  for key, status in pairs(state.status or {}) do
    if status == "missing" and soundsOn(state, key) then
      local channel = channelFor(ctx, priorityOf(state, key))
      local interval = channel["repeat"] or 0
      if interval > 0 then
        interval = math.max(Alerts.REPEAT_FLOOR, interval)
        local since = self.lastAlert[key] or self.missingSince[key]
        if since == nil then self.missingSince[key] = now; since = now end
        if now - since >= interval then alertOne(self, result, state, key, "missing", ctx) end
      end
    end
  end
  return finish(result)
end

function Alerts.Play(soundKey)
  local entry = BY_KEY[soundKey]
  if not entry or not entry.kit then return end
  local kit = (_G.SOUNDKIT and entry.constant and _G.SOUNDKIT[entry.constant]) or entry.kit
  local play = _G.PlaySound
  if play then pcall(play, kit, "Master") end
end

function Alerts.Deliver(result)
  if not result then return end
  for _, sound in ipairs(result.sounds or {}) do Alerts.Play(sound) end
  for _, t in ipairs(result.texts or {}) do
    local c = Alerts.TEXT_COLORS[t.priority] or Alerts.TEXT_COLORS.normal
    if FB.API and FB.API.ScreenText then FB.API.ScreenText(t.text, c[1], c[2], c[3]) end
  end
end

-- Flash when missing or running out and the entry's priority channel says so.
function Alerts.ShouldFlash(state, key, channels)
  local status = state.status[key]
  if status ~= "missing" and status ~= "expiring" then return false end
  local c = (type(channels) == "table" and channels) or defaultChannels()
  local channel = c[priorityOf(state, key)] or {}
  return channel.flash == true
end
