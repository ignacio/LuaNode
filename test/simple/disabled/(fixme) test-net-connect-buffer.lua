-- no anda porque el finish cuando el socket aun no esta conectado pierde los datos
module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require("luanode.net")

function test()
local tcpPort = common.PORT

--tcp = net.createServer(function (self, socket)
tcp = net.Server:new(function (self, s)
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

function startClient ()
	local socket = net.Stream:new()

	console.log("Connecting to socket")

	socket:connect(tcpPort)
	--socket._stream._stream = socket

	socket:on('connect', function ()
		console.log('socket connected')
		--socket:finish()		-- asi anda
	end)

	assert_equal("opening", socket:readyState())

	assert_equal(false, socket:write("foo"))
	socket:finish("bar")
	--socket:write("bar")	-- asi anda

	assert_equal("opening", socket:readyState())
end

tcp:listen(tcpPort, startClient)

process:loop()
end