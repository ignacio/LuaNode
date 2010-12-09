module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local EventEmitter = require "luanode.event_emitter"

function test()
local e = EventEmitter()
local num_args_emited = {}

e:on("numArgs", function(...)
	local numArgs = select("#", ...)
	console.log("numArgs: " .. numArgs)
	num_args_emited[#num_args_emited + 1] = numArgs
end)

console.log("start")

e:emit("numArgs")
e:emit("numArgs", 1)
e:emit("numArgs", 1, 2)
e:emit("numArgs", 1, 2, 3)
e:emit("numArgs", 1, 2, 3, 4)
e:emit("numArgs", 1, 2, 3, 4, 5)

process:addListener("exit", function ()
	for k,v in ipairs(num_args_emited) do
		assert_equal(k, v)
	end
end)

process:loop()
end

