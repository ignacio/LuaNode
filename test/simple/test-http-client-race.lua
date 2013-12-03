module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")
local url = require("luanode.url")


function test()
local body1_s = "1111111111111111"
local body2_s = "22222"

local server = http.createServer(function (self, req, res)
	local body = url.parse(req.url).pathname == "/1" and body1_s or body2_s
	res:writeHead(200, { ["Content-Type"] = "text/plain",
						 ["Content-Length"] = #body
				})
	res:finish(body)
end)
server:listen(common.PORT)

local body1 = ""
local body2 = ""

server:on("listening", function()

	local req1 = http.request{ port = common.PORT, path = "/1" }
	req1:finish()
	req1:on("response", function (self, res1)
		res1:setEncoding("utf8")

		res1:on("data", function (self, chunk)
			body1 = body1 .. chunk
		end)

		res1:on('end', function ()
			local req2 = http.request{ port = common.PORT, path = "/2" }
			req2:finish()
			req2:on('response', function (self, res2)
				res2:setEncoding("utf8")
				res2:on("data", function (self, chunk)
					body2 = body2 .. chunk
				end)
				res2:on("end", function ()
					server:close()
				end)
			end)
		end)
	end)
end)

process:on("exit", function ()
	assert_equal(body1_s, body1)
	assert_equal(body2_s, body2)
end)

process:loop()
end
