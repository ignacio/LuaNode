local Class = require "luanode.class"
local writeTTY = Stdio.writeTTY
local closeTTY = Stdio.closeTTY
local luanode_stream = require "luanode.stream"

local utils = require "luanode.utils"
	
-- TODO: sacar el seeall
module(..., package.seeall)

-- ReadStream class
ReadStream = Class.InheritsFrom(luanode_stream.Stream)

function ReadStream:__init(fd)
	local newStream = Class.construct(ReadStream)
	
	newStream.fd = fd
	newStream.paused = true
	newStream.readable = true
	
	local dataListeners = newStream:listeners("data")
	local dataUseString = false
	
	local function onError(err)
		newStream:emit("error", err)
	end
	
	local function onKeypress(char)
		--console.error(luanode.utils.DumpDataInHex(char))
		newStream:_emitKey(char)
		--[[
		newStream:emit("keypress", char)
		if #dataListeners > 0 and char then
			--self:emit("data", dataUseString and 
			newStream:emit("data", char)
		end
		]]
	end
	
	local function onResize()
		process:emit("SIGWINCH")
	end
	
	Stdio.initTTYWatcher(fd, onError, onKeypress, onResize)
	
	return newStream
end

ReadStream.isTTY = true

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

function ReadStream:_emitKey (s)
    local key = {
        name = nil,
        ctrl = false,
        meta = false,
        shift = false
	}
    --console.log("Emitkey")
    --console.log(luanode.utils.DumpDataInHex(s))

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
	
	--elseif parts 
		-- TODO: other combinations and function keys
	--else
		--console.error("unhandled key", key.name, key.meta, key.ctrl, key.shift)
	else
		local part, part_a, part_b, part_c, part_d = s:match("\027(%[)(%a)")
		if part_a then
			--console.log("parts", parts)
		--elseif s:match("\027%[%a") then
			local code = (part_a or "") .. (part_b or "") .. (part_c or "") .. (part_d or "")

			--local modifier = 
			--process.stdout:write(s)
			--console.log(s)
			if code == "D" then
				key.name = "left"
			elseif code == "C" then
				key.name = "right"
			elseif code == "A" then
				key.name = "up"
			elseif code == "B" then
				key.name = "down"

			else
				console.log("emitkey: '%s'\ncode: %s", luanode.utils.DumpDataInHex(s), code)
			end
		else
			--console.log(">> emitkey: '%s'", luanode.utils.DumpDataInHex(s))
		end
	end

	-- Don't emit a key if no name was found
  	if not key.name then
	    key = nil
  	end

	local char
  	if #s == 1 then
    	char = s
  	end

  	if key or char then
    	self:emit("keypress", char, key)
  	end


    --console.log(key.name, key.meta, string.byte(s), key.ctrl, key.shift)
end

function ReadStream:pause()
	if self.paused then return end
	
	self.paused = true
	Stdio.stopTTYWatcher()
end

function ReadStream:resume()
	if not self.readable then
		error('Cannot resume() closed tty.ReadStream.')
	end
	if not self.paused then return end

	self.paused = false
	Stdio.startTTYWatcher()
end

function ReadStream:destroy()
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



-- WriteStream class
WriteStream = Class.InheritsFrom(luanode_stream.Stream)

function WriteStream:__init(fd)
	local newStream = Class.construct(WriteStream)
	
	newStream.fd = fd
	newStream.writable = true
	
	return newStream
end

WriteStream.isTTY = true

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

function WriteStream:finish (data, encoding)
	if data then
		self:write(data, encoding)
	end
	self:destroy()
end

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

function WriteStream:moveCursor (dx, dy)
	if not self.writable then
		error("Stream is not writable")
	end
	
	Stdio.moveCursor(self.fd, dx, dy)
end

function WriteStream:cursorTo (x, y)
	if not self.writable then
		error("Stream is not writable")
	end
	
	Stdio.cursorTo(self.fd, x, y)
end

function WriteStream:clearLine (direction)
	if not self.writable then
		error("Stream is not writable")
	end
	
	Stdio.clearLine(self.fd, direction or 0)
end
