module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")


function test()

local body = "hello world\n";

server = http.createServer(function (self, req, res)
	common.error('req: ' .. req.method)
	res:writeHead(200, {["Content-Length"] = body.length})
	res:finish()
	server:close()
end)

local gotEnd = false

server:listen(common.PORT, function ()
	local client = http.createClient(common.PORT)
	local request = client:request("HEAD", "/")
	request:finish()
	request:addListener('response', function (self, response)
		common.error('response start')
		response:addListener("end", function ()
			common.error('response end')
			gotEnd = true
		end)
	end)
end)

process:addListener('exit', function ()
	assert_true(gotEnd)
end)

process:loop()
end