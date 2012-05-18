require "luanode.net"

-- Connects to a server on port 8080 and tries to perform N connections.
-- Each connection is kept alive until the client is closed.

-- Example 1:
-- On another terminal (or machine):
--   luanode server.lua
-- On this terminal or machine.
--   ulimit -n 50
--   luanode client.lua 100
-- The client should not crash and must emit an error.

-- Example 2:
-- On another terminal (or machine):
--   ulimit -n 50
--   luanode server.lua
-- On this terminal or machine.
--   luanode client.lua 100
-- The server should log errors (Too many open files).
--  stop the client (ctrl-c)
-- The server must keep running.
--   luanode client.lua 100
-- The server must be able to accept another batch of connections.

local num_connections = 0

local max_connections = tonumber(process.argv[1]) or 1024
console.log("max_connections", max_connections)

local function create()
	local client = luanode.net.createConnection(8080)
	console.log("Created connection", num_connections)
	num_connections = num_connections + 1

	client:on("connect", function()
		if num_connections < max_connections then
			process.nextTick(create)
		end
	end)

	client:on("error", function(self, err)
		console.log(self, err)
	end)
end

process.nextTick(create)

process:loop()
