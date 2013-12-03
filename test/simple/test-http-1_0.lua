module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require("luanode.net")
local http = require("luanode.http")

local common_port = common.PORT

local function perform (handler, request_generator, response_validator)
	local port = common_port + 1
	common_port = port

	local server = http.createServer(handler)

	local client_got_eof = false
	local server_response = {
		data = "",
		chunks = {}
	}

	local function cleanup ()
		server:close()
		response_validator(server_response, client_got_eof, true)
	end
	local timer = setTimeout(cleanup, 1000)
	process:on("exit", cleanup)

	server:listen(port)
	server:on("listening", function()
		local c = net.createConnection(port)
		c:setEncoding("utf8")

		c:on("connect", function()
			c:write(request_generator())
		end)

		c:on("data", function(_, chunk)
			--console.warn(chunk)
			server_response.data = server_response.data .. chunk
			table.insert(server_response.chunks, chunk)
		end)

		c:on("end", function()
			client_got_eof = true
			c:finish()
			server:close()
			clearTimeout(timer)
			process:removeListener("exit", cleanup)
			response_validator(server_response, client_got_eof, false)
		end)
	end)
end

function test()
	do
		local function handler(_, req, res)
			assert_equal("1.0", req.httpVersion)
			assert_equal(1, req.httpVersionMajor)
			assert_equal(0, req.httpVersionMinor)
			res:writeHead(200, { ["Content-Type"] = "text/plain" })
			res:finish(body)
		end

		local function request_generator()
			return "GET / HTTP/1.0\r\n\r\n"
		end

		local function response_validator(server_response, client_got_eof, timed_out)
			local m = server_response.data:match("^.+\r\n\r\n(.+)")
			assert_equal(body, m)
			assert_true(client_got_eof)
			assert_false(timed_out)
		end

		perform(handler, request_generator, response_validator)
	end

	-- 
	-- Don't send HTTP/1.1 status lines to HTTP/1.0 clients.
	--
	do
		local function handler(_, req, res)
			assert_equal("1.0", req.httpVersion)
			assert_equal(1, req.httpVersionMajor)
			assert_equal(0, req.httpVersionMinor)
			res.sendDate = false
			res:writeHead(200, { ["Content-Type"] = "text/plain" })
			res:write("Hello, "); res:_send("")
			res:write("world!"); res:_send("")

			res:finish()
		end

		local function request_generator()
			return  "GET / HTTP/1.0\r\n" .. 
					"User-Agent: curl/7.19.7 (x86_64-pc-linux-gnu) libcurl/7.19.7 " .. 
					"OpenSSL/0.9.8k zlib/1.2.3.3 libidn/1.15\r\n" .. 
					"Host: 127.0.0.1:1337\r\n" .. 
					"Accept: */*\r\n" ..
					"\r\n"
		end

		local function response_validator(server_response, client_got_eof, timed_out)
			local expected_response =   "HTTP/1.1 200 OK\r\n" .. 
										"Content-Type: text/plain\r\n" .. 
										"Connection: close\r\n" .. 
										"\r\n" .. 
										"Hello, world!"
			assert_equal(expected_response, server_response.data)
			assert_equal(2, #server_response.chunks)
			assert_true(client_got_eof)
			assert_false(timed_out)
		end

		perform(handler, request_generator, response_validator)
	end

	do 
		local function handler(_, req, res)
			assert_equal("1.1", req.httpVersion)
			assert_equal(1, req.httpVersionMajor)
			assert_equal(1, req.httpVersionMinor)
			res.sendDate = false
			res:writeHead(200, { ["Content-Type"] = "text/plain" })
			res:write("Hello, "); res:_send("")
			res:write("world!"); res:_send("")
			res:finish()
		end

		local function request_generator()
			return  "GET / HTTP/1.1\r\n" .. 
					"User-Agent: curl/7.19.7 (x86_64-pc-linux-gnu) libcurl/7.19.7 " .. 
					"OpenSSL/0.9.8k zlib/1.2.3.3 libidn/1.15\r\n" .. 
					"Connection: close\r\n" ..
					"Host: 127.0.0.1:1337\r\n" .. 
					"Accept: */*\r\n" ..
					"\r\n"
		end

		local function response_validator(server_response, client_got_eof, timed_out)
			local expected_response =   "HTTP/1.1 200 OK\r\n" .. 
										"Content-Type: text/plain\r\n" .. 
										"Connection: close\r\n" .. 
										"Transfer-Encoding: chunked\r\n" .. 
										"\r\n" .. 
										"7\r\n" .. 
										"Hello, \r\n" .. 
										"6\r\n" .. 
										"world!\r\n" .. 
										"0\r\n" .. 
										"\r\n"
			assert_equal(expected_response, server_response.data)
			assert_equal(3, #server_response.chunks)
			assert_true(client_got_eof)
			assert_false(timed_out)
		end

		perform(handler, request_generator, response_validator)
	end

	process:loop()
end