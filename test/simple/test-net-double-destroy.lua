---
-- Asserts that even if socket:destroy() is called mutiple times,
-- the "close" event will be emitted only once.
--

require "lunit"

module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require "luanode.net"

function test()

local catched = 0
local server = net.createServer(function() end)

server:listen(common.PORT)

server:on("listening", function()

	local client = net.createConnection(common.PORT)
	client:on("connect", function()
		client:destroy()
		client:destroy()
	end)

	client:on("close", function()
		catched = catched + 1
		server:close()
	end)
	
end)

process:loop()

assert_equal(catched, 1)
end
