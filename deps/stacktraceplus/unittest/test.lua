local STP = require "StackTracePlus"

module(..., lunit.testcase, package.seeall)

function testLuaModule()
	local f = function()
		local t = table
		error("an error")
	end

	local ok, err = xpcall(f, STP.stacktrace)
	assert_match( [[t = table module]], err, "" )
end

function testKnownFunction()
	local my_function = function()
	end
	local f = function()
		error("an error")
	end
	STP.add_known_function(my_function, "this is my function")

	local ok, err = xpcall(f, STP.stacktrace)
	assert_match( [['this is my function']], err, "" )
end

function testKnownTable()
	local my_table = {}
	local f = function()
		error("an error")
	end
	STP.add_known_table(my_table, "this is my table")

	local ok, err = xpcall(f, STP.stacktrace)
	assert_match( [[ = this is my table]], err, "" )
end

function testCoroutine()
	local var_outside_co = {}

	local function helper()
		local arg_helper = "hi there!"
		error("an error")
	end

	local co = coroutine.create(function()
		local arg_inside_co = "arg1"
		helper()
	end)

	local status, err_msg = coroutine.resume(co)
	assert_false(status)

	local trace = STP.stacktrace(co)
	assert_match("arg_inside_co", trace)
	assert_match("arg_helper", trace)
end

---
-- Test case for issue #4
-- https://github.com/ignacio/StackTracePlus/issues/4
--
-- When building the stack trace, if there is a table or userdata with a __tostring metamethod which may throw an 
-- error, we fail with 'error in error handling'.
--
function test_error_in_tostring()
	local t = setmetatable({}, {
		__tostring = function()
			error("Error in tostring")
		end
	})

	local f = function()
		error("an error")
	end

	local ok, err = xpcall(f, STP.stacktrace)
	assert_not_equal("error in error handling", err)
end
