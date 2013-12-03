module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
body = "hello world\n"
headers = {connection = 'keep-alive'}

local server = http.createServer(function (self, req, res)
	res:writeHead(200, {["Content-Length"] = #body, Connection="close"})
	res:write(body)
	res:finish()
end)

local connectCount = 0

server:listen(common.PORT, function () 
	
	local agent = http.Agent({ maxSockets = 1 })
	local request = http.request({
		method = "GET",
		path = "/",
		headers = headers,
		port = common.PORT,
		agent = agent,
	}, function()
		assert_equal(1, agent.sockets["localhost:"..common.PORT].length)
	end)
	request.id = "request 1"

	request:on("socket", function(_, s)
		s:on("connect", function()
			connectCount = connectCount + 1
		end)
	end)

	request:finish()
	--------------------

	request = http.request({
		method = "GET",
		path = "/",
		headers = headers,
		port = common.PORT,
		agent = agent,
	}, function()
		assert_equal(1, agent.sockets["localhost:"..common.PORT].length)
	end)
	request.id = "request 2"

	request:on("socket", function(_, s)
		s:on("connect", function()
			connectCount = connectCount + 1
		end)
	end)

	request:finish()
	--------------------

	request = http.request({
		method = "GET",
		path = "/",
		headers = headers,
		port = common.PORT,
		agent = agent,
	}, function(_, response)
		response:on("end", function()
			assert_equal(1, agent.sockets["localhost:"..common.PORT].length)
			server:close()
		end)
	end)

	request:on("socket", function(_, s)
		s:on("connect", function()
			connectCount = connectCount + 1
		end)
	end)

	request:finish()
end)

process:addListener('exit', function () 
	assert_equal(3, connectCount)
end)

process:loop()
end