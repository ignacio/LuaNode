require "lunit"

module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")
--assert = common.assert

function test()
	local EventEmitter = require "luanode.event_emitter"

	count = 0

	function listener1 ()
		console.log('listener1')
		count = count + 1
	end

	function listener2 ()
		console.log('listener2')
		count = count + 1
	end

	function listener3 ()
		console.log('listener3')
		count = count + 1
	end

	e1 = EventEmitter()
	e1:addListener("hello", listener1)
	e1:removeListener("hello", listener1)
	assert_equal(nil, e1:listeners('hello')[1])
	
	e2 = EventEmitter()
	e2:addListener("hello", listener1)
	e2:removeListener("hello", listener2)
	assert_equal(listener1, e2:listeners('hello')[1])

	e3 = EventEmitter()
	e3:addListener("hello", listener1)
	e3:addListener("hello", listener2)
	e3:removeListener("hello", listener1)
	assert_equal(listener2, e3:listeners('hello')[1])
	
	process:loop()
end

