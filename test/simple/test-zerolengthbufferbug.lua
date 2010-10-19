module(..., lunit.testcase, package.seeall)

-- Serving up a zero-length buffer should work.

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
	local server = http.createServer(function (self, req, res)
		local buffer = ""
		res:writeHead(200, {["Content-Type"] = "text/html",
							["Content-Length"] = #buffer})
		res:finish(buffer)
	end)

	local gotResponse = false
	local resBodySize = 0

	server:listen(common.PORT, function ()
		local client = http.createClient(common.PORT)
	  
		local req = client:request("GET", "/")
		req:finish()

		req:on("response", function (self, res)
			gotResponse = true

			res:on("data", function (self, d)
				resBodySize = resBodySize + #d
			end)

			res:on("end", function (self, d)
				server:close()
			end)
		end)
	end)

	process:on("exit", function ()
		assert_true(gotResponse)
		assert_equal(0, resBodySize)
	end)

	process:loop()
end