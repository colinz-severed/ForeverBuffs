T.test("KnowsSpell uses C_SpellBook", function()
  STUB.reset(); STUB.known[588] = true
  T.truthy(FB.API.KnowsSpell(588)); T.falsy(FB.API.KnowsSpell(1243))
end)
T.test("PlayerAura: present, absent, errored, secret", function()
  STUB.reset(); STUB.auras[588] = { name="Inner Fire", sourceUnit="player" }
  T.eq(FB.API.PlayerAura(588), true); T.eq(FB.API.PlayerAura(1243), false)
  STUB.restricted = true; T.eq(FB.API.PlayerAura(588), nil)
  STUB.restricted = false; STUB.auras[588].secret = true; T.eq(FB.API.PlayerAura(588), nil)
end)
T.test("PlayerAuraSource distinguishes own cast", function()
  STUB.reset(); STUB.auras[465] = { sourceUnit="party1" }
  T.eq(FB.API.PlayerAuraSource(465), "other")
  STUB.auras[465].sourceUnit = "player"; T.eq(FB.API.PlayerAuraSource(465), "player")
  STUB.auras[465].sourceUnit = STUB.secret("party1"); T.eq(FB.API.PlayerAuraSource(465), nil)
end)
T.test("PlayerAuraByName", function()
  STUB.reset(); STUB.auras[19705] = { name="Well Fed", sourceUnit="player" }
  T.eq(FB.API.PlayerAuraByName("Well Fed"), true); T.eq(FB.API.PlayerAuraByName("Flask of the Titans"), false)
  STUB.restricted = true; T.eq(FB.API.PlayerAuraByName("Well Fed"), nil)
end)
T.test("TempEnchant and OffhandIsWeapon", function()
  STUB.reset(); T.falsy(FB.API.TempEnchant(16))
  STUB.tempEnchant[16] = { enchantID=1 }; T.truthy(FB.API.TempEnchant(16))
  STUB.offhandItem = nil; T.falsy(FB.API.OffhandIsWeapon())
  STUB.offhandItem = { id=1, classID=4 }; T.falsy(FB.API.OffhandIsWeapon())
  STUB.offhandItem = { id=2, classID=2 }; T.truthy(FB.API.OffhandIsWeapon())
end)
T.test("MainhandWeaponKind and item helpers", function()
  STUB.reset(); STUB.mainhandItem = nil; T.eq(FB.API.MainhandWeaponKind(), nil)
  STUB.mainhandItem = { id=10, classID=2, subclassID=7 }; T.eq(FB.API.MainhandWeaponKind(), "edged")
  STUB.mainhandItem = { id=11, classID=2, subclassID=4 }; T.eq(FB.API.MainhandWeaponKind(), "blunt")
  STUB.mainhandItem = { id=12, classID=2, subclassID=19 }; T.eq(FB.API.MainhandWeaponKind(), nil)
  STUB.items[13452] = { name="Elixir of the Mongoose", icon=134873 }
  T.eq(FB.API.ItemName(13452), "Elixir of the Mongoose"); T.eq(FB.API.ItemIcon(13452), 134873); T.eq(FB.API.ItemName(1), nil)
  T.eq(FB.API.PlayerLevel(), 60); T.eq(FB.API.PlayerClass(), "PRIEST")
end)
T.test("AurasRestricted and SpellNeverSecret", function()
  STUB.reset(); T.falsy(FB.API.AurasRestricted())
  STUB.restricted = true; T.truthy(FB.API.AurasRestricted())
  STUB.neverSecret[1243] = true; T.truthy(FB.API.SpellNeverSecret(1243)); T.falsy(FB.API.SpellNeverSecret(588))
end)
T.test("AurasRestricted falls back to a probe when C_Secrets is missing", function()
  STUB.reset(); local saved = C_Secrets; C_Secrets = nil
  T.falsy(FB.API.AurasRestricted()); STUB.restricted = true; T.truthy(FB.API.AurasRestricted())
  C_Secrets = saved
end)
T.test("UnitClassLevel returns nil when secret", function()
  STUB.reset(); STUB.group = { { class="PRIEST", level=30 } }
  local c, l = FB.API.UnitClassLevel("party1"); T.eq(c, "PRIEST"); T.eq(l, 30)
  STUB.group[1].class = STUB.secret("PRIEST"); c = FB.API.UnitClassLevel("party1"); T.eq(c, nil)
end)
T.test("Probe lists functions and all exist in stub", function()
  STUB.reset(); local p = FB.API.Probe(); T.truthy(#p >= 10)
  for _, r in ipairs(p) do T.truthy(r.ok, r.name) end
end)
T.test("missing C_PaperDollInfo degrades, not errors", function()
  STUB.reset(); local saved = C_PaperDollInfo; C_PaperDollInfo = nil
  T.eq(FB.API.TempEnchant(16), false); C_PaperDollInfo = saved
  local p = FB.API.Probe(); local found
  for _, r in ipairs(p) do if r.name == "C_PaperDollInfo.GetTemporaryEnchantmentInfo" then found = r end end
  T.truthy(found)
end)
T.test("SpellName and SpellIcon", function()
  STUB.reset(); STUB.spells[588] = { name="Inner Fire", icon=135926 }
  T.eq(FB.API.SpellName(588), "Inner Fire"); T.eq(FB.API.SpellIcon(588), 135926); T.eq(FB.API.SpellName(1), nil)
end)
