module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
local body = "exports.A = function() { return 'A';}"
local server = http.createServer(function (self, req, res)
	console.log("got request")
	res:writeHead(200, {
		["Content-Length"] = #body,
		["Content-Type"] = "text/plain"
	})
	res:finish(body)
end)

local got_good_server_content = false
local bad_server_got_error = false

server:listen(common.PORT, function ()
	http.cat("http://localhost:" .. common.PORT .. "/", "utf8", function (self, err, content)
	--http.cat("http://127.0.0.1:" .. common.PORT .. "/", "utf8", function (self, err, content)
		if err then
			error(err)
		else
			console.log("got response")
			got_good_server_content = true
			assert_equal(body, content)
			server:close()
		end
	end)

	http.cat("http://localhost:12312/", "utf8", function (self, err, content)
		if err then
			console.log("got error (this should happen)")
			bad_server_got_error = true
		end
	end)
end)

process:addListener("exit", function ()
	console.log("exit")
	assert_equal(true, got_good_server_content)
	assert_equal(true, bad_server_got_error)
end)

process:loop()
end