T.test("every entry is well-formed and keys are unique", function()
  local seen = {}
  for _, e in ipairs(FB.Data.entries) do
    T.truthy(e.key and not seen[e.key], "dup/missing key " .. tostring(e.key)); seen[e.key] = true
    T.truthy(e.name and e.ids and #e.ids > 0 or e.kind == "weaponEnchant", e.key)
    T.truthy(e.kind == "aura" or e.kind == "weaponEnchant", e.key)
    T.truthy(#e.iconSpells >= 1, e.key)
    if e.kind == "weaponEnchant" then T.truthy(e.slot == 16 or e.slot == 17, e.key) end
    if e.class then T.truthy(e.learnLevel, e.key) else T.truthy(e.consumable, e.key) end
    T.eq(FB.Data.byKey[e.key], e)
  end
end)
T.test("spec entries exist with spec values", function()
  local d = FB.Data.byKey
  T.eq(d.inner_fire.learnLevel, 12); T.eq(d.inner_fire.class, "PRIEST"); T.truthy(d.inner_fire.selfOnly)
  T.eq(d.fortitude.learnLevel, 1);   T.falsy(d.fortitude.selfOnly)
  T.eq(d.divine_spirit.learnLevel, 30); T.eq(d.shadow_protection.defaultEnabled, false)
  T.eq(d.blessing.learnLevel, 4);    T.eq(d.blessing.iconSpells[1], 20217); T.eq(d.blessing.iconSpells[2], 19740)
  T.truthy(d.paladin_aura.mustBeOwn and d.hunter_aspect.mustBeOwn and d.trueshot_aura.mustBeOwn)
  T.eq(d.righteous_fury.defaultEnabled, false)
  T.eq(d.mage_armor.iconSpells[1], 6117); T.eq(d.mage_armor.iconSpells[3], 168)
  T.eq(d.shaman_imbue.kind, "weaponEnchant"); T.eq(d.shaman_imbue.slot, 16); T.eq(d.shaman_imbue.iconSpells[1], 8232)
  T.eq(d.rogue_poison_oh.slot, 17); T.truthy(d.rogue_poison_oh.requiresOffhandWeapon); T.eq(d.rogue_poison_oh.learnLevel, 20)
  T.truthy(d.flask.consumable and d.elixir.consumable and d.well_fed.consumable)
  T.eq(d.well_fed.nameMatch, "Well Fed"); T.eq(d.flask.ids[1], 17626); T.eq(d.flask.minLevel, 50)
  T.eq(d.weapon_mh.kind, "weaponEnchant"); T.eq(d.weapon_mh.slot, 16); T.truthy(d.weapon_mh.consumable)
  T.truthy(d.weapon_mh.excludeClasses.SHAMAN and d.weapon_mh.excludeClasses.ROGUE); T.eq(d.weapon_mh.defaultEnabledByClass.HUNTER, false)
  T.eq(d.weapon_oh.slot, 17); T.truthy(d.weapon_oh.requiresOffhandWeapon)
end)
T.test("DefaultRole and Recommend", function()
  T.eq(FB.Data.DefaultRole("MAGE"), "Caster"); T.eq(FB.Data.DefaultRole("WARRIOR"), "Melee"); T.eq(FB.Data.DefaultRole("PALADIN"), "Healer")
  T.eq(FB.Data.Recommend("elixir", "MAGE", "Caster", 60).itemID, 13454)
  T.eq(FB.Data.Recommend("elixir", "WARLOCK", "Caster", 60).itemID, 13454)    -- no Firepower for warlocks
  T.eq(FB.Data.Recommend("elixir", "WARLOCK", "Caster", 45).itemID, 9264)     -- Shadow Power at 40
  T.eq(FB.Data.Recommend("elixir", "ROGUE", "Melee", 60).itemID, 13452)
  T.eq(FB.Data.Recommend("elixir", "WARRIOR", "Melee", 60).itemID, 250351)
  T.eq(FB.Data.Recommend("elixir", "WARRIOR", "Tank", 30).itemID, 3825)
  T.eq(FB.Data.Recommend("flask", "PRIEST", "Healer", 60).itemID, 13511); T.eq(FB.Data.Recommend("flask", "PRIEST", "Healer", 49), nil)
  T.eq(FB.Data.Recommend("well_fed", "WARRIOR", "Melee", 60).itemID, 20452); T.eq(FB.Data.Recommend("well_fed", "ROGUE", "Melee", 60).itemID, 250072)
  T.eq(FB.Data.Recommend("weapon_mh", "MAGE", "Caster", 60).itemID, 20749); T.eq(FB.Data.Recommend("weapon_mh", "PRIEST", "Healer", 60).itemID, 20749)
  T.eq(FB.Data.Recommend("weapon_mh", "WARRIOR", "Melee", 60, "edged").itemID, 18262)
  T.eq(FB.Data.Recommend("weapon_mh", "WARRIOR", "Melee", 60, "blunt").itemID, 12643)
  T.eq(FB.Data.Recommend("weapon_mh", "WARRIOR", "Melee", 3, nil).itemID, 2862)   -- unknown weapon kind defaults to edged
  T.eq(FB.Data.Recommend("inner_fire", "PRIEST", "Healer", 60), nil)
  T.truthy(#FB.Data.AllItemIDs() > 30)
end)
T.test("display order: self buffs, then group buffs, then consumables", function()
  local order = {}
  for i, e in ipairs(FB.Data.entries) do order[e.key] = i end
  T.truthy(order.inner_fire < order.fortitude and order.fortitude < order.flask)
end)
T.test("AllSpellIDs is distinct and covers ids", function()
  local all, set = FB.Data.AllSpellIDs(), {}
  for _, id in ipairs(all) do T.falsy(set[id], "dup " .. id); set[id] = true end
  T.truthy(set[588] and set[1243] and set[17626] and set[8681])
end)
T.test("priorities and default by reason", function()
  T.eq(#FB.Data.PRIORITIES, 3); T.eq(FB.Data.DefaultPriority("known"), "normal")
  T.eq(FB.Data.DefaultPriority("group"), "low"); T.eq(FB.Data.DefaultPriority("consumable"), "low")
end)
T.test("catalogue rows are well-formed, sorted, and cover the recommendations", function()
  local C = FB.Data.CATALOGUE
  for _, cat in ipairs({"flask","elixir","well_fed","weapon"}) do
    local rows = C[cat]; T.truthy(rows and #rows > 0, cat)
    local lastLevel = -1
    for _, r in ipairs(rows) do
      T.truthy(r.itemID and r.name and r.level and r.summary, cat .. " row"); T.truthy(r.level >= lastLevel, "sorted " .. cat); lastLevel = r.level
      if cat ~= "weapon" and cat ~= "well_fed" then T.truthy(r.auraIDs and #r.auraIDs > 0, r.name .. " auraIDs") end
    end
  end
  for key, byRole in pairs(FB.Data.RECOMMEND) do
    local cat = FB.Data.CategoryOf(key)
    for _, rows in pairs(byRole) do for _, rec in ipairs(rows) do T.truthy(FB.Data.CatalogueItem(cat, rec.itemID), rec.name .. " in catalogue") end end
  end
end)
T.test("every catalogue aura id is in its category entry ids", function()
  for _, cat in ipairs({"flask","elixir","well_fed"}) do
    local ids = {}; for _, id in ipairs(FB.Data.byKey[cat].ids) do ids[id] = true end
    for _, r in ipairs(FB.Data.CATALOGUE[cat]) do for _, a in ipairs(r.auraIDs) do T.truthy(ids[a], r.name .. " aura " .. a) end end
  end
end)
T.test("catalogue includes the cheaper levelling items and excludes alcohol", function()
  T.truthy(FB.Data.CatalogueItem("elixir", 2457))
  T.truthy(FB.Data.CatalogueItem("elixir", 3390))   -- Elixir of Lesser Agility
  T.truthy(FB.Data.CatalogueItem("flask", 13513))   -- Flask of Chromatic Resistance
  T.truthy(FB.Data.CatalogueItem("well_fed", 12218)) -- Monster Omelet
  T.falsy(FB.Data.CatalogueItem("well_fed", 21151)) -- Rumsey Rum Black Label
  T.eq(FB.Data.CategoryOf("weapon_oh"), "weapon"); T.eq(FB.Data.CategoryOf("inner_fire"), nil)
end)
T.test("1.0 recommendations still hold after deriving from the catalogue", function()
  T.eq(FB.Data.Recommend("elixir", "MAGE", "Caster", 60).itemID, 13454)
  T.eq(FB.Data.Recommend("weapon_mh", "WARRIOR", "Melee", 60, "blunt").itemID, 12643)
  T.eq(FB.Data.Recommend("weapon_mh", "PRIEST", "Healer", 60, "blunt").itemID, 20749)   -- oils ignore weapon kind
  T.eq(FB.Data.Recommend("well_fed", "ROGUE", "Melee", 60).itemID, 250072)
end)
T.test("quietFromOthers is gone", function()
  for _, e in ipairs(FB.Data.entries) do T.eq(e.quietFromOthers, nil, e.key) end
end)
T.test("Forever corrections and new items", function()
  local holy = FB.Data.CatalogueItem("elixir", 21546); T.eq(holy.name, "Elixir of Holy Power"); T.eq(holy.roles, nil)
  T.eq(FB.Data.CatalogueItem("weapon", 2863).level, 5); T.eq(FB.Data.CatalogueItem("weapon", 12404).level, 35)
  T.truthy(FB.Data.CatalogueItem("elixir", 250351)); T.eq(FB.Data.Recommend("elixir", "WARRIOR", "Melee", 60).itemID, 250351)
  T.eq(FB.Data.Recommend("elixir", "HUNTER", "Melee", 60).itemID, 250328); T.eq(FB.Data.Recommend("elixir", "ROGUE", "Melee", 60).itemID, 13452)
  T.truthy(FB.Data.CatalogueItem("flask", 274274).summary:find("Hyjal only", 1, true))
  T.eq(FB.Data.CatalogueItem("well_fed", 12212).name, "Jungle Stew")
end)
T.test("ResolveItemSpells merges runtime buff IDs once", function()
  local before = #FB.Data.byKey.elixir.ids
  local n = FB.Data.ResolveItemSpells(function(id) if id == 250351 then return 9999901 end end)
  T.eq(n, 1); T.eq(#FB.Data.byKey.elixir.ids, before + 1)
  T.eq(FB.Data.ResolveItemSpells(function(id) if id == 250351 then return 9999901 end end), 0)
  T.eq(FB.Data.CatalogueItem("elixir", 250351).resolvedSpell, 9999901)
end)
T.test("RankInfo: current rank, next level, available", function()
  local e = { iconSpells = { 11 }, ranks = { { family = "Fort", spells = { {id=11,rank=1,level=1}, {id=12,rank=2,level=12}, {id=13,rank=3,level=24}, {id=14,rank=4,level=36} } } } }
  local known = { [11]=true, [12]=true }
  local r = FB.Data.RankInfo(e, function(id) return known[id] end, 21); T.eq(r.known, 2); T.eq(r.total, 4); T.eq(r.nextLevel, 24); T.falsy(r.available)
  r = FB.Data.RankInfo(e, function(id) return known[id] end, 26); T.truthy(r.available)
  local m = { iconSpells = { 31, 21 }, ranks = { { family = "Frost", spells = { {id=21,rank=1,level=1} } }, { family = "Mage", spells = { {id=31,rank=1,level=34} } } } }
  r = FB.Data.RankInfo(m, function(id) return id == 21 end, 30); T.eq(r.family, "Frost"); T.falsy(r.available)
  r = FB.Data.RankInfo(m, function(id) return id == 21 end, 40); T.truthy(r.available)
  T.eq(FB.Data.RankInfo({ iconSpells = {} }, function() return false end, 60), nil)
end)
T.test("generated sources and ranks are attached", function()
  local mongoose = FB.Data.CatalogueItem("elixir", 13452); T.truthy(mongoose.source); T.eq(mongoose.source.kind, "crafted"); T.eq(mongoose.source.profession, "Alchemy")
  T.truthy(#mongoose.source.reagents >= 1)
  local fort = FB.Data.byKey.fortitude; T.truthy(fort.ranks); T.eq(fort.ranks[1].family, "Power Word: Fortitude"); T.eq(#fort.ranks[1].spells, 6)
  local r = FB.Data.RankInfo(fort, function(id) return id == 1243 or id == 1244 end, 21); T.eq(r.known, 2); T.eq(r.nextLevel, 24); T.falsy(r.available)
  r = FB.Data.RankInfo(fort, function(id) return id == 1243 or id == 1244 end, 25); T.truthy(r.available)
  local hasDevo7 = false; for _, id in ipairs(FB.Data.byKey.paladin_aura.ids) do if id == 10293 then hasDevo7 = true end end; T.truthy(hasDevo7)
  T.eq(FB.Data.byKey.rogue_poison_mh.castIDs[1], 8681)
end)
T.test("food item spells (the eating spell) are not merged into Well Fed", function()
  local before = #FB.Data.byKey.well_fed.ids
  FB.Data.ResolveItemSpells(function(id) if id == 6888 then return 1248377 end end)
  T.eq(#FB.Data.byKey.well_fed.ids, before)
  for _, id in ipairs(FB.Data.byKey.well_fed.ids) do T.falsy(id == 1248377) end
end)
