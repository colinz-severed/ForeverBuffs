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
     ids = { 465, 10290, 643, 10291, 1032, 10292, 10293,      -- Devotion
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
  E{ key = "trueshot_aura", name = "Trueshot Aura", class = "HUNTER", learnLevel = 40, selfOnly = true, mustBeOwn = true,
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
-- 1.2: rebuilt from Wowhead's Forever item data and Method's Forever list
-- (docs/superpowers/research/). No Forever per-class consumable guides exist
-- yet, so "roles" (which items get recommended) are inferred from effects.
-- At load time Data.ResolveItemSpells asks the game which buff each item
-- gives and merges it in, so presence covers items whose aura ID is unknown.
-------------------------------------------------------------------------------
local function set(...) local s = {}; for i = 1, select("#", ...) do s[select(i, ...)] = true end; return s end
local CASTER_HEALER = set("Caster", "Healer")
local MELEE_TANK = set("Melee", "Tank")

local function R(t) t.auraIDs = t.auraIDs or {}; return t end

Data.CATALOGUE = {
  elixir = {
    R{ itemID = 247754, name = "Minor Arcane Elixir",          level = 1,  summary = "+5 spell damage",            auraIDs = { 1245244 }, roles = set("Caster") },
    R{ itemID = 2457,   name = "Elixir of Minor Agility",      level = 2,  summary = "+4 Agility",                 auraIDs = { 2374 } },
    R{ itemID = 2458,   name = "Elixir of Minor Fortitude",    level = 2,  summary = "+27 Health",                 auraIDs = { 2378 } },
    R{ itemID = 2454,   name = "Elixir of Minor Strength",     level = 5,  summary = "+4 Strength",                auraIDs = { 2367 }, roles = set("Melee") },
    R{ itemID = 5997,   name = "Elixir of Minor Defense",      level = 5,  summary = "+50 Armor",                  auraIDs = { 673 } },
    R{ itemID = 3383,   name = "Elixir of Wisdom",             level = 10, summary = "+3 Intellect",               auraIDs = { 3166 } },
    R{ itemID = 3389,   name = "Elixir of Lesser Defense",     level = 16, summary = "+150 Armor",                 auraIDs = { 3220 } },
    R{ itemID = 3390,   name = "Elixir of Lesser Agility",     level = 18, summary = "+8 Agility",                 auraIDs = { 3160 } },
    R{ itemID = 6373,   name = "Elixir of Firepower",          level = 18, summary = "+10 Fire damage",            auraIDs = { 7844 }, roles = set("Caster"), classes = set("MAGE") },
    R{ itemID = 3391,   name = "Elixir of Ogre Strength",      level = 20, summary = "+8 Strength",                auraIDs = { 3164 }, roles = set("Melee") },
    R{ itemID = 3825,   name = "Elixir of Lesser Fortitude",   level = 25, summary = "+120 Health",                auraIDs = { 3593 }, roles = set("Tank") },
    R{ itemID = 8949,   name = "Elixir of Agility",            level = 27, summary = "+15 Agility",                auraIDs = { 11328 }, roles = set("Melee") },
    R{ itemID = 17708,  name = "Elixir of Frost Power",        level = 28, summary = "+15 Frost damage",           auraIDs = { 21920 } },
    R{ itemID = 8951,   name = "Elixir of Defense",            level = 29, summary = "+250 Armor",                 auraIDs = { 11349 } },
    R{ itemID = 9155,   name = "Arcane Elixir",                level = 37, summary = "+20 spell damage",           auraIDs = { 11390 }, roles = set("Caster") },
    R{ itemID = 9179,   name = "Elixir of Greater Intellect",  level = 37, summary = "+25 Intellect",              auraIDs = { 11396 }, roles = set("Healer") },
    R{ itemID = 9187,   name = "Elixir of Greater Agility",    level = 38, summary = "+25 Agility",                auraIDs = { 11334 }, roles = set("Melee") },
    R{ itemID = 13447,  name = "Elixir of the Sages",          level = 38, summary = "+18 Intellect and Spirit",   auraIDs = { 17535 } },
    R{ itemID = 9224,   name = "Potion of Demon Slaying",      level = 40, summary = "+180 attack power vs demons", auraIDs = { 11406 } },
    R{ itemID = 9264,   name = "Elixir of Shadow Power",       level = 40, summary = "+40 Shadow damage",          auraIDs = { 11474 }, roles = set("Caster"), classes = set("WARLOCK", "PRIEST") },
    R{ itemID = 20007,  name = "Mageblood Elixir",             level = 40, summary = "12 mana per 5 sec",          auraIDs = { 24363 }, roles = set("Healer") },
    R{ itemID = 13445,  name = "Elixir of Greater Defense",    level = 43, summary = "+450 Armor",                 auraIDs = { 11348 }, roles = set("Tank") },
    R{ itemID = 13453,  name = "Elixir of Brute Force",        level = 45, summary = "+18 Strength and Stamina",   auraIDs = { 17537 } },
    R{ itemID = 246948, name = "Distilled Firewater",          level = 45, summary = "+35 attack power",           auraIDs = { 17038 } },
    R{ itemID = 13452,  name = "Elixir of the Mongoose",       level = 46, summary = "+25 Agility, +2% crit",      auraIDs = { 17538 }, roles = set("Melee") },
    R{ itemID = 13454,  name = "Greater Arcane Elixir",        level = 47, summary = "+35 spell damage",           auraIDs = { 17539 }, roles = set("Caster") },
    R{ itemID = 9206,   name = "Elixir of Greater Strength",   level = 48, summary = "+25 Strength",               auraIDs = { 11405 }, roles = set("Melee"), classes = set("WARRIOR", "PALADIN") },
    R{ itemID = 21546,  name = "Elixir of Holy Power",         level = 50, summary = "+40 Holy damage",            auraIDs = { 1310077 } },
    R{ itemID = 20004,  name = "Major Troll's Blood Elixir",   level = 53, summary = "Health regeneration",        auraIDs = { 24361 } },
    R{ itemID = 250328, name = "Elixir of Cunning",            level = 55, summary = "+25 Agility and Intellect",  auraIDs = { 1250918 }, roles = set("Melee"), classes = set("HUNTER") },
    R{ itemID = 250329, name = "Elixir of the Phalanx",        level = 55, summary = "+400 Health, +500 Armor",    auraIDs = { 1250920 }, roles = set("Tank") },
    R{ itemID = 250333, name = "Greater Cleric's Elixir",      level = 55, summary = "+40 healing",                auraIDs = { 1250926 }, roles = set("Healer") },
    R{ itemID = 250335, name = "Elixir of Greater Fortitude",  level = 55, summary = "+400 Health",                auraIDs = { 1250931 } },
    R{ itemID = 250336, name = "Elixir of Wicked Regeneration", level = 55, summary = "9 health and 10 mana per 5 sec", auraIDs = { 1250932 } },
    R{ itemID = 250337, name = "Elixir of the Owl",            level = 55, summary = "+25 Intellect, +2% crit",    auraIDs = { 1250940 } },
    R{ itemID = 250338, name = "Elixir of Sages",              level = 55, summary = "+25 Spirit, +2% crit",       auraIDs = { 1250941 } },
    R{ itemID = 250341, name = "Greater Mageblood Elixir",     level = 55, summary = "20 mana per 5 sec",          auraIDs = { 1250948 } },
    R{ itemID = 250343, name = "Elixir of Nature Power",       level = 55, summary = "+40 Nature damage",          auraIDs = { 1250972 }, roles = set("Caster"), classes = set("DRUID", "SHAMAN") },
    R{ itemID = 250347, name = "Elixir of Greater Spirit",     level = 55, summary = "+18 Spirit",                 auraIDs = { 1250979 } },
    R{ itemID = 250348, name = "Elixir of the Whale",          level = 55, summary = "+25 Spirit, +2% crit",       auraIDs = { 1250981 } },
    R{ itemID = 250350, name = "Elixir of Ferocity",           level = 55, summary = "+18 Strength and Agility",   auraIDs = { 1250985 } },
    R{ itemID = 250351, name = "Elixir of the Grizzly",        level = 55, summary = "+25 Strength, +2% crit",     auraIDs = { 1250986 }, roles = set("Melee"), classes = set("WARRIOR", "PALADIN") },
  },
  flask = {
    R{ itemID = 13513,  name = "Flask of Chromatic Resistance", level = 50, summary = "+25 all resistances",     auraIDs = { 17629 } },
    R{ itemID = 13511,  name = "Flask of Distilled Wisdom",     level = 50, summary = "+2000 Mana",              auraIDs = { 17627 }, roles = set("Healer") },
    R{ itemID = 13512,  name = "Flask of Supreme Power",        level = 50, summary = "+150 spell damage",       auraIDs = { 17628 }, roles = set("Caster") },
    R{ itemID = 13510,  name = "Flask of the Titans",           level = 50, summary = "+1200 Health",            auraIDs = { 17626 }, roles = MELEE_TANK },
    R{ itemID = 274273, name = "Flask of Natural Accuracy",     level = 55, summary = "+30 Sta, +2% hit (Hyjal only)",       auraIDs = { 1293740 } },
    R{ itemID = 274274, name = "Flask of Aggression",           level = 55, summary = "+30 Sta, +2% crit (Hyjal only)",      auraIDs = { 1293741 } },
    R{ itemID = 274275, name = "Flask of Precision",            level = 55, summary = "+30 Sta, -2% dodge/parry (Hyjal only)", auraIDs = { 1293742 } },
    R{ itemID = 274276, name = "Flask of Swiftness",            level = 55, summary = "+30 Sta, +2% haste (Hyjal only)",     auraIDs = { 1293743 } },
  },
  well_fed = {
    R{ itemID = 6888,   name = "Herb Baked Egg",                 level = 1,  summary = "+1 Stamina",            auraIDs = { 19705 } },
    R{ itemID = 3726,   name = "Big Bear Steak",                 level = 5,  summary = "+3 Strength",           auraIDs = { 19706 }, roles = set("Melee"), classes = set("WARRIOR", "PALADIN") },
    R{ itemID = 21072,  name = "Smoked Sagefish",                level = 10, summary = "+4 spell damage",       auraIDs = { 25694 }, roles = CASTER_HEALER },
    R{ itemID = 12210,  name = "Roast Raptor",                   level = 15, summary = "+5 Intellect",          auraIDs = {} },
    R{ itemID = 21217,  name = "Sagefish Delight",               level = 30, summary = "+7 spell damage",       auraIDs = { 25941 }, roles = CASTER_HEALER },
    R{ itemID = 12212,  name = "Jungle Stew",                    level = 35, summary = "+15 Agility",           auraIDs = {} },
    R{ itemID = 12218,  name = "Monster Omelet",                 level = 35, summary = "+15 Stamina",           auraIDs = { 19710 }, roles = set("Tank") },
    R{ itemID = 13931,  name = "Nightfin Soup",                  level = 35, summary = "+22 spell damage",      auraIDs = { 1249520 }, roles = set("Caster") },
    R{ itemID = 13932,  name = "Poached Sunscale Salmon",        level = 35, summary = "+40 attack power",      auraIDs = { 1249519 } },
    R{ itemID = 13928,  name = "Grilled Squid",                  level = 35, summary = "+1% crit",              auraIDs = { 18192 } },
    R{ itemID = 18045,  name = "Tender Wolf Steak",              level = 35, summary = "+15 Agility",           auraIDs = { 22790 }, roles = set("Melee"), classes = set("ROGUE", "HUNTER") },
    R{ itemID = 18254,  name = "Runn Tum Tuber Surprise",        level = 35, summary = "+15 Intellect",         auraIDs = { 22730 } },
    R{ itemID = 250065, name = "Savory Stag Sliders",            level = 35, summary = "+15 Strength",          auraIDs = {}, roles = set("Melee"), classes = set("WARRIOR", "PALADIN") },
    R{ itemID = 250076, name = "Raptor Rouladen",                level = 35, summary = "+15 Intellect",         auraIDs = {} },
    R{ itemID = 249869, name = "Sunny Tea",                      level = 35, summary = "+33 healing",           auraIDs = {}, roles = set("Healer") },
    R{ itemID = 13810,  name = "Blessed Sunfruit",               level = 45, summary = "+10 Strength",          auraIDs = { 18125 } },
    R{ itemID = 13813,  name = "Blessed Sunfruit Juice",         level = 45, summary = "+10 Spirit",            auraIDs = { 18141 } },
    R{ itemID = 13934,  name = "Mightfish Steak",                level = 45, summary = "+40 attack power",      auraIDs = { 1249519 } },
    R{ itemID = 13935,  name = "Baked Salmon",                   level = 45, summary = "+28 spell damage",      auraIDs = { 1249520 }, roles = set("Caster") },
    R{ itemID = 20452,  name = "Smoked Desert Dumplings",        level = 45, summary = "+20 Strength",          auraIDs = { 1248422 }, roles = set("Melee"), classes = set("WARRIOR", "PALADIN") },
    R{ itemID = 21023,  name = "Dirge's Kickin' Chimaerok Chops", level = 45, summary = "+25 Stamina",          auraIDs = { 25661 }, roles = set("Tank") },
    R{ itemID = 249870, name = "Sage's Tea",                     level = 45, summary = "+44 healing",           auraIDs = { 1249927 }, roles = set("Healer") },
    R{ itemID = 250068, name = "Savory Turtle Stew",             level = 45, summary = "+20 Stamina",           auraIDs = { 1248406 } },
    R{ itemID = 250071, name = "Steaming Stag Steak",            level = 45, summary = "+20 Strength",          auraIDs = {} },
    R{ itemID = 250072, name = "Swiftstrike Steak",              level = 45, summary = "+20 Agility",           auraIDs = { 1248420 }, roles = set("Melee"), classes = set("ROGUE", "HUNTER") },
  },
  weapon = {
    R{ itemID = 2862,  name = "Rough Sharpening Stone",     level = 1,  summary = "+2 weapon damage",      roles = MELEE_TANK, weapon = "edged" },
    R{ itemID = 3239,  name = "Rough Weightstone",          level = 1,  summary = "+2 weapon damage",      roles = MELEE_TANK, weapon = "blunt" },
    R{ itemID = 2863,  name = "Coarse Sharpening Stone",    level = 5,  summary = "+3 weapon damage",      roles = MELEE_TANK, weapon = "edged" },
    R{ itemID = 3240,  name = "Coarse Weightstone",         level = 5,  summary = "+3 weapon damage",      roles = MELEE_TANK, weapon = "blunt" },
    R{ itemID = 20744, name = "Minor Wizard Oil",           level = 5,  summary = "+8 spell damage and healing", roles = CASTER_HEALER, weapon = "oil" },
    R{ itemID = 2871,  name = "Heavy Sharpening Stone",     level = 15, summary = "+4 weapon damage",      roles = MELEE_TANK, weapon = "edged" },
    R{ itemID = 3241,  name = "Heavy Weightstone",          level = 15, summary = "+4 weapon damage",      roles = MELEE_TANK, weapon = "blunt" },
    R{ itemID = 20745, name = "Minor Mana Oil",             level = 20, summary = "5 mana per 5 sec, +10 healing", roles = set("Healer"), weapon = "oil" },
    R{ itemID = 7964,  name = "Solid Sharpening Stone",     level = 25, summary = "+6 weapon damage",      roles = MELEE_TANK, weapon = "edged" },
    R{ itemID = 7965,  name = "Solid Weightstone",          level = 25, summary = "+6 weapon damage",      roles = MELEE_TANK, weapon = "blunt" },
    R{ itemID = 20746, name = "Lesser Wizard Oil",          level = 30, summary = "+16 spell damage and healing", roles = CASTER_HEALER, weapon = "oil" },
    R{ itemID = 12404, name = "Dense Sharpening Stone",     level = 35, summary = "+8 weapon damage",      roles = MELEE_TANK, weapon = "edged" },
    R{ itemID = 12643, name = "Dense Weightstone",          level = 35, summary = "+8 weapon damage",      roles = MELEE_TANK, weapon = "blunt" },
    R{ itemID = 20747, name = "Lesser Mana Oil",            level = 40, summary = "10 mana per 5 sec, +20 healing", roles = set("Healer"), weapon = "oil" },
    R{ itemID = 20750, name = "Wizard Oil",                 level = 40, summary = "+24 spell damage and healing", roles = CASTER_HEALER, weapon = "oil" },
    R{ itemID = 20748, name = "Brilliant Mana Oil",         level = 45, summary = "15 mana per 5 sec, +30 healing", roles = set("Healer"), weapon = "oil" },
    R{ itemID = 20749, name = "Brilliant Wizard Oil",       level = 45, summary = "+36 spell damage and healing, +1% spell crit", roles = CASTER_HEALER, weapon = "oil" },
    R{ itemID = 18262, name = "Elemental Sharpening Stone", level = 50, summary = "+2% crit",              roles = MELEE_TANK, weapon = "edged" },
    R{ itemID = 23122, name = "Consecrated Sharpening Stone", level = 50, summary = "+100 attack power vs undead", weapon = "edged" },
    R{ itemID = 23123, name = "Blessed Wizard Oil",         level = 50, summary = "+60 spell damage vs undead", weapon = "oil" },
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

-- Adds the buff spell each catalogue item casts (from resolveFn(itemID)) to the
-- row and its category entry. Idempotent. Returns how many IDs were added to
-- category entries. onlyItems (optional set) limits the pass to those items.
function Data.ResolveItemSpells(resolveFn, onlyItems)
  local added = 0
  for cat, rows in pairs(Data.CATALOGUE) do
    local entry = (cat ~= "weapon") and Data.byKey[cat] or nil
    for _, r in ipairs(rows) do
      if not onlyItems or onlyItems[r.itemID] then
        local spell = resolveFn(r.itemID)
        if spell then
          r.resolvedSpell = spell
          local have = false
          for _, a in ipairs(r.auraIDs) do if a == spell then have = true end end
          if not have then r.auraIDs[#r.auraIDs + 1] = spell end
          if entry then
            local inEntry = false
            for _, id in ipairs(entry.ids) do if id == spell then inEntry = true end end
            if not inEntry then entry.ids[#entry.ids + 1] = spell; added = added + 1 end
          end
        end
      end
    end
  end
  return added
end

-- Rank summary for an entry's ladders (entry.ranks = { { family=, spells = {
-- { id=, rank=, level= }, ... } }, ... }). Chooses the ladder of the first
-- iconSpells family the player knows, else the first known ladder, else the
-- first ladder. available = any ladder has an unlearned rank at or below level.
function Data.RankInfo(entry, knowsFn, playerLevel)
  local ladders = entry.ranks
  if not ladders or #ladders == 0 then return nil end
  local function knownRank(ladder)
    local best = 0
    for _, sp in ipairs(ladder.spells) do if knowsFn(sp.id) and sp.rank > best then best = sp.rank end end
    return best
  end
  local chosen
  for _, iconID in ipairs(entry.iconSpells or {}) do
    if chosen then break end
    for _, ladder in ipairs(ladders) do
      for _, sp in ipairs(ladder.spells) do
        if sp.id == iconID and knownRank(ladder) > 0 then chosen = ladder end
      end
    end
  end
  if not chosen then
    for _, ladder in ipairs(ladders) do if knownRank(ladder) > 0 then chosen = ladder; break end end
  end
  chosen = chosen or ladders[1]
  local known = knownRank(chosen)
  local nextLevel
  for _, sp in ipairs(chosen.spells) do
    if sp.rank > known and (not nextLevel or sp.level < nextLevel) then nextLevel = sp.level end
  end
  local available = false
  for _, ladder in ipairs(ladders) do
    local k = knownRank(ladder)
    for _, sp in ipairs(ladder.spells) do
      if sp.rank > k and sp.level <= (playerLevel or 0) then available = true end
    end
  end
  local minL, maxL
  for _, sp in ipairs(chosen.spells) do
    minL = math.min(minL or sp.level, sp.level); maxL = math.max(maxL or sp.level, sp.level)
  end
  return { family = chosen.family, known = known, total = #chosen.spells, nextLevel = nextLevel,
           available = available, minLevel = minL, maxLevel = maxL }
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

-------------------------------------------------------------------------------
-- Generated data (DataGen.lua): consumable sources, spell rank ladders, and
-- the learned poison spells (rank 1 cast spells on Forever).
-------------------------------------------------------------------------------
local G = FB.DataGen or {}

for _, rows in pairs(Data.CATALOGUE) do
  for _, r in ipairs(rows) do r.source = G.SOURCES and G.SOURCES[r.itemID] or nil end
end

Data.FAMILIES = {
  fortitude = { "Power Word: Fortitude", "Prayer of Fortitude" },
  divine_spirit = { "Divine Spirit", "Prayer of Spirit" },
  shadow_protection = { "Shadow Protection", "Prayer of Shadow Protection" },
  inner_fire = { "Inner Fire" },
  arcane_intellect = { "Arcane Intellect", "Arcane Brilliance" },
  mage_armor = { "Mage Armor", "Ice Armor", "Frost Armor" },
  warlock_armor = { "Demon Armor", "Demon Skin" },
  mark_of_the_wild = { "Mark of the Wild", "Gift of the Wild" },
  thorns = { "Thorns" },
  blessing = { "Blessing of Kings", "Blessing of Might", "Blessing of Wisdom",
               "Greater Blessing of Kings", "Greater Blessing of Might", "Greater Blessing of Wisdom" },
  paladin_aura = { "Devotion Aura", "Retribution Aura", "Concentration Aura",
                   "Shadow Resistance Aura", "Frost Resistance Aura", "Fire Resistance Aura" },
  righteous_fury = { "Righteous Fury" },
  battle_shout = { "Battle Shout" },
  hunter_aspect = { "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Wild" },
  trueshot_aura = { "Trueshot Aura" },
  lightning_shield = { "Lightning Shield" },
  shaman_imbue = { "Windfury Weapon", "Frostbrand Weapon", "Flametongue Weapon", "Rockbiter Weapon" },
  rogue_poison_mh = { "Instant Poison", "Deadly Poison", "Crippling Poison", "Mind-numbing Poison", "Wound Poison" },
  rogue_poison_oh = { "Instant Poison", "Deadly Poison", "Crippling Poison", "Mind-numbing Poison", "Wound Poison" },
}

for key, families in pairs(Data.FAMILIES) do
  local entry = Data.byKey[key]
  if entry then
    local ladders = {}
    for _, family in ipairs(families) do
      local spells = G.LADDERS and G.LADDERS[family]
      if spells and #spells > 0 then ladders[#ladders + 1] = { family = family, spells = spells } end
    end
    if #ladders > 0 then entry.ranks = ladders end
  end
end

-- Poisons are learned spells on Forever: "knows the spell" uses the cast IDs.
if G.POISON_CAST then
  local casts = {}
  for _, family in ipairs({ "Instant Poison", "Crippling Poison", "Mind-numbing Poison", "Deadly Poison", "Wound Poison" }) do
    if G.POISON_CAST[family] then casts[#casts + 1] = G.POISON_CAST[family] end
  end
  if #casts > 0 then
    for _, key in ipairs({ "rogue_poison_mh", "rogue_poison_oh" }) do Data.byKey[key].castIDs = casts end
  end
end
