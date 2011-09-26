require "lunit"

module(..., lunit.testcase, package.seeall)

function test()

local catched = false

local net = require "luanode.net"

local server = net.createServer(function()
	console.log("yep, I'm connected")
end)

server:listen(30303)

local client = net.createConnection(30303)
client:on("connect", function()
	console.log("client: connected")
	error("die!")
end)

client:on("error", function()
	catched = true
	server:close()
end)

process:loop()

assert_true(catched)
end
