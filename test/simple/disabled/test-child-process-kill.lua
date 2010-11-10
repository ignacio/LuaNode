module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")

local spawn = require('luanode.ChildProcess').spawn


function test()
local exitCode
local termSignal
local gotStdoutEOF = false
local gotStderrEOF = false

local cat = spawn("cat")


cat.stdout:addListener("data", function (self, chunk)
	assert_true(false)
end)

cat.stdout:addListener("end", function ()
	gotStdoutEOF = true
end)

cat.stderr:addListener("data", function (self, chunk)
	assert_true(false)
end)

cat.stderr:addListener("end", function ()
	gotStderrEOF = true
end)

cat:addListener("exit", function (self, code, signal)
	exitCode = code
	termSignal = signal
end)

cat:kill()

process:addListener("exit", function ()
	assert_equal(exitCode, nil)
	assert_equal(termSignal, 'SIGTERM')
	assert_true(gotStdoutEOF)
	assert_true(gotStderrEOF)
end)

process:loop()
end