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

local stp = require "stacktraceplus"

-- put the current working directory in the modules path
package.path = path.normalize(([[%s\?\init.lua;%s\?.lua;]]):format( process.cwd(), process.cwd() )  .. package.path)

do
	local inverse_index = {}
	local constants = process.constants
	for k,v in pairs(constants) do inverse_index[v] = k end
	for k,v in pairs(inverse_index) do constants[k] = v end
end

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
		local ok, err = xpcall(nextTickQueue[i], stp.stacktrace)
		if not ok then
			if i <= l then
				nextTickQueue = splice(nextTickQueue, i + 1)
			end
			return err
		end
	end
	nextTickQueue = splice(nextTickQueue, l + 1)
end

process.nextTick = function(callback)
	nextTickQueue[#nextTickQueue + 1] = callback
	process._needTickCallback()
end

local Class = require "luanode.class"
local events = require "luanode.event_emitter"

-- Make 'process' become an event emitter, but hook some 'properties'
setmetatable(process, {
	__index = function(t, key)
		if key == "stdin" then
			local tty = require "luanode.tty"
			local fd = Stdio.openStdin()
			local stdin

			if tty.isatty(fd) then
				stdin = tty.ReadStream(fd)

			elseif Stdio.isStdinBlocking() then
				console.error("processing input from a file is not supported yet")
				os.exit(-1)
				--local fs = require "luanode.fs"
				--stdin = fs.ReadStream(nil, {fd = fd})

			else
				local net = require "luanode.net"
				stdin = net.Stream(fd)
				stdin.readable = true
			end
			rawset(t, key, stdin)
			return stdin

		elseif key == "title" then
			return process.get_process_title()
		
		elseif key == "stdout" then
			local tty = require "luanode.tty"
			local stdout
			if tty.isatty(Stdio.stdoutFD) then
				local tty = require "luanode.tty"
				stdout = tty.WriteStream(Stdio.stdoutFD)

			elseif Stdio.isStdoutBlocking() then
				-- use io.stderr to bypass process.stdout
				io.stderr:write("sending output to a file is not supported yet\n")
				os.exit(-1)
				--local fs = require "luanode.fs"
				--stdout = fs.WriteStream(nil, {fd = Stdio.stdoutFD})
			else
				local net = require "luanode.net"
				stdout = net.Stream(fd)
				stdout.readable = false
			end
			rawset(t, key, stdout)
			return stdout
		end

		return events[key]
	end,
	
	__newindex = function(t, key, value)
		if key == "title" then
			process.set_process_title(value)
		else
			rawset(t, key, value)
		end
	end
})

process.openStdin = function()
	process.stdin:resume()
	return process.stdin
end


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
			-- escape unrecognized formatters
			fmt = fmt:gsub("%%([^cdiouxXeEfgGqs])", "%%%%%1")
			msg = string.format(fmt, LogArgumentsFormatter(...))
		else
			local t = { fmt }
			ArgumentsToStrings(t, ...)
			msg = table.concat(t, "\t")
		end
	end
	return msg
end

function LogDebug(fmt, ...)
	local msg = BuildMessage(fmt, ...)
	process.__internal.LogDebug(msg)
	if decoda_output then decoda_output("[DEBUG] " .. msg) end
	return msg
end

function LogInfo(fmt, ...)
	local msg = BuildMessage(fmt, ...)
	process.__internal.LogInfo(msg)
	if decoda_output then decoda_output("[INFO ] " .. msg) end
	return msg
end

function LogWarning(fmt, ...)
	local msg = BuildMessage(fmt, ...)
	process.__internal.LogWarning(msg)
	if decoda_output then decoda_output("[WARN ] " .. msg) end
	return msg
end

function LogError(fmt, ...)
	local msg = BuildMessage(fmt, ...)
	process.__internal.LogError(msg)
	io.stderr:write(msg); io.stderr:write("\r\n")
	if decoda_output then decoda_output("[ERROR] " .. msg) end
	return msg
end

function LogFatal(fmt, ...)
	local msg = BuildMessage(fmt, ...)
	process.__internal.LogFatal(msg)
	io.stderr:write(msg); io.stderr:write("\r\n")
	if decoda_output then decoda_output("[FATAL] " .. msg) end
	return msg
end

console = require "luanode.console"

function console.log (fmt, ...)
	local msg = BuildMessage(fmt, ...)
	process.stdout:write(msg .. "\r\n")
	if decoda_output then decoda_output("[DEBUG] " .. msg) end
	return msg
end

console.debug = console.log

function console.info (fmt, ...)
	local msg = BuildMessage(fmt, ...)
	process.stdout:write(msg .. "\r\n")
	if decoda_output then decoda_output("[INFO ] " .. msg) end
	return msg
end

function console.warn (fmt, ...)
	local msg = BuildMessage(fmt, ...)
	console.color("yellow")
	process.stdout:write(msg)
	console.reset_color()
	process.stdout:write("\r\n")
	if decoda_output then decoda_output("[WARN ] " .. msg) end
	return msg
end

console["error"] = function (fmt, ...)
	local msg = BuildMessage(fmt, ...)
	console.color("lightred", "stderr")
	io.stderr:write(msg)
	console.reset_color("stderr")
	io.stderr:write("\r\n")
	if decoda_output then decoda_output("[ERROR] " .. msg) end
	return msg
end

function console.fatal (fmt, ...)
	local msg = BuildMessage(fmt, ...)
	console.color("lightred", "stderr")
	console.bgcolor("white", "stderr")
	io.stderr:write(msg)
	console.reset_color("stderr")
	io.stderr:write("\r\n")
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
	console.error("%s", debug.traceback(label or "", 2))
end

-- TODO: Sería la misma??
console.assert = assert


-- 
-- Calls back into a module.
process._postBackToModule = function(moduleName, functionName, key, ...)
	LogDebug("_postBackToModule: %s:%s:%d", moduleName, functionName, key)
	
	local ok, m = pcall(require, moduleName)
	if not ok then
		console.error(m)
		return
	end
	local f = m[functionName]
	if type(f) == "function" then
		f(key, ...)
	else
		console.error("%q is not a function in module %q", functionName, moduleName)
	end
end


local Timers = require "luanode.timers"


_G.setTimeout = Timers.setTimeout
_G.setInterval = Timers.setInterval
_G.clearTimeout = Timers.clearTimeout
_G.clearInterval = Timers.clearInterval


-- TODO: documentar
-- los modulos deben usar esta funcion como handler de sus lua_pcall
--process.traceback = debug.traceback
process.traceback = stp.stacktrace

--
--
function process:exit (code)
	if process._exit_already_emitted then return end
	
	process._exit_already_emitted = true
	pcall(process.emit, process, "exit", code or 0)
	process:removeAllListeners("exit")
	
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

-- Make process.argv[-1] and process.argv[0] into full paths.

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

if process.argv[0] then
	local first_arg = process.argv[0]
	if first_arg:sub(1,1) ~= path.dir_sep and not first_arg:match("^http://") then
		process.argv[0] = path.join(cwd, first_arg)
		print(process.argv[0])
	end
end
--]=]

