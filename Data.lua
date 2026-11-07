local ADDON, FB = ...
FB.Data = FB.Data or {}
local Data = FB.Data

-------------------------------------------------------------------------------
-- Buff entries for World of Warcraft: Forever (client 1.60.1).
-- Spell IDs are the Classic IDs, which Forever keeps. Learn levels from the
-- Forever spellbook. IDs verified against wowhead.com/forever and in-game
-- /fbuffs ids on: (pending, see Task 10 of the plan)
--
-- Entry fields:
--   key, name, class (nil = consumable), learnLevel, selfOnly, kind ("aura" |
--   "weaponEnchant"), castIDs (default = ids), ids, nameMatch, iconSpells
--   (first known wins, else last), defaultEnabled, defaultEnabledByClass,
--   quietFromOthers, mustBeOwn, slot, requiresOffhandWeapon, consumable,
--   excludeClasses, minLevel.
-------------------------------------------------------------------------------

Data.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
Data.ROLES = { "Caster", "Melee", "Healer", "Tank" }

local DEFAULT_ROLE = {
  MAGE = "Caster", WARLOCK = "Caster",
  ROGUE = "Melee", HUNTER = "Melee", WARRIOR = "Melee",
  PRIEST = "Healer", PALADIN = "Healer", SHAMAN = "Healer", DRUID = "Healer",
}
function Data.DefaultRole(class) return DEFAULT_ROLE[class] or "Melee" end

local function E(t)
  t.kind = t.kind or "aura"
  t.castIDs = t.castIDs or t.ids
  t.ids = t.ids or {}
  if t.defaultEnabled == nil then t.defaultEnabled = true end
  t.selfOnly = t.selfOnly or false
  t.quietFromOthers = t.quietFromOthers or false
  t.mustBeOwn = t.mustBeOwn or false
  t.consumable = t.consumable or false
  t.requiresOffhandWeapon = t.requiresOffhandWeapon or false
  t.excludeClasses = t.excludeClasses or {}
  t.defaultEnabledByClass = t.defaultEnabledByClass or {}
  return t
end

