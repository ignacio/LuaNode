require "lunit"

module(..., lunit.testcase, package.seeall)

function test()

local net = require "luanode.net"
local common = dofile("common.lua")

-- Makes sure that remoteAddress is available even after the socket has disconnected
-- socket:address is not available though
local server = net.createServer(function(self, cnx)
	process.nextTick(function()
		assert(cnx:remoteAddress())
		assert(not cnx:address())
	end)
	cnx:destroy()
	self:close()
end)

server:listen(common.PORT)

server:on("listening", function()
	local client = net.createConnection(common.PORT)
	client:on("connect", function(self)
		self:destroy()
	end)
end)

process:loop()

end