local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"
local utils = require "luanode.utils"
local rl = require "luanode.readline"
local console = console
local _G = _G

-- TODO: sacar el seeall
module(..., package.seeall)

-- The list of Lua keywords
local keywords = {
	'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for',
	'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat',
	'return', 'then', 'true', 'until', 'while'
}

-- Can be overridden with custom print functions, such as `probe` or `eyes.js`
writer = utils.inspect

---
--
local function gatherResults (success, ...)
	local n = select("#", ...)
	return success, { n = n, ...}
end

---
--
local function printResults (repl, results)
	for i = 1, results.n do
		results[i] = repl.writer(results[i])
	end
	repl.outputStream:write(table.concat(results, "\t"))
	repl.outputStream:write("\n")
end


---
--
local function defineDefaultCommands(repl)
	repl:defineCommand("exit", {
		help = "Exit the repl",
		action = function()
			repl.rli:close()
		end
	})

	repl:defineCommand("help", {
		help = "Show repl options",
		action = function()
		for name, cmd in pairs(repl.commands) do
				repl.outputStream:write(name .. "\t" .. (cmd.help or "") .. "\n")
			end
			repl:displayPrompt()
		end
	})
end

---
-- Repl Class
REPLServer = Class.InheritsFrom(EventEmitter)

---
--
function REPLServer:__init (prompt, stream, eval, useGlobal, ignoreUndefined)
	local repl = Class.construct(REPLServer)

	repl.bufferedCommand = ""
	
	local options, input, output
	if type(prompt) == "table" and not stream and not eval and not useGlobal and not ignoreUndefined then
		-- an options table was given
		options = prompt
		stream = options.stream or options.socket
		input = options.input
		output = options.output
		eval = options.eval
		useGlobal = options.global
		ignoreUndefined = options.ignoreUndefined
		prompt = options.prompt
	
	elseif type(prompt) ~= "string" then
		error("An options table, or a prompt string are required")
	else
		options = {}
	end

	if not input and not output then
		if not stream then
			-- use stdin and stdout as the default streams if none were given
			stream = process
		end
		if stream.stdin and stream.stdout then
			-- We're given custom object with 2 streams, or the `process` object
			input = stream.stdin
			output = stream.stdout
		else
			-- We're given a duplex readable/writable Stream, like a `net.Socket`
			input = stream
			output = stream
		end
	end
	
	repl.outputStream = output
	repl.inputStream = input
	
	repl.prompt = prompt or "> "

	local function complete (text, callback)
		repl:complete(text, callback)
	end

	local rli = rl.createInterface({
		input = repl.inputStream,
		output = repl.outputStream,
		completer = complete,
		terminal = options.terminal
	})
	repl.rli = rli

	repl.commands = {}
	defineDefaultCommands(repl)
	
	-- figure out which "writer" function to use
	repl.writer = options.writer or _M.writer
	
	if type(options.useColors) == "nil" then
		options.useColors = rli.terminal
	end
	repl.useColors = not not options.useColors
	
	if repl.useColors and repl.writer == luanode.utils.inspect then
		-- Turn on ANSI coloring.
		repl.writer = function(obj, showHidden, depth)
			return utils.inspect(obj, true, depth, true)
		end
	end
	
	rli:setPrompt(repl.prompt)
	
	rli:on("close", function()
		repl:emit("exit")
	end)
	
	local sawSIGINT = false
	rli:on("SIGINT", function()
		local empty = (#rli.line == 0)
		rli:clearline()

		if not(repl.bufferedCommand and #repl.bufferedCommand > 0) and empty then
			if sawSIGINT then
				rli:close()
				sawSIGINT = false
				return
			end
			rli.output:write("(Ctrl-C again to quit)\n")
			sawSIGINT = true
		else
			sawSIGINT = false
		end

		repl.bufferedCommand = ""
		repl:displayPrompt()
	end)

	rli:on("line", function (self, line)
		sawSIGINT = false
		line = line:match("^%s*(.-)[%s]*$")	-- trim whitespace
		-- Check to see if a REPL keyword was used. If it returns true, display next prompt and return.
		if line and line:match("^%.") then
			local keyword, rest = line:match("^([^%s]+)%s*(.*)$")
			if repl:parseReplKeyword(keyword, rest) then
				return
			else
				repl.outputStream:write("Invalid REPL keyword\n")
				repl.bufferedCommand = ""
				repl:displayPrompt()
			end
			return
		end

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
					printResults(repl, results)
				end
			else
				if repl.useColors then
					repl.outputStream:write( console.getColor("lightred") .. utils.inspect(results[1]) .. console.getResetColor() .. "\n" )
				else
					repl.outputStream:write( utils.inspect(results[1]) .. "\n" )
				end
				repl.rli:setPrompt(repl.prompt)
			end
			repl.bufferedCommand = ""
		else
			--console.warn("fallo ejecutando, ver si es eof '%s', err='%s'", chunk, err)
			if err:match("'<eof>'$") then
				-- expecting more input
				repl.bufferedCommand = chunk .. "\n"
				repl.rli:setPrompt(">> ")
			else
				--console.warn("fallo final err='%s', prompt=%s", err, repl.prompt)
				if repl.useColors then
					repl.outputStream:write( console.getColor("lightred") .. err .. console.getResetColor() .. "\n" )
				else
					repl.outputStream:write( err .. "\n" )
				end
				repl.bufferedCommand = ""
				repl.rli:setPrompt(repl.prompt)
			end
		end
		repl:displayPrompt()
	end)
	
	rli:on("SIGCONT", function()
		repl:displayPrompt(true)
	end)

	repl:displayPrompt()

	return repl
end

---
--
function REPLServer:displayPrompt (preserveCursor)
	if #self.bufferedCommand > 0 then
		self.rli:setPrompt(">> ")
	else
		self.rli:setPrompt(self.prompt)
	end
	self.rli:prompt(preserveCursor)
end

---
-- Helper function
local function completionGroupsLoaded (self, err, callback, completionGroups, completeOn, filter)
	if err then error(err) end

	local completions = {}

	if #completionGroups > 0 and filter then
		local newCompletionGroups = {}
		for _, group in ipairs(completionGroups) do
			local newGroup = {}
			for k,v in pairs(group) do
				if v:find(filter, 1, true) then
					table.insert(newGroup, v)
				end
			end
			if #newGroup > 0 then
				table.insert(newCompletionGroups, newGroup)
			end
		end
		completionGroups = newCompletionGroups
	end

	if #completionGroups > 0 then
		--local uniq = {}	-- unique completions across all groups
		-- Completion group 0 is the "closest"
		-- (least far up the inheritance chain)
		-- so we put its completions last: to be closest in the REPL.
		completions = {}
		for i = #completionGroups, 1, -1 do
			local group = completionGroups[i]
			table.sort(group)
			for j = 1, #group do
				local c = group[j]
				table.insert(completions, c)
				--uniq[c] = true
			end
			table.insert(completions, "") -- separator between groups
		end

		while #completions > 0 and completions[#completions] == "" do
			completions[#completions] = nil
		end
	
	else
		completions = completionGroups
	end

	callback(nil, completions or {}, completeOn)
end

---
-- Provide a list of completions for the given leading text. This is
-- given to the readline interface for handling tab completion.
--
-- Example:
--  complete('local foo = console.')
--    -> [['console.log', 'console.debug', 'console.info', 'console.warn', 'console.error'],
--        'console.' ]
--
-- Warning: This eval's code like "foo.bar.baz", so it will run property
-- getter code.
function REPLServer:complete (line, callback)

	local completions

	-- list of completion lists, one for each inheritance "level"
	local completionGroups = {}
	local completeOn, filter, i, j, group, c

	-- REPL commands (e.g. ".break")
	local match = line:match("^%s*(%.%w*)$")
	if match then
		local keys = {}
		for k in pairs(self.commands) do keys[#keys + 1] = k end
		table.insert(completionGroups, keys)
		completeOn = match
		if #match > 0 then
			filter = match
		end

	else
    	---[[
		-- TODO: don't try to autocomplete stuff like ). }., etc
		local i1,i2 = line:find("[.:%a_]+$")
  		if not i1 then
  			callback(nil, {})	-- report no completions
  			return
  		end

  		local group = {}
  		local front, partial = line:sub(1, i1 - 1), line:sub(i1)
  		-- if it ends on a non letter, and partial is not . or :, go away
  		if front:match("[^%w_]$") and partial == "." or partial == ":" then
  			callback(nil, {})	-- report no completions
  			return
  		end
  		--print(front, partial)
  		for _,w in ipairs(keywords) do
  			if w:match("^"..partial) then
  				table.insert(group, front .. w)
  			end
  		end
  		if #group > 0 then
			table.insert(completionGroups, group)
		end

  		local prefix, last = partial:match("(.-)([^.:]*)$")
  		--print(prefix, last)
  		local t, all = _G
  		if #prefix > 0 then
  			--print(prefix)
    		local P = prefix:sub(1, -2)
    		all = (last == "")
    		for w in P:gmatch("[^.:]+") do
      			t = t[w]
      			if not t then
      				callback(nil, {})	-- report no completions
      				return
      			end
    		end
  		end
  		prefix = front .. prefix
  		group = {}
  		local function append_candidates(t)  
    		for k, v in pairs(t) do
				if type(k) == "string" or type(k) == "number" then
					if all or k:sub(1, #last) == last then
						table.insert(group, prefix .. k)
					end
      			end
    		end
  		end
  		local mt = getmetatable(t)
  		if type(t) == "table" then
    		append_candidates(t)
  		end
  		if mt and type(mt.__index) == "table" then
    		append_candidates(mt.__index)
  		end
  		if #group > 0 then
			table.insert(completionGroups, group)
		end
		filter = line
		completeOn = line
		--]]
	end

	--for k,v in ipairs(completionGroups) do
	--	print(utils.inspect(v))
	--end

	completionGroupsLoaded(self, nil, callback, completionGroups, completeOn, filter)
end

---
--
function REPLServer:parseReplKeyword (keyword, rest)
	local cmd = self.commands[keyword]
	if cmd then
		cmd.action(self, rest)
		return true
	end
	return false
end

---
--
function REPLServer:defineCommand (keyword, cmd)
	if type(cmd) == "function" then
		cmd = { action = cmd }
	elseif type(cmd.action) ~= "function" then
		error("bad argument, action must be a function")
	end
	self.commands["." .. keyword] = cmd
end

---
--
function start (prompt, source)
	local repl = REPLServer(prompt, source)
	return repl
end
