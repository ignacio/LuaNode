module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local https = require "luanode.https"
local fs = require "luanode.fs"
local crypto = require ("luanode.crypto")

function test()

local request = https.request{ method = "GET", path = "/", host = "encrypted.google.com" }

request:finish("")


local response_received = false

local timer = setTimeout(function()
	request.connection:destroy()
	assert_true(response_received, "A response should have arrived by now")
	process:exit(-1)
end, 5000)

request:on('response', function (self, response)
	console.log('STATUS: ' .. response.statusCode)
	console.log('HEADERS: ')
	for k,v in pairs(response.headers) do
		console.log(k, v)
	end
	
	response_received = true
	timer:stop()
end)


process:loop()

end
