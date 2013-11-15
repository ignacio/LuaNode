---
-- Test for https://github.com/ignacio/LuaNode/issues/14
--
-- response:writeHead with a status reason ignores headers
--

module(..., lunit.testcase, package.seeall)

local common = dofile "common.lua"
local http = require "luanode.http"

function test()

local server = http.createServer(function(self, req, res)
	res:writeHead(200, "Some custom status", {["Content-Type"] = "text/plain"})
	res:finish("hello there")
	self:close()
end)


server:listen(common.PORT, function ()
	local client = http.createClient(common.PORT)
	local request = client:request("GET", "/")
	request:finish()
	request:on("response", function (self, response)
		assert_equal(response.headers["content-type"], "text/plain")
	end)
end)

process:loop()
end
