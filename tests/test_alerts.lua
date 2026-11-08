local function channels(over)
  local c = {
    high   = { sound = "alarm3",       ["repeat"] = 30, text = true,  flash = true },
    normal = { sound = "raid_warning", ["repeat"] = 0,  text = false, flash = true },
    low    = { sound = "none",         ["repeat"] = 0,  text = false, flash = false },
  }
  for p, t in pairs(over or {}) do for k, v in pairs(t) do c[p][k] = v end end
  return c
end
-- fake state: keys -> { prio=, sounds=, status=, name= }
local function st(def)
  local s = { status = {}, tracked = {}, expiresAt = {} }
  for k, d in pairs(def) do s.status[k] = d.status or "missing"; s.tracked[k] = { reason = "known" } end
  function s:Priority(k) return def[k].prio or "normal" end
  function s:Sounds(k) return def[k].sounds ~= false end
  function s:DisplayName(k) return def[k].name or k end
  function s:Remaining(k, now) return def[k].remaining end
  return s
end
local function ctx(o) o = o or {}; return { channels = o.channels or channels(), alertOnExpiring = o.alertOnExpiring ~= false, hidden = o.hidden, inGrace = o.inGrace, inCombat = o.inCombat, now = o.now or 0 } end
local PM = { { key = "inner_fire", from = "present", to = "missing" } }

