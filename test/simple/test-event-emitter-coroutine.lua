module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")

local EventEmitter = require "luanode.event_emitter"

function test()
	local e = EventEmitter()

	local emitted = {}
	
	e:on("hello", coroutine.wrap(function (self, msg)
		table.insert(emitted, msg)
		self, msg = coroutine.yield()
		table.insert(emitted, msg)
		self, msg = coroutine.yield()
		table.insert(emitted, msg)
		self, msg = coroutine.yield()
		table.insert(emitted, msg)
	end))

	e:emit("hello", "event number 1")
	e:emit("hello", "event number 2")
	e:emit("hello", "event number 3")
	process.nextTick(function()
		e:emit("hello", "event number 4")
	end)

	process:addListener("exit", function ()
		assert(#emitted > 0)
		for i, msg in ipairs(emitted) do
			console.log(msg)
			assert_equal("event number "..i, msg)
		end
	end)
	
	process:loop()
end
