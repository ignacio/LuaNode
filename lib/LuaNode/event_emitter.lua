local assert, type, error, ipairs, print, pcall = assert, type, error, ipairs, print, pcall
local table, setmetatable = table, setmetatable
local select = select

local Class = require "luanode.class"


-- This constructs instances of "Event Emitters"

local EventEmitter = Class{
	__init = function(class, t)
		t = t or {}
		t._events = {}
		t._co_waiting = {}
		return Class.base.rawnew(class, t)
	end
}

--
--
function EventEmitter:emit(kind, ...)
	assert(type(self) == "table" or type(self) == "userdata")
	-- If there is no 'error' event listener then throw.
	if kind == "error" then
		if not self._events or not self._events.error or ( type(self._events.error) == "table" and #(self._events.error) ) then
			-- squash the arguments and build an error message
			local msg = ""
			for i=1, select("#", ...) do
				msg = msg .. tostring( select(i, ...) ) .. "\n"
			end
			error(msg, 2)
		end
	end
	
	if not self._events then return false end
	
	local handler = self._events[kind]
	if not handler then return false end
	
	local result
	
	if type(handler) == "function" then
		result = handler(self, ...)
		
	elseif type(handler) == "table" then
		local listeners = {}
		for k,v in ipairs(handler) do listeners[k] = v end
		--print("before emitting " .. kind)
		for i = 1, #listeners do
			local listener = listeners[i]
			if type(listener) == "function" then
				result = listener(self, ...)
			elseif type(listener) == "thread" and self._co_waiting[listener] == "kind" then
				result = coroutine.resume(listener, self, ...)
			end
			-- Stop propagating if listener returned false
			if result == false then break end
		end
		--print("after emitting " .. kind)
		--return true
	elseif type(handler) == "thread" and self._co_waiting[handler] == kind then
		-- only resume the thread if it is indeed waiting for the event
		result = coroutine.resume(handler, self, ...)
		
	else
		--return false
	end
	
	return result == false
end

--
--
function EventEmitter:addListener(kind, listener)
	if type(listener) ~= "function" then
		error("addListener only takes functions")
	end
	
	self._events = self._events or {}
	
	-- To avoid recursion in the case that kind == "newListeners"! Before
	-- adding it to the listeners, first emit "newListeners".
	self:emit("newListener", kind, listener)
	
	local listeners = self._events[kind]
	if not listeners then
		-- Optimize the case of one listener. Don't need an extra table
		self._events[kind] = listener
	elseif type(listeners) == "table" then
		-- If we've already got an array, just append.
		listeners[#listeners + 1] = listener
	else
		-- Adding the second element, need to change to array.
		self._events[kind] = { listeners, listener }
	end
	
	return self
end

--
-- Wait for a given event, using a coroutine.
function EventEmitter:wait(kind, coro)
	coro = coro or coroutine.running()
	if type(coro) ~= "thread" then
		error("wait only takes threads as argument (or you're not on a running thread)")
	end
	
	self._events = self._events or {}
	
	-- To avoid recursion in the case that kind == "newListeners"! Before
	-- adding it to the listeners, first emit "newListeners".
	self:emit("newListener", kind, coro)
	
	local listeners = self._events[kind]
	if not listeners then
		-- Optimize the case of one listener. Don't need an extra table
		self._events[kind] = coro
	elseif type(listeners) == "table" then
		-- If we've already got an array, just append.
		listeners[#listeners + 1] = coro
	else
		-- Adding the second element, need to change to array.
		self._events[kind] = { listeners, coro }
	end
	
	self._co_waiting[coro] = kind
	
	local results = { coroutine.yield(kind) }
	self._co_waiting[coro] = nil
	return unpack(results)
end

--[[
function EventEmitter:resumeOn (kind)
end
--]]

--
--
EventEmitter.on = EventEmitter.addListener

function EventEmitter:once(kind, listener)
	local t = {}
	t.callback = function(...)
		self:removeListener(kind, t.callback)
		listener(...)
	end
	self:on(kind, t.callback)
end

--
--
function EventEmitter:removeListener(kind, listener)
	if type(listener) ~= "function" then
		error("removeListener only takes functions")
	end
	
	-- does not use listeners(), so no side effect of creating _events[type]
	if not self._events or not self._events[kind] then
		return self
	end
	
	local list = self._events[kind]
	if type(list) == "table" then
		for i, l in ipairs(list) do
			if l == listener then
				table.remove(list, i)
				return self
			end
		end
	elseif list == listener then
		self._events[kind] = nil
	end
	
	return self
end

--
--
function EventEmitter:removeAllListeners(kind)
	if kind and self._events and self._events[kind] then
		self._events[kind] = nil
	end
	
	return self
end

--
-- Returns an array of listeners for the specified event. This array can be manipulated, e.g. to 
-- remove listeners.
function EventEmitter:listeners(kind)
	self._events = self._events or {}
	self._events[kind] = self._events[kind] or {}
	
	if type(self._events[kind]) ~= "table" then
		self._events[kind] = { self._events[kind] }
	end
	
	return self._events[kind]
end

return EventEmitter
