module(..., lunit.testcase, package.seeall)

local dns = require "luanode.dns"
local os = require "luanode.os"
local net = require "luanode.net"

-- Retrieve this computer's hostname, and get its IP addresses
function test()
	os.getHostname(function(name)
		dns.lookupAll(name, 4, function(err, address, hostname)
			assert_nil(err)
			for k,v in ipairs(address) do
				assert_true(net.isIP(v.address))
			end
		end)
	end)

	process:loop()
end