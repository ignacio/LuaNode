module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")
net = require('luanode.net')

-- This test creates 200 connections to a server and sets the server's
-- maxConnections property to 100. The first 100 connections make it through
-- and the last 100 connections are rejected.
-- TODO: test that the server can accept more connections after it reaches
-- its maximum and some are closed.

function test()
N = 200
count = 0
closes = 0
waits = {}

local connections = {}

function makeConnection (index)
	setTimeout(function ()
		local c = net.createConnection(common.PORT)
		table.insert(connections, c)
		c.gotData = false

		c:on('end', function ()
			c:finish()
		end)

		c:on('data', function (self, b)
			self.gotData = true
			assert_true(0 < #b)
		end)

		c:on('error', function (self, e)
			console.error("error %d: %s", index, e)
		end)

		c:on('close', function (self)
			console.error("closed %d", index);
			closes = closes + 1

			if (closes < N/2) then
				assert_true(server.maxConnections <= index, 
					index .. " was one of the first closed connections but shouldn't have been");
			end

			if (closes == N/2) then
				local cb
				console.error("calling wait callback.")
				cb = table.remove(waits, 1)
				while cb do
					cb()
					cb = table.remove(waits, 1)
				end
				server:close()
			end

			if (index <= server.maxConnections) then
				assert_equal(true, self.gotData, index .. " didn't get data, but should have")
			else
				assert_equal(false, self.gotData, index .. " got data, but shouldn't have")
			end
		end)
	end, index)
end

server = net.createServer(function (self, connection)
	count = count + 1
	console.error("connect %d", count)
	connection:write("hello")
	table.insert(waits, function ()
		connection:finish()
	end)
end)

server:listen(common.PORT, function ()
	for i = 1, N do
		makeConnection(i)
	end
end)

server.maxConnections = N / 2

console.error("server.maxConnections = %d", server.maxConnections)

process:on('exit', function ()
	assert_equal(N, closes);
end);

process:loop()
a=2
end