module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require("luanode.net")

function test()
	local server1 = net.createServer(function (self, socket)
	end)
	server1:listen(common.PORT)
	
	local server2 = net.createServer(function (self, socket)
	end)
	server2:addListener('error', function(self, msg, code)
		assert_equal(process.constants.EADDRINUSE, code)
		server1:close()
	end)
	server2:listen(common.PORT)
	
	process:loop()
end