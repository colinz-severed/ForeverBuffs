local ADDON, FB = ...
FB.State = FB.State or {}
local State = FB.State

-------------------------------------------------------------------------------
-- Pure evaluation core. Knows nothing about Blizzard; everything comes in
-- through the env table of callbacks (see FB.Core.BuildEnv and tests/helpers.lua).
-------------------------------------------------------------------------------

local StateMT = {}
StateMT.__index = StateMT

function State.New(data, env)
  local s = setmetatable({}, StateMT)
  s.data = data
  s.env = env
  s.tracked = {}          -- key -> { reason=, quiet= }
  s.status = {}           -- key -> "present" | "missing"
  s.seenConsumable = {}   -- key -> true once seen present this session
  s.expiresAt = {}        -- key -> GetTime() value the buff ends (when known)
  s.fullDuration = {}     -- key -> full duration in seconds (when known)
  s.stale = false
  s.lastEvaluated = nil
  return s
end

local function anyKnown(env, ids)
  for _, id in ipairs(ids or {}) do
    if env.knows(id) then return true end
  end
  return false
end

local function settingsOf(env) return env.charSettings and env.charSettings() or {} end

-- Default for the Show tick: the 1.0/1.1 enabled default.
local function defaultShow(entry, env)
  local byClass = entry.defaultEnabledByClass and entry.defaultEnabledByClass[env.playerClass()]
  if byClass ~= nil then return byClass end
  return entry.defaultEnabled
end

local function showSetting(entry, env)
  local settings = settingsOf(env)
  local v = settings.show and settings.show[entry.key]
  if v ~= nil then return v end
  v = env.enabled and env.enabled(entry.key)       -- 1.1 setting, before migration
  if v ~= nil then return v end
  return defaultShow(entry, env)
end

-- The reason an entry is (or would be) tracked, used for default priority and
-- the default of the Sound tick.
local function wouldBeReason(entry, env)
  if entry.consumable then return "consumable" end
  if entry.class == env.playerClass() or anyKnown(env, entry.castIDs) then return "known" end
  return "group"
end

local function soundSetting(self, entry, env)
  local settings = settingsOf(env)
  local v = settings.sound and settings.sound[entry.key]
  if v ~= nil then return v end
  local legacy = env.enabled and env.enabled(entry.key)
  if legacy == false then return false end
  if not defaultShow(entry, env) then return false end
  return self.data.DefaultPriority(wouldBeReason(entry, env)) ~= "low"
end

local function isEnabled(self, entry, env)
  return showSetting(entry, env) or soundSetting(self, entry, env)
end

local function groupCanCast(entry, members)
  for _, m in ipairs(members or {}) do
    if m.class == entry.class then
      local level = m.level or 0
      if level <= 0 or level >= (entry.learnLevel or 1) then return true end
    end
  end
  return false
end

State.DEFAULT_SCOPE = { elixir = "instances", well_fed = "instances", weapon = "instances", flask = "raids" }

function State.ScopeOf(data, settings, key)
  local cat = data.CategoryOf and data.CategoryOf(key)
  local where = settings.consumableWhere and cat and settings.consumableWhere[cat]
  return where or State.DEFAULT_SCOPE[cat] or "instances"
end

local function consumableTracked(self, entry, env)
  local instance = env.instanceType()
  if instance == "pvp" or instance == "arena" then return false end
  if entry.minLevel and env.playerLevel() < entry.minLevel then return false end
  if entry.excludeClasses and entry.excludeClasses[env.playerClass()] then return false end
  local settings = settingsOf(env)
  local scope = State.ScopeOf(self.data, settings, entry.key)
  if scope == "never" then return false end
  if scope == "everywhere" then return true end
  if scope == "raids" and instance == "raid" then return true end
  if scope == "instances" and (instance == "raid" or instance == "party") then return true end
  local remindDrop = settings.consumablesRemindDrop
  if remindDrop == nil then remindDrop = true end
  if remindDrop and self.seenConsumable[entry.key] then return true end
  return false
end

