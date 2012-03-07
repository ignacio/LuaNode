local assert, type, error, ipairs, print, pcall = assert, type, error, ipairs, print, pcall
local table, setmetatable = table, setmetatable
local select = select

local Class = require "luanode.class"


-- This constructs instances of "Event Emitters"

local EventEmitter = Class{
	__init = function(class, t)
		t = t or {}
		t._events = {}
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
			result = listeners[i](self, ...)
			-- Stop propagating if listener returned false
			if result == false then break end
		end
		--print("after emitting " .. kind)
		--return true
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
--
EventEmitter.on = EventEmitter.addListener
function EventEmitter:once(kind, listener)
	local function callback(...)
		self:removeListener(kind, callback)
		listener(...)
	end
	self:on(kind, callback)
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
