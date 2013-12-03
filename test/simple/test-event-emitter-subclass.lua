module(..., lunit.testcase, package.seeall)

local EventEmitter = require "luanode.event_emitter"
local Class = require "luanode.class"

function test()
	
	local MyEventEmitter = Class.InheritsFrom(EventEmitter)
	function MyEventEmitter:__init(cb)
		local ee = Class.construct(MyEventEmitter)

		ee:on("foo", cb)
		process.nextTick(function()
			ee:emit("foo")
		end)

		return ee
	end

	local called = false
	local my_ee = MyEventEmitter(function()
		called = true
	end)

	process:on("exit", function()
		assert_true(called)
		console.log("ok")
	end)

	process:loop()
end
