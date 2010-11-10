module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require("luanode.net")

function test()
local serverConnection
local echoServer = net.createServer(function (self, connection)
	serverConnection = connection
	connection:setTimeout(0)
	assert_true(connection.setKeepAlive ~= nil)
	-- send a keepalive packet after 1000 ms
	connection:setKeepAlive(true, 1000)
	connection:addListener("end", function ()
		connection:finish()
	end)
end)
echoServer:listen(common.PORT)

echoServer:addListener("listening", function()
	local clientConnection = net.createConnection(common.PORT)
	clientConnection:setTimeout(0)

	setTimeout( function()
		-- make sure both connections are still open
		assert_equal("open", serverConnection:readyState())
		assert_equal("open", clientConnection:readyState())
		serverConnection:finish()
		clientConnection:finish()
		echoServer:close()
	end, 1200)
end)

process:loop()

end