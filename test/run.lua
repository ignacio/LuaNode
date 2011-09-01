package.path = ---[[d:\trunk_git\sources\LuaNode\lib\?.lua;d:\trunk_git\sources\LuaNode\lib\?\init.lua;]] ..
	[[d:\trunk_git\sources\LuaNode\lib\?\init.lua;]] .. 
	[[C:\LuaRocks\2.0\lua\?.lua;C:\LuaRocks\2.0\lua\?\init.lua;]] ..
	[[C:\LuaRocks\1.0\lua\?.lua;C:\LuaRocks\1.0\lua\?\init.lua;]] .. package.path
--package.cpath = [[.\?.dll;C:\LuaRocks\1.0\?.dll;C:\LuaRocks\1.0\loadall.dll;]] .. package.cpath

require "luarocks.require"
require "lunit"

local console = require "lunit-console"

-- eventos posibles:
-- begin, done, fail, err, run, pass

local num_tests = select("#", ...)
if num_tests == 0 then
	print("No tests tu run...")
	return
end

if num_tests == 1 and select(1, ...) == "all" then
	print("TODO: Run all tests")
	return
end

for i=1, num_tests do
	local test_case = select(i, ...)
	test_case = test_case:gsub("%.lua$", "")
	require(test_case)
end

lunit.setrunner({
	begin = console.begin,
	--fail = function(...)
		--LogError("Error in test case %s\r\nat %s\r\n%s\r\n%s", ...)
	--end,
	fail = console.fail,
	err = console.err,
	--err = function(...)
--		LogError(...)
--	end,
	done = function(...)
		process:emit("exit")
		process:removeAllListeners("exit")
		console.done()
	end
})

-- patch process:loop
local old_loop = process.loop
process.loop = function()
	assert(old_loop(process))
end

--console.begin()
local stats = lunit.run()
if stats.failed > 0 or stats.errors > 0 then
	return 1
end
--console.done()