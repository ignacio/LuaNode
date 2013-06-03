module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
server = http.createServer(function (self, req, res)
	console.log("got request. setting 0.5 second timeout")
	req.connection:setTimeout(500)

	req.connection:on("timeout", function()
		req.connection:destroy()
		common.debug("TIMEOUT")
		server:close()
	end)
end)

server:listen(common.PORT, function ()
	console.log("Server running at http://127.0.0.1:"..common.PORT.."/")

	local errorTimer = setTimeout(function ()
		error('Timeout was not sucessful')
	end, 2000)

	local x = http.get("http://localhost:"..common.PORT.."/")
	x:on("error", function (self, res)
		clearTimeout(errorTimer)
		console.log("HTTP REQUEST COMPLETE (this is good)")
	end)
	x:finish()
end)

process:loop()
end