module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require "luanode.http"
local fs = require "luanode.fs"
local crypto = require ("luanode.crypto")

function test()

local caPem = fs.readFileSync(common.fixturesDir .. "/test_ca.pem", 'ascii')
local certPem = fs.readFileSync(common.fixturesDir .. "/test_cert.pem", 'ascii')
local keyPem = fs.readFileSync(common.fixturesDir .. "/test_key.pem", 'ascii')

local context = crypto.createContext{key = keyPem, cert = certPem, ca = caPem}

local google = http.createClient(443, "encrypted.google.com", true)
local request = google:request("GET", "/", { Host = "encrypted.google.com"})

--[[
google:addListener("connect", function () 
	console.info("connected")
	--google:setSecure(context)
end)
--]]

--setTimeout(function()
	--request:finish("")
--end, 2000)

request:finish("")

google:on("secure", function ()
	local verified = google:verifyPeer()
	local peerDN = google:getPeerCertificate()
	console.log(verified)
		
	console.log(peerDN.subject)
	console.log(peerDN.issuer)

	console.log(peerDN.valid_from)
	console.log(peerDN.valid_to)	-- should extend this
	console.log(peerDN.fingerprint)
	--c:write( "GET /hello?hello=world&foo=bar HTTP/1.1\r\n\r\n" );
	--requests_sent = requests_sent + 1
	--request:finish()
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
	--clearInterval(timer)
	
	response:on('data', function (self, chunk)
		console.log('BODY: %s', chunk)
	end)
end)


process:loop()

end