T.test("high missing: sound and screen text", function()
  local a = FB.Alerts.New(); local r = a:Decide(PM, st({ inner_fire = { prio = "high", name = "Inner Fire" } }), ctx())
  T.eq(r.sounds[1], "alarm3"); T.eq(r.texts[1].text, "Inner Fire missing!"); T.eq(r.texts[1].priority, "high")
end)
T.test("Sound tick off silences everything", function()
  local a = FB.Alerts.New(); local r = a:Decide(PM, st({ inner_fire = { prio = "high", sounds = false } }), ctx())
  T.eq(#r.sounds, 0); T.eq(#r.texts, 0)
end)
T.test("low priority with Sound ticked uses the low channel", function()
  local a = FB.Alerts.New(); local s = st({ flask = { prio = "low", name = "Flask" } })
  local r = a:Decide({ { key = "flask", from = "present", to = "missing" } }, s, ctx({ channels = channels({ low = { sound = "whisper" } }) }))
  T.eq(r.sounds[1], "whisper")
end)
T.test("normal channel with no sound but text", function()
  local a = FB.Alerts.New(); local r = a:Decide(PM, st({ inner_fire = { name = "Inner Fire" } }), ctx({ channels = channels({ normal = { sound = "none", text = true } }) }))
  T.eq(#r.sounds, 0); T.eq(r.texts[1].text, "Inner Fire missing!")
end)
T.test("running out alerts once with minutes", function()
  local a = FB.Alerts.New(); local s = st({ inner_fire = { prio = "high", name = "Inner Fire", status = "expiring", remaining = 300 } })
  local r = a:Decide({ { key = "inner_fire", from = "present", to = "expiring" } }, s, ctx())
  T.eq(r.texts[1].text, "Inner Fire runs out in 5 min"); T.eq(r.sounds[1], "alarm3")
  s = st({ inner_fire = { prio = "high", name = "Inner Fire", status = "expiring", remaining = 45 } }); a = FB.Alerts.New()
  T.eq(a:Decide({ { key = "inner_fire", from = "present", to = "expiring" } }, s, ctx()).texts[1].text, "Inner Fire runs out in 45 s")
  a = FB.Alerts.New(); T.eq(#a:Decide({ { key = "inner_fire", from = "present", to = "expiring" } }, s, ctx({ alertOnExpiring = false })).sounds, 0)
end)
T.test("expiring to missing alerts as missing", function()
  local a = FB.Alerts.New(); local r = a:Decide({ { key = "inner_fire", from = "expiring", to = "missing" } }, st({ inner_fire = { prio = "high", name = "Inner Fire" } }), ctx())
  T.eq(r.texts[1].text, "Inner Fire missing!")
end)
T.test("untracked to missing is silent, but repeats start counting", function()
  local a = FB.Alerts.New(); local s = st({ inner_fire = { prio = "high", name = "Inner Fire" } })
  local r = a:Decide({ { key = "inner_fire", from = "untracked", to = "missing" } }, s, ctx({ now = 0 })); T.eq(#r.sounds, 0)
  T.eq(#a:DueRepeats(s, ctx({ now = 29 })).sounds, 0); T.eq(#a:DueRepeats(s, ctx({ now = 30 })).sounds, 1)
end)
T.test("repeats per priority, suppressed in combat, hidden and grace", function()
  local a = FB.Alerts.New(); local s = st({ inner_fire = { prio = "high", name = "Inner Fire" } })
  a:Decide(PM, s, ctx({ now = 0 }))
  T.eq(#a:DueRepeats(s, ctx({ now = 20 })).sounds, 0); T.eq(#a:DueRepeats(s, ctx({ now = 30 })).sounds, 1)
  T.eq(#a:DueRepeats(s, ctx({ now = 45 })).sounds, 0); T.eq(#a:DueRepeats(s, ctx({ now = 60 })).sounds, 1)
  T.eq(#a:DueRepeats(s, ctx({ now = 200, inCombat = true })).sounds, 0)
  T.eq(#a:DueRepeats(s, ctx({ now = 200, hidden = true })).sounds, 0)
  T.eq(#a:DueRepeats(s, ctx({ now = 200, inGrace = true })).sounds, 0)
  local n = st({ fortitude = { prio = "normal" } }); a = FB.Alerts.New(); a:Decide({ { key = "fortitude", from = "present", to = "missing" } }, n, ctx({ now = 0 }))
  T.eq(#a:DueRepeats(n, ctx({ now = 500 })).sounds, 0)
end)
T.test("repeat floor of 10 seconds", function()
  local a = FB.Alerts.New(); local s = st({ inner_fire = { prio = "high" } }); a:Decide(PM, s, ctx({ now = 0 }))
  T.eq(#a:DueRepeats(s, ctx({ now = 5, channels = channels({ high = { ["repeat"] = 1 } }) })).sounds, 0)
  T.eq(#a:DueRepeats(s, ctx({ now = 10, channels = channels({ high = { ["repeat"] = 1 } }) })).sounds, 1)
end)
T.test("two entries due together give one sound and one combined text", function()
  local a = FB.Alerts.New(); local s = st({ inner_fire = { prio = "high", name = "Inner Fire" }, fortitude = { prio = "high", name = "Fortitude" } })
  a:Decide({ { key = "inner_fire", from = "present", to = "missing" }, { key = "fortitude", from = "present", to = "missing" } }, s, ctx({ now = 0 }))
  local r = a:DueRepeats(s, ctx({ now = 30 })); T.eq(#r.sounds, 1); T.eq(#r.texts, 1)
  T.truthy(r.texts[1].text:find("Inner Fire", 1, true) and r.texts[1].text:find("Fortitude", 1, true)); T.truthy(r.texts[1].text:find("missing!", 1, true))
end)
T.test("present entries never repeat", function()
  local a = FB.Alerts.New(); local s = st({ inner_fire = { prio = "high" } }); a:Decide(PM, s, ctx({ now = 0 })); s.status.inner_fire = "present"
  T.eq(#a:DueRepeats(s, ctx({ now = 100 })).sounds, 0)
end)
T.test("sound table and Play", function()
  T.eq(#FB.Alerts.SOUNDS, 18); T.eq(FB.Alerts.SOUNDS[18].key, "none"); T.eq(FB.Alerts.SoundByKey("alarm1").kit, 18871)
  STUB.reset(); FB.Alerts.Play("ready_check"); T.eq(STUB.sounds[1][1], 8960); FB.Alerts.Play("none"); T.eq(#STUB.sounds, 1)
end)
T.test("Deliver plays sounds and shows texts in priority colours", function()
  STUB.reset(); FB.Alerts.Deliver({ sounds = { "ready_check", "alarm3" }, texts = { { text = "A missing!", priority = "high" }, { text = "B missing!", priority = "normal" } } })
  T.eq(#STUB.sounds, 2); T.eq(#STUB.raidNotices, 2); T.eq(STUB.raidNotices[1].color.g, 0.82); T.eq(STUB.raidNotices[2].color.g, 0.25)
end)
T.test("ShouldFlash follows the channel flash tick for missing and expiring", function()
  local s = st({ a = { prio = "high" }, b = { prio = "low" }, c = { prio = "normal", status = "expiring" }, d = { prio = "normal", status = "present" } })
  local c = channels()
  T.truthy(FB.Alerts.ShouldFlash(s, "a", c)); T.falsy(FB.Alerts.ShouldFlash(s, "b", c)); T.truthy(FB.Alerts.ShouldFlash(s, "c", c)); T.falsy(FB.Alerts.ShouldFlash(s, "d", c))
  T.falsy(FB.Alerts.ShouldFlash(s, "a", channels({ high = { flash = false } })))
end)
