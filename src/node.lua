return function(process)

_G.process = process

if DEBUG then
	-- TODO: fix me, infer the path instead of hardcoding it
	if process.platform == "windows" then
		package.path = [[d:\trunk_git\sources\LuaNode\lib\?.lua;d:\trunk_git\sources\LuaNode\lib\?\init.lua;]] .. [[C:\LuaRocks\1.0\lua\?.lua;C:\LuaRocks\1.0\lua\?\init.lua;]] .. package.path
		package.cpath = [[.\?.dll;C:\LuaRocks\1.0\?.dll;C:\LuaRocks\1.0\loadall.dll;]] .. package.cpath
	else
		package.path = [[/home/ignacio/devel/sources/LuaNode/lib/?.lua;/home/ignacio/devel/sources/LuaNode/lib/?/init.lua;]] .. package.path
	end
end

local path = require "luanode.path"

-- put the current working directory in the modules path
package.path = path.normalize(([[%s\?\init.lua;%s\?.lua;]]):format( process.cwd(), process.cwd() )  .. package.path)

--[[
-- Insert a loader that allows me to require luanode.* as if they were on a (case insensitive) filesystem
table.insert(package.loaders, function(name)
	print(name, package.preload[name])
	name = name:lower()
	if name:match("^luanode%.") and package.preload[name] then
		print(name, "found")
		--return function()
			return package.preload[name]
		--end
	end
end)
]]

-- nextTick()

local nextTickQueue = {}

