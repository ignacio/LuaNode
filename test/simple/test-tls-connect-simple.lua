module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local fs = require "luanode.fs"
local tls = require "luanode.tls"

local clientConnected = 0
local serverConnected = 0

local options = {
	key = fs.readFileSync(common.fixturesDir .. "/keys/agent1-key.pem"),
	cert = fs.readFileSync(common.fixturesDir .. "/keys/agent1-cert.pem"),
}


function test()

local server = tls.Server(options, function(server, socket)
	serverConnected = serverConnected + 1
	if serverConnected == 2 then
		server:close()
	end
end)

server:listen(common.PORT, function()
	local client1 = tls.connect({ port = common.PORT }, function(client1)
		console.log("client 1 connect")
		clientConnected = clientConnected + 1
		client1:finish()
	end)

	local client2 = tls.connect({ port = common.PORT })
	client2:on("secureConnect", function()
		console.log("client 2 connect")
		clientConnected = clientConnected + 1
		client2:finish()
	end)
end)

process:on("exit", function()
	assert_equal(2, clientConnected)
	assert_equal(2, serverConnected)
end)

process:loop()
end
