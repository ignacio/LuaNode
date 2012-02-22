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
	repl.history = {}
    repl.historyIndex = -1

    repl.input = process.stdin
    repl.output = process.stdout

	return repl
end

function REPLServer:displayPrompt (msg)
	--_oldprint("display_prompt " .. prompt)
	process.stdout:write(prompt .. " " .. msg)
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
    	process.stdout:write(c)--self.output:write(c)
  	end
end

-- TODO: mover a readline
function REPLServer:_refreshLine ()
	---[[
	if self._closed then return end

	-- Cursor to left edge.
	self.output:cursorTo(0)

	-- Write the prompt and the current buffer content.
	self.output:write(self.prompt)
	self.output:write(self.line)

	-- Erase to right.
	self.output:clearLine(1)

	-- Move cursor to original position.
	self.output:cursorTo(#self.prompt + self.cursor)
	--]]
end

function REPLServer:_deleteLineLeft ()
  	self.line = self.line:sub(self.cursor)
  	self.cursor = 0
  	self:_refreshLine()
end


function REPLServer:_deleteLineRight ()
  	self.line = self.line:sub(1, self.cursor)
  	self:_refreshLine()
end

function REPLServer:_deleteLeft ()
  	if self.cursor > 0 and #self.line > 0 then
    	self.line = self.line:sub(1, self.cursor - 1) .. self.line:sub(self.cursor + 1)
    	--console.log( self.line )

    	self.cursor = self.cursor - 1
    	self:_refreshLine()
  	end
end

function REPLServer:_deleteRight ()
   	self.line = self.line:sub(1, self.cursor) .. self.line:sub(self.cursor + 2)
   	self:_refreshLine()
end

function REPLServer:_line ()
	local line = self:_addHistory()
  	process.stdout:write("\r\n")--self.output:write('\r\n')
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

function REPLServer:_historyPrev ()
	if self.historyIndex + 1 < #self.history then
    	self.historyIndex = self.historyIndex + 1
    	--console.log(self.historyIndex, luanode.utils.inspect(self.history))
    	self.line = self.history[self.historyIndex + 1]
    	self.cursor = #self.line -- set cursor to end of line.

    	self:_refreshLine()
  	end
end

function REPLServer:_historyNext ()
  	if self.historyIndex > 0 then
	    self.historyIndex = self.historyIndex - 1
	    self.line = self.history[self.historyIndex + 1]
	    self.cursor = #self.line -- set cursor to end of line.
	    self:_refreshLine()

  	elseif self.historyIndex == 0 then
    	self.historyIndex = -1
    	self.cursor = 0
    	self.line = ""
    	self:_refreshLine()
  	end
end

---
-- Handle a write from the tty
function REPLServer:_ttyWrite (s, key)
	local next_word, next_non_word, previous_word, previous_non_word
	key = key or {}

	if key.ctrl and key.shift then
		if key.name == "backspace" then
			console.log("delete line left")
			self:_deleteLineLeft()
		elseif key.name == "delete" then
			console.log("delete line right")
			self:_deleteLineRight()
		end
	
	elseif key.ctrl then
		-- Control key pressed
		--console.log("Control key pressed", key.name)
		if key.name == "h" then	-- delete left
			self:_deleteLeft()
		elseif key.name == "d" then -- delete right or EOF
			if self.cursor == 0 and #self.line == 0 then
          		self:_attemptClose()
        	elseif self.cursor < #self.line then
          		self:_deleteRight()
        	end

        elseif key.name == "u" then	-- delete the whole line
        	self.cursor = 0
        	self.line = ""
        	self:_refreshLine()
        elseif key.name == "k" then	-- delete from current to end of line
        	self:_deleteLineRight()
        elseif key.name == "a" then	-- go to the start of the line
        	self.cursor = 0
        	self:_refreshLine()
        elseif key.name == "e" then -- go to the end of the line
        	self.cursor = #self.line
        	self:_refreshLine()
        elseif key.name == "b" then -- back one character
        	if self.cursor > 0 then
        		self.cursor = self.cursor - 1
        		self:_refreshLine()
        	end
        elseif key.name == "f" then -- forward one character
        	if self.cursor ~= #self.line then
        		self.cursor = self.cursor + 1
        		self:_refreshLine()
        	end
        elseif key.name == "n" then -- next history item
        	self:_historyNext()
        elseif key.name == "p" then -- previous history item
        	self:_historyPrev()
        
        elseif key.name == "z" then
        	process.kill(process.pid, 'SIGTSTP')	-- not implemented yet

        elseif key.name == "w" or key.name == "backspace" then	-- delete backwards to a word boundary
        	self:_deleteWordLeft()

        elseif key.name == "delete" then -- delete forward to a word boundary
        	self:_deleteWordRight()

        elseif key.name == "left" then
        	self:_wordLeft()

        elseif key.name == "right" then
        	self:_wordRight()
		end

	elseif key.meta then
		-- Meta key pressed	(el viejo y querido alt)
		console.log("Meta key pressed", key.name)
		
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
			repl:_refreshLine()
		else
			if err:match("'<eof>'$") then
				-- expecting more input
				repl.buffer = line .. "\n"
				--return ">>"
				return
			else
				print(err)
			end
			repl:_refreshLine()
		end
	end)

	repl:_refreshLine()

	return repl
end
