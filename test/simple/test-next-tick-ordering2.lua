module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")

function test()
	local order = {}
	process.nextTick(function ()
		setTimeout(function()
			table.insert(order, 'setTimeout')
		end, 0)

		process.nextTick(function()
			table.insert(order, 'nextTick')
		end)
	end)

	process:addListener('exit', function ()
		assert_equal(order[1], 'nextTick')
		assert_equal(order[2], 'setTimeout')
	end)

	process:loop()
end