function StateMT:ComputeTracked()
  local env = self.env
  local members = env.groupMembers() or {}
  local newTracked = {}
  for _, entry in ipairs(self.data.entries) do
    if isEnabled(self, entry, env) then
      local offhandOK = not entry.requiresOffhandWeapon or env.offhandWeapon()
      if offhandOK then
        if entry.consumable then
          if consumableTracked(self, entry, env) then
            newTracked[entry.key] = { reason = "consumable" }
          end
        else
          local known = anyKnown(env, entry.castIDs)
          if known then
            newTracked[entry.key] = { reason = "known" }
          elseif not entry.selfOnly and groupCanCast(entry, members) then
            newTracked[entry.key] = { reason = "group" }
          end
        end
      end
    end
  end
  self.tracked = newTracked
end

function StateMT:IconSpell(key)
  local entry = self.data.byKey[key]
  if not entry then return nil end
  local icons = entry.iconSpells or {}
  for _, id in ipairs(icons) do
    if self.env.knows(id) then return id end
  end
  return icons[#icons]
end

function StateMT:Role()
  local settings = self.env.charSettings() or {}
  if settings.role then return settings.role end
  return self.data.DefaultRole(self.env.playerClass())
end

function StateMT:Shows(key)
  local entry = self.data.byKey[key]; if not entry then return false end
  return showSetting(entry, self.env) and true or false
end

function StateMT:Sounds(key)
  local entry = self.data.byKey[key]; if not entry then return false end
  return soundSetting(self, entry, self.env) and true or false
end

function StateMT:DisplayName(key)
  local entry = self.data.byKey[key]; if not entry then return key end
  if entry.consumable then return entry.name end
  local id = self:IconSpell(key)
  return (id and self.env.spellName and self.env.spellName(id)) or entry.name
end

function StateMT:Visibility(key)
  local settings = settingsOf(self.env)
  local v = settings.visibility and settings.visibility[key]
  if v then return v end
  return (self.env.globalVisibility and self.env.globalVisibility()) or "always"
end

function StateMT:Remaining(key, now)
  local e = self.expiresAt[key]
  if not e then return nil end
  return math.max(0, e - now)
end

-- Priority: explicit per-character setting, else the default for the reason
-- the entry is tracked (own buff → normal, group or consumable → low).
function StateMT:Priority(key)
  local settings = self.env.charSettings() or {}
  local explicit = settings.priority and settings.priority[key]
  if explicit then return explicit end
  local tracked = self.tracked[key]
  if not tracked then return "normal" end
  return self.data.DefaultPriority(tracked.reason)
end

-- The player's own choice of consumable for this entry's category, if any.
function StateMT:Pick(key)
  local category = self.data.CategoryOf and self.data.CategoryOf(key)
  if not category then return nil end
  local settings = self.env.charSettings() or {}
  return settings.pick and settings.pick[category] or nil
end

function StateMT:Recommendation(key)
  local pick = self:Pick(key)
  if pick then
    local row = self.data.CatalogueItem(self.data.CategoryOf(key), pick)
    if row then return { itemID = row.itemID, name = row.name, level = row.level, picked = true } end
  end
  local rec = self.data.Recommend(key, self.env.playerClass(), self:Role(), self.env.playerLevel(), self.env.weaponKind())
  if rec then rec.picked = false end
  return rec
end

-------------------------------------------------------------------------------
-- Presence evaluation
-------------------------------------------------------------------------------
local function allNeverSecret(entry, env)
  for _, id in ipairs(entry.ids or {}) do
    if not env.neverSecret(id) then return false end
  end
  return true
end

local WEAPON_FULL = { consumable = 1800, class = 3600 }

-- Returns present (true / false / nil = unknown), expiresAt, fullDuration.
local function presence(entry, env)
  if entry.kind == "weaponEnchant" then
    local has = env.tempEnchant(entry.slot) == true
    if not has then return false end
    local rem = env.weaponRemaining and env.weaponRemaining(entry.slot)
    if rem then return true, env.now() + rem, entry.consumable and WEAPON_FULL.consumable or WEAPON_FULL.class end
    return true
  end
  local anyUnknown, found = false, false
  local bestExp, bestDur
  local function takeTimes(exp, dur)
    if exp and dur and (not bestExp or exp > bestExp) then bestExp, bestDur = exp, dur end
  end
  for _, id in ipairs(entry.ids or {}) do
    local v = env.aura(id)
    if v == true then
      local counts = true
      if entry.mustBeOwn then counts = env.auraSource(id) ~= "other" end
      if counts then
        found = true
        if env.auraTimes then takeTimes(env.auraTimes(id)) end
      end
    elseif v == nil then
      anyUnknown = true
    end
  end
  if entry.nameMatch then
    local v = env.auraByName(entry.nameMatch)
    if v == true then
      found = true
      if env.auraTimesByName then takeTimes(env.auraTimesByName(entry.nameMatch)) end
    elseif v == nil then anyUnknown = true end
  end
  if found then return true, bestExp, bestDur end
  if anyUnknown then return nil end
  return false
end

local function thresholdsOf(env)
  return (env.thresholds and env.thresholds()) or { long = 300, short = 60, longBuff = 900 }
end

-- "expiring" or "present" for a present entry with known end time.
local function timedStatus(self, key, now)
  local exp = self.expiresAt[key]
  if not exp then return "present" end
  local t = thresholdsOf(self.env)
  local full = self.fullDuration[key] or 0
  local threshold = (full >= (t.longBuff or 900)) and (t.long or 300) or (t.short or 60)
  if exp - now <= threshold then return "expiring" end
  return "present"
end

-- Moves present/expiring entries between the two from cached end times only;
-- safe in combat (no aura calls). Returns transitions.
function StateMT:UpdateExpiring(now)
  local transitions = {}
  for _, entry in ipairs(self.data.entries) do
    local key = entry.key
    local old = self.status[key]
    if (old == "present" or old == "expiring") and self.expiresAt[key] then
      local new = timedStatus(self, key, now)
      if new ~= old then
        self.status[key] = new
        transitions[#transitions + 1] = { key = key, from = old, to = new }
      end
    end
  end
  return transitions
end

-- opts.onlyKinds: set of entry kinds to check (others keep their status).
function StateMT:Evaluate(opts)
  local env = self.env
  local onlyKinds = opts and opts.onlyKinds or nil
  self:ComputeTracked()
  local restricted = env.restricted() == true
  local transitions = {}

  for key, old in pairs(self.status) do
    if not self.tracked[key] then
      transitions[#transitions + 1] = { key = key, from = old, to = "untracked" }
      self.status[key] = nil
      self.expiresAt[key], self.fullDuration[key] = nil, nil
    end
  end

  for _, entry in ipairs(self.data.entries) do
    local key = entry.key
    local wanted = not onlyKinds or onlyKinds[entry.kind]
    if wanted and self.tracked[key] and (not restricted or allNeverSecret(entry, env)) then
      local present, exp, full = presence(entry, env)
      if present ~= nil then
        if entry.consumable and present then self.seenConsumable[key] = true end
        local new
        if present then
          self.expiresAt[key], self.fullDuration[key] = exp, full
          new = timedStatus(self, key, env.now())
        else
          self.expiresAt[key], self.fullDuration[key] = nil, nil
          new = "missing"
        end
        local old = self.status[key]
        if old ~= new then
          transitions[#transitions + 1] = { key = key, from = old or "untracked", to = new }
          self.status[key] = new
        end
      end
    end
  end

  if onlyKinds then
    for _, t in ipairs(self:UpdateExpiring(env.now())) do transitions[#transitions + 1] = t end
  end
  if not onlyKinds then
    self.stale = restricted
    if not restricted then self.lastEvaluated = env.now() end
  end
  return transitions
end

function StateMT:TrackedKeys()
  local out = {}
  for _, entry in ipairs(self.data.entries) do
    if self.tracked[entry.key] then out[#out + 1] = entry.key end
  end
  return out
end

function StateMT:Missing()
  local out = {}
  for _, entry in ipairs(self.data.entries) do
    if self.tracked[entry.key] and self.status[entry.key] == "missing" then out[#out + 1] = entry.key end
  end
  return out
end
