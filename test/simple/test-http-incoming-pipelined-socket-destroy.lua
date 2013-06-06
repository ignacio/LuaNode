local http = require "luanode.http"
local net = require "luanode.net"
local common = dofile("common.lua")

-- Set up some timing issues where sockets can be destroyed
-- via either the req or res
local server = http.createServer(function(self, req, res)
	console.log("Got request %s", req.url)
	if req.url == "/1" then
		return setTimeout(function()
			req.socket:destroy()
		end)

	elseif req.url == "/2" then
		return process.nextTick(function()
			res:destroy()
		end)

	-- in one case, actually send a response in 2 chunks
	elseif req.url == "/3" then
		res:write("hello ")
		return setTimeout(function()
			res:finish("world!")
		end)
	else
		return res:destroy()
	end
end)

-- Make a bunch of requests pipelined on the same socket
function generator()
	local reqs = { 3, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4 }
	local t = {}
	for _, req in ipairs(reqs) do
		table.insert(t, "GET /" .. req .. " HTTP/1.1\r\n" ..
						"Host: localhost:" .. common.PORT .. "\r\n" ..
						"\r\n" ..
						"\r\n"
		)
	end

	return table.concat(t)
end

server:listen(common.PORT, function()

	local client = net.connect({ port = common.PORT })

	-- immediately write the pipelined requests.
	-- Some of these will not have a socket to destroy!
	client:write(generator())
	-- TODO: should use the write callback but I haven't implemented it yet
	setTimeout(function()
		server:close()
	end, 1000)
end)

process:on("exit", function(_, c)
	if not c then
		console.log("ok")
	end
end)

process:loop()
