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
		console.log("end")
		socket:finish()
	end)
end)

local function upgradeRequest(fn)
	console.log('req')
	local header = { Connection = 'Upgrade', Upgrade = 'Test' }
    local request = http.request({ port = common.PORT, headers = header })	
	local wasUpgrade = false
	
	function onUpgrade(self, res, socket, head)
		console.log("client upgraded")
		wasUpgrade = true
		
		self:removeListener('upgrade', onUpgrade)
		socket:finish()
		
		-- Stop propagation and notify that "upgrade" event was caught
		-- Otherwise socket will be destroyed
		--return false
	end
	request:on('upgrade', onUpgrade)
	
	function onEnd()
		console.log("client end")
		request:removeListener('end', onEnd)
		if not wasUpgrade then
			error("hasn't received upgrade event")
		else
			if fn then
				process.nextTick(fn)
			end
		end
	end
	request:on('close', onEnd)
	
	request:write('head')
end

server:listen(common.PORT, function()
	
	successCount = 0
	upgradeRequest(function()
		successCount = successCount + 1
		upgradeRequest(function()
			successCount = successCount + 1
			-- Test pass
			console.log('Pass!')
			server:close()
		end)
	end)
end)

process:on('exit', function ()
	assert_equal(2, successCount)
end)

process:loop()
end