local propagate_result = 0
if not process.argv[0] then
	io.write("LuaNode " .. process.version .. "\n")
	-- run repl
	local Repl = require "luanode.repl"
	Repl.start(">")
	process:loop()
else
	local file, err = io.open(process.argv[0])
	if not file then
		console.error(err)
		process:emit("exit")
		return err
	end
	--local code = file:read("*a")
	file:close()
	
	--code = code .. "\r\nprocess:loop()"
	code, err = loadfile(process.argv[0])
	--code, err = loadstring(code, "@"..process.argv[0])
	--code, err = loadstring(code, process.argv[0])
	if not code then
		error(err, 2)	-- skip this level
	end
	
	-- put the directory name of the main script in the "require" path
	local script_path = path.normalize( process.cwd() .. "/" .. process.argv[0])
	script_path = path.dirname(script_path)
	package.path = path.normalize(([[%s\?\init.lua;%s\?.lua;]]):format( script_path, script_path ) ) .. package.path
	script_path = nil
	
	local arg = {}
	for k,v in pairs(process.argv) do arg[k] = v end
	_G.arg = arg
	local result = code(unpack(process.argv))
	if result ~= nil then
		propagate_result = tonumber(result)
	end
end

if not process._exit_already_emitted then
	process:emit("exit")
end

return propagate_result

end
