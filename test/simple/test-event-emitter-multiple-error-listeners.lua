---
-- If more than one error listeners were registered, emitting an error would trigger an error
-- instead of calling the listeners.
--

module(..., lunit.testcase, package.seeall)

local EventEmitter = require "luanode.event_emitter"

function test()

	local e = EventEmitter()

	local times_error_emitted = 0

	e:on("error", function()
		times_error_emitted = times_error_emitted + 1
	end)

	e:on("error", function()
		times_error_emitted = times_error_emitted + 1
	end)

	e:emit("error")

	process:on("exit", function ()
		assert_equal(2, times_error_emitted)
	end)
	
	process:loop()
end
