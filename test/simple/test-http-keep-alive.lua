module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
local body = "hello world\n"
local headers = {connection = "keep-alive"}

local server = http.createServer(function (self, req, res)
	res:writeHead(200, {["Content-Length"] = #body})
	res:write(body)
	res:finish()
end)

local name = "localhost:" .. common.PORT
local agent = http.Agent{ maxSockets = 1 }
local headers = { connection = "keep-alive" }

server:listen(common.PORT, function ()
	http.get({ path = "/", headers = headers, port = common.PORT, agent = agent }, function(self, response)
		assert_equal(1, agent.sockets[name].length)
		assert_equal(2, #agent.requests[name])
	end)

	http.get({ path = "/", headers = headers, port = common.PORT, agent = agent }, function(self, response)
		assert_equal(1, agent.sockets[name].length)
		assert_equal(1, #agent.requests[name])
	end)

	http.get({ path = "/", headers = headers, port = common.PORT, agent = agent }, function(self, response)

		response:on("end", function()
			assert_equal(1, agent.sockets[name].length)
			assert_nil(agent.requests[name])
			server:close()
		end)
	end)
end)

process:on("exit", function ()
	assert_nil(agent.requests[name])
	assert_nil(agent.sockets[name])
end)

process:loop()
end