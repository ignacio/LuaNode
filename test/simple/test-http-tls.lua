module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local net = require "luanode.net"
local http = require "luanode.http"
local url = require "luanode.url"
local qs = require "luanode.querystring"
local fs = require "luanode.fs"
local json = require "json"

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
local caPem = fs.readFileSync(common.fixturesDir .. "/test_ca.pem", 'ascii')
local certPem = fs.readFileSync(common.fixturesDir .. "/test_cert.pem", 'ascii')
local keyPem = fs.readFileSync(common.fixturesDir .. "/test_key.pem", 'ascii')

--try{
	local credentials = crypto.createCredentials{key = keyPem, cert = certPem, ca = caPem}
--} catch (e) {
--  console.log("Not compiled with OPENSSL support.");
--  process.exit();
--}


local https_server = http.createServer(function (self, req, res)
	res.id = request_number
	req.id = request_number
	request_number = request_number + 1

	local verified = res.connection:verifyPeer()
	local peerDN = req.connection:getPeerCertificate()
	assert_equal(verified, true)
	assert_equal(peerDN.subject, "/C=UK/ST=Acknack Ltd/L=Rhys Jones/O=node.js/OU=Test TLS Certificate/CN=localhost")
	assert_equal(peerDN.issuer, "/C=UK/ST=Acknack Ltd/L=Rhys Jones/O=node.js/OU=Test TLS Certificate/CN=localhost")

	assert_equal(peerDN.valid_from, "Nov 11 09:52:22 2009 GMT")
	assert_equal(peerDN.valid_to, "Nov  6 09:52:22 2029 GMT")
	assert_equal(peerDN.fingerprint, "2A:7A:C2:DD:E5:F9:CC:53:72:35:99:7A:02:5A:71:38:52:EC:8A:DF")	

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
		--console.log("server closed")
	end
	setTimeout(function ()
		res:writeHead(200, {["Content-Type"] = "text/plain"})
		res:write(url.parse(req.url).pathname)
		res:finish()
	end, 1)
end)

https_server:setSecure(credentials)
https_server:listen(common.PORT)

https_server:addListener("listening", function()
	local c = net.createConnection(common.PORT)

	c:setEncoding("utf8")

	c:addListener("connect", function ()
		c:setSecure(credentials)
	end)

	c:addListener("secure", function ()
		local verified = c:verifyPeer()
		local peerDN = c:getPeerCertificate()
		assert_equal(verified, true)
		assert_equal(peerDN.subject, "/C=UK/ST=Acknack Ltd/L=Rhys Jones/O=node.js/OU=Test TLS Certificate/CN=localhost")
		assert_equal(peerDN.issuer, "/C=UK/ST=Acknack Ltd/L=Rhys Jones/O=node.js/OU=Test TLS Certificate/CN=localhost")

		assert_equal(peerDN.valid_from, "Nov 11 09:52:22 2009 GMT")
		assert_equal(peerDN.valid_to, "Nov  6 09:52:22 2029 GMT")
		assert_equal(peerDN.fingerprint, "2A:7A:C2:DD:E5:F9:CC:53:72:35:99:7A:02:5A:71:38:52:EC:8A:DF")	
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
			c:write("GET / HTTP/1.1\r\nX-X: foo\r\n\r\n"
				.. "GET / HTTP/1.1\r\nX-X: bar\r\n\r\n")
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
	
	assert_equal("/hello", server_response:match("/hello"));
	
	assert_equal("/quit", server_response:match("/quit"));
	
	assert_true(client_got_eof)
end)

process:loop()
end