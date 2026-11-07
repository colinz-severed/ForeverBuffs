"""Run the ForeverBuffs Lua test suite under Lua 5.1 (via lupa).

Usage: python tests/run_tests.py [filter]
  filter: only run test files whose name contains this substring.
"""
import glob
import os
import sys

from lupa import lua51

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

L = lua51.LuaRuntime(unpack_returned_tuples=True)

L.execute(r'''
package.path = "tests/?.lua;" .. package.path
T = { passed = 0, failed = 0, failures = {} }
local function fmt(v) if type(v) == "string" then return string.format("%q", v) end; return tostring(v) end
function T.eq(a, b, msg)
  if a ~= b then error((msg and (msg .. ": ") or "") .. "expected " .. fmt(b) .. ", got " .. fmt(a), 2) end
end
function T.truthy(v, msg) if not v then error((msg and (msg .. ": ") or "") .. "expected truthy, got " .. fmt(v), 2) end end
function T.falsy(v, msg) if v then error((msg and (msg .. ": ") or "") .. "expected falsy, got " .. fmt(v), 2) end end
function T.raises(fn, msg) local ok = pcall(fn); if ok then error((msg and (msg .. ": ") or "") .. "expected an error", 2) end end
function T.test(name, fn)
  local ok, err = xpcall(fn, function(e) return debug.traceback(tostring(e), 2) end)
  if ok then
    T.passed = T.passed + 1
    io.write("PASS ", T.currentFile, " :: ", name, "\n")
  else
    T.failed = T.failed + 1
    table.insert(T.failures, T.currentFile .. " :: " .. name .. "\n" .. err)
    io.write("FAIL ", T.currentFile, " :: ", name, "\n", err, "\n")
  end
end
assert(loadfile("tests/wow_stub.lua"))()
STUB.reload()
''')

filt = sys.argv[1] if len(sys.argv) > 1 else ""
files = sorted(f for f in glob.glob("tests/test_*.lua") if filt in os.path.basename(f))
for f in files:
    path = f.replace("\\", "/")
    L.execute(f'T.currentFile = "{os.path.basename(path)}"; assert(loadfile("{path}"))()')

passed = int(L.eval("T.passed"))
failed = int(L.eval("T.failed"))
L.execute('io.write("\\n")')
L.execute(f'io.write("{passed} passed, {failed} failed\\n"); io.flush()')
sys.exit(1 if failed else 0)
