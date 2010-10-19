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

server:addListener("listening", function()
	local client = http.createClient(common.PORT)

	local req1 = client:request("/1")
	req1:finish()
	req1:addListener("response", function (self, res1)
		res1:setEncoding("utf8")

		res1:addListener("data", function (self, chunk)
			body1 = body1 .. chunk
		end)

		res1:addListener('end', function ()
			local req2 = client:request("/2")
			req2:finish()
			req2:addListener('response', function (self, res2)
				res2:setEncoding("utf8")
				res2:addListener("data", function (self, chunk)
					body2 = body2 .. chunk
				end)
				res2:addListener("end", function ()
					server:close()
				end)
			end)
		end)
	end)
end)

process:addListener("exit", function ()
	assert_equal(body1_s, body1)
	assert_equal(body2_s, body2)
end)

process:loop()
end
