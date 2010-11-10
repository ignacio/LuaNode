module(..., lunit.testcase, package.seeall)

local timers = require("luanode.timers")

function test()

	local count = 0
	local timer = process.Timer()
	timer.callback = function()
		print("timer callback", count)
		count = count + 1
		if count < 3 then
			timer:again(1000)
		end
	end
	
	timer:start(2000, 0)
	
	process:addListener("exit", function ()
		assert_equal(3, count)
	end)

	process:loop()
end