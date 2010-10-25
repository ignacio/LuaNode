module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require "luanode.net"

function test()
local tests_run = 0

function pingPong (port, host)
	local N = 1000
	local count = 0
	local sent_final_ping = false

	local server = net.createServer(function (self, socket)
		console.log("connection: %s:%d", socket:remoteAddress())
		assert_equal(self, socket.server)
		assert_equal(1, self.connections)

		socket:setNoDelay()
		socket.timeout = 0

		socket:setEncoding("utf8")
		socket:addListener("data", function (self, data)
			console.log("server got: %s", data)
			assert_equal(true, socket.writable)
			assert_equal(true, socket.readable)
			assert_equal(true, count <= N)
			if data:match("PING") then
				socket:write("PONG")
			end
		end)

		socket:addListener("end", function (self)
			assert_equal(true, socket.writable)
			assert_equal(false, socket.readable)
			socket:finish()
		end)

		socket:addListener("error", function (self, e)
			error(e)
		end)

		socket:addListener("close", function (self)
			console.log("server socket.end")
			assert_equal(false, socket.writable)
			assert_equal(false, socket.readable)
			socket.server:close()
		end)
	end)

	server:listen(port, host, function (self)
		console.log("server listening on " .. port .. " " .. (host and host or ""))

		local client = net.createConnection(port, host)
		collectgarbage()

		client:setEncoding("ascii")
		client:addListener("connect", function ()
			assert_equal(true, client.readable)
			assert_equal(true, client.writable)
			client:write("PING")
		end)

		client:addListener("data", function (self, data)
			console.log("client got: %s", data)

			assert_equal("PONG", data)
			count = count + 1

			if sent_final_ping then
				assert_equal(false, client.writable)
				assert_equal(true, client.readable)
				return
			else
				assert_equal(true, client.writable)
				assert_equal(true, client.readable)
			end

			if count < N then
				client:write("PING")
			else
				sent_final_ping = true
				client:write("PING")
				client:finish()
			end
		end)

		client:addListener("close", function ()
			console.log("client.end")
			assert_equal(N + 1, count)
			assert_equal(true, sent_final_ping)
			tests_run = tests_run + 1
		end)

		client:addListener("error", function (self, e)
			error(e)
		end)
	end)
end

-- All are run at once, so run on different ports
pingPong(20989, "localhost")
pingPong(20988)
--pingPong(20997, "::1")	-- deshabilitado porque mi notebook no soporta ipv6
--pingPong("/tmp/pingpong.sock")	-- aun no soporto unix domain sockets

process:addListener("exit", function ()
	--assert_equal(3, tests_run)
	assert_equal(2, tests_run)
	console.log("done")
end)

process:loop()
end