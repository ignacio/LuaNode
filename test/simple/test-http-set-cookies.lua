module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
nresponses = 0

local server = http.createServer(function(self, req, res)
	if req.url == '/one' then
		res:writeHead(200, { {'set-cookie', 'A'},
							{'content-type', 'text/plain'} });
		res:finish("one\n")
	else
		res:writeHead(200, { {'set-cookie', 'A'},
							{'set-cookie', 'B'},
							{'content-type', 'text/plain'} });
		res:finish("two\n")
	end
end)
server:listen(common.PORT)

server:addListener("listening", function()
	--
	-- one set-cookie header
	--
	local client = http.createClient(common.PORT)
	local req = client:request('GET', '/one')
	req:finish()

	req:addListener('response', function(self, res)
		-- set-cookie headers are always return in an array.
		-- even if there is only one.
		assert_equal("A", res.headers['set-cookie'][1])
		assert_equal('text/plain', res.headers['content-type'])
	
		res:addListener('data', function(self, chunk)
			console.log(chunk)
		end)

		res:addListener('end', function()
			nresponses = nresponses + 1
			if nresponses == 2 then
				server:close()
			end
		end)
	end)

	-- two set-cookie headers

	local client = http.createClient(common.PORT)
	local req = client:request('GET', '/two')
	req:finish()

	req:addListener('response', function(slef, res)
		for k,v in ipairs({'A', 'B'}) do
			assert_equal(v, res.headers['set-cookie'][k])
		end
		assert_equal('text/plain', res.headers['content-type'])

		res:addListener('data', function(self, chunk)
			console.log(chunk)
		end)

		res:addListener('end', function()
			nresponses = nresponses + 1
			if nresponses == 2 then
				server:close()
			end
		end)
	end)

end)

process:addListener("exit", function ()
	assert_equal(2, nresponses)
end)

process:loop()
end