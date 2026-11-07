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

local function isEnabled(entry, env)
  local v = env.enabled(entry.key)
  if v ~= nil then return v end
  local byClass = entry.defaultEnabledByClass and entry.defaultEnabledByClass[env.playerClass()]
  if byClass ~= nil then return byClass end
  return entry.defaultEnabled
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

local function consumableTracked(self, entry, env)
  local instance = env.instanceType()
  if instance == "pvp" or instance == "arena" then return false end
  if entry.minLevel and env.playerLevel() < entry.minLevel then return false end
  if entry.excludeClasses and entry.excludeClasses[env.playerClass()] then return false end
  local settings = env.charSettings() or {}
  local raidsOnly = settings.consumablesRaidsOnly
  if raidsOnly == nil then raidsOnly = true end
  local remindDrop = settings.consumablesRemindDrop
  if remindDrop == nil then remindDrop = true end
  if not raidsOnly then return true end
  if instance == "raid" then return true end
  if remindDrop and self.seenConsumable[entry.key] then return true end
  return false
end

function StateMT:ComputeTracked()
  local env = self.env
  local members = env.groupMembers() or {}
  local newTracked = {}
  for _, entry in ipairs(self.data.entries) do
    if isEnabled(entry, env) then
      local offhandOK = not entry.requiresOffhandWeapon or env.offhandWeapon()
      if offhandOK then
        if entry.consumable then
          if consumableTracked(self, entry, env) then
            newTracked[entry.key] = { reason = "consumable", quiet = false }
          end
        else
          local known = anyKnown(env, entry.castIDs)
          if known then
            newTracked[entry.key] = { reason = "known", quiet = false }
          elseif not entry.selfOnly and groupCanCast(entry, members) then
            newTracked[entry.key] = { reason = "group", quiet = entry.quietFromOthers == true }
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

function StateMT:Recommendation(key)
  return self.data.Recommend(key, self.env.playerClass(), self:Role(), self.env.playerLevel(), self.env.weaponKind())
end
