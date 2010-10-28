module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")

local EventEmitter = require "luanode.event_emitter"

function test()
	local e = EventEmitter:new()

	local times_hello_emited = 0
	
	local f = {}
	f.read = function()
		--queue_read()
		local res = coroutine.yield("entra")
		print(res)
		return res
	end
	
	local c = coroutine.create(function ()
		local data = f:read()
		coroutine.yield(2)
	end)
	print(coroutine.resume(c))
	print(coroutine.resume(c, "sale"))
	print(coroutine.resume(c))
	
	print(type(c))
	
	print(type(coroutine.wrap(function ()
	end)))
	
	e:on("hello", coroutine.wrap(function (self, a, b)
		--times_hello_emited = times_hello_emited + 1
		print("event number 1")
		coroutine.yield("hola")
		print("event number 2")
		coroutine.yield()
		print("event number 3")
		coroutine.yield()
		print("event number 4")
	end))

	e:emit("hello", "a", "b")
	e:emit("hello", "a", "b")
	e:emit("hello", "a", "b")
	e:emit("hello", "a", "b")

	process:addListener("exit", function ()
		--assert_equal(1, times_hello_emited)
	end)
	
	process:loop()
end