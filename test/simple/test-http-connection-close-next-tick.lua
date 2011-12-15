module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")
local net = require("luanode.net")

function test()
local body = "hello world\n"

local server = http.createServer(function (self, req, res)
	process.nextTick(function()
		res:writeHead(200, {["Content-Length"] = #body})
		res:write(body)
		res:finish()
	end)
end)

server:listen(common.PORT, function ()
	local c = net.createConnection(common.PORT)
	local server_response = ""

	c:addListener("connect", function ()
		c:write( "GET / HTTP/1.0\r\n\r\n" )
	end)

	c:addListener("data", function (self, chunk)
		console.log(chunk)
		server_response = server_response .. chunk
	end)

	c:addListener("end", function ()
		client_got_eof = true
		c:finish()
		server:close()
	end)
end)

process:addListener('exit', function ()
	assert_true(client_got_eof)
end)

process:loop()
end