Data.entries = {
  ---------------------------------------------------------------------------
  -- Self-only buffs (tracked once the player knows the spell)
  ---------------------------------------------------------------------------
  E{ key = "inner_fire", name = "Inner Fire", class = "PRIEST", learnLevel = 12, selfOnly = true,
     ids = { 588, 7128, 602, 1006, 10951, 10952 }, iconSpells = { 588 } },
  E{ key = "mage_armor", name = "Armor", class = "MAGE", learnLevel = 1, selfOnly = true,
     ids = { 168, 7300, 7301, 7302, 7320, 10219, 10220, 6117, 22782, 22783 },
     iconSpells = { 6117, 7302, 168 } },
  E{ key = "warlock_armor", name = "Demon Armor", class = "WARLOCK", learnLevel = 1, selfOnly = true,
     ids = { 687, 696, 706, 1086, 11733, 11734, 11735 }, iconSpells = { 706, 687 } },
  E{ key = "thorns", name = "Thorns", class = "DRUID", learnLevel = 6, selfOnly = true,
     ids = { 467, 782, 1075, 8914, 9756, 9910 }, iconSpells = { 467 } },
  E{ key = "paladin_aura", name = "Aura", class = "PALADIN", learnLevel = 1, selfOnly = true, mustBeOwn = true,
     ids = { 465, 10290, 643, 10291, 1032, 10292,             -- Devotion
             7294, 10298, 10299, 10300, 10301,                -- Retribution
             19746,                                           -- Concentration
             19876, 19895, 19896,                             -- Shadow Resistance
             19888, 19897, 19898,                             -- Frost Resistance
             19891, 19899, 19900 },                           -- Fire Resistance
     iconSpells = { 465 } },
  E{ key = "righteous_fury", name = "Righteous Fury", class = "PALADIN", learnLevel = 10, selfOnly = true,
     ids = { 25780 }, iconSpells = { 25780 }, defaultEnabled = false },
  E{ key = "hunter_aspect", name = "Aspect", class = "HUNTER", learnLevel = 4, selfOnly = true, mustBeOwn = true,
     ids = { 13163, 13165, 14318, 14319, 14320, 14321, 14322, 25296, 5118, 13161, 13159, 20043, 20190 },
     iconSpells = { 13165, 13163 } },
  E{ key = "trueshot_aura", name = "Trueshot Aura", class = "HUNTER", learnLevel = 60, selfOnly = true, mustBeOwn = true,
     ids = { 19506, 20905, 20906 }, iconSpells = { 19506 } },
  E{ key = "lightning_shield", name = "Lightning Shield", class = "SHAMAN", learnLevel = 8, selfOnly = true,
     ids = { 324, 325, 905, 945, 8134, 10431, 10432 }, iconSpells = { 324 } },
  E{ key = "shaman_imbue", name = "Weapon Imbue", class = "SHAMAN", learnLevel = 1, selfOnly = true,
     kind = "weaponEnchant", slot = 16, castIDs = { 8017, 8024, 8033, 8232 },
     iconSpells = { 8232, 8033, 8024, 8017 } },
  E{ key = "rogue_poison_mh", name = "Poison (main hand)", class = "ROGUE", learnLevel = 20, selfOnly = true,
     kind = "weaponEnchant", slot = 16, castIDs = { 8681, 3408, 5761, 2823, 13219 }, iconSpells = { 8681 } },
  E{ key = "rogue_poison_oh", name = "Poison (off hand)", class = "ROGUE", learnLevel = 20, selfOnly = true,
     kind = "weaponEnchant", slot = 17, requiresOffhandWeapon = true,
     castIDs = { 8681, 3408, 5761, 2823, 13219 }, iconSpells = { 8681 } },

  ---------------------------------------------------------------------------
  -- Group buffs (tracked if the player knows them or an eligible member is present)
  ---------------------------------------------------------------------------
  E{ key = "fortitude", name = "Power Word: Fortitude", class = "PRIEST", learnLevel = 1,
     ids = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 }, iconSpells = { 1243 } },
  E{ key = "divine_spirit", name = "Divine Spirit", class = "PRIEST", learnLevel = 30,
     ids = { 14752, 14818, 14819, 27841, 27681 }, iconSpells = { 14752 } },
  E{ key = "shadow_protection", name = "Shadow Protection", class = "PRIEST", learnLevel = 30, defaultEnabled = false,
     ids = { 976, 10957, 10958, 27683 }, iconSpells = { 976 } },
  E{ key = "arcane_intellect", name = "Arcane Intellect", class = "MAGE", learnLevel = 1,
     ids = { 1459, 1460, 1461, 10156, 10157, 23028 }, iconSpells = { 1459 } },
  E{ key = "mark_of_the_wild", name = "Mark of the Wild", class = "DRUID", learnLevel = 1,
     ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 }, iconSpells = { 1126 } },
  E{ key = "blessing", name = "Blessing", class = "PALADIN", learnLevel = 4,
     castIDs = { 19740, 19742, 20217 },
     ids = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916,   -- Might
             19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918,          -- Wisdom
             20217, 25898,                                                    -- Kings
             1038, 25895,                                                     -- Salvation
             19977, 19978, 19979, 25890 },                                    -- Light
     iconSpells = { 20217, 19740 } },
  E{ key = "battle_shout", name = "Battle Shout", class = "WARRIOR", learnLevel = 1, quietFromOthers = true,
     ids = { 6673, 5242, 6192, 11549, 11550, 11551, 25289 }, iconSpells = { 6673 } },

  ---------------------------------------------------------------------------
  -- Consumables (any class)
  ---------------------------------------------------------------------------
  E{ key = "flask", name = "Flask", consumable = true, minLevel = 50,
     ids = { 17626, 17627, 17628, 17629 }, iconSpells = { 17626 } },
  E{ key = "elixir", name = "Elixir", consumable = true,
     ids = { 17538, 17539, 11474, 26276, 11390, 3593, 11348, 11349, 11405, 11334, 11406, 21920, 17535, 11396,
             24363, 24361, 17537, 2367, 3164, 11328 },
     iconSpells = { 17538 } },
  E{ key = "well_fed", name = "Well Fed", consumable = true, nameMatch = "Well Fed",
     ids = { 19705, 19706, 19708, 19709, 19710, 19711, 24799, 24870, 25661, 18192, 18194, 18222, 22730, 25941 },
     iconSpells = { 19705 } },
  E{ key = "weapon_mh", name = "Weapon Oil / Stone", consumable = true, kind = "weaponEnchant", slot = 16,
     castIDs = {}, iconSpells = { 8017 },
     excludeClasses = { SHAMAN = true, ROGUE = true }, defaultEnabledByClass = { HUNTER = false } },
  E{ key = "weapon_oh", name = "Weapon Oil / Stone (off hand)", consumable = true, kind = "weaponEnchant", slot = 17,
     requiresOffhandWeapon = true, castIDs = {}, iconSpells = { 8017 },
     excludeClasses = { SHAMAN = true, ROGUE = true }, defaultEnabledByClass = { HUNTER = false } },
}

