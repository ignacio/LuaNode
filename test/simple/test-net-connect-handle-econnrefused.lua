module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require("luanode.net")

function test()
-- Hopefully nothing is running on common.PORT
local c = net.createConnection(common.PORT)

c:on('connect', function ()
	console.error("connected?!");
	error("should not have happened")
end)

local gotError = false
c:on('error', function (self, e)
	console.debug("couldn't connect.")
	gotError = true
	--assert_equal(require('constants').ECONNREFUSED, e.errno)
	console.error(e)	-- TODO: propagar el codigo de error y no solo el mensaje
	--assert_equal(require('constants').ECONNREFUSED, e.errno)
end)


process:on('exit', function ()
  assert_true(gotError)
end)

process:loop()
end