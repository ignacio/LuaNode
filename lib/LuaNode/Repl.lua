local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"
local utils = require "luanode.utils"
local rl = require "luanode.readline"
local console = console

-- TODO: sacar el seeall
module(..., package.seeall)

---
--
local function gatherResults (success, ...)
	local n = select("#", ...)
	return success, { n = n, ...}
end

---
--
local function printResults (results)
	for i = 1, results.n do
		results[i] = utils.inspect(results[i])
	end
	console.log("%s", table.concat(results, '\t'))
end

---
-- Repl Class
REPLServer = Class.InheritsFrom(EventEmitter)

---
--
function REPLServer:__init (prompt, stream, eval, useGlobal, ignoreUndefined)
	local repl = Class.construct(REPLServer)

	repl.bufferedCommand = ""

	repl.prompt = prompt or "> "

	if stream then
		-- We're given a duplex socket
		if stream.stdin or stream.stdout then
			repl.outputStream = stream.stdout
			repl.inputStream = stream.stdin
		else
			repl.outputStream = stream
			repl.inputStream = stream
		end
	else
		repl.outputStream = process.stdout
		repl.inputStream = process.stdin
		process.stdin:resume()
	end

	local function complete (text, callback)
		repl:complete(text, callback)
	end

	local rli = rl.createInterface(repl.inputStream, repl.outputStream, complete)
	repl.rli = rli

	self.commands = {}
	--defineDefaultCommands(repl)
	--[[
	if (rli.enabled && !exports.disableColors && exports.writer === util.inspect) {
		// Turn on ANSI coloring.
		exports.writer = function(obj, showHidden, depth) {
			return util.inspect(obj, showHidden, depth, true);
		};
	}
	]]
	rli:setPrompt(repl.prompt)

	rli:on("close", function ()
		repl.inputStream:destroy()
	end)

	rli:on("line", function (self, line)
		local chunk  = repl.bufferedCommand .. line
		--console.warn("ejecutando '%s' prev='%s'", chunk, repl.bufferedCommand)
		local f, err = loadstring("return " .. chunk, "REPL")
		if not f then
			if err:match("'<eof>'$") then
				repl.bufferedCommand = chunk .. "\n"
				repl.rli:setPrompt(">> ")
			else
				--console.warn("fallo ejecutando return", chunk, err)
				f, err = loadstring(chunk, "REPL")
			end
		end
		if f then
			local success, results = gatherResults(xpcall(f, debug.traceback))
			if success then
				--console.warn("success")
				if results.n > 0 then
					printResults(results)
				end
			else
				repl.outputStream:write( console.getColor("lightred") .. results[1] .. console.getResetColor() .. "\n" )
			end
			repl.bufferedCommand = ""
		else
			--console.warn("fallo ejecutando, ver si es eof '%s', err='%s'", chunk, err)
			if err:match("'<eof>'$") then
				-- expecting more input
				repl.bufferedCommand = chunk .. "\n"
				repl.rli:setPrompt(">> ")
			else
				--console.warn("fallo final err='%s'", err)
				--print(err)
				repl.outputStream:write( console.getColor("lightred") .. err .. console.getResetColor() .. "\n" )
				--repl.outputStream:write( "-" )
			end
		end
		repl:displayPrompt()
	end)

	repl:displayPrompt()

	return repl
end

---
--
function REPLServer:displayPrompt ()
	if #self.bufferedCommand > 0 then
		self.rli:setPrompt(">> ")
	else
		self.rli:setPrompt(self.prompt)
	end
	self.rli:prompt()
end

---
--
function start (prompt, source)
	local repl = REPLServer(prompt, source)
	return repl
end
