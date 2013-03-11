local STP = require "StackTracePlus"

module(..., lunit.testcase, package.seeall)

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