Data.byKey = {}
for _, e in ipairs(Data.entries) do Data.byKey[e.key] = e end

-------------------------------------------------------------------------------
-- Recommended consumables by role and level (Classic item IDs).
-- Rows: { level=, itemID=, name=, classes=set|nil, weapon="edged"|"blunt"|nil }
-------------------------------------------------------------------------------
local function set(...) local s = {}; for i = 1, select("#", ...) do s[select(i, ...)] = true end; return s end

local STONES_EDGED = {
  { level = 1,  itemID = 2862,  name = "Rough Sharpening Stone", weapon = "edged" },
  { level = 10, itemID = 2863,  name = "Coarse Sharpening Stone", weapon = "edged" },
  { level = 20, itemID = 2871,  name = "Heavy Sharpening Stone", weapon = "edged" },
  { level = 35, itemID = 7964,  name = "Solid Sharpening Stone", weapon = "edged" },
  { level = 45, itemID = 12404, name = "Dense Sharpening Stone", weapon = "edged" },
  { level = 50, itemID = 18262, name = "Elemental Sharpening Stone", weapon = "edged" },
}
local STONES_BLUNT = {
  { level = 1,  itemID = 3239,  name = "Rough Weightstone", weapon = "blunt" },
  { level = 10, itemID = 3240,  name = "Coarse Weightstone", weapon = "blunt" },
  { level = 20, itemID = 3241,  name = "Heavy Weightstone", weapon = "blunt" },
  { level = 35, itemID = 7965,  name = "Solid Weightstone", weapon = "blunt" },
  { level = 45, itemID = 12643, name = "Dense Weightstone", weapon = "blunt" },
}
local function concat(...)
  local out = {}
  for i = 1, select("#", ...) do for _, row in ipairs((select(i, ...))) do out[#out + 1] = row end end
  return out
end
local OILS = {
  { level = 5,  itemID = 20744, name = "Minor Wizard Oil" },
  { level = 20, itemID = 20745, name = "Minor Mana Oil" },
  { level = 30, itemID = 20746, name = "Lesser Wizard Oil" },
  { level = 35, itemID = 20747, name = "Lesser Mana Oil" },
  { level = 40, itemID = 20750, name = "Wizard Oil" },
}
local WEAPON_CASTER = concat(OILS, { { level = 45, itemID = 20749, name = "Brilliant Wizard Oil" } })
local WEAPON_HEALER = concat(OILS, { { level = 45, itemID = 20748, name = "Brilliant Mana Oil" } })
local WEAPON_MELEE = concat(STONES_EDGED, STONES_BLUNT)

Data.RECOMMEND = {
  elixir = {
    Caster = {
      { level = 33, itemID = 6373,  name = "Elixir of Firepower", classes = set("MAGE") },
      { level = 37, itemID = 9155,  name = "Arcane Elixir" },
      { level = 40, itemID = 9264,  name = "Elixir of Shadow Power", classes = set("WARLOCK", "PRIEST") },
      { level = 47, itemID = 13454, name = "Greater Arcane Elixir" },
      { level = 50, itemID = 21546, name = "Elixir of Greater Firepower", classes = set("MAGE") },
    },
    Melee = {
      { level = 5,  itemID = 2454,  name = "Elixir of Lion's Strength" },
      { level = 20, itemID = 3391,  name = "Elixir of Ogre's Strength" },
      { level = 27, itemID = 8949,  name = "Elixir of Agility" },
      { level = 38, itemID = 9187,  name = "Elixir of Greater Agility" },
      { level = 46, itemID = 13452, name = "Elixir of the Mongoose" },
      { level = 46, itemID = 9206,  name = "Elixir of Giants", classes = set("WARRIOR", "PALADIN") },
    },
    Healer = {
      { level = 37, itemID = 9179,  name = "Elixir of Greater Intellect" },
      { level = 50, itemID = 20007, name = "Mageblood Potion" },
    },
    Tank = {
      { level = 25, itemID = 3825,  name = "Elixir of Fortitude" },
      { level = 43, itemID = 13445, name = "Elixir of Superior Defense" },
    },
  },
  flask = {
    Caster = { { level = 50, itemID = 13512, name = "Flask of Supreme Power" } },
    Healer = { { level = 50, itemID = 13511, name = "Flask of Distilled Wisdom" } },
    Melee  = { { level = 50, itemID = 13510, name = "Flask of the Titans" } },
    Tank   = { { level = 50, itemID = 13510, name = "Flask of the Titans" } },
  },
  well_fed = {
    Caster = { { level = 35, itemID = 13931, name = "Nightfin Soup" } },
    Healer = {
      { level = 30, itemID = 21217, name = "Sagefish Delight" },
      { level = 35, itemID = 13931, name = "Nightfin Soup" },
    },
    Melee = {
      { level = 45, itemID = 13928, name = "Grilled Squid", classes = set("ROGUE", "HUNTER") },
      { level = 45, itemID = 20452, name = "Smoked Desert Dumplings", classes = set("WARRIOR", "PALADIN") },
    },
    Tank = { { level = 55, itemID = 21023, name = "Dirge's Kickin' Chimaerok Chops" } },
  },
  weapon_mh = { Caster = WEAPON_CASTER, Healer = WEAPON_HEALER, Melee = WEAPON_MELEE, Tank = WEAPON_MELEE },
  weapon_oh = { Caster = WEAPON_CASTER, Healer = WEAPON_HEALER, Melee = WEAPON_MELEE, Tank = WEAPON_MELEE },
}

function Data.Recommend(key, class, role, level, weaponKind)
  local byRole = Data.RECOMMEND[key]
  if not byRole then return nil end
  local rows = byRole[role]
  if not rows then return nil end
  weaponKind = weaponKind or "edged"
  local best
  for _, row in ipairs(rows) do
    local okClass = not row.classes or row.classes[class]
    local okWeapon = not row.weapon or row.weapon == weaponKind
    if okClass and okWeapon and row.level <= (level or 0) and (not best or row.level >= best.level) then
      best = row
    end
  end
  if not best then return nil end
  return { itemID = best.itemID, name = best.name, level = best.level }
end

function Data.AllSpellIDs()
  local seen, out = {}, {}
  local function add(list)
    for _, id in ipairs(list or {}) do
      if not seen[id] then seen[id] = true; out[#out + 1] = id end
    end
  end
  for _, e in ipairs(Data.entries) do add(e.ids); add(e.castIDs); add(e.iconSpells) end
  return out
end

function Data.AllItemIDs()
  local seen, out = {}, {}
  for _, byRole in pairs(Data.RECOMMEND) do
    for _, rows in pairs(byRole) do
      for _, row in ipairs(rows) do
        if not seen[row.itemID] then seen[row.itemID] = true; out[#out + 1] = row.itemID end
      end
    end
  end
  table.sort(out)
  return out
end
