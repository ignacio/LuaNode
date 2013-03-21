local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"
local utils = require "luanode.utils"
local tty = require "luanode.tty"

module(..., package.seeall)

-- Reference:
-- * http://invisible-island.net/xterm/ctlseqs/ctlseqs.html
-- * http://www.3waylabs.com/nw/WWW/products/wizcon/vt220.html

local kHistorySize = 30
local kBufSize = 10 * 1024

local emitKey

---
-- Mappings from ansi codes to key names (and modifiers)
local keymap = {
	-- xterm/gnome ESC O letter
	["OP"] = {"f1"},
	["OQ"] = {"f2"},
	["OR"] = {"f3"},
	["OS"] = {"f4"},

	-- xterm/rxvt ESC [ number ~ 
	["[11~"] = {"f1"},
	["[12~"] = {"f2"},
	["[13~"] = {"f3"},
	["[14~"] = {"f4"},

	-- from Cygwin and used in libuv
	["[[A"] = {"f1"},
	["[[B"] = {"f2"},
	["[[C"] = {"f3"},
	["[[D"] = {"f4"},
	["[[E"] = {"f5"},

	-- common 
	["[15~"] = {"f5"},
	["[17~"] = {"f6"},
	["[18~"] = {"f7"},
	["[19~"] = {"f8"},
	["[20~"] = {"f9"},
	["[21~"] = {"f10"},
	["[23~"] = {"f11"},
	["[24~"] = {"f12"},

	-- xterm ESC [ letter
	["[A"] = {"up"},
	["[B"] = {"down"},
	["[C"] = {"right"},
	["[D"] = {"left"},
	["[E"] = {"clear"},
	["[F"] = {"end"},
	["[H"] = {"home"},

	-- xterm/gnome ESC O letter
	["OA"] = {"up"},
	["OB"] = {"down"},
	["OC"] = {"right"},
	["OD"] = {"left"},
	["OE"] = {"clear"},
	["OF"] = {"end"},
	["OH"] = {"home"},

	-- xterm/rxvt ESC [ number ~
	["[1~"] = {"home"},
	["[2~"] = {"insert"},
	["[3~"] = {"delete"},
	["[4~"] = {"end"},
	["[5~"] = {"pageup"},
	["[6~"] = {"pagedown"},

	-- putty 
	["[[5~"] = {"pageup"},
	["[[6~"] = {"pagedown"},

	-- rxvt 
	["[7~"] = {"home"},
	["[8~"] = {"end"},

	-- rxvt keys with modifiers 
	-- shift, ctrl
	["[a"] = {"up", true},
	["[b"] = {"down", true},
	["[c"] = {"right", true},
	["[d"] = {"left", true},
	["[e"] = {"clear", true},

	["[2$"] = {"insert", true},
	["[3$"] = {"delete", true},
	["[5$"] = {"pageup", true},
	["[6$"] = {"pagedown", true},
	["[7$"] = {"home", true},
	["[8$"] = {"end", true},

	["Oa"] = {"up", nil, true},
	["Ob"] = {"down", nil, true},
	["Oc"] = {"right", nil, true},
	["Od"] = {"left", nil, true},
	["Oe"] = {"clear", nil, true},

	["[2^"] = {"insert", nil, true},
	["[3^"] = {"delete", nil, true},
	["[5^"] = {"pageup", nil, true},
	["[6^"] = {"pagedown", nil, true},
	["[7^"] = {"home", nil, true},
	["[8^"] = {"end", nil, true},

	-- misc. 
	["[Z"] = {"tab", true},
}

---
-- Simple and pure Lua bit operations by R. Ierusalimschy.
-- http://lua-users.org/lists/lua-l/2002-09/msg00134.html
local bit = {}
do
	local tab = {  -- tab[i][j] = xor(i-1, j-1)
		{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, },
		{1, 0, 3, 2, 5, 4, 7, 6, 9, 8, 11, 10, 13, 12, 15, 14, },
		{2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13, },
		{3, 2, 1, 0, 7, 6, 5, 4, 11, 10, 9, 8, 15, 14, 13, 12, },
		{4, 5, 6, 7, 0, 1, 2, 3, 12, 13, 14, 15, 8, 9, 10, 11, },
		{5, 4, 7, 6, 1, 0, 3, 2, 13, 12, 15, 14, 9, 8, 11, 10, },
		{6, 7, 4, 5, 2, 3, 0, 1, 14, 15, 12, 13, 10, 11, 8, 9, },
		{7, 6, 5, 4, 3, 2, 1, 0, 15, 14, 13, 12, 11, 10, 9, 8, },
		{8, 9, 10, 11, 12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, },
		{9, 8, 11, 10, 13, 12, 15, 14, 1, 0, 3, 2, 5, 4, 7, 6, },
		{10, 11, 8, 9, 14, 15, 12, 13, 2, 3, 0, 1, 6, 7, 4, 5, },
		{11, 10, 9, 8, 15, 14, 13, 12, 3, 2, 1, 0, 7, 6, 5, 4, },
		{12, 13, 14, 15, 8, 9, 10, 11, 4, 5, 6, 7, 0, 1, 2, 3, },
		{13, 12, 15, 14, 9, 8, 11, 10, 5, 4, 7, 6, 1, 0, 3, 2, },
		{14, 15, 12, 13, 10, 11, 8, 9, 6, 7, 4, 5, 2, 3, 0, 1, },
		{15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, },
	}

	function bit.bxor (a,b)
		local res, c = 0, 1
		while a > 0 and b > 0 do
			local a2, b2 = math.fmod(a, 16), math.fmod(b, 16)
			res = res + tab[a2+1][b2+1]*c
			a = (a-a2)/16
			b = (b-b2)/16
			c = c*16
		end
		res = res + a*c + b*c
		return res
	end

	local ff = 2^32 - 1
	function bit.bnot (a) return ff - a end
	function bit.band (a,b) return ((a+b) - bit.bxor(a,b))/2 end
	function bit.bor (a,b) return ff - bit.band(ff - a, ff - b) end
end


---
--
Interface = Class.InheritsFrom(EventEmitter)

---
--
function createInterface (input, output, completer, terminal)
	return Interface(input, output, completer, terminal)
end

---
--
function Interface:__init (input, output, completer, terminal)
	local interface = Class.construct(Interface)

	if input and not output and not completer and not terminal then
		-- an options object was given
		output = input.output
		completer = input.completer
		terminal = input.terminal
		input = input.input
	end
	
	completer = completer or function() return {} end
	assert(type(completer) == "function", "Argument 'completer' must be a function")
	
	-- backwards compat; check the isTTY prop of the output stream
	--  when `terminal` was not specified
	if not terminal then
		terminal = not not output.isTTY
	end
	
	interface.input = input
	interface.output = output
	input:resume()

	-- TODO
	--// Check arity, 2 - for async, 1 for sync
	--interface.completer = completer.length === 2 ? completer : function(v, callback) {
	interface.completer = completer

	interface:setPrompt("> ")
	
	interface.terminal = not not terminal
	
	if not interface.terminal then
		input:on("data", function(self, data)
			interface:_normalWrite(data)
		end)
		input:on("end", function()
			interface:close()
		end)
		
	else
		emitKeypressEvents(input)
		
		-- input usually refers to stdin
		input:on("keypress", function(self, s, key)
			interface:_ttyWrite(s, key)
		end)

		-- Current line
		interface.line = ""

		interface:_setRawMode(true)
		interface.terminal = true

		-- Cursor position on the line
		interface.cursor = 0

		interface.history = {}
		interface.historyIndex = -1
		
		output:on("resize", function()
			interface:_refreshLine()
		end)
	end
	
	return interface
end

---
--
function Interface:columns ()
	return self.output.columns or math.huge
end

---
--
function Interface:setPrompt (prompt, length)
	self._prompt = prompt
	if length then
		self._promptLength = length
	else
		local last_line = prompt:match("[\r\n].+$")
		self._promptLength = last_line and #last_line or #prompt
	end
end

---
--
function Interface:_setRawMode (mode)
	if type(self.input.setRawMode) == "function" then
		return self.input:setRawMode(mode)
	end
end

---
--
function Interface:prompt (preserveCursor)
	if self.paused then self:resume() end
	if self.terminal then
		if not preserveCursor then self.cursor = 0 end
		self:_refreshLine()
	else
		self.output:write(self._prompt)
	end
end

---
--
function Interface:question (query, callback)
	if type(callback) == "function" then
		if self._questionCallback then
			self:prompt()
		else
			self._oldPrompt = self._prompt
			self:setPrompt(query)
			self._questionCallback = callback
			self:prompt()
		end
	end
end

---
--
function Interface:_onLine (line)
	if self._questionCallback then
		local cb = self._questionCallback
		self._questionCallback = nil
		self:setPrompt(self._oldPrompt)
		cb(self, line)
	else
		self:emit("line", line)
	end
end

---
--
function Interface:_addHistory ()
	if #self.line == 0 then return "" end

	table.insert(self.history, 1, self.line)
	self.line = ""
	self.historyIndex = -1

	-- Only store so many
	if #self.history > kHistorySize then
		table.remove(self.history, 1)
	end

	return self.history[1]
end

---
--
function Interface:_refreshLine ()
	local columns = self:columns()
	
	-- line length
	local line = self._prompt .. self.line
	local lineLength = #line
	local lineCols = lineLength % columns
	local lineRows = (lineLength - lineCols) / columns
	
	-- cursor position
	local cursorPosCols, cursorPosRows = self:_getCursorPos()
	
	-- first move to the bottom of the current line, based on cursor pos
	local prevRows = self.prevRows or 0
	if prevRows > 0 then
		moveCursor(self.output, 0, -prevRows)
	end
	
	-- Cursor to left edge.
	cursorTo(self.output, 0)
	-- erase data
	clearScreenDown(self.output)
	
	-- Write the prompt and the current buffer content.
	self.output:write(line)
	
	-- Force terminal to allocate a new line
	if lineCols == 0 then
		self.output:write(" ")
	end
	
	-- Move cursor to original position
	cursorTo(self.output, cursorPosCols)

	local diff = lineRows - cursorPosRows
	if diff > 0 then
		moveCursor(self.output, 0, -diff)
	end
	
	self.prevRows = cursorPosRows
end

---
--
function Interface:close ()
	if self.closed then return end
	if self.terminal then
		self:_setRawMode(false)
	end
	self:pause()
	self.closed = true
	self:emit("close")
end

---
--
function Interface:pause ()
	if self.paused then return end
	self.input:pause()
	self.paused = true
	self:emit("pause")
end

---
--
function Interface:resume ()
	if not self.paused then return end
	self.input:resume()
	self.paused = false
	self:emit("resume")
end

---
--
function Interface:write (d, key)
	if self.paused then self:resume() end
	if self.terminal then
		self:_ttyWrite(d, key)
	else
		self:_normalWrite(d, key)
	end
end

---
--
function Interface:_normalWrite (b)
	-- Very simple implementation right now. Should try to break on new lines.
	if not b then
		return
	end
	
	local str = b
	if self._line_buffer then
		str = self._line_buffer .. str
		self._line_buffer = nil
	end
	
	if string.find(str, "\n") then
		-- got one or more newlines; process into "line" events
		-- TODO: fix, if last line does not end with CR/LF, buffer it
		for line in str:gmatch("[^\r\n]+") do
			-- either '' or (concievably) the unfinished portion of the next line
			self:_onLine(line .. "\n")
		end
	elseif str then
		-- no newlines this time, save what we have for next time
		self._line_buffer = str
	end
end

---
--
function Interface:_insertString (c)
	--BUG: Problem when adding tabs with following content.
	--     Perhaps the bug is in _refreshLine(). Not sure.
	--     A hack would be to insert spaces instead of literal '\t'.
	if self.cursor < #self.line then
		local beg_text = self.line:sub(1, self.cursor)
		local end_text = self.line:sub(self.cursor + 1)
		self.line = beg_text .. c .. end_text
		self.cursor = self.cursor + #c
		self:_refreshLine()
	else
		self.line = self.line .. c
		self.cursor = self.cursor + #c
		
		if self:_getCursorPos() == 0 then
			self:_refreshLine()
		else
			self.output:write(c)
		end
		
		-- a hack to get the line refreshed if it's needed
		self:_moveCursor(0)
	end
end

---
--
function Interface:_tabComplete ()
	self:pause()

	self.completer(self.line:sub(1, self.cursor), function(err, completions, completeOn)
		self:resume()
		if err then
			-- XXX Log it somewhere?
			return
		end

		-- the text that was completed
		if completions and #completions > 0 then
			-- Apply/show completions.
			if #completions == 1 then
				self:_insertString(completions[1]:sub(#completeOn + 1))
			else
				self.output:write("\r\n")
				local width = 0
				for _, v in ipairs(completions) do
					if #v > width then
						width = #v
					end
				end
				width = width + 2 -- 2 space padding
				local maxColumns = math.floor(self:columns() / width) or 1

				-- this shows each group, grouped by columns
				local function handleGroup(group)
					if #group == 0 then
						return
					end
					local minRows = math.ceil(#group / maxColumns)
					for row = 0, minRows - 1 do
						for col = 0, maxColumns - 1 do
							local idx = row * maxColumns + col
							if idx >= #group then
								break
							end
							local item = group[idx + 1]
							self.output:write(item)
							if col < maxColumns - 1 then
								for s = 1, width - #item do
									self.output:write(" ")
								end
							end
						end
						self.output:write("\r\n")
					end
					self.output:write("\r\n")
				end

				-- an empty string separates groups
				local group = {}
				for i = 1, #completions do
					local c = completions[i]
					if c == "" then
						handleGroup(group)
						group = {}
					else
						table.insert(group, c)
					end
				end
				handleGroup(group)

				-- If there is a common prefix to all matches, then apply that portion.
				local f = completions
				local prefix = commonPrefix(f)
				--print(prefix, completeOn)
				if #prefix > #completeOn then
					self:_insertString(prefix:sub(#completeOn + 1))
				end

			end
			self:_refreshLine()
		end
	end)
end

function commonPrefix (strings)
	if not strings or #strings == 0 then
		return ""
	end
	local sorted = {}
	for k,v in pairs(strings) do sorted[k] = v end
	table.sort(sorted)
	--local sorted = strings.slice().sort()
	local min, max = sorted[1], sorted[#sorted]
	--print(min, max)
	for i = 1, #min do
		if min:byte(i) ~= max:byte(i) then
			return min:sub(1, i-1)
		end
	end
	return min
end

---
--
function Interface:_wordLeft ()
	if self.cursor > 0 then
		local leading = self.line:sub(1, self.cursor)
		local match = leading:match("([^%w%s]+)%s*$")
		if not match then
			match = leading:match("(%w+)%s*$")
		end
		self:_moveCursor(-#match)
	end
end

---
-- 
function Interface:_wordRight ()
	if self.cursor < #self.line then
		local trailing = self.line:sub(self.cursor + 1)
		local match = trailing:match("^(%s+%s*)")
		if not match then
			match = trailing:match("^(%W+%s*)")
		end
		if not match then
			match = trailing:match("^(%w+%s*)")
		end
		self:_moveCursor(#match)
	end
end

---
--
function Interface:_deleteLeft ()
	if self.cursor > 0 and #self.line > 0 then
		self.line = self.line:sub(1, self.cursor - 1) .. self.line:sub(self.cursor + 1)
		self.cursor = self.cursor - 1
		self:_refreshLine()
	end
end

---
--
function Interface:_deleteRight ()
	self.line = self.line:sub(1, self.cursor) .. self.line:sub(self.cursor + 2)
	self:_refreshLine()
end

---
--
function Interface:_deleteWordLeft ()
	if self.cursor > 0 then
		local leading = self.line:sub(1, self.cursor)
		local match = leading:match("([^%w%s]+)%s*$")
		if not match then
			match = leading:match("(%w+)%s*$")
		end
		if not match then
			self.line = ""
			self.cursor = 0
		else
			leading = leading:sub(1, #leading - #match)
			self.line = leading .. self.line:sub(self.cursor + 1)
			self.cursor = #leading
		end
		self:_refreshLine()
	end
end

---
--
function Interface:_deleteWordRight ()
	if self.cursor < #self.line then
		local trailing = self.line:sub(self.cursor + 1)
		local match = trailing:match("^(%s+%s*)")
		if not match then
			match = trailing:match("^(%W+%s*)")
		end
		if not match then
			match = trailing:match("^(%w+%s*)")
		end
		self.line = self.line:sub(1, self.cursor) .. trailing:sub(#match + 1)
		self:_refreshLine()
	end
end

---
--
function Interface:_deleteLineLeft ()
	self.line = self.line:sub(self.cursor)
	self.cursor = 0
	self:_refreshLine()
end

---
--
function Interface:_deleteLineRight ()
	self.line = self.line:sub(1, self.cursor)
	self:_refreshLine()
end

---
--
function Interface:clearline ()
	self:_moveCursor(math.huge)
	self.output:write("\r\n")
	self.line = ""
	self.cursor = 0
	self.prevRows = 0
end

---
--
function Interface:_line ()
	local line = self:_addHistory()
	self:clearline()
	self:_onLine(line)
end

---
--
function Interface:_historyNext ()
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
--
function Interface:_historyPrev ()
	if self.historyIndex + 1 < #self.history then
		self.historyIndex = self.historyIndex + 1
		self.line = self.history[self.historyIndex + 1]
		self.cursor = #self.line -- set cursor to end of line.

		self:_refreshLine()
	end
end

---
-- Returns current cursor's position and line (x, y)
--
function Interface:_getCursorPos ()
	local columns = self:columns()
	local cursorPos = self.cursor + self._promptLength
	local cols = cursorPos % columns
	local rows = (cursorPos - cols) / columns
	return cols, rows
end

---
-- This function moves cursor dx places to the right
-- (-dx for left) and refreshes the line if it is needed
--
function Interface:_moveCursor (dx)
	local oldCursor = self.cursor
	local oldPosCols, oldPosRows = self:_getCursorPos()
	self.cursor = self.cursor + dx
	-- bounds check
	if self.cursor < 0 then self.cursor = 0 end
	if self.cursor > #self.line then self.cursor = #self.line end
	
	local newPosCols, newPosRows = self:_getCursorPos()
	
	-- check if cursors are in the same line
	if oldPosRows == newPosRows then
		moveCursor(self.output, self.cursor - oldCursor, 0)
		self.prevRows = newPosRows
	else
		self:_refreshLine()
	end
end

---
-- Handle a write from the tty
function Interface:_ttyWrite (s, key)
	key = key or {}
	
	-- Ignore escape key
	if key.name == "escape" then return end

	if key.ctrl and key.shift then
		if key.name == "backspace" then
			self:_deleteLineLeft()
		elseif key.name == "delete" then
			self:_deleteLineRight()
		end
	
	elseif key.ctrl then
		-- Control key pressed
		if key.name == "c" then
			if #self:listeners("SIGINT") > 0 then
				self:emit("SIGINT")
			else
				-- This readline instance is finished
				self:close()
			end
			
		elseif key.name == "h" then -- delete left
			self:_deleteLeft()
			
		elseif key.name == "d" then -- delete right or EOF
			if self.cursor == 0 and #self.line == 0 then
				-- This readline instance is finished
				self:close()
			elseif self.cursor < #self.line then
				self:_deleteRight()
			end

		elseif key.name == "u" then -- delete the whole line
			self.cursor = 0
			self.line = ""
			self:_refreshLine()
			
		elseif key.name == "k" then -- delete from current to end of line
			self:_deleteLineRight()
			
		elseif key.name == "a" then -- go to the start of the line
			self:_moveCursor(-math.huge)
			
		elseif key.name == "e" then -- go to the end of the line
			self:_moveCursor(math.huge)
			
		elseif key.name == "b" then -- back one character
			self:_moveCursor(-1)
			
		elseif key.name == "f" then -- forward one character
			self:_moveCursor(1)
			
		elseif key.name == "n" then -- next history item
			self:_historyNext()
			
		elseif key.name == "p" then -- previous history item
			self:_historyPrev()
		
		elseif key.name == "z" then
			if process.platform == "windows" then
				--return
			end
			if #self:listeners("SIGSTP") > 0 then
				self:emit("SIGSTP")
			else
				process:once("SIGCONT", function()
					-- Don't raise events if stream has already been abandoned
					if not self.paused then
						-- Stream must be paused and resumed after SIGCONT to catch
						-- SIGINT, SIGSTP and EOF.
						self:pause()
						self:emit("SIGCONT")
					end
					-- explictly re-enable "raw mode" and move the cursor to the correct
					 -- position. See https://github.com/joyent/node/issues/3295.
					self:_setRawMode(true)
					self:_refreshLine()
				end)
			end
			self:_setRawMode(false)
			process.kill(process.pid, "SIGTSTP")    -- not implemented yet

		elseif key.name == "w" or key.name == "backspace" then  -- delete backwards to a word boundary
			self:_deleteWordLeft()

		elseif key.name == "delete" then -- delete forward to a word boundary
			self:_deleteWordRight()

		elseif key.name == "left" then
			self:_wordLeft()

		elseif key.name == "right" then
			self:_wordRight()
		end

	elseif key.meta then
		-- Meta key pressed (el viejo y querido alt)

		if key.name == "b" then
			-- backward word
			self:_wordLeft()
			
		elseif key.name == "f" then
			-- forward word
			self:_wordRight()
			
		elseif key.name == "d" or key.name == "delete" then
			-- delete forward word
			self:_deleteWordRight()
			
		elseif key.name == "backspace" then
			-- delete backwards to a word boundary
			self:_deleteWordLeft()
		end
		
	else
		-- No modifier keys used
		if key.name == "enter" then
			self:_line()
			
		elseif key.name == "backspace" then
			self:_deleteLeft()
			
		elseif key.name == "delete" then
			self:_deleteRight()
			
		elseif key.name == "tab" then	-- tab completion
			self:_tabComplete()
			
		elseif key.name == "left" then
			self:_moveCursor(-1)
			
		elseif key.name == "right" then
			self:_moveCursor(1)
			
		elseif key.name == "home" then
			self:_moveCursor(-math.huge)
			
		elseif key.name == "end" then
			self:_moveCursor(math.huge)
			
		elseif key.name == "up" then
			self:_historyPrev()
			
		elseif key.name == "down" then
			self:_historyNext()
			
		else
			
			if s then
				-- split in lines
				local i = 0
				for line in s:gmatch("[^\r\n]+") do
					if i > 0 then
						self:_line()
					end
					i = i + 1
					self:_insertString(line)
				end
			end
		end
	end
end

---
-- accepts a readable Stream instance and makes it emit "keypress" events
--
function emitKeypressEvents (stream)
	if stream._emitKeypress then return end
	stream._emitKeypress = true

	local keypressListeners = stream:listeners("keypress")

	local onData
	local onNewListener
	
	onData = function(self, b)
		if #keypressListeners then
			emitKey(stream, b)
		else
			-- Nobody's watching anyway
			stream:removeListener("data", onData)
			stream:on("newListener", onNewListener)
		end
	end

	onNewListener = function(self, event)
		if event == "keypress" then
			stream:on('data', onData)
			stream:removeListener("newListener", onNewListener)
		end
	end

	if #keypressListeners then
		stream:on("data", onData)
	else
		stream:on("newListener", onNewListener)
	end
end


--[[
  Some patterns seen in terminal key escape codes, derived from combos seen
  at http://www.midnight-commander.org/browser/lib/tty/key.c

  ESC letter
  ESC [ letter
  ESC [ modifier letter
  ESC [ 1 ; modifier letter
  ESC [ num char
  ESC [ num ; modifier char
  ESC O letter
  ESC O modifier letter
  ESC O 1 ; modifier letter
  ESC N letter
  ESC [ [ num ; modifier char
  ESC [ [ 1 ; modifier letter
  ESC ESC [ num char
  ESC ESC O letter

  - char is usually ~ but $ and ^ also happen with rxvt
  - modifier is 1 +
				(shift     * 1) +
				(left_alt  * 2) +
				(ctrl      * 4) +
				(right_alt * 8)
  - two leading ESCs apparently mean the same as one leading ESC
--]]

---
-- Disgusting piece of code... Of the million ways of solving this, I chose the worst...
--
local function parseFunctionKeyCode (s)
	local escapes, rest = s:match("^([\027]+)(.+)")
	if not escapes then
		return "", 0
	end

	local letter, num, char, modifier
	
	local prefix = rest:sub(1,1)

	-- ESC N letter
	if prefix == "N" then
		letter = rest:match("^N(%a)")
		--if letter then print("ESC N letter", letter) end

	elseif prefix == "O" then
		-- ESC O letter
		letter = rest:match("^O(%a)")
		if letter then
			--print("ESC O letter", letter)
		else
			-- ESC O modifier letter
			modifier, letter = rest:match("^O(%d+)(%a)")
			if modifier then
				--print("ESC O modifier letter", modifier, letter)
			else
				-- ESC O 1 ; modifier letter
				modifier, letter = rest:match("^O1;(%d+)(%a)")
				if modifier then
					--print("ESC O 1 ; modifier letter", modifier, letter)
				end
			end
		end

	elseif prefix == "[" then
		if rest:match("^%[%[") then
			prefix = "[["
			-- ESC [ [ num ; modifier char
			num, modifier, char = rest:match("^%[%[(%d+);(%d+)([~$^])")
			if not num then
				--ESC [ [ 1 ; modifier letter
				modifier, letter = rest:match("^%[%[1;(%d+)(%a)")
				if not modifier then
					-- ESC [ letter
					letter = rest:match("^%[%[(%a)")
				end
			end
		else
			--prefix = "["
			-- ESC [ letter
			letter = rest:match("^%[(%a)")
			if letter then
				--print("letter", letter)
			else
				-- ESC [ num char
				num, char = rest:match("^%[(%d+)([~$^])")
				if num then
					--print("prefix, num, char", prefix, num, char)
				else
					-- ESC [ 1 ; modifier letter
					modifier, letter = rest:match("^%[1;(%d+)(%a)")
					if modifier then
						--print("ESC [ 1 ; modifier letter", modifier, letter)
					else
						-- ESC [ modifier letter
						modifier, letter = rest:match("^%[(%d+)(%a)")
						if modifier then
							--print("ESC [ modifier letter", modifier, letter)
						else
							-- ESC [ num ; modifier char
							num, modifier, char = rest:match("^%[(%d+);(%d+)([~$^])")
							if num then
								--print("ESC [ num ; modifier char", num, modifier, char)
							end
						end
					end
				end
			end
		end
	else
		-- ESC letter
		letter = rest
	end

	local code = prefix .. (letter or "") .. (num or "") .. (char or "")
	local modifier = (tonumber(modifier) or 1) - 1
	--print("code is", code, "modifier", modifier)
	return code, modifier
end

---
--
function emitKey (stream, s)
	--console.log("key", s)

	local key = {
		name = nil,
		ctrl = false,
		meta = false,
		shift = false,
		sequence = s
	}
	--console.log("EmitKey", luanode.utils.DumpDataInHex(s))

	if s == "\r" or s == "\n" then
		-- enter
		key.name = "enter"
	
	elseif s == "\t" then
		-- tab
		key.name = "tab"
	
	elseif s == "\b" or s == "\127" or s == "\027\127" or s == "\027\b" then
		-- backspace or ctrl+h
		--console.log("backspace or ctrl+h", s, luanode.utils.DumpDataInHex(s))
		-- en mi debian me viene 0x7f cuando apreto backspace entonces me salta que tengo CTRL apretado
		key.name = "backspace"
		key.meta = s:sub(1,1) == "\027"
		if process.platform == "windows" then
			key.ctrl = s:sub(1,1) == "\127"
		end
	
	elseif s == "\027" or s == "\027\027" then
		-- escape key
		key.name = "escape"
		key.meta = #s == 2
	
	elseif s == " " or s == "\027 " then
		key.name = "space"
		key.meta = #s == 2
	
	elseif s <= "\026" then
		-- ctrl+letter
		key.name = string.char( string.byte(s) + string.byte("a") - 1)
		key.ctrl = true
	
	elseif #s == 1 and s >= "a" and s <= "z" then
		-- lowercase letter
		key.name = s
	
	elseif #s == 1 and s >= "A" and s <= "Z" then
		-- shift+letter
		key.name = s:lower()
		key.shift = true

	else
		local match = s:match("^\027(%a)$")
		if match then
			-- meta+character key
			key.name = match:lower()
			key.meta = true
			key.shift = match >= "A" and match <= "Z"
		else
			local code, modifier = parseFunctionKeyCode(s)
			if code ~= "" then
				-- function keys
				local entry = keymap[code]
				if entry then
					key.name = entry[1]
					key.shift = (entry[2] ~= nil and true) or (bit.band(modifier, 1) ~= 0)
					key.ctrl = (entry[3] ~= nil and true) or (bit.band(modifier, 4) ~= 0)
					key.meta = bit.band(modifier, 10) ~= 0
				else
					key.shift = bit.band(modifier, 1) ~= 0
					key.ctrl = bit.band(modifier, 4) ~= 0
					key.meta = bit.band(modifier, 10) ~= 0
					key.name = "undefined"
				end
				key.code = code
			else
				--console.log(">> emitkey: '%s'", luanode.utils.DumpDataInHex(s))
				--for chr in string.gmatch(s, "([%z\1-\127\194-\244][\128-\191]*)") do
					-- got utf8 char
					--self:_emitKey(chr)
				--end
				-- Typing or pasting otf-8 chars in the console does not work yet
				if #s > 1 and string.byte(s, 1) ~= "\027" then
					for i=1, #s do
						emitKey(stream, s:sub(i,i))
					end
					return
				end
			end
		end
	end
	--console.log(">> emitkey: '%s'", luanode.utils.DumpDataInHex(s))
	--console.log(key.name, key.meta, string.byte(s), key.ctrl, key.shift)

	-- Don't emit a key if no name was found
	if not key.name then key = nil end

	local char
	if #s == 1 then
		char = s
	end

	if key or char then
		stream:emit("keypress", char, key)
	end
end

---
-- moves the cursor to the x and y coordinate on the given stream
--
function cursorTo (stream, x, y)

	if type(x) ~= "number" and type(y) ~= "number" then return end

	if type(x) ~= "number" then
		error("Can't set cursor row without also setting its column")
	end
	
	if type(y) ~= "number" then
		stream:write("\027[" .. (x + 1) .. "G")
	else
		stream:write("\027[" .. (y + 1) .. ";" .. (x + 1) .. "H")
	end
end

---
-- moves the cursor relative to its current location
--
function moveCursor (stream, dx, dy)
	if dx < 0 then
		stream:write("\027[" .. -dx .. "D")
	elseif dx > 0 then
		stream:write("\027[" .. dx .. "C")
	end

	if dy < 0 then
		stream:write("\027[" .. -dy .. "A")
	elseif dy > 0 then
		stream:write("\027[" .. dy .. "B")
	end
end

---
-- clears the current line cursor is on:
--  -1 for left of the cursor
--  +1 for right of the cursor
--   0 for the entire line
--
function clearLine (stream, direction)

	if direction < 0 then
		-- to the beginning
		stream:write("\027[1K")
	elseif direction > 0 then
		-- to the end
		stream:write("\027[0K")
	else
		-- entire line
		stream:write("\027[2K")
	end
end

---
-- clears the screen from the current position of the cursor down
-- 
function clearScreenDown (stream)
	stream:write("\027[0J")
end
