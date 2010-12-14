module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require("luanode.net")
local http = require("luanode.http")

function test()
local requests_recv = 0
local requests_sent = 0
local request_upgradeHead = null

function createTestServer()
	local server = http.Server()

	server:addListener("connection", function()
		requests_recv = requests_recv + 1
	end)

	server:addListener("request", function(self, req, res)
		res:writeHead(200, {["Content-Type"] = "text/plain"})
		res:write("okay")
		res:finish()
	end)

	server:addListener("upgrade", function(self, req, socket, upgradeHead)
		socket:write( "HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
					.. "Upgrade: WebSocket\r\n"
					.. "Connection: Upgrade\r\n"
					.. "\r\n\r\n");

		request_upgradeHead = upgradeHead

		socket.ondata = function(self, d, start, finish)
			local data = d
			if data == "kill" then
				socket:finish()
			else
				socket:write(data, "utf8")
			end
		end
		
		-- Stop propagation and notify that "upgrade" event was caught
		-- Otherwise socket will be destroyed
		return false
	end)
		
	return server
end

function writeReq(socket, data, encoding)
	requests_sent = requests_sent + 1
	socket:write(data)
end

local server = createTestServer()

-----------------------------------------------
--  connection: Upgrade with listener
-----------------------------------------------
function test_upgrade_with_listener(_server)
	local conn = net.createConnection(common.PORT)
	conn:setEncoding("utf8")
	local state = 0

	conn:addListener("connect", function ()
		writeReq( conn
				, "GET / HTTP/1.1\r\n"
				.. "Upgrade: WebSocket\r\n"
				.. "Connection: Upgrade\r\n"
				.. "\r\n"
				.. "WjN}|M(6")
	end)

	conn:addListener("data", function (self, data)
		state = state + 1

		assert_string(data)

		if state == 1 then
			assert_equal("HTTP/1.1 101", data:sub(1, 12))
			assert_equal("WjN}|M(6", request_upgradeHead)
			conn:write("test", "utf8")
		elseif state == 2 then
			assert_equal("test", data)
			conn:write("kill", "utf8")
		end
	end)

	conn:addListener("end", function()
		assert_equal(2, state)
		conn:finish()
		_server:removeAllListeners("upgrade")
		test_upgrade_no_listener()
	end)
end

-----------------------------------------------
--  connection: Upgrade, no listener
-----------------------------------------------
local test_upgrade_no_listener_ended = false

function test_upgrade_no_listener()
	local conn = net.createConnection(common.PORT)
	conn:setEncoding("utf8")

	conn:addListener("connect", function ()
		writeReq(conn, "GET / HTTP/1.1\r\nUpgrade: WebSocket\r\nConnection: Upgrade\r\n\r\n")
	end)

	conn:addListener("end", function()
		test_upgrade_no_listener_ended = true
		conn:finish()
	end)

	conn:addListener("close", function()
		test_standard_http()
	end)
end

-----------------------------------------------
--  connection: normal
-----------------------------------------------
function test_standard_http()
	local conn = net.createConnection(common.PORT);
	conn:setEncoding("utf8");

	conn:addListener("connect", function ()
		writeReq(conn, "GET / HTTP/1.1\r\n\r\n")
	end)

	conn:addListener("data", function(self, data)
		if data:match("^0") then return end
		assert_string(data)
		assert_equal("HTTP/1.1 200", data:sub(1, 12))
		conn:finish()
	end)

	conn:addListener("close", function(self)
		server:close()
	end)
end

server:listen(common.PORT, function ()
	-- All tests get chained after this:
	test_upgrade_with_listener(server)
end)

-----------------------------------------------
--  Fin.
-----------------------------------------------
process:addListener("exit", function ()
	assert_equal(3, requests_recv)
	assert_equal(3, requests_sent)
	assert_true(test_upgrade_no_listener_ended)
end)


process:loop()
end