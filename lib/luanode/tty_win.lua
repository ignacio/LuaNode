local Class = require "luanode.class"
local Stdio = Stdio
local writeTTY = Stdio.writeTTY
local closeTTY = Stdio.closeTTY
local luanode_stream = require "luanode.stream"

local utils = require "luanode.utils"

-- TODO: sacar el seeall
module(..., package.seeall)

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
-- ReadStream class
ReadStream = Class.InheritsFrom(luanode_stream.Stream)

function ReadStream:__init(fd)
	local newStream = Class.construct(ReadStream)
	
	newStream.fd = fd
	newStream.paused = true
	newStream.readable = true
	
	local dataListeners = newStream:listeners("data")
	local dataUseString = false
	
	local function onError (err)
		newStream:emit("error", err)
	end
	
	local function onKeypress (char)
		--console.error(luanode.utils.DumpDataInHex(char))
		newStream:_emitKey(char)
		if #dataListeners > 0 and char then
			newStream:emit("data", char)
		end
	end
	
	local function onResize ()
		process:emit("SIGWINCH")
	end
	
	Stdio.initTTYWatcher(fd, onError, onKeypress, onResize)
	
	return newStream
end

ReadStream.isTTY = true


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
function ReadStream:_emitKey (s)
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
		key.name = "backspace"
		key.meta = s:sub(1,1) == "\027"
		key.ctrl = s:sub(1,1) == "\127"
	
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
						self:_emitKey(s:sub(i,i))
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
		self:emit("keypress", char, key)
	end
end

---
--
function ReadStream:pause ()
	if self.paused then return end
	
	self.paused = true
	Stdio.stopTTYWatcher()
end

---
--
function ReadStream:resume ()
	if not self.readable then
		error("Cannot resume() closed tty.ReadStream.")
	end
	if not self.paused then return end

	self.paused = false
	Stdio.startTTYWatcher()
end

---
--
function ReadStream:destroy ()
	if not self.readable then return end
	
	self.readable = false
	Stdio.destroyTTYWatcher()
	
	process.nextTick(function()
		-- try
		closeTTY(self.fd)
		self:emit("close")
		-- catch self:emit("error")
	end)
end

ReadStream.destroySoon = ReadStream.destroy


---
-- WriteStream class
WriteStream = Class.InheritsFrom(luanode_stream.Stream)

function WriteStream:__init (fd)
	local newStream = Class.construct(WriteStream)
	
	newStream.fd = fd
	newStream.writable = true
	
	return newStream
end

WriteStream.isTTY = true

---
--
function WriteStream:write (data, encoding)
	if not self.writable then
		self:emit("error", "stream not writable")
		return false
	end
	
	-- ignore encoding and buffer stuff (for now)
	-- try
	writeTTY(self.fd, data)
	-- catch err, emit(error, err)
	return true
end

---
--
function WriteStream:finish (data, encoding)
	if data then
		self:write(data, encoding)
	end
	self:destroy()
end

---
--
function WriteStream:destroy ()
	if not self.writable then return end
	
	self.writable = false
	
	process.nextTick(function()
		local closed = false
		-- try
		closeTTY(self.fd)
		closed = true
		-- catch(err) self:emit("error", err)
		if closed then
			self:emit("close")
		end
	end)
end

---
--
function WriteStream:moveCursor (dx, dy)
	if not self.writable then
		error("Stream is not writable")
	end
	
	if dx < 0 then
		self:write("\027[" .. -dx .. "D")
	elseif dx > 0 then
		self:write("\027[" .. dx .. "C")
	end

	if dy < 0 then
		self:write("\027[" .. -dy .. "A")
	elseif dy > 0 then
		self:write("\027[" .. dy .. "B")
	end
end

---
--
function WriteStream:cursorTo (x, y)
	if not self.writable then
		error("Stream is not writable")
	end
	
	if type(x) ~= "number" and type(y) ~= "number" then
		return
	end

	if type(x) ~= "number" then
		error("Can't set cursor row without also setting it's column")
	end

	if type(y) ~= "number" then
		self:write("\027[" .. (x + 1) .. "G")
	else
		self:write("\027[" .. (y + 1) .. ";" .. (x + 1) .. "H")
	end
end

---
--
function WriteStream:clearLine (direction)
	if not self.writable then
		error("Stream is not writable")
	end
	if direction < 0 then
		-- to the beginning
		self:write("\027[1K")
	elseif direction > 0 then
		-- to the end
		self:write("\027[0K")
	else
		-- entire line
		self:write("\027[2K")
	end
end
