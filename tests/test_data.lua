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
  T.truthy(d.battle_shout.quietFromOthers); T.falsy(d.fortitude.quietFromOthers)
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
  T.eq(FB.Data.Recommend("elixir", "MAGE", "Caster", 60).itemID, 21546)       -- Greater Firepower beats Greater Arcane at 50
  T.eq(FB.Data.Recommend("elixir", "WARLOCK", "Caster", 60).itemID, 13454)    -- no Firepower for warlocks
  T.eq(FB.Data.Recommend("elixir", "WARLOCK", "Caster", 45).itemID, 9264)     -- Shadow Power at 40
  T.eq(FB.Data.Recommend("elixir", "ROGUE", "Melee", 60).itemID, 13452)
  T.eq(FB.Data.Recommend("elixir", "WARRIOR", "Melee", 60).itemID, 9206)
  T.eq(FB.Data.Recommend("elixir", "WARRIOR", "Tank", 30).itemID, 3825)
  T.eq(FB.Data.Recommend("flask", "PRIEST", "Healer", 60).itemID, 13511); T.eq(FB.Data.Recommend("flask", "PRIEST", "Healer", 49), nil)
  T.eq(FB.Data.Recommend("well_fed", "WARRIOR", "Melee", 60).itemID, 20452); T.eq(FB.Data.Recommend("well_fed", "ROGUE", "Melee", 60).itemID, 13928)
  T.eq(FB.Data.Recommend("weapon_mh", "MAGE", "Caster", 60).itemID, 20749); T.eq(FB.Data.Recommend("weapon_mh", "PRIEST", "Healer", 60).itemID, 20748)
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
