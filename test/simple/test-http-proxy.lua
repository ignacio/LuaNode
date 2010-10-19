module(..., lunit.testcase, package.seeall)

require "json"

local common = dofile("common.lua")
local http = require("luanode.http")
local url = require("luanode.url")

function test()
local PROXY_PORT = common.PORT
local BACKEND_PORT = common.PORT + 1

local cookies = { "session_token=; path=/; expires=Sun, 15-Sep-2030 13:48:52 GMT",
					"prefers_open_id=; path=/; expires=Thu, 01-Jan-1970 00:00:00 GMT" }

local headers = {["content-type"] = "text/plain",
				["set-cookie"] = cookies,
				hello = "world" }

local backend = http.createServer(function (self, req, res)
	common.debug("backend request");
	res:writeHead(200, headers)
	res:write("hello world\n")
	res:finish()
end)

local proxy_client = http.createClient(BACKEND_PORT)
local proxy = http.createServer(function (self, req, res)
	common.debug("proxy req headers: " .. json.encode(req.headers))
	local proxy_req = proxy_client:request(url.parse(req.url).pathname)
	proxy_req:finish()
	proxy_req:addListener('response', function(self, proxy_res)

		common.debug("proxy res headers: " .. json.encode(proxy_res.headers))
		assert_equal('world', proxy_res.headers['hello'])
		assert_equal('text/plain', proxy_res.headers['content-type'])
		for k,v in ipairs(cookies) do
			assert_equal(v, proxy_res.headers['set-cookie'][k])
		end

		res:writeHead(proxy_res.statusCode, proxy_res.headers)

		proxy_res:addListener("data", function(self, chunk)
			res:write(chunk)
		end)

		proxy_res:addListener("end", function()
			res:finish()
			common.debug("proxy res")
		end)
	end)
end)

local body = ""

nlistening = 0
function startReq ()
	nlistening = nlistening + 1
	if nlistening < 2 then return end

	local client = http.createClient(PROXY_PORT)
	local req = client:request("/test")
	common.debug("client req")
	req:addListener('response', function (self, res)
		common.debug("got res")
		assert_equal(200, res.statusCode)

		assert_equal('world', res.headers['hello'])
		assert_equal('text/plain', res.headers['content-type'])
		for k,v in ipairs(cookies) do
			assert_equal(v, res.headers['set-cookie'][k])
		end
	
		res:setEncoding("utf8")
		res:addListener('data', function (self, chunk)
			body = body .. chunk
		end)
		res:addListener('end', function ()
			proxy:close()
			backend:close()
			common.debug("closed both")
		end)
	end)
	req:finish()
end

common.debug("listen proxy")
proxy:listen(PROXY_PORT, startReq)

common.debug("listen backend")
backend:listen(BACKEND_PORT, startReq)

process:addListener("exit", function ()
	assert_equal("hello world\n", body)
end)

process:loop()
end