module(..., lunit.testcase, package.seeall)

function test()

local http = require "luanode.http"

local google = http.createClient(80, 'www.google.com')
local request = google:request('GET', '/', { host = 'www.google.com'})

request:finish("")

local response_received = false

local timer = setTimeout(function()
	request.connection:destroy()
	assert_true(response_received, "A response should have arrived by now")
	process:exit(-1)
end, 5000)

request:on('response', function (self, response)
	console.log('STATUS: ' .. response.statusCode)
	console.log('HEADERS: ')
	for k,v in pairs(response.headers) do
		console.log(k, v)
	end
	
	response_received = true
	timer:stop()
	--clearInterval(timer)
	
	response:on('data', function (self, chunk)
		console.log('BODY: %s', chunk)
	end)
end)


process:loop()

end
