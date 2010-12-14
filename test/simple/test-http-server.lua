module(..., lunit.testcase, package.seeall)


local common = dofile("common.lua")
local http = require("luanode.http")
local net = require("luanode.net")
local url = require("luanode.url")
local qs = require("luanode.querystring")

function test()
	local request_number = 0
	local requests_sent = 0
	local server_response = ""
	local client_got_eof = false

	local server = http.createServer(function (self, req, res)
		res.id = request_number
		req.id = request_number
		request_number = request_number + 1

		if req.id == 0 then
			assert_equal("GET", req.method)
			assert_equal("/hello", url.parse(req.url).pathname)
			assert_equal("world", qs.parse(url.parse(req.url).query).hello)
			assert_equal("b==ar", qs.parse(url.parse(req.url).query).foo)
		end

		if req.id == 1 then
			common.error("req 1")
			assert_equal("POST", req.method)
			assert_equal("/quit", url.parse(req.url).pathname)
		end

		if req.id == 2 then
			common.error("req 2")
			assert_equal("foo", req.headers['x-x'])
		end

		if req.id == 3 then
			common.error("req 3")
			assert_equal("bar", req.headers['x-x'])
			self:close()
			common.error("server closed")
		end

		setTimeout(function ()
			res:writeHead(200, {["Content-Type"] = "text/plain"})
			res:write(url.parse(req.url).pathname)
			res:finish()
		end, 1)
	end)
	server:listen(common.PORT)

	server:addListener("listening", function()
		local c = net.createConnection(common.PORT)

		c:setEncoding("utf8")

		c:addListener("connect", function ()
			c:write( "GET /hello?hello=world&foo=" .. qs.url_encode("b==ar") .. " HTTP/1.1\r\n\r\n" )
			requests_sent = requests_sent + 1
		end)

		c:addListener("data", function (self, chunk)
			server_response = server_response .. chunk
	
			if requests_sent == 1 then
				c:write("POST /quit HTTP/1.1\r\n\r\n")
				requests_sent = requests_sent + 1
			end

			if requests_sent == 2 then
				c:write("GET / HTTP/1.1\r\nX-X: foo\r\n\r\n" .. "GET / HTTP/1.1\r\nX-X: bar\r\n\r\n")
				c:finish()
				--assert_equal(c:readyState(), "readOnly")
				requests_sent = requests_sent + 2
			end
		end)

		c:addListener("end", function ()
			client_got_eof = true
		end)

		c:addListener("close", function ()
			assert_equal(c:readyState(), "closed")
		end)
	end)

	process:addListener("exit", function ()
		assert_equal(4, request_number)
		assert_equal(4, requests_sent)

		assert_equal(true, server_response:match("/hello") ~= nil)
	
		assert_equal(true, server_response:match("/quit") ~= nil)

		assert_equal(true, client_got_eof)
	end)

	process:loop()
end