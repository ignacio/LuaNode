module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")
local net = require("luanode.net")

function test()
-- Create a TCP server
local srv = net.createServer(function(self, c)
	c:write('bad http - should trigger parse error\r\n')

	console.log("connection")

	c:addListener('end', function()
		c:finish()
	end)
end)

local parseError = false

srv:listen(common.PORT, '127.0.0.1', function()

	local hc = http.createClient(common.PORT, '127.0.0.1')
	hc:request('GET', '/'):finish()

	hc:on("error", function (self, e)
		console.log("got error from client")
		srv:close()
		assert_not_nil(e:lower():match("parse error"))
		parseError = true
	end)
end)

process:addListener("exit", function()
	assert_true(parseError)
end)

process:loop()
end
