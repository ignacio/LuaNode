---
-- Luanode.Net _doflush was not handling correctly errors on write_callback handlers
--
module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require "luanode.net"

function test()
	
	local server = net.createServer(function (self, socket)
		socket:write("hello")	-- this will succeed
		socket:write("hello")	-- this triggers the error
		self:close()
	end)
	
	server:listen(common.PORT, function(self)
		console.log("server listening on %s:%d", self:address())
		
		local client = net.createConnection(common.PORT, "127.0.0.1")
		client:on("connect", function()
			-- slam shut the connection, this will make the second write fail
			client._raw_socket:shutdown()
			--client._raw_socket:close()
		end)
		
	end)

	process:loop()
end
