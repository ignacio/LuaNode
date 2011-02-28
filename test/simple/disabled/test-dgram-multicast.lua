module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local dgram = require "luanode.datagram"

--var dgram = require('dgram'),
  --  util = require('util'),
    --assert = require('assert'),
    --Buffer = require('buffer').Buffer;
	
function test()

local LOCAL_BROADCAST_HOST = '224.0.0.1'
local sendMessages = {
  'First message to send',
  'Second message to send',
  'Third message to send',
  'Fourth message to send'
}

local listenSockets = {}

local sendSocket = dgram.createSocket('udp4')

sendSocket:on('close', function()
	console.error('sendSocket closed')
end)

sendSocket:setBroadcast(true)

local i = 0

sendSocket.sendNext = function()
	i = i + 1
	local buf = sendMessages[i]

	if not buf then
		sendSocket:close()
		return
	end

	sendSocket:send(buf, 0, #buf, common.PORT, LOCAL_BROADCAST_HOST, function(self, err)
		if err then error(err) end
		console.error('sent %q to %q', buf, LOCAL_BROADCAST_HOST .. common.PORT)
		process.nextTick(sendSocket.sendNext)
	end)
end

local listener_count = 0

function mkListener()
	local receivedMessages = {}
	local listenSocket = dgram.createSocket('udp4')

	listenSocket:on('message', function(self, buf, rinfo)
		console.error('received %s from %j', buf, rinfo)
		receivedMessages[#receivedMessages + 1] = buf

		if #receivedMessages == #sendMessages then
			listenSocket:close()
		end
	end)

	listenSocket:on('close', function()
		console.error('listenSocket closed -- checking received messages')
		local count = 0
		for _,buf in ipairs(receivedMessages) do
			for _, msg in ipairs(sendMessages) do
				if buf == msg then
					count = count + 1
					break
				end
			end
		end
		console.error('count %d', count)
		--assert.strictEqual(count, sendMessages.length)
	end)

	listenSocket:on('listening', function()
		listenSockets[#listenSockets + 1] = listenSocket
		if #listenSockets == 3 then
			sendSocket:sendNext()
		end
	end)

	listenSocket:bind(common.PORT)
end

mkListener()
mkListener()
mkListener()

process:loop()

end