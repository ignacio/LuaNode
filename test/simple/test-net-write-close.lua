module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require "luanode.net"

function test()

local server = net.createServer(function (self, socket)
	
	socket:addListener("data", function (self, data)
		assert_equal(true, socket.readable)
		assert_equal(true, socket.writable)
		assert_equal("hello world", data)
	end)

	socket:addListener("end", function (self)
		socket:finish()
	end)

	socket:addListener("close", function (self)
		assert_equal(false, socket.writable)
		assert_equal(false, socket.readable)
		socket.server:close()
	end)
end)

server:listen(common.PORT, function (self)

	local client = net.createConnection(common.PORT)
	
	client:addListener("connect", function ()
		client:finish("hello world")
	end)
end)

process:loop()
end
