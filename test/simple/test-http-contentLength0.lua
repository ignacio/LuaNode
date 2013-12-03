module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

-- Simple test of Node's HTTP Client choking on a response with a "Content-Length: 0 " response header.
-- I.E. a space character after the "Content-Length" throws an `error` event.
function test()

local s  = http.createServer(function(self, req, res)
	res:writeHead(200, { ["Content-Length"] = "0 " })
	res:finish()
end)
s:listen(common.PORT, function()

	local request = http.request({ port = common.PORT }, function(self, response)
		console.log("STATUS: " .. response.statusCode)
		s:close()
	end)

	request:finish()
end)

process:loop()
end
