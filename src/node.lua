return function(process)

_G.process = process

if DEBUG then
	-- TODO: fix me, infer the path instead of hardcoding it
	package.path = [[d:\trunk_git\sources\LuaNode\lib\?.lua;d:\trunk_git\sources\LuaNode\lib\?\init.lua;]] .. 
		[[C:\LuaRocks\1.0\lua\?.lua;C:\LuaRocks\1.0\lua\?\init.lua;]] .. package.path
	package.cpath = [[.\?.dll;C:\LuaRocks\1.0\?.dll;C:\LuaRocks\1.0\loadall.dll;]] .. package.cpath
end

package.path = ([[%s\?\init.lua;%s\?.lua;]]):format( process.cwd(), process.cwd() )  .. package.path

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

local events = require "luanode.event_emitter"
-- hacemos que process se convierta en un EventEmitter
setmetatable(process, {__index = events:new() })


-- TODO: Meter la parte de Signal Handlers de node.js
--[=[
// Signal Handlers
(function() {
  var signalWatchers = {};
  var addListener = process.addListener;
  var removeListener = process.removeListener;

  function isSignal (event) {
    if (!constants) constants = process.binding("constants");
    return event.slice(0, 3) === 'SIG' && constants[event];
  }

  // Wrap addListener for the special signal types
  process.on = process.addListener = function (type, listener) {
    var ret = addListener.apply(this, arguments);
    if (isSignal(type)) {
      if (!signalWatchers.hasOwnProperty(type)) {
        if (!constants) constants = process.binding("constants");
        var b = process.binding('signal_watcher');
        var w = new b.SignalWatcher(constants[type]);
        w.callback = function () { process.emit(type); };
        signalWatchers[type] = w;
        w.start();

      } else if (this.listeners(type).length === 1) {
        signalWatchers[event].start();
      }
    }

    return ret;
  };

  process.removeListener = function (type, listener) {
    var ret = removeListener.apply(this, arguments);
    if (isSignal(type)) {
      process.assert(signalWatchers.hasOwnProperty(type));

      if (this.listeners(type).length === 0) {
        signalWatchers[type].stop();
      }
    }

    return ret;
  };
})();
--]=]

-- 
-- Calls 
process._postBackToModule = function(moduleName, functionName, key, ...)
	LogDebug("%s:%s:%d", moduleName, functionName, key)
	
	local ok, m = pcall(require, moduleName)
	if not ok then
		console.error(m)
		return
	end
	local f = m[functionName]
	if type(f) == "function" then
		pcall(f, key, ...)
	end
end


local Timers = require "luanode.timers"


_G.setTimeout = Timers.setTimeout
_G.setInterval = Timers.setInterval
_G.clearTimeout = Timers.clearTimeout
_G.clearInterval = Timers.clearInterval

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
		msg = {}
		msg[#msg + 1] = tostring(fmt)
		ArgumentsToStrings(msg, ...)
		msg = table.concat(msg, "\t")
	else
		if fmt:find("%%") then
			msg = string.format(fmt, LogArgumentsFormatter(...))
		else
			msg = {}
			msg[#msg + 1] = fmt
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
	console.color("gray")
	io.write("\r\n")
	if decoda_output then decoda_output("[WARN ] " .. msg) end
	return msg
end

console["error"] = function (fmt, ...)
	local msg = BuildMessage(fmt, ...)
	--print(msg) --scriptLogger.LogError(msg)
	console.color("lightred")
	io.write(msg)
	console.color("gray")
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
--
process.exit = function(code)
	process:emit("exit", code or 0)
	--process.reallyExit(code, code or 0)
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
local path = require "luanode.path"

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
	io.write("LuaNode " .. process.version)
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
	
	-- All our arguments are loaded. We've evaluated all of the scripts. We
	-- might even have created TCP servers. Now we enter the main eventloop. If
	-- there are no watchers on the loop (except for the ones that were
	-- ev_unref'd) then this function exits. As long as there are active
	-- watchers, it blocks.
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
