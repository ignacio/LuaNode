-- TODO: implement rejectUnauthorized

module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local tls = require "luanode.tls"
local fs = require "luanode.fs"


local function authorized ()
	local socket = tls.connect(common.PORT, { rejectUnauthorized = true,
		ca = fs.readFileSync(common.fixturesDir .. "/keys/agent1-key.pem"),
	}, function(socket)
		assert(socket.authorized)
		socket:finish()
		server:close()
	end)

	socket:on("error", function(_, err)
		console.log(err)
		assert(false)
	end)
	socket:write("ok")
end

local function rejectUnauthorized ()
	local socket = tls.connect(common.PORT, { rejectUnauthorized = true	}, function(socket)
		console.log("err")
		assert(false)
	end)

	socket:on("error", function(_, err)
		console.debug(err)
		authorized()
	end)
	socket:write("ng")
end


local function unauthorized ()
	local socket = tls.connect(common.PORT, function(socket)
		assert(not socket.authorized)
		socket:finish()
		rejectUnauthorized()
	end)
	socket:on("error", function(_, err)
		console.log(err)
		assert(false)
	end)
	socket:write("ok")
end



function test()
	local connectCount = 0

	local options = {
		key = fs.readFileSync(common.fixturesDir .. "/keys/agent1-key.pem"),
		cert = fs.readFileSync(common.fixturesDir .. "/keys/agent1-cert.pem")
	}

	local server = tls.createServer(options, function(socket)
		connectCount = connectCount + 1
		socket:on("data", function(self, data)
			console.debug(data)
			assert_equal(data, "ok")
		end)
	end)
	server:listen(common.PORT, function()
		unauthorized()
	end)

	process:on("exit", function()
		assert_equal(connectCount, 3)
	end)

	process:loop()
end