-- como lo de javascript
local function splice(array, from)
	local t = {} 
	for i = from, #array do
		t[#t + 1] = array[i]
	end 
	return t
end

process._tickcallback = function()
	local l = #nextTickQueue
	if l == 0 then
		return
	end
	
	-- can't use ipairs because if a callback calls nextTick it will be called immediately
	for i=1, l do
		nextTickQueue[i]()
		--local ok, err = pcall(nextTickQueue[i])
		--if not ok then
			--if i < l then
				--nextTickQueue = splice(nextTickQueue, i + 1)
			--end
			--error(tostring(err))
		--end
	end
	nextTickQueue = splice(nextTickQueue, l + 1)
end

process.nextTick = function(callback)
	nextTickQueue[#nextTickQueue + 1] = callback
	process._needTickCallback()
end

local Class = require "luanode.class"
local events = require "luanode.event_emitter"

-- Make 'process' become an event emitter
setmetatable(process, events.__index)


-- TODO: Meter la parte de Signal Handlers 

--
-- Console
--
-- TODO: Usar libBlogger2
local function LogArgumentsFormatter(...)
	local args = {...}
	for i=1, select("#", ...) do
		local arg = args[i]
		local arg_type = type(arg)
		if arg_type ~= "string" and arg_type ~= "number" then
			args[i] = tostring(arg)
		end
	end
	return unpack(args)
end

local function ArgumentsToStrings(t, ...)
	for i=1, select("#", ...)  do
		local arg = select(i, ...)
		local arg_type = type(arg)
		if arg_type ~= "string" and arg_type ~= "number" then
			t[#t + 1] = tostring(arg)
		else
			t[#t + 1] = arg
		end
	end
	return t
end

local function BuildMessage(fmt, ...)
	local msg
	if type(fmt) ~= "string" then
		msg = { tostring(fmt) }
		ArgumentsToStrings(msg, ...)
		msg = table.concat(msg, "\t")
	else
		if fmt:find("%%") then
			msg = string.format(fmt, LogArgumentsFormatter(...))
		else
			msg = { fmt }
			ArgumentsToStrings(msg, ...)
			msg = table.concat(msg, "\t")
		end
	end
	return msg
end

function LogDebug(fmt, ...)
	local msg = BuildMessage(fmt, ...)
	--print(msg) --scriptLogger.LogDebug(msg)
	if decoda_output then decoda_output("[DEBUG] " .. msg) end
	return msg
end

function LogInfo(fmt, ...)
	local msg = BuildMessage(fmt, ...)
	--print(msg) --scriptLogger.LogInfo(msg)
	if decoda_output then decoda_output("[INFO ] " .. msg) end
	return msg
end

function LogWarning(fmt, ...)
	local msg = BuildMessage(fmt, ...)
	--print(msg) --scriptLogger.LogWarning(msg)
	io.write(msg); io.write("\r\n")
	if decoda_output then decoda_output("[WARN ] " .. msg) end
	return msg
end

function LogError(fmt, ...)
	local msg = BuildMessage(fmt, ...)
	--print(msg) --scriptLogger.LogError(msg)
	io.write(msg); io.write("\r\n")
	if decoda_output then decoda_output("[ERROR] " .. msg) end
	return msg
end

function LogFatal(fmt, ...)
	local msg = BuildMessage(fmt, ...)
	--print(msg) --scriptLogger.LogFatal(msg)
	io.write(msg); io.write("\r\n")
	if decoda_output then decoda_output("[FATAL] " .. msg) end
	return msg
end

console = require "luanode.console"

function console.log (fmt, ...)
	local msg = BuildMessage(fmt, ...)
	--print(msg) --scriptLogger.LogDebug(msg)
	io.write(msg); io.write("\r\n")
	if decoda_output then decoda_output("[DEBUG] " .. msg) end
	return msg
end

console.debug = console.log

function console.info (fmt, ...)
	local msg = BuildMessage(fmt, ...)
	--print(msg) --scriptLogger.LogInfo(msg)
	io.write(msg); io.write("\r\n")
	if decoda_output then decoda_output("[INFO ] " .. msg) end
	return msg
end

function console.warn (fmt, ...)
	local msg = BuildMessage(fmt, ...)
	--print(msg) --scriptLogger.LogWarning(msg)
	console.color("yellow")
	io.write(msg)
	console.reset_color()
	io.write("\r\n")
	if decoda_output then decoda_output("[WARN ] " .. msg) end
	return msg
end

console["error"] = function (fmt, ...)
	local msg = BuildMessage(fmt, ...)
	--print(msg) --scriptLogger.LogError(msg)
	console.color("lightred")
	io.write(msg)
	console.reset_color()
	io.write("\r\n")
	if decoda_output then decoda_output("[ERROR] " .. msg) end
	return msg
end

function console.fatal (fmt, ...)
	local msg = BuildMessage(fmt, ...)
	--print(msg) --scriptLogger.LogFatal(msg)
	console.color("lightred")
	console.bgcolor("white")
	io.write(msg)
	console.reset_color()
	io.write("\r\n")
	if decoda_output then decoda_output("[FATAL] " .. msg) end
	return msg
end


local times = {}
-- TODO: Supply a high-perf timer if available. This sucks
console.time = function(label)
	times[label] = os.time()
end

console.timeEnd = function(label)
	local duration = os.time() - (times[label] or 0)
	console.log("%s: %dms", label, duration);
end

console.trace = function(label)
	console.error("%s - %s", label, debug.traceback())
end

-- TODO: Sería la misma??
console.assert = assert


-- 
-- Calls 
process._postBackToModule = function(moduleName, functionName, key, ...)
	LogDebug("_postBackToModule: %s:%s:%d", moduleName, functionName, key)
	
	local ok, m = pcall(require, moduleName)
	if not ok then
		console.error(m)
		return
	end
	local f = m[functionName]
	if type(f) == "function" then
		ok, m = pcall(f, key, ...)
		if not ok then
			console.error("Error while calling %s:%s - %s", moduleName, functionName, m)
		end
	end
end


local Timers = require "luanode.timers"


_G.setTimeout = Timers.setTimeout
_G.setInterval = Timers.setInterval
_G.clearTimeout = Timers.clearTimeout
_G.clearInterval = Timers.clearInterval


-- TODO: documentar
-- los modulos deben usar esta funcion como handler de sus lua_pcall
process.traceback = function()
	console.error(debug.traceback("traceback", 2))
end

--
--
function process:exit (code)
	process:emit("exit", code or 0)
	
	process.nextTick(function()
		process._exit(code or 0)
	end)
end

--
--
process.kill = function(pid, sig)
	-- TODO: implement
	error("not implemented")
	--if (!constants) constants = process.binding("constants");
	--sig = sig || 'SIGTERM';
	--if (!constants[sig]) throw new Error("Unknown signal: " + sig);
	--process._kill(pid, constants[sig]);
end

local cwd = process.cwd()

-- Make process.argv[1] and process.argv[2] into full paths.

-- if tengo arguments
--print(process.argv[1])
--for k,v in pairs(package) do print(k,v) end
--print(string.find(process.argv[1], path.dir_sep))
-- TODO: revisar todo este código, porque es muy unix dependiente (las charolas que los paths comienzan con /)
-- En el inConcertWebHandler tengo código para convertir filenames relativos a absolutos
--[=[
if not string.find(process.argv[1], path.dir_sep) then
	--process.argv[1] = path.join(current_dir, process.argv[1])
	process.argv[1] = path.join(process.argv[1])
	--print(process.argv[1])
end

if process.argv[2] then
	local first_arg = process.argv[2]
	if first_arg:sub(1,1) ~= path.dir_sep and not first_arg:match("^http://") then
		process.argv[2] = path.join(cwd, first_arg)
		print(process.argv[2])
	end
end
--]=]
local propagate_result = 0
if not process.argv[2] then
	io.write("LuaNode " .. process.version .. "\n")
	-- run repl
	process:loop()
else
	local file, err = io.open(process.argv[2])
	if not file then
		console.error(err)
		process:emit("exit")
		return err
	end
	--local code = file:read("*a")
	--file:close()
	
	--code = code .. "\r\nprocess:loop()"
	code, err = loadfile(process.argv[2])
	--code, err = loadstring(code, "@"..process.argv[2])
	--code, err = loadstring(code, process.argv[2])
	if not code then
		error(err)
	end
	local args = {}
	for i=3, #process.argv do args[#args + 1] = process.argv[i] end
	local result = code(unpack(args))
	if result ~= nil then
		propagate_result = tonumber(result)
	end
end

process:emit("exit")

return propagate_result

end
