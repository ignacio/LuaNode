module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")

local http = require("luanode.http")
local net = require("luanode.net")

function test()
	local gotReq = false

	local server = http.createServer(function (self, req, res)
		common.error('got req')
		gotReq = true
		assert_equal('GET', req.method)
		assert_equal('/blah', req.url)
		assert_equal("mapdevel.trolologames.ru:443", req.headers.host)
		assert_equal("http://mapdevel.trolologames.ru", req.headers.origin)
		assert_equal("", req.headers.cookie)
	end)


	server:listen(common.PORT, function ()
		local c = net.createConnection(common.PORT)

		c:addListener('connect', function ()
			common.error('client wrote message')
			c:write( "GET /blah HTTP/1.1\r\n"
				.. "Host: mapdevel.trolologames.ru:443\r\n"
				.. "Cookie:\r\n"
				.. "Origin: http://mapdevel.trolologames.ru\r\n"
				.. "\r\n\r\nhello world"
			)
		end)

		c:addListener('end', function ()
			c:finish()
		end)

		c:addListener('close', function ()
			common.error('client close')
			server:close()
		end)
	end)


	process:addListener('exit', function ()
		assert_true(gotReq)
	end)

	process:loop()
end