module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")
local net = require("luanode.net")

-- Verify that the 'upgrade' header causes an 'upgrade' event to be emitted to
-- the HTTP client. This test uses a raw TCP server to better control server
-- behavior.
function test()

	-- Create a TCP server
	local srv = net.createServer(function(self, c)
		local data = ''
		c:addListener('data', function(self, d)
			data = data .. d
			
			if data:match("\r\n\r\n$") then
				c:write('HTTP/1.1 101\r\n')
				c:write('hello: world\r\n')
				c:write('connection: upgrade\r\n')
				c:write('upgrade: websocket\r\n')
				c:write('\r\n')
				c:write('nurtzo')
			end
		end)

		c:addListener('end', function()
			c:finish()
		end)
	end)

	local gotUpgrade = false
	
	srv:listen(common.PORT, '127.0.0.1', function()

		local hc = http.createClient(common.PORT, '127.0.0.1')
		hc:addListener('upgrade', function(self, res, socket, upgradeHead)
			-- XXX: This test isn't fantastic, as it assumes that the entire response
			--      from the server will arrive in a single data callback
			assert_equal('nurtzo', upgradeHead)
		
			for k,v in pairs(res.headers) do
				console.log("%s - %s", k, v)
			end
			for k,v in pairs({ hello="world", connection= "upgrade", upgrade= "websocket" }) do
				assert_equal(v, res.headers[k])
			end

			socket:finish()
			srv:close()
	
			gotUpgrade = true
			
			-- Stop propagation and notify node, that "upgrade" event was caught
			-- Otherwise socket will be destroyed
			return false
		end)
		hc:request('GET', '/'):finish()
	end)

	process:addListener('exit', function()
		assert_true(gotUpgrade)
	end)

	process:loop()
end