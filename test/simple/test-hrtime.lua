require "lunit"

module(..., lunit.testcase, package.seeall)

function test()

	local t1 = process.hrtime()
	assert(type(t1) == "userdata", "process.hrtime() should return a userdata")

	local t2 = process.hrtime()

	-- time values can be substracted
	assert(type(t2 - t1) == "userdata", "the difference must be a userdata")

	-- time values can be compared
	assert_true(t2 > t1)
	assert_false(t1 > t2)
	assert_false(t2 < t1)
	assert_true(t1 < t2)
	assert_true(t2 >= t1)
	assert_false(t2 <= t1)

	local sec, nanosec = t1:split()
	assert_number(sec, "seconds is just a number")
	assert_number(nanosec, "nanoseconds is just a number")

	assert_number(t1:us(), "the number of microseconds is just a number")
	assert_number(t1:ms(), "the number of milliseconds is just a number")

	local start = process.hrtime()

	setTimeout(function()
		local end_time = process.hrtime(start)
		
		-- should be at around 1 second, with an error margin of 50 ms (to be safe)
		assert(math.abs(1000 - end_time:ms()) < 50)
		
		assert_number(sec, "seconds is just a number")
		assert_number(nanosec, "nanoseconds is just a number")

		assert_number(end_time:us(), "the number of microseconds is just a number")
		assert_number(end_time:ms(), "the number of milliseconds is just a number")
	end, 1000)

	process:loop()
end
