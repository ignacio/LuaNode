-- este test no funciona porque no tiro los eventos dentro de un pcall
module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require("luanode.net")
local http = require("luanode.http")


function test()
server = http.createServer(function (self, req, res)
	common.error('got req')
	error("This shouldn't happen.")
end)

server:addListener('upgrade', function (self, req, socket, upgradeHead)
	common.error('got upgrade event');
	-- test that throwing an error from upgrade gets
	-- is uncaught
	error('upgrade error')
end)

gotError = false

process:addListener('uncaughtException', function (e)
	common.error('got "clientError" event')
	assert_equal('upgrade error', e)
	gotError = true
	process:exit(0)
end)


server:listen(common.PORT, function ()
	local c = net.createConnection(common.PORT)

	c:addListener('connect', function ()
		common.error('client wrote message')
		c:write( "GET /blah HTTP/1.1\r\n"
			.. "Upgrade: WebSocket\r\n"
			.. "Connection: Upgrade\r\n"
			.. "\r\n\r\nhello world");
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
	assert_true(gotError)
end)

process:loop()
end