---
-- Luanode.Net _doflush was not handling correctly errors on write_callback handlers
--
module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require "luanode.net"

function test()
	
local server = net.createServer(function (self, socket)
	self:close()
end)
	
server:listen(common.PORT, function(self)
	console.log("server listening on %s:%d", self:address())
		
	local client = net.createConnection(common.PORT, "127.0.0.1")
	process.nextTick(function()
		client:destroy()
	end)
	
end)

process:loop()
end
