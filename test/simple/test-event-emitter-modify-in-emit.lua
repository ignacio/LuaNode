require "lunit"

module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")
--assert = common.assert
local EventEmitter = require "luanode.event_emitter"

function test()
	local callbacks_called = {}

	local e = EventEmitter()

	function callback1()
		table.insert(callbacks_called, "callback1")
		e:addListener("foo", callback2)
		e:addListener("foo", callback3)
		e:removeListener("foo", callback1)
	end

	function callback2()
		table.insert(callbacks_called, "callback2")
		e:removeListener("foo", callback2)
	end

	function callback3()
		table.insert(callbacks_called, "callback3")
		e:removeListener("foo", callback3)
	end

	e:addListener("foo", callback1)
	assert_equal(1, #e:listeners("foo"))

	e:emit("foo")
	assert_equal(2, #e:listeners("foo"))
	assert_equal("callback1", callbacks_called[1])

	e:emit("foo")
	assert_equal(0, #e:listeners("foo"))
	assert_equal("callback1", callbacks_called[1])
	assert_equal("callback2", callbacks_called[2])
	assert_equal("callback3", callbacks_called[3])

	e:emit("foo")
	assert_equal(0, #e:listeners("foo"))
	assert_equal("callback1", callbacks_called[1])
	assert_equal("callback2", callbacks_called[2])
	assert_equal("callback3", callbacks_called[3])

	e:addListener("foo", callback1)
	e:addListener("foo", callback2)
	assert_equal(2, #e:listeners("foo"))
	e:removeAllListeners("foo")
	assert_equal(0, #e:listeners("foo"))

	-- Verify that removing callbacks while in emit allows emits to propagate to
	-- all listeners
	callbacks_called = {}

	e:addListener("foo", callback2)
	e:addListener("foo", callback3)
	assert_equal(2, #e:listeners("foo"))
	e:emit("foo")
	assert_equal("callback2", callbacks_called[1])
	assert_equal("callback3", callbacks_called[2])
	assert_equal(0, #e:listeners("foo"))

	process:loop()
end