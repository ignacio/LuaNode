module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local socket = require('luanode.luasocket')

function test()

-- The server
coroutine.wrap(function()
	
	local s = assert(socket.bind("*", common.PORT))
	local i, p = s:getsockname()
	assert(i, p)
	c = assert(s:accept())
	local l, e, partial = c:receive("*l")
	assert(not l)
	assert_equal("closed", e)
	assert_equal("hello world", partial)
	
end)()

-- The client
coroutine.wrap(function()
	
	local c = assert(socket.connect("localhost", common.PORT))
	c:send("hello world")
	c:close()
	
end)()

process:loop()

end