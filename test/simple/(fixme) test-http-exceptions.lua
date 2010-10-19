-- no anda porque en el event emitter no llamo los eventos con pcall
module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()

local server = http.createServer(function (self, req, res)
	intentionally_not_defined()
	res:writeHead(200, {["Content-Type"] = "text/plain"})
	res:write("Thank you, come again.")
	res:finish()
end)

server:listen(common.PORT, function ()
	local req
	for i=1, 4 do
		req = http.createClient(common.PORT):request('GET', '/busy/' .. i)
		req:finish()
	end
end)

local exception_count = 0

process:addListener("uncaughtException", function (self, err)
	console.log("Caught an exception: " .. err)
	--if err.name == "AssertionError" then
	--		error(err)
	--end
	exception_count = exception_count + 1
	if exception_count == 4 then
		process.exit(0)
	end
end)

process:loop()
end

