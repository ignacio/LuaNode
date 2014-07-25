-------------------------------------------------------------------------------
-- This module implements a function that traverses all live objects.
-- You can implement your own function to pass as a parameter of traverse
-- and give you the information you want. As an example we have implemented
-- countreferences and findallpaths
--
-- Alexandra Barros - 2006.03.15
-------------------------------------------------------------------------------

-- Modifications by Ignacio Burgueño, mostly drop the use of 'module'
--

local _M = {
	_NAME = "luanode.__private_traverse",
	_PACKAGE = "luanode."
}
--module("traverse", package.seeall)

local List = {}

function List.new ()
	return {first = 0, last = -1}
end

function List.push (list, value)
	local last = list.last + 1
    list.last = last
    list[last] = value
end

function List.pop (list)
    local first = list.first
    if first > list.last then error("list is empty") end
    local value = list[first]
    list[first] = nil
    list.first = first + 1
    return value
end

function List.isempty (list)
	return list.first > list.last
end


local edge	-- forward declaration

local traverse = {}
function traverse.table(env, obj)
	
	local f = env.funcs.table
	if f then f(obj) end
	
	for key, value in pairs(obj) do
		edge(env, obj, key, "key", nil)
		edge(env, obj, value, "value", key)
	end
	
	local mtable = debug.getmetatable(obj)
	if mtable then edge(env, obj, mtable, "ismetatable", nil) end

end
			
function traverse.string(env, obj)
	local f = env.funcs.string
	if f then f(obj) end
	
end

function traverse.userdata(env, obj)
	local f = env.funcs.userdata
	if f then f(obj) end
	
	local mtable = debug.getmetatable(obj)
	if mtable then edge(env, obj, mtable, "ismetatable", nil) end
	
	local fenv = debug.getfenv(obj)
	if fenv then edge(env, obj, fenv, "environment", nil) end
	
end

traverse["function"] = function (env, obj)
	local f = env.funcs.func
	if f then f(obj) end
	
	-- gets the upvalues
	local i = 1
	while true do
		local n, v = debug.getupvalue(obj, i)
		if not n then break end -- when there is no upvalues
		edge(env, obj, n, "isname", nil)
		edge(env, obj, v, "upvalue", n)
		i = i + 1
	end
		
	local fenv = debug.getfenv(obj)
	edge(env, obj, fenv, "environment", nil)
	
end
			
function traverse.thread(env, t)
	local f = env.funcs.thread
	if f then f(t) end
	
	for i=1, math.huge do
		local info = debug.getinfo(t, i, "f")
		if not info then break end
		for j=1, math.huge do
			local n, v = debug.getlocal(t, i , j)
			if not n then break end
			print(n, v)
		
			edge(env, nil, n, "isname", nil)
			edge(env, nil, v, "local", n)
		end
	end
	
	local fenv = debug.getfenv(t)
	edge(env, t, fenv, "environment", nil)
	
end


-- 'how' is a string that identifies the content of 'to' and 'value':
-- 		if 'how' is "key", then 'to' is a key and 'name' is nil.
-- 		if 'how' is "value", then 'to' is an object and 'name' is the name of the
--		key.
edge = function (env, from, to, how, name)
	
	local t = type(to)
	
	if to and (t~="boolean") and (t~="number") and (t~="new") then
		-- If the destination object has not been found yet
		if not env.marked[to] then
			env.marked[to] = true
			List.push(env.list, to) -- puts on the list to be traversed
		end
		
		local f = env.funcs.edge
		if f then f(from, to, how, name) end
		
	end
end



-- Counts all references for a given object
function _M.countreferences(value)
	local count = -1
	local f = function(from, to, how, v)
		if to == value then
			count = count + 1
		end
	end
	_M.traverse({edge=f}, {count, f})
	return count
end

-- Main function
-- 'funcs' is a table that contains a funcation for every lua type and also the
-- function edge edge (traverseedge).
function _M.traverse(funcs, ignoreobjs)

	-- The keys of the marked table are the objetcts (for example, table: 00442330).
	-- The value of each key is true if the object has been found and false
	-- otherwise.
	local env = {marked = {}, list=List.new(), funcs=funcs}
	
	if ignoreobjs then
		for i=1, #ignoreobjs do
			env.marked[ignoreobjs[i]] = true
		end
	end
	
	env.marked["traverse"] = true
	env.marked[_M.traverse] = true
	env.marked[traverse] = true
	env.marked[edge] = true
	
	-- marks and inserts on the list
	edge(env, nil, "_G", "isname", nil)
	edge(env, nil, _G, "value", "_G")

	-- traverses the active thread
	-- inserts the local variables
	-- interates over the function on the stack, starting from the one that
	-- called traverse
	
	for i=2, math.huge do
		local info = debug.getinfo(i, "f")
		if not info then break end
		for j=1, math.huge do
			local n, v = debug.getlocal(i, j)
			if not n then break end
		
			edge(env, nil, n, "isname", nil)
			edge(env, nil, v, "local", n)
		end
	end
	
	while not List.isempty(env.list) do
	
		local obj = List.pop(env.list)
		local t = type(obj)
		--_M["traverse" .. t](env, obj)
		traverse[t](env, obj)
			
	end
	
end

return _M
