-- Copyright (c) 2011-2012 by Robert G. Jakabosky <bobby@neoawareness.com>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local ltraverse = require("luanode.__private_traverse")
local have_getsize = false
local getsize = function()
	return 0
end
if not jit then
	--getsize = require"getsize"
	--have_getsize = true
end

--[[
local inspect = require("luanode.utils").inspect
local pp = function(v)
	return inspect(v, true)
end
--]]

-- helpers for collecting strings to be used when assembling the final output
--[[
local Dumper = {}
local Dumper_mt = { __index = Dumper }

Dumper.new = function()
	local t = setmetatable({ lines = {} }, Dumper_mt)
	return t
end

function Dumper:add (text)
	self.lines[#self.lines + 1] = text
end
function Dumper:add_f (fmt, ...)
	self:add(fmt:format(...))
end
function Dumper:concat_lines ()
	return table.concat(self.lines)
end
--]]

local _M = {
	_NAME = "luanode.__private_luastate",
	_PACKAGE = "luanode."
}

function _M.dump_stats (options)
	options = options or {}
	local type_cnts = {}
	local function type_inc(t)
		type_cnts[t] = (type_cnts[t] or 0) + 1
	end
	local type_mem = {}
	local function type_mem_inc(v)
		if not have_getsize then return end
		local t = type(v)
		local s = getsize(v)
		type_mem[t] = (type_mem[t] or 0) + s
	end
	-- build metatable->type map for userdata type detection.
	local ud_types = {}
	local reg = debug.getregistry()
	for k,v in pairs(reg) do
		--print(type(k))
		if type(k) == 'string' and type(v) == 'table' then
			ud_types[v] = k
		elseif type(k) == "userdata" then
			local __name, __type = rawget(v.__name), rawget(v.__type)
			if __name then
				ud_types[v] = __name
			elseif __type then
				ud_types[v] = __type
			end
			--print(tostring(k), tostring(v), pp(v))
			--ud_types[v] = "coso"
		--else
			--print("what??", k, pp(v), pp(getmetatable(v)))
		end
	end
	local function ud_type(ud)
		--print("ud_type", ud, debug.getmetatable(ud))
		return ud_types[debug.getmetatable(ud)] or "<unknown>"
	end
	local str_data = 0
	local funcs = {
	["edge"] = function(from, to, how, name)
		--[[
		if type(from) == "userdata" then
			if how == "environment" then
				if to == package then
					print("From (".. pp(from) .. ") -> _G.package <" .. how .. ">", name or "")
				elseif to == _G then
					print("From ("..pp(from) .. ") -> _G <" .. how .. ">", name or "")
				else
					print("From ("..pp(from) .. ") -> ".. pp(to) .. " <" .. how .. ">", name or "")
					--print("++", from, pp(to), how, name or "")
				end
			else
				--print("edge", how)
			end
			--print("From", inspect(from), pp(to))
		end
		--]]
		type_inc"edges"
	end,
	["table"] = function(v)
		local t = debug.getmetatable(v)
		if t then
			local __name, __type = rawget(t.__name), rawget(t.__type)
			if type(__name) == "string" then
				type_inc(__name)
			elseif type(__type) == "string" then
				type_inc(__type)
			else
				type_inc("table")
			end
		else
			type_inc("table")
		end
		type_mem_inc(v)
	end,
	["string"] = function(v)
		type_inc"string"
		str_data = str_data + #v
		type_mem_inc(v)
	end,
	["userdata"] = function(v)
		--print(pp(v), pp(debug.getmetatable(v)) )
		type_inc"userdata"
		type_inc(ud_type(v))
		type_mem_inc(v)
	end,
	["cdata"] = function(v)
		type_inc"cdata"
	end,
	["func"] = function(v)
		--print(inspect(v), inspect(debug.getinfo(v)) )
		type_inc"function"
		type_mem_inc(v)
	end,
	["thread"] = function(v)
		type_inc"thread"
		type_mem_inc(v)
	end,
	}
	local ignores = {}
	for k,v in pairs(funcs) do
		ignores[#ignores + 1] = k
		ignores[#ignores + 1] = v
	end
	ignores[#ignores + 1] = type_cnts
	ignores[#ignores + 1] = funcs
	ignores[#ignores + 1] = ignores
	--ignores[#ignores + 1] = Dumper

	-- process additional elements to ignore
	if type(options.ignore) == "table" then
		for _,v in ipairs(options.ignore) do
			ignores[#ignores + 1] = v
		end
	end

	ltraverse.traverse(funcs, ignores)

	local results = {}
	results.memory = collectgarbage("count") * 1024
	results.str_data = str_data
	results.object_counts = {}
	for t,cnt in pairs(type_cnts) do
		results.object_counts[t] = cnt
	end
	if have_getsize then
		results.per_type_memory_usage = {}
		local total = 0
		for t,mem in pairs(type_mem) do
			total = total + mem
			results.per_type_memory_usage[t] = mem
		end
		results.per_type_memory_usage.total = total
	end
	return results

	--[=[
	local dumper = Dumper:new()
	dumper:add_f("memory = %i bytes\n", results.memory)
	dumper:add_f("str_data = %i\n", results.str_data)
	dumper:add("object type counts:\n")
	for t,cnt in pairs(type_cnts) do
		dumper:add_f("  %9s = %9i\n", t, cnt)
	end
	
	if have_getsize then
		dumper:add("per type memory usage:\n")
		local total = 0
		for t,mem in pairs(type_mem) do
			total = total + mem
			dumper:add_f("  %9s = %9i bytes\n", t, mem)
		end
		dumper:add_f("total: %9i bytes\n", total)
	end
	--[[
	fd:write("LUA_REGISTRY dump:\n")
	for k,v in pairs(reg) do
		fd:write(tostring(k),'=', tostring(v),'\n')
	end
	--]]
	return dumper:concat_lines()
	--]=]
end

return _M
