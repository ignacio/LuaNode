module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")

local EventEmitter = require "luanode.event_emitter"

function test()
	local e = EventEmitter()

	local times_hello_emited = 0

	e:once("hello", function (self, a, b)
		times_hello_emited = times_hello_emited + 1
	end)

	e:emit("hello", "a", "b")
	e:emit("hello", "a", "b")
	e:emit("hello", "a", "b")
	e:emit("hello", "a", "b")

	process:addListener("exit", function ()
		assert_equal(1, times_hello_emited)
	end)
	
	process:loop()
end