module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require "luanode.net"

function test()

local text = {}
for i = 1, 1000 do
	table.insert(text, "a random string that will be sent byte by byte and then")
end






local server = net.createServer(function (self, socket)
	--socket:setNoDelay()
	--socket.timeout = 0

	socket:setEncoding("utf8")
	
	socket:addListener("data", function (self, data)
		assert_equal(true, socket.readable)
		assert_equal(true, socket.writable)
		
		for i, t in ipairs(text) do
			socket:write(t)
		end
	end)

	socket:addListener("end", function (self)
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

server:listen(common.PORT, function (self)

	local client = net.createConnection(common.PORT)
	local data = {}

	client:setEncoding("ascii")
		
	client:addListener("connect", function ()
		client:write("start")
		client:finish()
	end)

	client:addListener("data", function (self, d)
		table.insert(data, d)
	end)
	
	client:addListener("end", function ()
		client:finish()
	end)

	client:addListener("close", function ()
		console.log("client.end")
		assert_equal(table.concat(text), table.concat(data))
	end)

	client:addListener("error", function (self, e)
		error(e)
	end)
end)


process:addListener("exit", function ()
	console.log("done")
end)

process:loop()
end