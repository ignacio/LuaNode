require "lunit"

module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")
--assert = common.assert
local EventEmitter = require "luanode.EventEmitter"

function test()
	local e = EventEmitter:new()

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

	console.log("start")

	e:emit("hello", "a", "b")

	process:addListener("exit", function ()
		assert_equal("hello", events_new_listener_emited[1])
		assert_equal(1, times_hello_emited)
	end)
	
	process:loop()
end