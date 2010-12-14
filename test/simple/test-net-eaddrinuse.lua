module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require("luanode.net")

function test()
	local server1 = net.createServer(function (self, socket)
	end)
	server1:listen(common.PORT)
	
	local server2 = net.createServer(function (self, socket)
	end)
	server2:addListener('error', function(self, error, msg)
		assert_true(error == 10048 or error == 98)	-- I really should unify error codes
		server1:close()
	end)
	server2:listen(common.PORT)
	
	process:loop()
end