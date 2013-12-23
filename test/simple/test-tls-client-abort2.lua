module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local tls = require "luanode.tls"

function test()
	local errors = 0

	local conn = tls.connect({ port = common.PORT }, function()
		assert(false)	-- callback should never be executed
	end)

	conn:on("error", function()
		errors = errors + 1
		assert_pass(function()
			conn:destroy()
		end)
	end)

	process:on("exit", function()
		assert_equal(errors, 1)
	end)

	process:loop()
end
