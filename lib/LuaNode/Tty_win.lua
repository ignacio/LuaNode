local Class = require "luanode.class"
local writeTTY = Stdio.writeTTY
local closeTTY = Stdio.closeTTY
local luanode_stream = require "luanode.stream"
	
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
	
	local function onKeypress(char, key)
		newStream:emit("keypress", char, key)
		if #dataListeners > 0 and char then
			--self:emit("data", dataUseString and 
			newStream:emit("data", char)
		end
	end
	
	local function onResize()
		process:emit("SIGWINCH")
	end
	
	Stdio.initTTYWatcher(fd, onError, onKeypress, onResize)
	
	return newStream
end

ReadStream.isTTY = true

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
