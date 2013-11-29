module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")


function test()

local body = "hello world\n";

server = http.createServer(function (self, req, res)
	common.error("req: " .. req.method)
	res:writeHead(200, {["Content-Length"] = body.length})
	res:finish()
	server:close()
end)

local gotEnd = false

server:listen(common.PORT, function ()
	local request = http.request({
		port = common.PORT,
		method = "HEAD",
		path = "/"
	}, function (self, response)
		common.error("response start")
		response:on("end", function ()
			common.error("response end")
			gotEnd = true
		end)
	end)
	request:finish()
end)

process:on("exit", function ()
	assert_true(gotEnd)
end)

process:loop()
end