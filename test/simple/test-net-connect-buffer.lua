module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require("luanode.net")

function test()
local tcpPort = common.PORT

local tcp
tcp = net.Server(function (self, s)
	tcp:close()

	console.log("tcp server connection")

	local buf = "";
	s:on('data', function (self, d)
		buf = buf .. d
	end)

	s:on('end', function ()
		assert_equal("foobar", buf)
		console.log("tcp socket disconnect")
		s:finish()
	end)

	s:on('error', function (self, e)
		console.log("tcp server-side error: " .. e)
		process:exit(1)
	end)
end)

tcp:listen(common.PORT, function()
	local socket = net.Socket()

	console.log("Connecting to socket")

	socket:connect(tcpPort, function()
		console.log('socket connected')
		connectHappened = true
	end)

	assert_equal("opening", socket:readyState())
	
	local r = socket:write("foo", function()
		fooWritten = true
		assert_true(connectHappened)
		console.error("foo written")
	end)

	assert_equal(false, r)
	socket:finish("bar")

	assert_equal("opening", socket:readyState())
end)

process:loop()
end
