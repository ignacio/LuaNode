local os = require "os"
local Timer = process.Timer	-- TODO: change this to require
local setmetatable, print, assert, select, unpack, type, tostring =
		setmetatable, print, assert, select, unpack, type, tostring

--local process = process

module((...))

function debug(...)
	--if DEBUG 
end

-- This differs with node.js implementationin that it is not intrusive. It won't add stuff to items

local items = {}
-- make it weak-keyed, so the items can be collected
setmetatable(items, {__mode = "k"})

--
-- IDLE TIMEOUTS
--
-- Because often many items will have the same idle timeout we will not
-- use one timeout watcher per item. It is too much overhead.  Instead
-- we'll use a single watcher for all items with the same timeout value
-- and a linked list. This technique is described in the libev manual:
-- http://pod.tst.eu/http://cvs.schmorp.de/libev/ev.pod#Be_smart_about_timeouts

local Timers = {}

local lists = {}

--
-- show the most idle item
local function peek(list)
	if list._idlePrev == list then
		return nil
	end
	return list._idlePrev
end

--
-- remove the most idle item from the list
local function shift(list)
	local first = list._idlePrev
	remove(first)
	return first
end

-- remove a item from its list
local function remove(item)
	item._idleNext._idlePrev = item._idlePrev
	item._idlePrev._idleNext = item._idleNext
end

-- remove a item from its list and place at the end
local function append(list, item)
	--remove(item)
	item._idleNext = list._idleNext
	list._idleNext._idlePrev = item
	item._idlePrev = list
	list._idleNext = item
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
local function insert(item, msecs)
	item._idleStart = os.time() * 1000
	item._idleTimeout = msecs
	
	if msecs < 0 then return end
	
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
					if first.item._onTimeout then
						first.item:_onTimeout()
					end
						--:emit("timeout")
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
	
	append(list, item)
	assert(list._idleNext ~= list) -- list is not empty
end

--
--
Timers.Unenroll = function(item)
	local wrapper = items[item]
	if wrapper then
	--if item._idleNext then
		wrapper._idleNext._idlePrev = wrapper._idlePrev
		wrapper._idlePrev._idleNext = wrapper._idleNext
		
		local list = lists[wrapper._idleTimeout]
		-- if empty then stop the watcher
		if list and list._idlePrev == list then
			list:stop()
		end
		items[item] = nil
	end
end

--
-- does not start the time, just sets up the members needed
Timers.Enroll = function(item, msecs)
	local wrapper = items[item]
	-- if this item was already in a list somewhere then we should unenroll it from that
	if wrapper then
		Timers.Unenroll(wrapper.item)
	end
	wrapper = { item = item }
	items[item] = wrapper
	
	wrapper._idleTimeout = msecs
	wrapper._idleNext = item
	wrapper._idlePrev = item
end

--
-- call this whenever the item is active (not idle) it will reset its timeout.
Timers.Active = function(item)
	local wrapper = items[item]
	if not wrapper then
		return
	end
	
	local msecs = wrapper._idleTimeout
	if msecs then
		local list = lists[msecs]
		if wrapper._idleNext == item then
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

--
-- Timers
--
function Timers.setTimeout(callback, after, ...)
	assert(callback, "A callback function must be supplied")
	local timer
	
	-- Can't use timer lists.
	-- I'm failing simple/test-next-tick-ordering.lua
	-- It's either that boost::deadline_timer are firing out of order (unlikely) or that having a resolution of one second 
	-- (due to os.time) is what is causing trouble
	--if after <= 0 then
		-- Use the slow case for after == 0
		timer = Timer()
		timer.callback = callback
	--[[
	else
		timer = {
			_idleTimeout = after,
			item = {
				_onTimeout = callback
			}
		}
		timer._idlePrev = timer
		timer._idleNext = timer
		items[timer] = timer
	end
	--]]
	
	--
	-- Sometimes setTimeout is called with arguments, EG
	--
	--   setTimeout(callback, 2000, "hello", "world")
	--
	-- If that's the case we need to call the callback with
	-- those args. The overhead of an extra closure is not
	-- desired in the normal case.
	--
	
	if select("#", ...) > 0 then
		local args = {...}
		local cb = function()
			callback(unpack(args))
		end
		if type(timer) == "userdata" then
			timer.callback = cb
		else
			timer.item._onTimeout = cb
		end
	end
	
	if type(timer) == "userdata" then
		timer:start(after, 0)
	else
		Timers.Active(timer)
	end
	return timer
end

function Timers.clearTimeout(timer)
	--TODO: assert(timer es un timer posta)
	timer.callback = nil
	timer._onTimeout = nil
	Timers.Unenroll(timer)
	if type(timer) == "userdata" then
		timer:stop()	-- for after == 0
	end
end

function Timers.setInterval(callback, repeat_, ...)
	assert(callback, "A callback function must be supplied")
	local timer = Timer()
	if select("#", ...) > 0 then
		local args = {...}
		timer.callback = function()
			callback(unpack(args))
		end
	else
		timer.callback = callback
	end
	timer:start(repeat_, repeat_ and repeat_ or 1)
	return timer
end

function Timers.clearInterval (timer)
	--TODO: assert(timer es un timer posta)
	timer.callback = nil
	timer:stop()
end

return Timers