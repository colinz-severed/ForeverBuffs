local ADDON, FB = ...
FB.Data = FB.Data or {}
local Data = FB.Data

-------------------------------------------------------------------------------
-- Buff entries for World of Warcraft: Forever (client 1.60.1).
-- Spell IDs are the Classic IDs, which Forever keeps. Learn levels from the
-- Forever spellbook. IDs verified against wowhead.com/forever and in-game
-- /fbuffs ids on 2026-11-08 (Forever 1.60.1): every spell and item ID below
-- resolves on the client.
--
-- Entry fields:
--   key, name, class (nil = consumable), learnLevel, selfOnly, kind ("aura" |
--   "weaponEnchant"), castIDs (default = ids), ids, nameMatch, iconSpells
--   (first known wins, else last), defaultEnabled, defaultEnabledByClass,
--   mustBeOwn, slot, requiresOffhandWeapon, consumable,
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
             20217, 25898 },                                                  -- Kings
             -- Salvation (1038, 25895) and Light (19977-19979, 25890) do not exist on Forever
     iconSpells = { 20217, 19740 } },
  E{ key = "battle_shout", name = "Battle Shout", class = "WARRIOR", learnLevel = 1,
     ids = { 6673, 5242, 6192, 11549, 11550, 11551, 25289 }, iconSpells = { 6673 } },

  ---------------------------------------------------------------------------
  -- Consumables (any class)
  ---------------------------------------------------------------------------
  E{ key = "flask", name = "Flask", consumable = true, minLevel = 50,
     ids = { 17626, 17627, 17628, 17629 }, iconSpells = { 17626 } },
  E{ key = "elixir", name = "Elixir", consumable = true,
     ids = { 17538, 17539, 11474, 26276, 11390, 3593, 11348, 11349, 11405, 11334, 11406, 21920, 11396,
             24363, 17537, 2367, 3164, 11328 },
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
-- Priorities
-------------------------------------------------------------------------------
Data.PRIORITIES = { "high", "normal", "low" }
function Data.DefaultPriority(reason)
  if reason == "known" then return "normal" end
  return "low"
end

-------------------------------------------------------------------------------
-- Consumables catalogue (Classic item IDs, which Forever keeps).
-- Row: { itemID, name, level (required level), summary, roles=set|nil
--        (recommended for these roles; nil = listed only), classes=set|nil,
--        weapon="edged"|"blunt"|"oil"|nil, auraIDs={...} }
-- Aura IDs are best-effort: presence is checked against the whole category,
-- so a wrong mapping cannot cause a false reminder as long as the ID exists.
-------------------------------------------------------------------------------
local function set(...) local s = {}; for i = 1, select("#", ...) do s[select(i, ...)] = true end; return s end
local CASTER_HEALER = set("Caster", "Healer")
local MELEE_TANK = set("Melee", "Tank")

local function R(t) t.auraIDs = t.auraIDs or {}; return t end

Data.CATALOGUE = {
  elixir = {
    R{ itemID = 2457,  name = "Elixir of Minor Agility",     level = 5,  summary = "+4 Agility",            auraIDs = { 2374 } },
    R{ itemID = 2454,  name = "Elixir of Lion's Strength",   level = 5,  summary = "+4 Strength",           auraIDs = { 2367 }, roles = set("Melee") },
    R{ itemID = 5997,  name = "Elixir of Minor Defense",     level = 5,  summary = "+50 Armor",             auraIDs = { 673 } },
    R{ itemID = 2458,  name = "Elixir of Minor Fortitude",   level = 5,  summary = "+27 Health",            auraIDs = { 2378 } },
    R{ itemID = 3383,  name = "Elixir of Wisdom",            level = 10, summary = "+6 Intellect",          auraIDs = { 3166 } },
    R{ itemID = 3389,  name = "Elixir of Defense",           level = 16, summary = "+150 Armor",            auraIDs = { 3220 } },
    R{ itemID = 3390,  name = "Elixir of Lesser Agility",    level = 18, summary = "+8 Agility",            auraIDs = { 3160 } },
    R{ itemID = 3391,  name = "Elixir of Ogre's Strength",   level = 20, summary = "+8 Strength",           auraIDs = { 3164 }, roles = set("Melee") },
    R{ itemID = 3825,  name = "Elixir of Fortitude",         level = 25, summary = "+120 Health",           auraIDs = { 3593 }, roles = set("Tank") },
    R{ itemID = 8949,  name = "Elixir of Agility",           level = 27, summary = "+15 Agility",           auraIDs = { 11328 }, roles = set("Melee") },
    R{ itemID = 8951,  name = "Elixir of Greater Defense",   level = 29, summary = "+250 Armor",            auraIDs = { 11349 } },
    R{ itemID = 6373,  name = "Elixir of Firepower",         level = 33, summary = "+10 Fire damage",       auraIDs = { 7844 }, roles = set("Caster"), classes = set("MAGE") },
    R{ itemID = 9155,  name = "Arcane Elixir",               level = 37, summary = "+20 spell damage",      auraIDs = { 11390 }, roles = set("Caster") },
    R{ itemID = 9179,  name = "Elixir of Greater Intellect", level = 37, summary = "+25 Intellect",         auraIDs = { 11396 }, roles = set("Healer") },
    R{ itemID = 9187,  name = "Elixir of Greater Agility",   level = 38, summary = "+25 Agility",           auraIDs = { 11334 }, roles = set("Melee") },
    R{ itemID = 17708, name = "Elixir of Frost Power",       level = 40, summary = "+15 Frost damage",      auraIDs = { 21920 } },
    R{ itemID = 9264,  name = "Elixir of Shadow Power",      level = 40, summary = "+40 Shadow damage",     auraIDs = { 11474 }, roles = set("Caster"), classes = set("WARLOCK", "PRIEST") },
    R{ itemID = 9224,  name = "Elixir of Demonslaying",      level = 40, summary = "+265 attack power vs demons", auraIDs = { 11406 } },
    R{ itemID = 13445, name = "Elixir of Superior Defense",  level = 43, summary = "+450 Armor",            auraIDs = { 11348 }, roles = set("Tank") },
    R{ itemID = 9206,  name = "Elixir of Giants",            level = 46, summary = "+25 Strength",          auraIDs = { 11405 }, roles = set("Melee"), classes = set("WARRIOR", "PALADIN") },
    R{ itemID = 13452, name = "Elixir of the Mongoose",      level = 46, summary = "+25 Agility, +2% crit", auraIDs = { 17538 }, roles = set("Melee") },
    R{ itemID = 13454, name = "Greater Arcane Elixir",       level = 47, summary = "+35 spell damage",      auraIDs = { 17539 }, roles = set("Caster") },
    R{ itemID = 13453, name = "Elixir of Brute Force",       level = 50, summary = "+18 Strength and Stamina", auraIDs = { 17537 } },
    R{ itemID = 21546, name = "Elixir of Greater Firepower", level = 50, summary = "+40 Fire damage",       auraIDs = { 26276 }, roles = set("Caster"), classes = set("MAGE") },
    R{ itemID = 20007, name = "Mageblood Potion",            level = 50, summary = "12 mana per 5 sec",     auraIDs = { 24363 }, roles = set("Healer") },
  },
  flask = {
    R{ itemID = 13513, name = "Flask of Chromatic Resistance", level = 50, summary = "+25 all resistances", auraIDs = { 17629 } },
    R{ itemID = 13511, name = "Flask of Distilled Wisdom",     level = 50, summary = "+2000 Mana",           auraIDs = { 17627 }, roles = set("Healer") },
    R{ itemID = 13512, name = "Flask of Supreme Power",        level = 50, summary = "+150 spell damage",    auraIDs = { 17628 }, roles = set("Caster") },
    R{ itemID = 13510, name = "Flask of the Titans",           level = 50, summary = "+1200 Health",         auraIDs = { 17626 }, roles = MELEE_TANK },
  },
  well_fed = {
    R{ itemID = 6888,  name = "Herb Baked Egg",                 level = 1,  summary = "+2 Stamina and Spirit",  auraIDs = { 19705 } },
    R{ itemID = 3726,  name = "Big Bear Steak",                 level = 10, summary = "+4 Stamina and Spirit",  auraIDs = { 19706 } },
    R{ itemID = 21072, name = "Smoked Sagefish",                level = 10, summary = "3 mana per 5 sec",       auraIDs = { 25694 } },
    R{ itemID = 12212, name = "Hot Lion Chops",                 level = 25, summary = "+8 Stamina and Spirit",  auraIDs = { 19708 } },
    R{ itemID = 21217, name = "Sagefish Delight",               level = 30, summary = "6 mana per 5 sec",       auraIDs = { 25941 }, roles = set("Healer") },
    R{ itemID = 12218, name = "Monster Omelet",                 level = 35, summary = "+12 Stamina and Spirit", auraIDs = { 19710 } },
    R{ itemID = 13931, name = "Nightfin Soup",                  level = 35, summary = "8 mana per 5 sec",       auraIDs = { 18194 }, roles = CASTER_HEALER },
    R{ itemID = 18045, name = "Tender Wolf Steak",              level = 40, summary = "+12 Stamina and Spirit", auraIDs = { 22790 } },
    R{ itemID = 13810, name = "Blessed Sunfruit",               level = 45, summary = "+10 Strength",           auraIDs = { 18125 } },
    R{ itemID = 13813, name = "Blessed Sunfruit Juice",         level = 45, summary = "+10 Spirit",             auraIDs = { 18141 } },
    R{ itemID = 13928, name = "Grilled Squid",                  level = 45, summary = "+10 Agility",            auraIDs = { 18192 }, roles = set("Melee"), classes = set("ROGUE", "HUNTER") },
    R{ itemID = 18254, name = "Runn Tum Tuber Surprise",        level = 45, summary = "+10 Intellect",          auraIDs = { 22730 } },
    R{ itemID = 20452, name = "Smoked Desert Dumplings",        level = 45, summary = "+20 Strength",           auraIDs = { 24799 }, roles = set("Melee"), classes = set("WARRIOR", "PALADIN") },
    R{ itemID = 21023, name = "Dirge's Kickin' Chimaerok Chops", level = 55, summary = "+25 Stamina",          auraIDs = { 25661 }, roles = set("Tank") },
  },
  weapon = {
    R{ itemID = 2862,  name = "Rough Sharpening Stone",     level = 1,  summary = "+2 weapon damage",      roles = MELEE_TANK, weapon = "edged" },
    R{ itemID = 3239,  name = "Rough Weightstone",          level = 1,  summary = "+2 weapon damage",      roles = MELEE_TANK, weapon = "blunt" },
    R{ itemID = 20744, name = "Minor Wizard Oil",           level = 5,  summary = "+8 spell damage",       roles = CASTER_HEALER, weapon = "oil" },
    R{ itemID = 2863,  name = "Coarse Sharpening Stone",    level = 10, summary = "+3 weapon damage",      roles = MELEE_TANK, weapon = "edged" },
    R{ itemID = 3240,  name = "Coarse Weightstone",         level = 10, summary = "+3 weapon damage",      roles = MELEE_TANK, weapon = "blunt" },
    R{ itemID = 2871,  name = "Heavy Sharpening Stone",     level = 20, summary = "+4 weapon damage",      roles = MELEE_TANK, weapon = "edged" },
    R{ itemID = 3241,  name = "Heavy Weightstone",          level = 20, summary = "+4 weapon damage",      roles = MELEE_TANK, weapon = "blunt" },
    R{ itemID = 20745, name = "Minor Mana Oil",             level = 20, summary = "4 mana per 5 sec",      roles = CASTER_HEALER, weapon = "oil" },
    R{ itemID = 20746, name = "Lesser Wizard Oil",          level = 30, summary = "+16 spell damage",      roles = CASTER_HEALER, weapon = "oil" },
    R{ itemID = 7964,  name = "Solid Sharpening Stone",     level = 35, summary = "+6 weapon damage",      roles = MELEE_TANK, weapon = "edged" },
    R{ itemID = 7965,  name = "Solid Weightstone",          level = 35, summary = "+6 weapon damage",      roles = MELEE_TANK, weapon = "blunt" },
    R{ itemID = 20747, name = "Lesser Mana Oil",            level = 35, summary = "8 mana per 5 sec",      roles = CASTER_HEALER, weapon = "oil" },
    R{ itemID = 20750, name = "Wizard Oil",                 level = 40, summary = "+24 spell damage",      roles = CASTER_HEALER, weapon = "oil" },
    R{ itemID = 12404, name = "Dense Sharpening Stone",     level = 45, summary = "+8 weapon damage",      roles = MELEE_TANK, weapon = "edged" },
    R{ itemID = 12643, name = "Dense Weightstone",          level = 45, summary = "+8 weapon damage",      roles = MELEE_TANK, weapon = "blunt" },
    R{ itemID = 20748, name = "Brilliant Mana Oil",         level = 45, summary = "12 mana per 5 sec, +25 healing", roles = set("Healer"), weapon = "oil" },
    R{ itemID = 20749, name = "Brilliant Wizard Oil",       level = 45, summary = "+36 spell damage, +1% spell crit", roles = set("Caster"), weapon = "oil" },
    R{ itemID = 18262, name = "Elemental Sharpening Stone", level = 50, summary = "+2% crit",              roles = MELEE_TANK, weapon = "edged" },
  },
}

-- Sort each category by level, then name; build lookups.
local CATALOGUE_INDEX = {}
for cat, rows in pairs(Data.CATALOGUE) do
  table.sort(rows, function(a, b) if a.level ~= b.level then return a.level < b.level end; return a.name < b.name end)
  CATALOGUE_INDEX[cat] = {}
  for _, r in ipairs(rows) do CATALOGUE_INDEX[cat][r.itemID] = r end
end

local CATEGORY_OF = { flask = "flask", elixir = "elixir", well_fed = "well_fed", weapon_mh = "weapon", weapon_oh = "weapon" }
function Data.CategoryOf(key) return CATEGORY_OF[key] end
function Data.CatalogueItem(category, itemID) local idx = CATALOGUE_INDEX[category]; return idx and idx[itemID] or nil end

-- Merge every catalogue aura ID into the category entry's ids.
for _, cat in ipairs({ "flask", "elixir", "well_fed" }) do
  local entry = Data.byKey[cat]
  local have = {}
  for _, id in ipairs(entry.ids) do have[id] = true end
  for _, r in ipairs(Data.CATALOGUE[cat]) do
    for _, a in ipairs(r.auraIDs) do
      if not have[a] then have[a] = true; entry.ids[#entry.ids + 1] = a end
    end
  end
end

-- Recommendation table derived from the catalogue: key -> role -> ordered rows.
Data.RECOMMEND = {}
local function addRecommend(key, cat)
  Data.RECOMMEND[key] = {}
  for _, role in ipairs(Data.ROLES) do
    local out = {}
    for _, r in ipairs(Data.CATALOGUE[cat]) do
      if r.roles and r.roles[role] then
        out[#out + 1] = { level = r.level, itemID = r.itemID, name = r.name, classes = r.classes, weapon = r.weapon }
      end
    end
    Data.RECOMMEND[key][role] = out
  end
end
for key, cat in pairs(CATEGORY_OF) do addRecommend(key, cat) end

-- Highest-level qualifying row at or below the player's level. Ties: a
-- class-specific row beats a generic one, otherwise the later row wins.
function Data.Recommend(key, class, role, level, weaponKind)
  local byRole = Data.RECOMMEND[key]
  if not byRole then return nil end
  local rows = byRole[role]
  if not rows then return nil end
  weaponKind = weaponKind or "edged"
  local best
  for _, row in ipairs(rows) do
    local okClass = not row.classes or row.classes[class]
    local okWeapon = not row.weapon or row.weapon == "oil" or row.weapon == weaponKind
    if okClass and okWeapon and row.level <= (level or 0) then
      if not best or row.level > best.level
         or (row.level == best.level and (row.classes ~= nil or best.classes == nil)) then
        best = row
      end
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
  for _, rows in pairs(Data.CATALOGUE) do
    for _, row in ipairs(rows) do
      if not seen[row.itemID] then seen[row.itemID] = true; out[#out + 1] = row.itemID end
    end
  end
  table.sort(out)
  return out
end
