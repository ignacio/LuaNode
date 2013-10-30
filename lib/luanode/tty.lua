local pairs, require, process, Stdio = pairs, require, process, Stdio
local Class = require "luanode.class"
local Socket = require "luanode.net".Socket
local luanode_stream = require "luanode.stream"
local utils = require "luanode.utils"
local stdinHandle

local _M = {
	_NAME = "luanode.tty",
	_PACKAGE = "luanode."
}

-- Make LuaNode 'public' modules available as globals.
luanode.tty = _M

_M.isatty = function (fd)
	return Stdio.isatty(fd)
end

_M.setWindowSize = function ()
	--Stdio.setWindowSize()
end

---
--
function _M.setRawMode (flags)
	assert(stdinHandle, "stdin must be initialized before calling setRawMode")
	stdinHandle:setRawMode(flags)
end

---
-- ReadStream class
--ReadStream = Class.InheritsFrom(Socket)
local ReadStream = Class.InheritsFrom(luanode_stream.Stream)
_M.ReadStream = ReadStream

function ReadStream:__init(fd)
	--local newStream = Class.construct(ReadStream)--, fd)
	local newStream = Class.construct(ReadStream)--, fd)
	
	newStream.fd = fd
	newStream.readable = true
	newStream.writable = false
	newStream.paused = true
	newStream.isRaw = false
	
	-- veamos si podemos salirnos con la nuestra. Pongo en raw_socket algo que "parece" un socket, pero en realidad 
	-- es un boost::asio::posix_stream
	newStream._handle = process.TtyStream(fd, true)
	stdinHandle = newStream._handle
	
	newStream._handle.read_callback = function(raw_socket, data, err_msg, err_code)
		--print("read_callback: %s", data)
		if not data or #data == 0 then
			newStream.readable = false
			--if reason == "eof" or reason == "closed" or reason == "aborted" or reason == "reset" then
				if not newStream.writable then
					newStream:destroy()
					-- note: 'close' not emitted until nextTick
				end
				newStream:emit("end")
				if type(newStream.onend) == "function" then
					newStream:onend()
				end
			--end
		elseif #data > 0 then
			if newStream._decoder then
				-- emit String
				local s = newStream._decoder:write(data)--pool.slice(start, end))
				if #s > 0 then newStream:emit("data", s) end
			else
				-- emit buffer
				newStream:emit("data", data)	-- emit slice newStream.emit('data', pool.slice(start, end))
			end
			-- Optimization: emit the original buffer with end points
			if newStream.ondata then
				--newStream.ondata(pool, start, end)
				newStream:ondata(data)
			end

			-- the socket may have been closed on Stream.destroy or paused
			if newStream._handle and not newStream._dont_read and not newStream.paused then
				newStream._handle:read()	-- issue another async read
				--newStream:_readImpl()
			end
		end
	end
	
	return newStream
end

---
--
function ReadStream:setRawMode (flag)
	self._handle:setRawMode(flag)
	self.isRaw = flag
end

ReadStream.isTTY = true

---
--
function ReadStream:pause ()
	if self.paused then return end
	self.paused = true
	self._handle:pause()
	--Class.superclass(ReadStream).pause(self)
end

---
--
function ReadStream:resume ()
	if not self.readable then
		error("Cannot resume() closed tty.ReadStream.")
	end
	if not self.paused then return end

	self.paused = false
	-- en serio no tengo una forma mejor de hacer esto?
	--Class.superclass(ReadStream).resume(self)
	self._handle:read()
end

---
--
function ReadStream:destroy (err_msg, err_code)
	if not self.readable then return end
	
	self.readable = false
	
	if self._handle then
		self._handle:close()
		self._handle.read_callback = function() end
		self._handle = nil
	end

	process.nextTick(function()
		-- try
		self:emit("close", err_msg and true or false)
		-- catch self:emit("error")
	end)
end

---
-- WriteStream class
local WriteStream = Class.InheritsFrom(luanode_stream.Stream)
_M.WriteStream = WriteStream

function WriteStream:__init (fd)
	local newStream = Class.construct(WriteStream)
	
	newStream.fd = fd
	newStream._handle = process.TtyStream(fd, false)
	newStream.writable = true
	newStream.readable = false
	
	local winSizeCols, winSizeRows = newStream._handle:getWindowSize()
	if winSizeCols then
		newStream.columns = winSizeCols
		newStream.rows = winSizeRows
	end
	
	return newStream
end

WriteStream.isTTY = true


function WriteStream:_refreshSize ()
	local oldCols = self.columns
	local oldRows = self.rows
	local newCols, newRows = self._handle:getWindowSize()
	if not newCols then
		self:emit("error", "error in getWindowSize")--errnoException(errno, 'getWindowSize'))
		return
	end
	if oldCols ~= newCols or oldRows ~= newRows then
		self.columns = newCols
		self.rows = newRows
		self:emit("resize")
	end
end

---
--
function WriteStream:write (data, encoding)
	if not self.writable then
		self:emit("error", "stream not writable")
		return false
	end
	-- ignore encoding and buffer stuff (for now)
	self._handle:write(data)
	return true
end

return _M
