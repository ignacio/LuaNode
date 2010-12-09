require "lunit"

module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")

local EventEmitter = require "luanode.event_emitter"

function test()
	local e = EventEmitter()

	local events_new_listener_emited = {}
	local times_hello_emited = 0

	e:addListener("newListener", function (self, event, listener)
		console.log("newListener: %s", event)
		table.insert(events_new_listener_emited, event)
	end)

	e:on("hello", function (self, a, b)
		console.log("hello")
		times_hello_emited = times_hello_emited + 1
		assert_equal("a", a)
		assert_equal("b", b)
	end)
	
	local propagation_test_times = 0
	
	e:on("propagation-test", function ()
		propagation_test_times = propagation_test_times + 1
		console.log("This listener will stop propagation")
		return false
	end)

	e:on("propagation-test", function (msg)
		propagation_test_times = propagation_test_times + 1
		console.log("You will not see this message!")
	end)

	console.log("start")

	local not_propagated_emit = e:emit("hello", "a", "b")
	
	local propagated_emit = e:emit("propagation-test")

	process:addListener("exit", function ()
		assert_equal("hello", events_new_listener_emited[1])
		assert_equal("propagation-test", events_new_listener_emited[2])
		assert_equal("propagation-test", events_new_listener_emited[3])
		
		-- When noone stops propagation Emit return false
		assert_false(not_propagated_emit)
		
		-- But when propagation was stopped Emit returns true
		assert_true(propagated_emit)
		
		assert_equal(1, propagation_test_times)
		assert_equal(1, times_hello_emited)
	end)
	
	process:loop()
end