require "luanode.net"

-- Starts a server on port 8080. It just logs how many connections are established at a given time.

local server = luanode.net.createServer(function(server, connection)
	console.info("New connection (current: %d)", server.connections)

	connection:on("end", function()
		console.info("Client closed connection (current: %d)", server.connections)
		connection:finish()
	end)
end)

server:listen(8080, function()
	console.info("Server listening on port 8080")
end)

process:loop()
