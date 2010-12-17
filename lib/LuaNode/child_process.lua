local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"
local Stream = require("luanode.stream").Stream

-- TODO: sacar el seeall
module(..., package.seeall)

local InternalChildProcess = process.ChildProcess
local constants


ChildProcess = Class.InheritsFrom(EventEmitter)

function ChildProcess:__init()
	local newProcess = Class.construct(ChildProcess)
	
	local gotCHLD = false
	local exitCode
	local termSignal
	local internal = InternalChildProcess()
	newProcess._internal = internal

	local stdin = Stream()
	newProcess.stdin = stdin
	
	local stdout = Stream()
	newProcess.stdout = stdout
	
	local stderr = Stream()
	newProcess.stderr = stderr
	
	local stderrClosed = false
	local stdoutClosed = false

	stderr:addListener("close", function ()
		stderrClosed = true
		if gotCHLD and (not newProcess.stdout or stdoutClosed) then
			newProcess:emit("exit", exitCode, termSignal)
		end
	end)

	stdout:addListener("close", function ()
		stdoutClosed = true
		if gotCHLD and (not newProcess.stderr or stderrClosed) then
			newProcess:emit("exit", exitCode, termSignal)
		end
	end)

	internal.onexit = function (self, code, signal)
		gotCHLD = true
		exitCode = code
		termSignal = signal
		if newProcess.stdin then
			newProcess.stdin:finish()
		end
		if (not newProcess.stdout or not newProcess.stdout.readable) and 
			(not newProcess.stderr or not newProcess.stderr.readable) 
		then
			newProcess:emit("exit", exitCode, termSignal)
		end
	end

	return newProcess
	--this.__defineGetter__('pid', function () { return internal.pid; });
end

--
--
function ChildProcess:kill(sig)
	if not constants then
		--constants = process.binding("constants");
	end
	sig = sig or "SIGTERM"
	if not constants[sig] then
		error("Unknown signal: " .. tostring(sig))
	end
	return self._internal:kill(constants[sig])
end

--
--
function ChildProcess:spawn(path, args, options, customFds)
	args = args or {}

	local cwd, env
	if (not options or not options.cwd and not options.env and not options.customFds) then
		-- Deprecated API: (path, args, options, env, customFds)
		cwd = ""
		env = options or process.env
		customFds = customFds or {-1, -1, -1}
	else
		-- Recommended API: (path, args, options)
		cwd = options.cwd or ""
		env = options.env or process.env
		customFds = options.customFds or {-1, -1, -1}
	end

	local envPairs = {}
	for key, value in pairs(env) do
		table.insert(envPairs, key .. "=" .. value)
	end
	
	local fds = self._internal:spawn(path, args, cwd, envPairs, customFds)
	self.fds = fds

	if customFds[1] == -1 or not customFds[1] then
		self.stdin:open(fds[1])
		self.stdin.writable = true
		self.stdin.readable = false
	else
		self.stdin = nil
	end

	if customFds[2] == -1 or not customFds[2] then
		self.stdout:open(fds[2])
		self.stdout.writable = false
		self.stdout.readable = true
		self.stdout:resume()
	else
		self.stdout = nil
	end

	if customFds[3] == -1 or not customFds[3] then
		self.stderr:open(fds[3])
		self.stderr.writable = false
		self.stderr.readable = true
		self.stderr:resume()
	else
		self.stderr = nil
	end
end

--
--
function spawn(...)--/*, options OR env, customFds */)
	local child = ChildProcess()
	child:spawn(path, args)
	return child
end


--[[
function exec(command, options, callback)-- /*, options, callback */) {
	if (arguments.length < 3) {
		return exports.execFile("/bin/sh", ["-c", command], arguments[1]);
	} else if (arguments.length < 4) {
		return exports.execFile("/bin/sh", ["-c", command], arguments[1], arguments[2]);
	} else {
		return exports.execFile("/bin/sh", ["-c", command], arguments[1], arguments[2], arguments[3]);
	}
end
]]

--[[
--// execFile("something.sh", { env: ENV }, funciton() { })

exports.execFile = function (file /* args, options, callback */) {
  var options = { encoding: 'utf8'
                , timeout: 0
                , maxBuffer: 200*1024
                , killSignal: 'SIGKILL'
                , cwd: null
                , env: null
                };
  var args, optionArg, callback;

  // Parse the parameters.

  if (typeof arguments[arguments.length-1] === "function") {
    callback = arguments[arguments.length-1];
  }

  if (Array.isArray(arguments[1])) {
    args = arguments[1];
    if (typeof arguments[2] === 'object') optionArg = arguments[2];
  } else {
    args = [];
    if (typeof arguments[1] === 'object') optionArg = arguments[1];
  }

  // Merge optionArg into options
  if (optionArg) {
    var keys = Object.keys(options);
    for (var i = 0, len = keys.length; i < len; i++) {
      var k = keys[i];
      if (optionArg[k] !== undefined) options[k] = optionArg[k];
    }
  }

  var child = spawn(file, args, {cwd: options.cwd, env: options.env});
  var stdout = "";
  var stderr = "";
  var killed = false;

  var timeoutId;
  if (options.timeout > 0) {
    timeoutId = setTimeout(function () {
      if (!killed) {
        child.kill(options.killSignal);
        killed = true;
        timeoutId = null;
      }
    }, options.timeout);
  }

  child.stdout.setEncoding(options.encoding);
  child.stderr.setEncoding(options.encoding);

  child.stdout.addListener("data", function (chunk) {
    stdout += chunk;
    if (!killed && stdout.length > options.maxBuffer) {
      child.kill(options.killSignal);
      killed = true;
    }
  });

  child.stderr.addListener("data", function (chunk) {
    stderr += chunk;
    if (!killed && stderr.length > options.maxBuffer) {
      child.kill(options.killSignal);
      killed = true;
    }
  });

  child.addListener("exit", function (code, signal) {
    if (timeoutId) clearTimeout(timeoutId);
    if (code === 0 && signal === null) {
      if (callback) callback(null, stdout, stderr);
    } else {
      var e = new Error("Command failed: " + stderr);
      e.killed = killed;
      e.code = code;
      e.signal = signal;
      if (callback) callback(e, stdout, stderr);
    }
  });

  return child;
};
]]
