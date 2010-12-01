module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
	-- first 204 or 304 works, subsequent anything fails
	local codes = { 204, 200 }

	-- Methods don't really matter, but we put in something realistic.
	local methods = {'DELETE', 'DELETE'}

	local server = http.createServer(function (self, req, res)
		local code = table.remove(codes, 1)
		assert_number(code)
		assert_true(code > 0)
		console.debug('writing %d response', code)
		res:writeHead(code, {})
		res:finish()
	end)

	local client = http.createClient(common.PORT)

	function nextRequest()
		local method = table.remove(methods, 1)
		console.debug("writing request: %s", method)
	
		local request = client:request(method, '/')
		request:on('response', function (self, response)
			if #methods == 1 then
				assert_equal(204, response.statusCode)
			else
				assert_equal(200, response.statusCode)
			end
			response:on('end', function()
				if #methods == 0 then
					console.debug("close server")
					server:close()
				else
					-- throws error:
					nextRequest()
					-- works just fine:
					--process.nextTick(nextRequest)
				end
			end)
		end)
		request:finish()
	end

	server:listen(common.PORT, nextRequest)

	process:loop()
end