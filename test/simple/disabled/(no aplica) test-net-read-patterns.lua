module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require "luanode.net"

function test()

local message = [[
a text that spawns many lines
here's one
here's another]]
--message = message:rep(1000)

local server = net.createServer(function (self, socket)

	socket:setNoDelay()
	socket:setEncoding("utf8")

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
		--socket.server:close()
	end)
		
	--socket:write(message)
	socket:write("hola\r\n")
end)

server:listen(common.PORT, function (self)

--[[
	local client = net.createConnection(common.PORT)
	local data = ""

	client:setEncoding("ascii")

	client:addListener("data", function (self, d)
		console.log("client got: %s", d)
		data = data .. d
		if #data == #message then
			client:finish()
		end
	end)
	
	client:addListener("end", function ()
		client:finish()
	end)

	client:addListener("close", function ()
		console.log("client.end")
		assert_equal(message, data)
	end)

	client:addListener("error", function (self, e)
		error(e)
	end)
	--]]
end)


process:addListener("exit", function ()
	console.log("done")
end)

process:loop()
end