module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")

function test()
	local complete = 0

	process.nextTick(function ()
		complete = complete + 1
		process.nextTick(function ()
			complete = complete + 1
			process.nextTick(function ()
				complete = complete + 1
			end)
		end)
	end)

	setTimeout(function ()
		process.nextTick(function ()
			complete = complete + 1
		end)
	end, 50)

	process.nextTick(function ()
		complete = complete + 1
	end)


	process:addListener('exit', function ()
		assert_equal(5, complete)
	end)
	
	process:loop()
end