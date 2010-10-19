module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")

function test()
	assert_equal(true, process.cwd() ~= __dirname)

	process.chdir(__dirname)

	assert_equal(true, process.cwd() ~= __dirname)
end