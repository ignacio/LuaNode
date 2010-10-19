local os = require "os"
local Timer = process.Timer	-- TODO: change this to require

module(..., package.seeall)

-- This iffers with node.js implementationin that it is not intrusive. It won't add stuff to sockets

local sockets = {}
-- make it weak-keyed, so the sockets can be collected
setmetatable(sockets, {__mode = "k"})

--
-- IDLE TIMEOUTS
--
-- Because often many sockets will have the same idle timeout we will not
-- use one timeout watcher per socket. It is too much overhead.  Instead
-- we'll use a single watcher for all sockets with the same timeout value
-- and a linked list. This technique is described in the libev manual:
-- http://pod.tst.eu/http://cvs.schmorp.de/libev/ev.pod#Be_smart_about_timeouts

local Timeout = {}

local lists = {}

--
-- show the most idle socket
local function peek(list)
	if list._idlePrev == list then
		return nil
	end
	return list._idlePrev
end

--
-- remove the most idle socket from the list
local function shift(list)
	local first = list._idlePrev
	remove(first)
	return first
end

-- remove a socket from its list
local function remove(socket)
	socket._idleNext._idlePrev = socket._idlePrev
	socket._idlePrev._idleNext = socket._idleNext
end

-- remove a socket from its list and place at the end
local function append(list, socket)
	remove(socket)
	socket._idleNext = list._idleNext
	socket._idleNext._idlePrev = socket
	socket._idlePrev = list
	list._idleNext = socket
end

local function normalize(msecs)
	if not msecs or msecs <= 0 then
		return 0
	end
	-- round up to one sec
	if msecs < 1000 then
		return 1000
	end
	-- round down to nearest second
	return msecs - (msecs % 1000)
end

--
-- the main function - creates lists on demand and the watchers associated with them
local function insert(socket, msecs)
	socket._idleStart = os.time() * 1000
	socket._idleTimeout = msecs
	
	if not msecs then return end
	
	local list
	if lists[msecs] then
		list = lists[msecs]
	else
		list = Timer()
		list._idleNext = list
		list._idlePrev = list
		
		lists[msecs] = list
		
		list.callback = function()
			print("timeout callback " .. tostring(msecs))
			
			-- TODO: don't stop and start the watcher all the time. Just set its repeat
			local now = os.time() * 1000
			print("now: " .. now)
			local first = peek(list)
			while first do
				local diff = now - first._idleStart
				if diff < msecs then
					list:again(msecs - diff)
					print(msecs .. " list wait because diff is " .. diff)
					return
				else
					remove(first)
					assert(first ~= peek(list))
					first.socket:emit("timeout")
				end
				first = peek(list)
			end
			
			print(msecs .. " list empty")
			assert(list._idleNext == list)	-- list is empty
			list:stop()
		end
	end
	
	if list._idleNext == list then
		-- if empty (re)start the timer
		list:again(msecs)
	end
	
	append(list, socket)
	assert(list._idleNext ~= list) -- list is not empty
end



Timeout.Unenroll = function(socket)
	local wrapper = sockets[socket]
	if wrapper then
	--if socket._idleNext then
		wrapper._idleNext._idlePrev = wrapper._idlePrev
		wrapper._idlePrev._idleNext = wrapper._idleNext
		
		local list = lists[wrapper._idleTimeout]
		-- if empty then stop the watcher
		if list and list._idlePrev == list then
			list:stop()
		end
		sockets[socket] = nil
	end
end

-- does not start the time, just sets up the members needed
Timeout.Enroll = function(socket, msecs)
	local wrapper = sockets[socket]
	-- if this socket was already in a list somewhere then we should unenroll it from that
	if wrapper then
		Timeout.Unenroll(wrapper.socket)
	end
	wrapper = { socket = socket }
	sockets[socket] = wrapper
	
	wrapper._idleTimeout = msecs
	wrapper._idleNext = socket
	wrapper._idlePrev = socket
	
	--[[
	if socket._idleNext then
		Timeout.Unenroll(socket)
	end
	
	socket._idleTimeout = msecs
	socket._idleNext = socket
	socket._idlePrev = socket
	--]]
end

-- call this whenever the socket is active (not idle) it will reset its timeout.
Timeout.Active = function(socket)
	local wrapper = sockets[socket]
	if not wrapper then
		return
	end
	
	local msecs = wrapper._idleTimeout
	if msecs then
		local list = lists[msecs]
		if wrapper._idleNext == socket then
			insert(wrapper, msecs)
		else
			-- inline append
			wrapper._idleStart = os.time() * 1000
			wrapper._idleNext._idlePrev = wrapper._idlePrev
			wrapper._idlePrev._idleNext = wrapper._idleNext
			wrapper._idleNext = list._idleNext
			wrapper._idleNext._idlePrev = wrapper
			wrapper._idlePrev = list
			list._idleNext = wrapper
		end
	end
end

return Timeout