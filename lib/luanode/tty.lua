local pairs, require, process, Stdio = pairs, require, process, Stdio
local Class = require "luanode.class"
local Socket = require "luanode.net".Socket
local luanode_stream = require "luanode.stream"
local utils = require "luanode.utils"
local stdinHandle

-- TODO: sacar el seeall
module(..., package.seeall)

_M.isatty = function (fd)
	return Stdio.isatty(fd)
end

_M.setWindowSize = function ()
	--Stdio.setWindowSize()
end

---
--
function setRawMode (flags)
	assert(stdinHandle, "stdin must be initialized before calling setRawMode")
	stdinHandle:setRawMode(flags)
end

---
-- ReadStream class
--ReadStream = Class.InheritsFrom(Socket)
ReadStream = Class.InheritsFrom(luanode_stream.Stream)

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
	newStream._raw_socket = process.TtyStream(fd, true)
	stdinHandle = newStream._raw_socket
	
	newStream._raw_socket.read_callback = function(raw_socket, data, reason)
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
			if newStream._raw_socket and not newStream._dont_read and not newStream.paused then
				newStream._raw_socket:read()	-- issue another async read
				--newStream:_readImpl()
			end
		end
	end
	
	return newStream
end

---
--
function ReadStream:setRawMode (flag)
	self._raw_socket:setRawMode(flag)
	self.isRaw = flag
end

ReadStream.isTTY = true

---
--
function ReadStream:pause ()
	if self.paused then return end
	self.paused = true
	self._raw_socket:pause()
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
	self._raw_socket:read()
end

---
--
function ReadStream:destroy ()
	if not self.readable then return end
	
	self.readable = false
	
	process.nextTick(function()
		-- try
		self._raw_socket:close()
		self:emit("close")
		-- catch self:emit("error")
	end)
end

---
-- WriteStream class
WriteStream = Class.InheritsFrom(luanode_stream.Stream)

function WriteStream:__init (fd)
	local newStream = Class.construct(WriteStream)
	
	newStream.fd = fd
	newStream._raw_socket = process.TtyStream(fd, false)
	newStream.writable = true
	newStream.readable = false
	
	local winSizeCols, winSizeRows = newStream._raw_socket:getWindowSize()
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
	local newCols, newRows = self._raw_socket:getWindowSize()
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
	self._raw_socket:write(data)
	return true
end

return _M
