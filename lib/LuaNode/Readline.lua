local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"
local utils = require "luanode.utils"
local tty = require "luanode.tty"

module(..., package.seeall)

Interface = Class.InheritsFrom(EventEmitter)

local kHistorySize = 30
local kBufSize = 10 * 1024

function Interface:__init (input, output, completer)
	local interface = Class.construct(Interface)

	completer = completer or function() return {} end

	assert(type(completer) == "function", "Argument 'completer' must be a function")

	interface.input = input
	interface.output = output
	input:resume()

	-- TODO
	--// Check arity, 2 - for async, 1 for sync
  	--this.completer = completer.length === 2 ? completer : function(v, callback) {
	    --callback(null, completer(v));
  	--};

  	interface:setPrompt("> ")
	
	interface.enabled = output.isTTY

	if process.env.LUANODE_NO_READLINE then
		interface.enabled = false
	end

	if not interface.enabled then
		input:on("data", function(self, data)
			interface:_normalWrite(data)
		end)
	else
		-- input usually refers to stdin
    	input:on("keypress", function(self, s, key)
      		interface:_ttyWrite(s, key)
    	end)

    	-- Current line
    	interface.line = ""

    	-- Check process.env.TERM ?
    	tty.setRawMode(true)
    	interface.enabled = true

    	-- Cursor position on the line
    	interface.cursor = 0

    	interface.history = {}
    	interface.historyIndex = -1

    	local winSize = {80}--Poutput:getWindowSize()
    	columns = winSize[1]

    	if #process:listeners("SIGWINCH") == 0 then
      		process:on("SIGWINCH", function()
        		local winSize = output:getWindowSize()
	        	columns = winSize[1]
      		end)
    	end

	end

	return interface
end

Interface.columns = _M.columns

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
function Interface:prompt ()
	if self.enabled then
		self.cursor = 0
		self:_refreshLine()
	else
		self.output:write(self._prompt)
	end
end

---
--
function Interface:question (query, callback)
	if calback then
		self:resume()
		if self._questionCallback then
			self.output:write("\n")
			self:prompt()
		else
			self._oldPrompt = self._prompt
			self:setPrompt(query)
			self._questionCallback = callback
			self.output:write("\n")
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

	self.cursor = 0

	-- Only store so many
	if #self.history > kHistorySize then
		table.remove(self.history, 1)
	end

	return self.history[1]
end

