module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require "luanode.net"

function test()

local N = 50

local c = 0
local client_recv_count = 0
local disconnect_count = 0

local server = net.createServer(function (self, socket)
	socket:addListener("connect", function ()
		socket:write("hello\r\n")
	end)

	socket:addListener("end", function ()
		socket:finish()
	end)

	socket:addListener("close", function (self, had_error)
		assert_equal(false, had_error)
	end)
end)

server:listen(common.PORT, function ()
	console.log("listening")
	local client = net.createConnection(common.PORT)

	client:setEncoding("UTF8")

	client:addListener("connect", function ()
		console.log("client connected.")
	end)

	client:addListener("data", function (self, chunk)
		client_recv_count = client_recv_count + 1
		console.log("client_recv_count %d", client_recv_count)
		assert_equal("hello\r\n", chunk)
		client:finish()
	end)

	client:addListener("close", function (self, had_error)
		console.log("disconnect")
		assert_equal(false, had_error)
		disconnect_count = disconnect_count + 1
		if disconnect_count < N then
			client:connect(common.PORT) -- reconnect
		else
			server:close()
		end
	end)
end)

process:addListener("exit", function ()
	assert_equal(N, disconnect_count)
	assert_equal(N, client_recv_count)
end)

process:loop()
end