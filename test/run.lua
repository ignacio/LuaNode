require "luarocks.require"
require "lunit"

local console = require "lunit-console"

-- eventos posibles:
-- begin, done, fail, err, run, pass

--require "simple.test-net-binary"
--require "simple.test-net-isip"
--require "simple.test-net-server-max-connections"
--require "simple.test-http"

--require "simple.test-event-emitter-add-listeners"

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

--console.begin()
lunit.run()
--console.done()