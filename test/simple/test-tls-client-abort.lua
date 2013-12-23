module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local fs = require "luanode.fs"
local tls = require "luanode.tls"

function test()
	local key = fs.readFileSync(common.fixturesDir .. "/keys/agent1-key.pem")
	local cert = fs.readFileSync(common.fixturesDir .. "/keys/agent1-cert.pem")

	local conn = tls.connect({ cert = cert, key = key, port = common.PORT}, function()
		assert(false)	-- callback should never be executed
	end)

	conn:on("error", function()
	end)

	assert_pass(function()
		conn:destroy()
	end)

	process:loop()
end
