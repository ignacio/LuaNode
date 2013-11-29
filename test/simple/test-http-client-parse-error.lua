module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")
local net = require("luanode.net")

function test()

local connects = 0
local parseErrors = 0

-- Create a TCP server
local srv = net.createServer(function(self, c)
	console.log("connection")

	connects = connects + 1
	if connects == 1 then
		c:finish("HTTP/1.1 302 Object Moved\r\nContent-Length: 0\r\n\r\nhi world")
	else
		c:finish("bad http - should trigger parse error\r\n")
		self:close()
	end
end)

local parseError = false

srv:listen(common.PORT, '127.0.0.1', function()

	for i = 1, 2 do
		http.request({
			host = "127.0.0.1",
			port = common.PORT,
			method = "GET",
			path = "/"
		}):on("error", function(self, e)
			console.log("got error from client", e)
			assert_not_nil(e:lower():match("parse error"))
			parseError = true
		end)
	end
end)

process:on("exit", function()
	assert_true(parseError)
end)

process:loop()
end
