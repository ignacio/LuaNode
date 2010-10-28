module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require "luanode.net"

function test()

local huge_data = ("start"):rep(1240):rep(1024)

local server = net.createServer(function (self, socket)
	--socket:setNoDelay()
	--socket.timeout = 0

	socket:setEncoding("utf8")
	
	socket:addListener("data", function (self, data)
		--assert_equal(true, socket.readable)
		--assert_equal(true, socket.writable)
		socket:write(data)
	end)

	socket:addListener("end", function (self)
		socket:finish()
	end)

	socket:addListener("error", function (self, e)
		error(e)
	end)

	socket:addListener("close", function (self)
		console.log("server socket.end")
		socket.server:close()
	end)
end)

server:listen(common.PORT, function (self)

	local client = net.createConnection(common.PORT)

	local data = {}
	client:setEncoding("ascii")
		
	client:addListener("connect", function ()
		client:write(huge_data)
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
		assert_true(huge_data == table.concat(data))
		if(#huge_data ~= #table.concat(data)) then
			console.error("no matchean")
		end
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