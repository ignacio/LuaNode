module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")

function test()
	local order = {}
	local exceptionHandled = false

	-- This nextTick function will throw an error.  It should only be called once.
	-- When it throws an error, it should still get removed from the queue.
	process.nextTick(function()
		table.insert(order, "A")
		-- cause an error
		what()
	end)

	-- This nextTick function should remain in the queue when the first one
	-- is removed.  It should be called if the error in the first one is
	-- caught (which we do in this test).
	process.nextTick(function()
		table.insert(order, "C")
	end)

	process:addListener('unhandledError', function()
		if not exceptionHandled then
			exceptionHandled = true
			table.insert(order, "B")
		else
			-- If we get here then the first process.nextTick got called twice
			table.insert(order, "OOPS!")
		end
	end)

	process:addListener("exit", function()
		assert_equal("A", order[1])
		assert_equal("B", order[2])
		assert_equal("C", order[3])
	end)

	process:loop()
end