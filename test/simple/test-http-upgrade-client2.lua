module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")
local CRLF = '\r\n'

function test()
local server = http.createServer()
server:on('upgrade', function(self, req, socket, head)
	socket:write('HTTP/1.1 101 Ok' .. CRLF ..
				'Connection: Upgrade' .. CRLF ..
				'Upgrade: Test' .. CRLF .. CRLF .. 'head')
	socket:on('end', function ()
		socket:finish()
	end)
end)
server:listen(8000)

local client = http.createClient(8000)

function upgradeRequest(fn)
	local request = client:request('GET', '/', {
		Connection = 'Upgrade',
		Upgrade = 'Test'
	})
	
	local wasUpgrade = false
	
	function onUpgrade(self, res, socket, head)
		wasUpgrade = true
		
		client:removeListener('upgrade', onUpgrade)
		socket:finish()
	end
	client:on('upgrade', onUpgrade)
	
	function onEnd()
		client:removeListener('end', onEnd);
		if not wasUpgrade then
			error("hasn't received upgrade event")
		else
			if fn then
				process.nextTick(fn)
			end
		end
	end
	client:on('end', onEnd)
	
	request:write('head');
end

successCount = 0
upgradeRequest(function()
	successCount = successCount + 1
	upgradeRequest(function()
		successCount = successCount + 1
		-- Test pass
		console.log('Pass!')
		client:finish()
		client:destroy()
		server:close()
	end)
end)

process:on('exit', function ()
	assert_equal(2, successCount)
end)

process:loop()
end