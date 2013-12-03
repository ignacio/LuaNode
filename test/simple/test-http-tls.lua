-- This test needs httpAllowHalfOpen enabled, because it sends the last
-- requests (pipelined) and then calls finish.
-- The http implementation will close http connections that are half open.

module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require "luanode.net"
local http = require "luanode.http"
local url = require "luanode.url"
local qs = require "luanode.querystring"
local fs = require "luanode.fs"

function test()
local have_openssl
crypto = require ("luanode.crypto")
have_openssl = true
--have_openssl, crypto = pcall(require, "luanode.crypto")
if not have_openssl then
	console.log("Not compiled with OPENSSL support.")
	process:exit()
end

local request_number = 0
local requests_sent = 0
local server_response = ""
local client_got_eof = false
local caPem = fs.readFileSync(common.fixturesDir .. "/keys/ca1-cert.pem", 'ascii')
local certPem = fs.readFileSync(common.fixturesDir .. "/keys/agent1-cert.pem", 'ascii')
local keyPem = fs.readFileSync(common.fixturesDir .. "/keys/agent1-key.pem", 'ascii')

--try{
	local context = crypto.createContext{key = keyPem, cert = certPem, ca = caPem}
--} catch (e) {
--  console.log("Not compiled with OPENSSL support.");
--  process.exit();
--}


local https_server = http.createServer(function (self, req, res)
	res.id = request_number
	req.id = request_number
	request_number = request_number + 1
	
	-- we check against req instead of res, because the response may not have a connection bound to it
	-- see the way sockets are assigned on luanode.http -> parser.onIncoming
	local verified = req.connection:verifyPeer()
	local peerDN = req.connection:getPeerCertificate()
	assert_equal(true, verified)
	assert_equal("/C=UY/ST=Montevideo/L=Montevideo/O=LuaNode/OU=LuaNode/CN=agent1/emailAddress=iburgueno@gmail.com", peerDN.subject)
	assert_equal("/C=UY/ST=Montevideo/L=Montevideo/O=LuaNode/OU=LuaNode/CN=ca1/emailAddress=iburgueno@gmail.com", peerDN.issuer)

	if req.id == 0 then
		assert_equal("GET", req.method)
		assert_equal("/hello", url.parse(req.url).pathname)
		assert_equal("world", qs.parse(url.parse(req.url).query).hello)
		assert_equal("bar", qs.parse(url.parse(req.url).query).foo)
	end

	if req.id == 1 then
		assert_equal("POST", req.method)
		assert_equal("/quit", url.parse(req.url).pathname)
	end
	
	if req.id == 2 then
		assert_equal("foo", req.headers["x-x"])
	end

	if req.id == 3 then
		assert_equal("bar", req.headers['x-x']);
		self:close()
		console.log("server closed")
	end
	setTimeout(function ()
		console.log("reply")
		res:writeHead(200, {["Content-Type"] = "text/plain"})
		res:write(url.parse(req.url).pathname)
		res:finish()
	end, 1)
end)

https_server.httpAllowHalfOpen = true
https_server:setSecure(context)
https_server:listen(common.PORT)

https_server:addListener("listening", function()
	local c = net.createConnection(common.PORT)

	c:setEncoding("utf8")

	c:addListener("connect", function ()
		c:setSecure(context)
	end)

	c:addListener("secure", function ()
		local verified = c:verifyPeer()
		local peerDN = c:getPeerCertificate()
		assert_equal(true, verified)
		
		assert_equal("/C=UY/ST=Montevideo/L=Montevideo/O=LuaNode/OU=LuaNode/CN=agent1/emailAddress=iburgueno@gmail.com", peerDN.subject)
		assert_equal("/C=UY/ST=Montevideo/L=Montevideo/O=LuaNode/OU=LuaNode/CN=ca1/emailAddress=iburgueno@gmail.com", peerDN.issuer)

		c:write( "GET /hello?hello=world&foo=bar HTTP/1.1\r\n\r\n" );
		requests_sent = requests_sent + 1
	end)

	c:addListener("data", function (self, chunk)
		server_response = server_response .. chunk

		if requests_sent == 1 then
			c:write("POST /quit HTTP/1.1\r\n\r\n")
			requests_sent = requests_sent + 1
		end

		if requests_sent == 2 then
			c:write("GET /req1 HTTP/1.1\r\nX-X: foo\r\n\r\n"
				.. "GET /req2 HTTP/1.1\r\nX-X: bar\r\n\r\n")
			c:finish()
			assert_equal(c:readyState(), "readOnly")
			requests_sent = requests_sent + 2
		end
	end)

	c:addListener("end", function ()
		client_got_eof = true
	end)

	c:addListener("close", function ()
		assert_equal(c:readyState(), "closed")
	end)
end)

process:addListener("exit", function ()
	assert_equal(4, request_number)
	assert_equal(4, requests_sent)

	--console.log(server_response)
	--console.log(#server_response)
	
	assert_equal("/hello", server_response:match("/hello"));
	assert_equal("/quit", server_response:match("/quit"));
	assert_equal("/req1", server_response:match("/req1"));
	assert_equal("/req2", server_response:match("/req2"));
	
	assert_true(client_got_eof)
end)

process:loop()
end