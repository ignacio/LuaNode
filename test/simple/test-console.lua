module(..., lunit.testcase, package.seeall)

function test()

	assert_true(process.stdout.writable)
	assert_true(process.stderr.writable)

	local stdout_write = process.stdout.write
	local strings = {}
	process.stdout.write = function (self, string)
		table.insert(strings, string)
	end

	console.log("foo")
	console.log("foo", "bar")
	console.log("%s %s", "foo", "bar", "hop")
	--console.log({slashes = "\\\\"})

	process.stdout.write = stdout_write
	assert_equal("foo\r\n", strings[1])
	assert_equal("foo\tbar\r\n", strings[2])
	assert_equal("foo bar\r\n", strings[3])
	--assert_equal("{ slashes: '\\\\\\\\' }\n", strings[4])

	process.stderr:write("hello world\r\n")

	assert_error(function ()
		console.timeEnd('no such label')
	end)

	assert_pass(function()
		console.time("label")
		console.timeEnd("label")
	end)

	process:loop()
end
