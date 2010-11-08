local assert, type, error, ipairs, print, pcall = assert, type, error, ipairs, print, pcall
local table, setmetatable = table, setmetatable
local select = select

module((...))

_M.__index = _M

--TODO: better check for array-like tables
local function isArray(t)
	if type(t) == "table" then
		return true
	end
	return false
end

-- esto debe construir instancias de "EventEmitters"

-- self._events = {}

--
--
function _M:emit(kind, ...)
	assert(type(self) == "table" or type(self) == "userdata")
	-- If there is no 'error' event listener then throw.
	if kind == "error" then
		if not self._events or not self._events.error or 
			( isArray(self._events.error) and #(self._events.error) )
		then
			-- TODO: entender como funciona esta parte en events.js@EventEmitter.emit
			-- porque cuando esto ocurre (desde un callback) se tranca la consola y ctrl-c no la mata
			error(...)
		end
	end
	
	if not self._events then return false end
	
	local handler = self._events[kind]
	if not handler then return false end
	
	if type(handler) == "function" then
		local num_args = select("#", ...)
		if num_args == 0 then
			--print("before emitting " .. kind)
			handler(self)
			--print("after emitting " .. kind)
		elseif num_args <= 2 then
			-- TODO: consolidar en uno solo? esto como que no aplica en Lua...
			--fast case
			local arg1 = select(1, ...)
			local arg2 = select(2, ...)
			--print("before emitting " .. kind)
			--print(type(handler))
			handler(self, arg1, arg2)
			--print("after emitting " .. kind)
		else
			-- slow case
			--print("before emitting " .. kind)
			handler(self, ...)
			--print("after emitting " .. kind)
		end
		
	elseif isArray(handler) then
		local listeners = {}
		for k,v in ipairs(handler) do listeners[k] = v end
		--print("before emitting " .. kind)
		for i = 1, #listeners do
			listeners[i](self, ...)
		end
		--print("after emitting " .. kind)
		return true
	else
		return false
	end
end

--
--
function _M:addListener(kind, listener)
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
_M.on = _M.addListener

function _M:once(kind, listener)
	local t = {}
	t.callback = function(...)
		self:removeListener(kind, t.callback)
		listener(self, ...)
	end
	self:on(kind, t.callback)
end

--
--
function _M:removeListener(kind, listener)
	if type(listener) ~= "function" then
		error("removeListener only takes functions")
	end
	
	-- does not use listeners(), so no side effect of creating _events[type]
	if not self._events or not self._events[kind] then
		return self
	end
	
	local list = self._events[kind]
	if isArray(list) then
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
function _M:removeAllListeners(kind)
	if kind and self._events and self._events[kind] then
		self._events[kind] = nil
	end
	
	return self
end

--
-- Returns an array of listeners for the specified event. This array can be manipulated, e.g. to 
-- remove listeners.
function _M:listeners(kind)
	self._events = self._events or {}
	self._events[kind] = self._events[kind] or {}
	
	if not isArray(self._events[kind]) then
		self._events[kind] = { self._events[kind] }
	end
	
	return self._events[kind]
end


function new()
	local o = setmetatable({}, _M)
	o._events = {}
	return o
end