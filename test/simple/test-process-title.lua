module(..., lunit.testcase, package.seeall)

function test()
	
	process.title = "hello world"
	
	assert_equal("hello world", process.title)

	process:loop()
end
