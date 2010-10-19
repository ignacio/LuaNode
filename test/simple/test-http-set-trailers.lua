module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")
local net = require("luanode.net")

function test()
outstanding_reqs = 0

local server = http.createServer(function(self, req, res)
	res:writeHead(200, { {'content-type', 'text/plain'}, {"connection", "close"} })
	res:addTrailers({["x-foo"] = "bar"})
	res:finish("stuff\n")
end)
server:listen(common.PORT)

-- first, we test an HTTP/1.0 request.
server:addListener("listening", function()
	local c = net.createConnection(common.PORT);
	local res_buffer = ""

	c:setEncoding("utf8")

	c:addListener("connect", function ()
		outstanding_reqs = outstanding_reqs + 1
		c:write( "GET / HTTP/1.0\r\n\r\n" )
	end)

	c:addListener("data", function (self, chunk)
		--console.log(chunk);
		res_buffer = res_buffer .. chunk
	end)

	c:addListener("end", function ()
		c:finish()
		assert_true(not res_buffer:match("x%-foo"), "Trailer in HTTP/1.0 response.");
		outstanding_reqs = outstanding_reqs - 1
		if outstanding_reqs == 0 then
			server:close()
			process:exit()
		end
	end)
end)

-- now, we test an HTTP/1.1 request.
server:addListener("listening", function()
	local c = net.createConnection(common.PORT)
	local res_buffer = ""
	local tid

	c:setEncoding("utf8")

	c:addListener("connect", function ()
		outstanding_reqs = outstanding_reqs + 1
		c:write( "GET / HTTP/1.1\r\n\r\n" )
		tid = setTimeout(function()
			assert(false, "Couldn't find last chunk.")
		end, 2000)
	end)
	
	c:addListener("data", function (self, chunk)
		-- console.log(chunk);
		res_buffer = res_buffer .. chunk
	end)
	c:addListener("end", function()
		if res_buffer:match("0\r\n") then	-- got the end.
			outstanding_reqs = outstanding_reqs - 1
			clearTimeout(tid)
			assert_true(
				res_buffer:match("0\r\nx%-foo: bar\r\n\r\n$") ~= nil,
				"No trailer in HTTP/1.1 response."
			)
			if outstanding_reqs == 0 then
				server:close()
				process:exit()
			end
		end
	end)
end)

-- now, see if the client sees the trailers.
server:addListener('listening', function()
	local client = http.createClient(common.PORT)
	local req = client:request("/hello", {})
	req:finish()
	outstanding_reqs = outstanding_reqs + 1
	req:addListener('response', function (self, res)
		res:addListener('end', function ()
			--console.log(res.trailers);
			assert_true(res.trailers["x-foo"] ~= nil, "Client doesn't see trailers.")
			outstanding_reqs = outstanding_reqs - 1
			if outstanding_reqs == 0 then
				server:close()
				process:exit()
			end
		end)
	end)
end)

process:loop()
end