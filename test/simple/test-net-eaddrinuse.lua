module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require("luanode.net")

function test()
	local server1 = net.createServer(function (self, socket)
	end)
	local server2 = net.createServer(function (self, socket)
	end)
	server1:listen(31337)
	
	server2:addListener('error', function(self, error, msg)
		assert_equal(10048, error)
		server1:close()
	end)
	server2:listen(31337)
	
	process:loop()
end