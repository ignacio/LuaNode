module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")
net = require("luanode.net")

function test()

local binaryString = ""
for i = 255, 0, -1 do
	binaryString = binaryString .. string.char(i)
end

-- safe constructor
local echoServer = net.createServer(function (self, connection)
	connection:setEncoding("binary")
	connection:addListener("data", function (self, chunk)
		common.error("recved: %s", chunk)
		connection:write(chunk, "binary")
	end)
	connection:addListener("end", function ()
		connection:finish()
	end)
end)
echoServer:listen(common.PORT)

local recv = ""

echoServer:addListener("listening", function()
	local j = 0
	local c = net.createConnection(common.PORT)

	c:setEncoding("binary")
	c:addListener("data", function (self, chunk)
		if j < 256 then
			common.error("write " .. j);
			c:write(string.char(j), "binary")
			j = j + 1
		else
			c:finish()
		end
		recv = recv .. chunk
	end)

	c:addListener("connect", function ()
		c:write(binaryString, "binary")
	end)

	c:addListener("close", function ()
		common.p(recv)
		echoServer:close()
	end)
end)

process:addListener("exit", function ()
	console.log("recv: %s", recv)

	assert_equal(2 * 256, #recv)

	local a = recv

	local first = a:sub(1, 256):reverse()
  
	console.log("first: %s", first)

	local second = a:sub(257, 2 * 256)
	console.log("second: %s", second)

	assert_equal(first, second)
end)

process:loop()

end