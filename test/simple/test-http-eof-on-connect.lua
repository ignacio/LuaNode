module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")
local net = require("luanode.net")

-- This is a regression test for http://github.com/ry/node/issues/#issue/44
-- It is separate from test-http-malformed-request.js because it is only
-- reproduceable on the first packet on the first connection to a server.

function test()
local server = http.createServer(function (self, req, res) end)
server:listen(common.PORT)

server:addListener("listening", function()
	net.createConnection(common.PORT):addListener("connect", function (self)
		self:destroy()
	end):addListener("close", function ()
		server:close()
	end)
end)

process:loop()
end