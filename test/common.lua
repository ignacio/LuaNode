local path = require "luanode.path"

--print(debug.getinfo(1, "S").source)


local t = {}
-- TODO: FIXME
t.testDir = process.cwd()
--..print(t.testDir)
t.fixturesDir = path.join(t.testDir, "fixtures")
--print("fixturesdir", t.fixturesDir)
--t.fixturesDir = "//home/ignacio/devel/sources/LuaNode/test/fixtures"
t.libDir = path.join(t.testDir, "../lib")
t.tmpDir = path.join(t.testDir, "tmp")
t.PORT = 12346

local assert = assert

t.debug = LogDebug
t.error = LogError

t.p = print

return t