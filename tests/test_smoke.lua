T.test("addon files load and define modules", function()
  for _, m in ipairs({"Data","API","State","Alerts","Display","Core","Options"}) do
    T.truthy(FB[m], m .. " module missing")
  end
end)
T.test("TOC interface is 16001", function()
  local toc = io.open("ForeverBuffs.toc"):read("*a")
  T.truthy(toc:find("## Interface: 16001", 1, true))
end)
