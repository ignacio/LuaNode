module(..., lunit.testcase, package.seeall)

function test()
	
	if process.platform == "darwin" then
		-- process.title is not implemented yet on OS X
		return
	end
	process.title = "hello world"
	
	assert_equal("hello world", process.title)

	process:loop()
end
