-- no anda porque no propago errores en los callbacks del http parser
module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")

-- The purpose of this test is not to check HTTP compliance but to test the
-- binding. Tests for pathological http messages should be submitted
-- upstream to http://github.com/ry/http-parser for inclusion into
-- deps/http-parser/test.c

function test()
--local HTTPParser = process.binding('http_parser').HTTPParser;
local HTTPParser = process.HTTPParser

local parser = HTTPParser("request")

local request = "GET /hello HTTP/1.1\r\n\r\n"

local callbacks = 0

parser.onMessageBegin = function ()
	console.log("message begin")
	callbacks = callbacks + 1
end

parser.onHeadersComplete = function (self, info)
	for k,v in pairs(info) do
		console.log("headers complete: %s - %s", k, v)
	end
	assert_equal('GET', info.method)
	assert_equal(1, info.versionMajor)
	assert_equal(1, info.versionMinor)
	callbacks = callbacks + 1
end

parser.onURL = function (self, b, off, length)
	--throw new Error("hello world");
	callbacks = callbacks + 1
end

parser.onPath = function (self, b, off, length)
	console.log("path [" .. off .. ", " .. length .. "]")
	local path = b
	console.log("path = '" .. path .. "'")
	assert_equal('/hello', path)
	callbacks = callbacks + 1
end

parser:execute(request, 0, #request)
assert_equal(4, callbacks)

--
-- Check that if we throw an error in the callbacks that error will be
-- thrown from parser.execute()
--
-- FIXME: no anda esto

parser.onURL = function (self, b, off, length)
	error("hello world")
end

assert_error(function ()
	parser:execute(request, 0, #request)
end, Error, "hello world")


process:loop()
end