module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
body = "hello world\n"
headers = {connection = 'keep-alive'}

server = http.createServer(function (self, req, res)
	res:writeHead(200, {["Content-Length"] = #body, Connection="close"})
	res:write(body)
	res:finish()
end)

connectCount = 0

server:listen(common.PORT, function () 
	local client = http.createClient(common.PORT)

	client:addListener("connect", function () 
		common.error("CONNECTED")
		connectCount = connectCount + 1
	end)

  local request = client:request("GET", "/", headers)
	request:finish()
	request:addListener('response', function (self, response) 
		common.error('response start')

		response:addListener("end", function () 
			common.error('response end')
			local req = client:request("GET", "/", headers)
			req:addListener('response', function (self, response) 
				response:addListener("end", function () 
					client:finish()
					server:close()
				end)
			end)
			req:finish()
		end)
	end)
end)

process:addListener('exit', function () 
	assert_equal(2, connectCount)
end)

process:loop()
end