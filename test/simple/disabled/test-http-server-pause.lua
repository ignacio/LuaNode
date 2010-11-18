module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")
local net = require("luanode.net")

function test()

local serverResponse = ""
local clientGotEOF = false

server = http.createServer(function (self, req, res)
	console.log('server req')
	assert_equal('/hello', req.url)
	assert_equal('GET', req.method)

	req:pause()

	local timeoutComplete = false

	req:addListener('data', function (self, d)
		console.log('server req data')
		assert_equal(true, timeoutComplete)
		assert_equal(12, #d)
	end)

	req:addListener('end', function (self, d)
		console.log('server req end')
		assert_equal(true, timeoutComplete)
		res:writeHead(200)
		res:finish("bye\n")
		server:close()
	end)

	setTimeout(function ()
		timeoutComplete = true
		req:resume()
	end, 500)
end)


server:listen(common.PORT, function ()
	local c = net.createConnection(common.PORT)

	c:setEncoding("utf8")

	c:addListener("connect", function ()
		c:write( "GET /hello HTTP/1.1\r\n"
			.. "Content-Type: text/plain\r\n"
			.. "Content-Length: 12\r\n"
			.. "\r\n"
			.. "hello world\n"
		)
		c:finish()
	end)

	c:addListener("data", function (self, chunk)
		serverResponse = serverResponse .. chunk
	end)

	c:addListener("end", function ()
		clientGotEOF = true
	end)

	c:addListener("close", function ()
		assert_equal(c:readyState(), "closed")
	end)
end)


process:addListener("exit", function ()
	assert_equal("bye", serverResponse:match("bye"))
	assert_true(clientGotEOF)
end)

	process:loop()
end