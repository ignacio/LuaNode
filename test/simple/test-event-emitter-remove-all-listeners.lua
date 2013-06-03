module(..., lunit.testcase, package.seeall)

local function listener() end

function test()
	local EventEmitter = require "luanode.event_emitter"

	local e1 = EventEmitter()
	e1:on("foo", listener)
	e1:on("bar", listener)
	e1:on("baz", listener)
	e1:on("baz", listener)

	local fooListeners = e1:listeners("foo")
	local barListeners = e1:listeners("bar")
	local bazListeners = e1:listeners("baz")

	e1:removeAllListeners("bar")
	e1:removeAllListeners("baz")

	assert_equal(listener, e1:listeners("foo")[1])
	assert_equal(0, #e1:listeners("bar"))
	assert_equal(0, #e1:listeners("baz"))

	-- after calling removeAllListeners,
	-- the old listeners array should stay unchanged
	assert_equal(listener , fooListeners[1])
	assert_equal(listener , barListeners[1])
	assert_equal(listener , bazListeners[1])
	assert_equal(listener , bazListeners[2])

	-- after calling removeAllListeners,
	-- new listeners arrays are different from the old
	assert_not_equal(barListeners, e1:listeners("bar"))
	assert_not_equal(bazListeners, e1:listeners("baz"))

	local e2 = EventEmitter()
	e2:on("foo", listener)
	e2:on("bar", listener)

	e2:removeAllListeners()

	assert_equal(0, #e2:listeners("foo"))
	assert_equal(0, #e2:listeners("bar"))

	process:loop()
end
