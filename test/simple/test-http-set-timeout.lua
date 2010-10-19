module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
server = http.createServer(function (self, req, res)
	console.log('got request. setting 1 second timeout')
	req.connection:setTimeout(500)

	req.connection:addListener('timeout', function()
		common.debug("TIMEOUT")
		server:close()
	end)
end)

server:listen(common.PORT, function ()
	console.log('Server running at http://127.0.0.1:'..common.PORT..'/')

	errorTimer = setTimeout(function ()
		error('Timeout was not sucessful')
	end, 2000)

	http.cat('http://localhost:'..common.PORT..'/', 'utf8', function (self, err, content)
		clearTimeout(errorTimer)
		console.log('HTTP REQUEST COMPLETE (this is good)')
	end)
end)

process:loop()
end