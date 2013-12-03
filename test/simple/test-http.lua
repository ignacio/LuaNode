module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")
http = require "luanode.http"
url = require "luanode.url"


function test()

local responses_sent = 0
local responses_recvd = 0
local body0 = ""
local body1 = ""

local server = http.createServer(function (self, req, res)
	if (responses_sent == 0) then
		assert_equal("GET", req.method)
		assert_equal("/hello", url.parse(req.url).pathname)

		print(req.headers)
		assert_equal(true, req.headers["accept"] and true)
		assert_equal("*/*", req.headers["accept"])

		assert_equal(true, req.headers["foo"] and true)
		assert_equal("bar", req.headers["foo"])
	end

	if (responses_sent == 1) then
		assert_equal("POST", req.method)
		assert_equal("/world", url.parse(req.url).pathname)
		self:close()
	end

	req:addListener('end', function (self)
		console.log("replying")
		res:writeHead(200, {["Content-Type"] = "text/plain"})
		res:write("The path was " .. url.parse(req.url).pathname)
		res:finish()
		responses_sent = responses_sent + 1
	end)

	--assert_equal("127.0.0.1", res.connection.remoteAddress);
end)
server:listen(common.PORT)

server:addListener("listening", function(self)
	local agent = http.Agent({ port = common.PORT, maxSockets = 1 })
	http.get({
		port = common.PORT,
		path = "/hello",
		headers = {Accept = "*/*", Foo = "bar" },
		agent = agent
	},
	function (_, res)
		assert_equal(200, res.statusCode)
		responses_recvd = responses_recvd + 1
		res:setEncoding("utf8")
		res:on('data', function (self, chunk)
			body0 = body0 .. chunk
		end)
		common.debug("Got /hello response")
	end)

	setTimeout(function ()
		req = http.request({
			port = common.PORT,
			method = "POST",
			path = "/world",
			agent = agent
		},
		function (self, res)
			assert_equal(200, res.statusCode)
			responses_recvd = responses_recvd + 1;
			res:setEncoding("utf8")
			res:addListener('data', function (self, chunk)
				body1 = body1 .. chunk
			end)
			common.debug("Got /world response")
		end)
		req:finish()
	end, 1)
end)

process:addListener("exit", function ()
	common.debug("responses_recvd: " .. responses_recvd)
	assert_equal(2, responses_recvd)

	common.debug("responses_sent: " .. responses_sent)
	assert_equal(2, responses_sent)

	assert_equal("The path was /hello", body0)
	assert_equal("The path was /world", body1)
end)

	process:loop()
end