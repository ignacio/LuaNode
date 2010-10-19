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

	req:addListener('data', function (self, chunk)
		console.log("server got: " .. chunk)
		sent_body = sent_body .. chunk
	end)

	req:addListener('end', function ()
		server_req_complete = true
		console.log("request complete from server")
		res:writeHead(200, {["Content-Type"] = 'text/plain'})
		res:write('hello\n')
		res:finish()
	end)
end)
server:listen(common.PORT)

server:addListener("listening", function()
	local client = http.createClient(common.PORT)
	local req = client:request('POST', '/')
	req:write('1\n')
	req:write('2\n')
	req:write('3\n')
	req:finish()

	common.error("client finished sending request")

	req:addListener('response', function(self, res)
		res:setEncoding("utf8")
		res:addListener('data', function(self, chunk)
			console.log(chunk)
		end)
		res:addListener('end', function()
			client_res_complete = true
			server:close()
		end)
	end)
end)

process:addListener("exit", function ()
	assert_equal("1\n2\n3\n", sent_body)
	assert_equal(true, server_req_complete)
	assert_equal(true, client_res_complete)
end)

process:loop()
end