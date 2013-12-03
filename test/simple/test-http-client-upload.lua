module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
local sent_body = ""
local server_req_complete = false
local client_res_complete = false

local server = http.createServer(function(self, req, res)
	assert_equal("POST", req.method)
	req:setEncoding("utf8")

	req:on("data", function (self, chunk)
		console.log("server got: " .. chunk)
		sent_body = sent_body .. chunk
	end)

	req:on("end", function ()
		server_req_complete = true
		console.log("request complete from server")
		res:writeHead(200, {["Content-Type"] = "text/plain"})
		res:write("hello\n")
		res:finish()
	end)
end)
server:listen(common.PORT)

server:on("listening", function()
	local req = http.request{ method ="POST", path = "/", port = common.PORT }
	req:write("1\n")
	req:write("2\n")
	req:write("3\n")
	req:finish()

	console.log("client finished sending request")

	req:on("response", function(self, res)
		res:setEncoding("utf8")
		res:on("data", function(self, chunk)
			console.log(chunk)
		end)
		res:on("end", function()
			client_res_complete = true
			server:close()
		end)
	end)
end)

process:on("exit", function ()
	assert_equal("1\n2\n3\n", sent_body)
	assert_equal(true, server_req_complete)
	assert_equal(true, client_res_complete)
end)

process:loop()
end