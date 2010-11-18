module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require("luanode.net")
local http = require("luanode.http")

function test()

local server = http.createServer(function (self, req, res)
	assert_equal("M-SEARCH", req.method)
	assert_equal("*", req.url)

	res:writeHead(200, { Connection = 'close' })
	res:finish()
end)

server.listen(common.PORT, function ()

	local stream = net.createConnection(common.PORT)
	body = ""
	stream:setEncoding("ascii")
	stream:on("data", function (chunk)
		body = body .. chunk
	end)
	stream:on("end", function ()
		server:close()
	end)
	stream:write([[
M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
MX: 3
ST: urn:schemas-upnp-org:device:InternetGatewayDevice:1

]])
end)

process:loop()
end