---
--
function Interface:_refreshLine ()
	if self._closed then return end

	-- Cursor to left edge.
	self.output:cursorTo(0)

	-- Write the prompt and the current buffer content.
	self.output:write(self._prompt .. self.line)

	-- Erase to right.
	self.output:clearLine(1)

	-- Move cursor to original position.
	self.output:cursorTo(#self._prompt + self.cursor)
end

---
--
function Interface:close (d)
	if self._closing then return end
	self._closing = true
	if self.enabled then
		tty.setRawMode(false)
	end
	self:emit("close")
	self._closed = true
end

---
--
function Interface:pause ()
	if self.enabled then
		tty.setRawMode(false)
	end
end

---
--
function Interface:resume ()
	if self.enabled then
		tty.setRawMode(true)
	end
end

---
--
function Interface:write (d, key)
	if self._closed then return end
  	if self.enabled then
  		self:_ttyWrite(d, key)
  	else
  		self:_normalWrite(d, key)
  	end
end

---
--
function Interface:_normalWrite (b)
	-- Very simple implementation right now. Should try to break on new lines.
  	if b then
    	self:_onLine(tostring(b))
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
    	self.output:write(c)
  	end
end

--[[
Interface.prototype._tabComplete = function() {
  var self = this;

  self.pause();
  self.completer(self.line.slice(0, self.cursor), function(err, rv) {
    self.resume();

    if (err) {
      // XXX Log it somewhere?
      return;
    }

    var completions = rv[0],
        completeOn = rv[1];  // the text that was completed
    if (completions && completions.length) {
      // Apply/show completions.
      if (completions.length === 1) {
        self._insertString(completions[0].slice(completeOn.length));
      } else {
        self.output.write('\r\n');
        var width = completions.reduce(function(a, b) {
          return a.length > b.length ? a : b;
        }).length + 2;  // 2 space padding
        var maxColumns = Math.floor(self.columns / width) || 1;

        function handleGroup(group) {
          if (group.length == 0) {
            return;
          }
          var minRows = Math.ceil(group.length / maxColumns);
          for (var row = 0; row < minRows; row++) {
            for (var col = 0; col < maxColumns; col++) {
              var idx = row * maxColumns + col;
              if (idx >= group.length) {
                break;
              }
              var item = group[idx];
              self.output.write(item);
              if (col < maxColumns - 1) {
                for (var s = 0, itemLen = item.length; s < width - itemLen;
                     s++) {
                  self.output.write(' ');
                }
              }
            }
            self.output.write('\r\n');
          }
          self.output.write('\r\n');
        }

        var group = [], c;
        for (var i = 0, compLen = completions.length; i < compLen; i++) {
          c = completions[i];
          if (c === '') {
            handleGroup(group);
            group = [];
          } else {
            group.push(c);
          }
        }
        handleGroup(group);

        // If there is a common prefix to all matches, then apply that
        // portion.
        var f = completions.filter(function(e) { if (e) return e; });
        var prefix = commonPrefix(f);
        if (prefix.length > completeOn.length) {
          self._insertString(prefix.slice(completeOn.length));
        }

      }
      self._refreshLine();
    }
  });
};

function commonPrefix(strings) {
  if (!strings || strings.length == 0) {
    return '';
  }
  var sorted = strings.slice().sort();
  var min = sorted[0];
  var max = sorted[sorted.length - 1];
  for (var i = 0, len = min.length; i < len; i++) {
    if (min[i] != max[i]) {
      return min.slice(0, i);
    }
  }
  return min;
}

Interface.prototype._wordLeft = function() {
  if (this.cursor > 0) {
    var leading = this.line.slice(0, this.cursor);
    var match = leading.match(/([^\w\s]+|\w+|)\s*$/);
    this.cursor -= match[0].length;
    this._refreshLine();
  }
};

Interface.prototype._wordRight = function() {
  if (this.cursor < this.line.length) {
    var trailing = this.line.slice(this.cursor);
    var match = trailing.match(/^(\s+|\W+|\w+)\s*/);
    this.cursor += match[0].length;
    this._refreshLine();
  }
};



]]

---
--
function Interface:_deleteLeft ()
  	if self.cursor > 0 and #self.line > 0 then
    	self.line = self.line:sub(1, self.cursor - 1) .. self.line:sub(self.cursor + 1)
    	--console.log( self.line )

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

--[[
Interface.prototype._deleteWordLeft = function() {
  if (this.cursor > 0) {
    var leading = this.line.slice(0, this.cursor);
    var match = leading.match(/([^\w\s]+|\w+|)\s*$/);
    leading = leading.slice(0, leading.length - match[0].length);
    this.line = leading + this.line.slice(this.cursor, this.line.length);
    this.cursor = leading.length;
    this._refreshLine();
  }
};


Interface.prototype._deleteWordRight = function() {
  if (this.cursor < this.line.length) {
    var trailing = this.line.slice(this.cursor);
    var match = trailing.match(/^(\s+|\W+|\w+)\s*/);
    this.line = this.line.slice(0, this.cursor) +
                trailing.slice(match[0].length);
    this._refreshLine();
  }
};
]]

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
function Interface:_line ()
	local line = self:_addHistory()
  	self.output:write('\r\n')
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
    	--console.log(self.historyIndex, luanode.utils.inspect(self.history))
    	self.line = self.history[self.historyIndex + 1]
    	self.cursor = #self.line -- set cursor to end of line.

    	self:_refreshLine()
  	end
end

---
--
function Interface:_attemptClose ()
  	if #self:listeners("attemptClose") > 0 then
    	-- User is to call interface.close() manually.
    	self:emit("attemptClose")
  	else
    	self:close()
  	end
end

---
--
---
-- Handle a write from the tty
function Interface:_ttyWrite (s, key)
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
		if key.name == "c" then
        	if #self:listeners("SIGINT") > 0 then
          		self:emit("SIGINT")
        	else
          		-- default behavior, end the readline
          		self:_attemptClose()
        	end
        elseif key.name == "h" then	-- delete left
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
			--self:_tabComplete()
			self.output:write("\t")
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

function createInterface (input, output, completer)
  	return Interface(input, output, completer)
end
