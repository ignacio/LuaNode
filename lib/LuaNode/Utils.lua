local string, table, math = string, table, math
local console = require "luanode.console"
local tostring, type, process = tostring, type, process
local rawget, ipairs, pairs = rawget, ipairs, pairs

local print = print

module((...))

---
-- Dumps binary data in a "memory viewer" fashion. Ie:
-- Dumping 12 bytes
-- 00000000  68 65 6C 6C 6F 2C 20 77  6F 72 6C 64 .. .. .. ..  hello, world
-- [first] begin dump at 16 byte-aligned offset containing 'first' byte
-- [last] end dump at 16 byte-aligned offset containing 'last' byte
-- Adapted from a snippet by Steve Donovan (http://snippets.luacode.org/?p=snippets/Hex_Dump_of_a_String_22)
function DumpDataInHex(buf, first, last)
	local res = {}
	if not first and not last then
		res[#res + 1] = ("Dumping %d bytes\n"):format((last or #buf) - (first or 1) + 1)
	else
		res[#res + 1] = ("Dumping from offset %d to %d\n\n"):format(first or 1, last or #buf)
		res[#res + 1] = "          00 01 02 03 04 05 06 07  08 09 10 0b 0c 0d 0e 0f\n"
		res[#res + 1] = "          ================================================\n"
	end
	local function align(n) return math.ceil(n/16) * 16 end
	for i = (align((first or 1) - 16) + 1), align(math.min(last or #buf, #buf)) do
		if (i - 1) % 16 == 0 then
			res[#res + 1] = string.format('%08X  ', i - 1)
		end
		res[#res + 1] =  i > #buf and '.. ' or string.format('%02X ', buf:byte(i))
		if i %  8 == 0 then
			res[#res + 1] = " "
		end
		if i % 16 == 0 then
			res[#res + 1] = buf:sub(i - 16 + 1, i):gsub('%c', '.')
			res[#res + 1] = '\n' 
		end
	end
	return table.concat(res)
end

---
-- Checks that a given table is array-like
-- TODO: Avoid false positives??
function isArray(t)
	if type(t) == "table" and rawget(t, 1) ~= nil then
		return true
	end
	return false
end

--
-- A table with color info on how we style the values
local styleTable = {
	special = console.getColor('magenta'),
	number = console.getColor('cyan'),
	boolean = console.getColor('yellow'),
	["nil"] = console.getColor('bold'),
	["string"] = console.getColor('green'),
	["function"] = console.getColor('blue'),
	thread = console.getColor('blue'),
	userdata = console.getColor('red'),
}

--- Pretty prints a given value.
-- value is the value to print out
-- showHidden shows hidden members (those that start with an underscore, by convention)
-- depth in which to descend. 2 by default.
-- Adapted from Penlight.pretty, by Steve Donovan
-- https://github.com/stevedonovan/Penlight
function inspect(value, showHidden, depth, colors)
	depth = depth or 2
	if type(depth) == "string" then depth = 1000 end	-- hack
	
	if not colors then
		colors = (process.platform ~= "windows")
	end
	
	local stylize = function(str, styleType)
		local style = styleTable[styleType]
		if style then
			return style .. str .. string.char(27)..'[0m'
		else
			return str
		end
	end
	
	if not colors then
		stylize = function(str, styleType) return str end
	end
	
	local not_clever = false--true

	local space = space or '  '
	local lines = {}
	local line = ''
	local tables = {}

	local function put(s)
		if #s > 0 then
			line = line..s
		end
	end

	local function putln (s)
		if #line > 0 then
			line = line..s..","
			table.insert(lines, line)
			line = ''
		else
			table.insert(lines, s)
		end
    end

	local function eat_last_comma ()
		local n, lastch = #lines
		local lastch = lines[n]:sub(-1, -1)
		if lastch == ',' then
			lines[n] = lines[n]:sub(1, -2)
		end
	end

	local function quote (s)
		return ('%q'):format(tostring(s))
	end

	local function index (numkey,key)
		if not numkey then key = quote(key) end
		return '['..key..']'
	end
	
	local function can_show_key(key)
		if showHidden then return true end
		if type(key) ~= "string" then return true end
		local m = key:match("^[_]+(.*)")
		if m == "NAME" or m == "PACKAGE" or m == "type" then
			return true
		end
		return not m
	end

	local writeit
	writeit = function (t, oldindent, indent, recurseTimes)
		local tp = type(t)
		if tp == 'string' then
			if t:find('\n') then
				putln(stylize('[[\n'..t..']]', "string"))
			else
				putln(stylize(quote(t), "string"))
			end
		elseif tp == "number" then
			putln( stylize(tostring(t), "number") )
		elseif tp == "boolean" then
			putln( stylize(tostring(t), "boolean") )
		elseif tp == "function" then
			putln( stylize(tostring(t), "function") )
		elseif tp == "thread" then
			putln( stylize(tostring(t), "thread") )
		elseif tp == "nil" then
			putln( stylize(tostring(t), "nil") )
		elseif tp == "userdata" then
			putln( stylize(tostring(t), "userdata") )
		elseif tp == 'table' then
			if type(t.inspect) == "function" and t.inspect ~= _M.inspect then
				putln(t.inspect(recurseTimes))
				return
			end
			
			if recurseTimes == 0 then
				putln( "<<...>>" )
				return
			end
			if tables[t] then
				putln( stylize('<cycle>', "special") )
				return
			end
			tables[t] = true
			local newindent = indent .. space
			local t_is_array_like = isArray(t)
			
			putln(t_is_array_like and '[' or '{')
			eat_last_comma()
			
			local max = 0
			if not not_clever then
				for i, val in ipairs(t) do
					put(indent)
					writeit(val, indent, newindent, recurseTimes - 1)
					max = i
				end
			end
			for key, val in pairs(t) do
				if can_show_key(key) then
					local numkey = type(key) == 'number'
					if not_clever then
						key = tostring(key)
						put(indent .. index(numkey, key) .. ' => ')
						writeit(val, indent, newindent, recurseTimes - 1)
					else
						if not numkey or key < 1 or key > max then -- non-array indices
							if numkey then
								key = index(numkey, key)
							end
							put(indent .. key .. ' => ')
							writeit(val, indent, newindent, recurseTimes - 1)
						end
					end
				end
			end
			eat_last_comma()
			putln(oldindent .. (t_is_array_like and ']' or '}') ..",")
		else
			putln(tostring(t))
		end
	end
	writeit(value, '', space, depth)
	eat_last_comma()
	return table.concat(lines, #space > 0 and '\n' or '')
end
