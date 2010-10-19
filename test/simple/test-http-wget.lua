module(..., lunit.testcase, package.seeall)
local common = dofile("common.lua")
local net = require("luanode.net")
local http = require("luanode.http")


-- wget sends an HTTP/1.0 request with Connection: Keep-Alive
--
-- Sending back a chunked response to an HTTP/1.0 client would be wrong,
-- so what has to happen in this case is that the connection is closed
-- by the server after the entity body if the Content-Length was not
-- sent.
--
-- If the Content-Length was sent, we can probably safely honor the
-- keep-alive request, even though HTTP 1.0 doesn't say that the
-- connection can be kept open.  Presumably any client sending this
-- header knows that it is extending HTTP/1.0 and can handle the
-- response.  We don't test that here however, just that if the
-- content-length is not provided, that the connection is in fact
-- closed.
function test()

local server_response = ""
local client_got_eof = false
local connection_was_closed = false

local server = http.createServer(function (self, req, res)
	res:writeHead(200, {["Content-Type"] = "text/plain"})
	res:write("hello ")
	res:write("world\n")
	res:finish()
end)
server:listen(common.PORT)

server:addListener("listening", function()
	local c = net.createConnection(common.PORT);

	c:setEncoding("utf8")

	c:addListener("connect", function ()
		c:write("GET / HTTP/1.0\r\n" .. "Connection: Keep-Alive\r\n\r\n")
	end)

	c:addListener("data", function (self, chunk)
		console.log(chunk)
		server_response = server_response .. chunk
	end)

	c:addListener("end", function ()
		client_got_eof = true
		console.log('got end')
		c:finish()
	end)

	c:addListener("close", function ()
		connection_was_closed = true
		console.log('got close')
		server:close()
	end)
end)

process:addListener("exit", function ()
	local m = server_response:match("\r\n\r\n(.+)")
	assert_equal("hello world\n", m)
	assert_true(client_got_eof)
	assert_true(connection_was_closed)
end)

process:loop()

end
