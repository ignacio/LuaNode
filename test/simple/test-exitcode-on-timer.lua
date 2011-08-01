module(..., lunit.testcase, package.seeall)

function test()

local got_error = false

process:on("unhandledError", function(self, message)
	got_error = true
end)

local timer = setTimeout(function()
	error("foo")
end, 1000)


process:loop()
assert_true(got_error)

end