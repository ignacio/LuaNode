require "lunit"

module(..., lunit.testcase, package.seeall)

function test()

local t = process.Timer()

local flag = false

local callback = function()
	t.callback = function()
		flag = true
	end
	t:start(1000, 0)
end

local co = coroutine.create(function()
	setTimeout(callback, 1000)
	process:loop()
end)

coroutine.resume(co)
co = nil
for i=1,1000 do collectgarbage() end

assert_true(flag)

end
