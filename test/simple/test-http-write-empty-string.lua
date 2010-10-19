module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
server = http.createServer(function (self, request, response)
	console.log('responding to ' .. request.url)

	response:writeHead(200, {['Content-Type'] = 'text/plain'})
	response:write('1\n')
	response:write('')
	response:write('2\n')
	response:write('')
	response:finish('3\n')

	self:close()
end)

local response = ""

process:addListener('exit', function ()
	assert_equal('1\n2\n3\n', response)
end)


server:listen(common.PORT, function ()
	local client = http.createClient(common.PORT)
	local req = client:request("/")
	req:finish()
	req:addListener('response', function (self, res)
		assert_equal(200, res.statusCode)
		res:setEncoding("ascii");
		res:addListener('data', function (self, chunk)
			response = response .. chunk
		end)
		common.error("Got /hello response")
	end)
end)

process:loop()
end