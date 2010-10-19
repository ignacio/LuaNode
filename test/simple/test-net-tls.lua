module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require "luanode.net"
local json = require "json"
local fs = require('luanode.fs')

function test()
local have_openssl

crypto = require ("luanode.crypto")
have_openssl = true
--have_openssl, crypto = pcall(require, "luanode.crypto")
if not have_openssl then
	console.log("Not compiled with OPENSSL support.")
	process:exit()
end

local caPem = fs.readFileSync(common.fixturesDir .. "/test_ca.pem", 'ascii')
local certPem = fs.readFileSync(common.fixturesDir .. "/test_cert.pem", 'ascii')
local keyPem = fs.readFileSync(common.fixturesDir .. "/test_key.pem", 'ascii')

--try{
  local credentials = crypto.createCredentials({key=keyPem, cert=certPem, ca=caPem})
--} catch (e) {
--  console.log("Not compiled with OPENSSL support.")
--  process.exit()
--}

local testData = "TEST123"
local serverData = ''
local clientData = ''
local gotSecureServer = false
local gotSecureClient = false

local secureServer = net.createServer(function (self, connection)
	local server = self
	console.log("server got connection: remoteAddress: %s:%s", connection:remoteAddress())
	connection:setSecure(credentials)
	connection:setEncoding("UTF8")

	connection:addListener("secure", function ()
		gotSecureServer = true
		local verified = connection:verifyPeer()
		local peerDN = connection:getPeerCertificate()
		assert_equal(verified, true)
		assert_equal(peerDN.subject, "/C=UK/ST=Acknack Ltd/L=Rhys Jones/O=node.js/OU=Test TLS Certificate/CN=localhost")
		assert_equal(peerDN.issuer, "/C=UK/ST=Acknack Ltd/L=Rhys Jones/O=node.js/OU=Test TLS Certificate/CN=localhost")

		assert_equal(peerDN.valid_from, "Nov 11 09:52:22 2009 GMT")
		assert_equal(peerDN.valid_to, "Nov  6 09:52:22 2029 GMT")
		assert_equal(peerDN.fingerprint, "2A:7A:C2:DD:E5:F9:CC:53:72:35:99:7A:02:5A:71:38:52:EC:8A:DF")	
	end)

	connection:addListener("data", function (self, chunk)
		serverData = serverData .. chunk
		connection:write(chunk)
	end)

	connection:addListener("end", function ()
		assert_equal(serverData, testData)
		connection:finish()
		server:close()
	end)
end)
secureServer:listen(common.PORT)

secureServer:addListener("listening", function()
	local secureClient = net.createConnection(common.PORT)

	secureClient:setEncoding("UTF8")
	secureClient:addListener("connect", function ()
		secureClient:setSecure(credentials)
	end)

	secureClient:addListener("secure", function ()
		gotSecureClient = true
		local verified = secureClient:verifyPeer()
		local peerDN = secureClient:getPeerCertificate()
		assert_equal(verified, true)
		assert_equal(peerDN.subject, "/C=UK/ST=Acknack Ltd/L=Rhys Jones/O=node.js/OU=Test TLS Certificate/CN=localhost")
		assert_equal(peerDN.issuer, "/C=UK/ST=Acknack Ltd/L=Rhys Jones/O=node.js/OU=Test TLS Certificate/CN=localhost")

		assert_equal(peerDN.valid_from, "Nov 11 09:52:22 2009 GMT")
		assert_equal(peerDN.valid_to, "Nov  6 09:52:22 2029 GMT")
		assert_equal(peerDN.fingerprint, "2A:7A:C2:DD:E5:F9:CC:53:72:35:99:7A:02:5A:71:38:52:EC:8A:DF")

		secureClient:write(testData)
		secureClient:finish()
	end)

	secureClient:addListener("data", function (self, chunk)
		clientData = clientData .. chunk
	end)

	secureClient:addListener("end", function ()
		assert_equal(clientData, testData)
	end)
end)

process:addListener("exit", function ()
	assert_true(gotSecureServer, "Did not get secure event for server")
	assert_true(gotSecureClient, "Did not get secure event for client")
end)


process:loop()
end