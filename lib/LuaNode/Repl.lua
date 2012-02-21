local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"
local utils = require "luanode.utils"

-- TODO: sacar el seeall
module(..., package.seeall)

-- Repl Class
local REPLServer = Class.InheritsFrom(EventEmitter)

local kHistorySize = 30
local kBufSize = 10 * 1024

local function gatherResults (success, ...)
	local n = select("#", ...)
	return success, { n = n, ...}
end

local function printResults(results)
  	for i = 1, results.n do
	    results[i] = utils.inspect(results[i])
  	end
  	console.log(table.concat(results, '\t'))
end

function REPLServer:__init (prompt)
	local repl = Class.construct(REPLServer)

	repl.prompt = prompt

	-- esto se va a readline
	repl.cursor = 0
	repl.line = ""
	self.history = {}
    self.historyIndex = -1

	return repl
end

function REPLServer:displayPrompt (msg)
	--_oldprint("display_prompt " .. prompt)
	--process.stdout:write(prompt .. ' ', noop)
	console.log(self.prompt .. " " .. msg)
end

function REPLServer:evaluateLine (line)
end

---
-- TODO: mover a readline
function REPLServer:_insertString (c)
  	--BUG: Problem when adding tabs with following content.
  	--     Perhaps the bug is in _refreshLine(). Not sure.
  	--     A hack would be to insert spaces instead of literal '\t'.
  	if self.cursor < #self.line then
    	local beg_text = self.line:sub(1, self.cursor)
    	local end_text = self.line.sub(self.cursor)
    	self.line = beg_text .. c .. end_text
    	self.cursor = self.cursor + #c
    	self:_refreshLine()
  	else
    	self.line = self.line .. c
    	self.cursor = self.cursor + #c
    	io.stdout:write(c)--self.output:write(c)
  	end
end

-- TODO: mover a readline
function REPLServer:_refreshLine ()
	--[[
	if self._closed then return end

	-- Cursor to left edge.
	self.output:cursorTo(0)

	-- Write the prompt and the current buffer content.
	self.output:write(self._prompt)
	self.output:write(self.line)

	-- Erase to right.
	self.output:clearLine(1)

	-- Move cursor to original position.
	self.output:cursorTo(self._promptLength + self.cursor)
	--]]
end

function REPLServer:_deleteLeft ()
  	if self.cursor > 0 and #self.line > 0 then
    	self.line = self.line:sub(1, self.cursor - 1) .. self.line:sub(self.cursor)

    	self.cursor = self.cursor - 1
    	self:_refreshLine()
  	end
end

function REPLServer:_line ()
	local line = self:_addHistory()
  	io.stdout:write("\r\n")--self.output:write('\r\n')
  	self:_onLine(line)
end

function REPLServer:_onLine (line)
  	if self._questionCallback then
    	local cb = self._questionCallback
    	self._questionCallback = nil
    	self:setPrompt(self._oldPrompt)
    	cb(self, line)
  	else
	    self:emit("line", line)
  	end
end

function REPLServer:_addHistory ()
	if #self.line == 0 then return "" end

	table.insert(self.history, 1, self.line)
	self.line = ""
	self.historyIndex = -1

	self.cursor = 0

	-- Only store so many
	if #self.history > kHistorySize then
		table.remove(self.history, 1)
	end

	return self.history[1]
end

---
-- Handle a write from the tty
function REPLServer:_ttyWrite (s, key)
	local next_word, next_non_word, previous_word, previous_non_word
	key = key or {}

	if key.ctrl and key.shift then
		if key.name == "backspace" then
			console.log("delete line left")
		elseif key.name == "delete" then
			console.log("delete line right")
		end
	
	elseif key.ctrl then
		-- Control key pressed
	elseif key.meta then
		-- Meta key pressed
	else
		-- No modifier keys used
		if key.name == "enter" then
			self:_line()
		elseif key.name == "backspace" then
			self:_deleteLeft()
		elseif key.name == "delete" then
			self:_deleteRight()
		elseif key.name == "tab" then
			self:_tabComplete()
		elseif key.name == "left" then
			if self.cursor > 0 then
				self.cursor = self.cursor - 1
				self.output:moveCursor(-1, 0)
			end
		elseif key.name == "right" then
			if self.cursor ~= #self.line then
				self.cursor = self.cursor + 1
				self.output:moveCursor(1, 0)
			end
		elseif key.name == "home" then
			self.cursor = 0
			self:_refreshLine()
		elseif key.name == "end" then
			self.cursor = #self.line
			self:_refreshLine()
		elseif key.name == "up" then
			self:_historyPrev()
		elseif key.name == "down" then
			self:_historyNext()
		else
			--TODO: separar en lineas
			self:_insertString(s)
		end
	end
end

function start (prompt)
	local repl = REPLServer(prompt)

	--console.log("")
	console.log("Welcome to LuaNode")

	--process.stdin:on("data", function(self, data)
		--console.log("event data", data)
		--repl:evaluateLine(data)
	--end)

	process.stdin:on("keypress", function(self, char, key)
		--console.log("event keypress", char, key)
		repl:_ttyWrite(char, key)
	end)

	process.stdin:on("end", function()
		process:exit()
	end)

	process.stdin:resume()


	repl:on("line", function(self, line)
		--console.warn("ejecutando", line)
		local f, err = loadstring("return " .. line, "REPL")
		if not f then
			f, err = loadstring(line, "REPL")
		end
		if f then
			local success, results = gatherResults(xpcall(f, debug.traceback))
			if success then
				if results.n > 0 then
					printResults(results)
				end
			else
				print(results[1])
			end
		else
			if err:match("'<eof>'$") then
				-- expecting more input
				repl.buffer = line .. "\n"
				--return ">>"
				return
			else
				print(err)
			end
		end
	end)

	return repl
end
