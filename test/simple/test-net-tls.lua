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

local caPem = fs.readFileSync(common.fixturesDir .. "/keys/ca1-cert.pem", 'ascii')
local certPem = fs.readFileSync(common.fixturesDir .. "/keys/agent1-cert.pem", 'ascii')
local keyPem = fs.readFileSync(common.fixturesDir .. "/keys/agent1-key.pem", 'ascii')

--try{
local context = crypto.createContext({key=keyPem, cert=certPem, ca=caPem})
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
	connection:setSecure(context)
	connection:setEncoding("UTF8")

	connection:addListener("secure", function ()
		local verified = connection:verifyPeer()
		assert_equal(true, verified)

		local peerDN = connection:getPeerCertificate()
		assert_equal("/C=UY/ST=Montevideo/L=Montevideo/O=LuaNode/OU=LuaNode/CN=agent1/emailAddress=iburgueno@gmail.com", peerDN.subject)
		assert_equal("/C=UY/ST=Montevideo/L=Montevideo/O=LuaNode/OU=LuaNode/CN=ca1/emailAddress=iburgueno@gmail.com", peerDN.issuer)
	
		gotSecureServer = true
	end)

	connection:addListener("data", function (self, chunk)
		serverData = serverData .. chunk
		connection:write(chunk)
	end)

	connection:addListener("end", function ()
		assert_equal(testData, serverData)
		connection:finish()
		server:close()
	end)
end)
secureServer:listen(common.PORT)

secureServer:addListener("listening", function()
	local secureClient = net.createConnection(common.PORT)

	secureClient:setEncoding("UTF8")
	secureClient:addListener("connect", function ()
		secureClient:setSecure(context)
	end)

	secureClient:addListener("secure", function ()
		local verified = secureClient:verifyPeer()
		local peerDN = secureClient:getPeerCertificate()
		
		assert_equal(true, verified)
		assert_equal("/C=UY/ST=Montevideo/L=Montevideo/O=LuaNode/OU=LuaNode/CN=agent1/emailAddress=iburgueno@gmail.com", peerDN.subject)
		assert_equal("/C=UY/ST=Montevideo/L=Montevideo/O=LuaNode/OU=LuaNode/CN=ca1/emailAddress=iburgueno@gmail.com", peerDN.issuer)
		
		secureClient:write(testData)
		secureClient:finish()
		
		gotSecureClient = true
	end)

	secureClient:addListener("data", function (self, chunk)
		clientData = clientData .. chunk
	end)

	secureClient:addListener("end", function ()
		assert_equal(testData, clientData)
	end)
end)

process:addListener("exit", function ()
	assert_true(gotSecureServer, "Did not get secure event for server")
	assert_true(gotSecureClient, "Did not get secure event for client")
end)


process:loop()
end