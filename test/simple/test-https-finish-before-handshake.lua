module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require "luanode.http"
local fs = require "luanode.fs"
local crypto = require ("luanode.crypto")

function test()

local google = http.createClient(443, "encrypted.google.com", true)
local request = google:request("GET", "/", { Host = "encrypted.google.com"})


request:finish("")

google:on("secure", function ()
	console.log("secure")
	local verified = google:verifyPeer()
	local peerDN = google:getPeerCertificate()
	
	assert_true(verified)
		
	console.log(peerDN.subject)
	console.log(peerDN.issuer)

	console.log(peerDN.valid_from)
	console.log(peerDN.valid_to)
	console.log(peerDN.fingerprint)
end)



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
