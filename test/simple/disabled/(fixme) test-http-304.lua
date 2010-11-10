module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")

local http = require("luanode.http")
--childProcess = require('child_process');

function test()
	local s = http.createServer(function (self, request, response)
		response:writeHead(304)
		response:finish()
	end)

	s:listen(common.PORT, function ()
		--local a, b, c, d = io.popen(("curl -i http://127.0.0.1:%d/"):format(common.PORT))
		--print(a,b,c,d)
		--os.execute( ("curl -i http://127.0.0.1:%d/"):format(common.PORT) )
		--childProcess.exec('curl -i http://127.0.0.1:'+common.PORT+'/', function (err, stdout, stderr)
			--if err then error(err) end
			--s:close()
			--common.error('curled response correctly')
			--common.error(common.inspect(stdout))
		--end)
	end)

	console.log('Server running at http://127.0.0.1:'..common.PORT..'/')

	process:loop()
end