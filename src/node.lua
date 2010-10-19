return function(process)

_G.process = process

-- TODO: fix me
-- a prepo enchufo los paths de luarocks
package.path = [[d:\trunk_git\sources\LuaNode\lib\?.lua;d:\trunk_git\sources\LuaNode\lib\?\init.lua;]] .. [[C:\LuaRocks\1.0\lua\?.lua;C:\LuaRocks\1.0\lua\?\init.lua;]] .. package.path

--
--
--[=[
local function require_internal(...)
	local path, cpath = package.path, package.cpath
	
	-- TODO: fix these paths
	package.path = [[d:\trunk_git\sources\LuaNode\lib\?.lua;d:\trunk_git\sources\LuaNode\lib\?\init.lua;]] .. path
	package.cpath = [[d:\trunk_git\sources\LuaNode\lib\?.dll;]] .. cpath
	
	local ok, result = pcall(require, ...)
	
	package.path = path
	package.cpath = cpath
	
	if not ok then
		error(result)
	end
	
	return result
end
]=]

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
	print("_tickcallback - begin")
	local l = #nextTickQueue
	--print("_tickcallback - "..l.." callbacks in queue")
	if l == 0 then
		print("_tickcallback - end")
		return
	end
	
	-- can't use ipairs because if a callback calls nextTick it will be called immediately
	--for _, callback in ipairs(nextTickQueue) do
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
	--local t = {}
	--for i = l + 1, #nextTickQueue do
	--		t[#t + 1] = nextTickQueue[i]
	--	end
	--	nextTickQueue = t

	print("_tickcallback - end")
end

process.nextTick = function(callback)
	nextTickQueue[#nextTickQueue + 1] = callback
	process._needTickCallback()
end

--local events = require_internal "LuaNode.EventEmitter"
local events = require "LuaNode.EventEmitter"

-- hacemos que process se convierta en un EventEmitter
setmetatable(process, {__index = events:new() })
--setmetatable(process, events:new())

-- TODO: esto luego va a funcionar con require normal y no lo voy a hacer de acá a prepo
-- ojo con el clash de nombres, que tengo el modulo Net desde LuaNode
--local net = require_internal "net"
--local net = require "LuaNode.Net"
--local http = require_internal "http"
--local http = require "LuaNode.Http"
--local url = require_internal "url"
--local url = require "LuaNode.Url"

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
-- Timers
--
local function addTimerListener(timer, callback, ...)
	print("addTimerListener", type(callback))
	if select("#", ...) > 0 then
		local args = {...}
		timer.callback = function()
			callback(unpack(args))
		end
	else
		timer.callback = callback
	end
end

function _G.setTimeout(callback, after, ...)
	assert(callback, "A callback function must be supplied")
	local timer = process.Timer()
	addTimerListener(timer, callback, ...)
	timer:start(after, 0)
	return timer
end

function _G.setInterval(callback, repeat_, ...)
	local timer = process.Timer()
	addTimerListener(timer, callback, ...)
	timer:start(repeat_, repeat_ and repeat_ or 1)
	return timer
end

function _G.clearTimeout(timer)
	--TODO: assert(timer es un timer posta)
	timer.callback = nil
	timer:stop()
end

_G.clearInterval = clearTimeout

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

function LogDebug(fmt, ...)
	local msg = string.format(fmt, LogArgumentsFormatter(...))
	print(msg) --scriptLogger.LogDebug(msg)
	if decoda_output then decoda_output("[DEBUG] " .. msg) end
	return msg
end

function LogInfo(fmt, ...)
	local msg = string.format(fmt, LogArgumentsFormatter(...))
	print(msg) --scriptLogger.LogInfo(msg)
	if decoda_output then decoda_output("[INFO ] " .. msg) end
	return msg
end

function LogWarning(fmt, ...)
	local msg = string.format(fmt, LogArgumentsFormatter(...))
	print(msg) --scriptLogger.LogWarning(msg)
	if decoda_output then decoda_output("[WARN ] " .. msg) end
	return msg
end

function LogError(fmt, ...)
	local msg = string.format(fmt, LogArgumentsFormatter(...))
	print(msg) --scriptLogger.LogError(msg)
	if decoda_output then decoda_output("[ERROR] " .. msg) end
	return msg
end

function LogFatal(fmt, ...)
	local msg = string.format(fmt, LogArgumentsFormatter(...))
	print(msg) --scriptLogger.LogFatal(msg)
	if decoda_output then decoda_output("[FATAL] " .. msg) end
	return msg
end


console = {
	log   = LogDebug,
	info  = LogInfo,
	warn  = LogWarning,
	["error"] = LogError,
	fatal = LogFatal
}

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
	process:emit("exit")
	--process.reallyExit(code)
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
--local path = require_internal("path")
local path = require "LuaNode.path"

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
if not process.argv[2] then
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
	code(unpack(args))
end

process:emit("exit")

end
