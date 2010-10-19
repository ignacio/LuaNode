module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

-- This test is to make sure that when the HTTP server
-- responds to a HEAD request, it does not send any body.
-- In this case it was sending '0\r\n\r\n'

function test()
local server = http.createServer(function(self, req, res)
	res:writeHead(200) 	-- broken: defaults to TE chunked
	res:finish()
end)
server:listen(common.PORT)

local responseComplete = false

server:addListener("listening", function()
	local req = http.createClient(common.PORT):request('HEAD', '/')
	common.error('req')
	req:finish()
	req:addListener('response', function (self, res)
		common.error('response');
		res:addListener('end', function()
			common.error('response end')
			server:close()
			responseComplete = true
		end)
	end)
end)

process:addListener('exit', function ()
	assert_true(responseComplete)
end)

process:loop()
end