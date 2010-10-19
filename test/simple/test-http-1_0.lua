module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require("luanode.net")
local http = require("luanode.http")

function test()
	local body = "hello world\n"
	local server_response = ""
	local client_got_eof = false

	local server = http.createServer(function (self, req, res)
		assert_equal('1.0', req.httpVersion)
		assert_equal(1, req.httpVersionMajor)
		assert_equal(0, req.httpVersionMinor)
		res:writeHead(200, {["Content-Type"] = "text/plain"})
		res:finish(body)
	end)
	server:listen(common.PORT)

	server:addListener("listening", function()
		local c = net.createConnection(common.PORT)

		c:setEncoding("utf8")

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

	process:addListener("exit", function ()
		local m = server_response:match("^.+\r\n\r\n(.+)")
		assert_equal(body, m)
		assert_equal(true, client_got_eof)
	end)

	process:loop()
end