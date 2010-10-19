module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")
local net = require("luanode.net")
local url = require("luanode.url")

-- Make sure no exceptions are thrown when receiving malformed HTTP
-- requests.
function test()
	nrequests_completed = 0
	nrequests_expected = 1

	local server = http.createServer(function (self, req, res)
		for k,v in pairs(url.parse(req.url)) do
			console.log("req: %s - %s", k, v)
		end

		res:writeHead(200, {["Content-Type"] = "text/plain"})
		res:write("Hello World")
		res:finish()

		nrequests_completed = nrequests_completed + 1
		if nrequests_completed == nrequests_expected then
			self:close()
		end
	end)
	server:listen(common.PORT)

	server:addListener("listening", function()
		local c = net.createConnection(common.PORT)
		c:addListener("connect", function ()
			c:write("GET /hello?foo=%99bar HTTP/1.1\r\n\r\n")
			c:finish()
		end)

	-- TODO add more!
	end)

	process:addListener("exit", function ()
		assert_equal(nrequests_expected, nrequests_completed)
	end)
	
	process:loop()
end
