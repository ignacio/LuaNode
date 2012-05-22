local Class = require "luanode.class"
local Socket = require "luanode.net".Socket

-- TODO: sacar el seeall
module(..., package.seeall)

-- ReadStream class
ReadStream = Class.InheritsFrom(Socket)

function ReadStream:__init(fd)
	local newStream = Class.construct(ReadStream, fd)
	
	local keypressListeners = newStream:listeners("keypress")
	
	local onData
	local onNewListener
	
	onNewListener = function(self, event)
		if event == "keypress" then
			newStream:on("data", onData)
			newStream:removeListener("newListener", onNewListener)
		end
	end
	
	onData = function(self, b)
		if #keypressListeners > 0 then
			newStream:_emitKey(b)
		else
			-- Nobody's watching anyway
			newStream:removeListener('data', onData)
			newStream:on('newlistener', onNewListener)
		end
	end
	
	newStream:on("newListener", onNewListener)
	
	-- veamos si podemos salirnos con la nuestra. Pongo en raw_socket algo que "parece" un socket, pero en realidad 
	-- es un boost::asio::posix_stream
	newStream._raw_socket = process.PosixStream(fd)
	newStream._raw_socket.read_callback = function(raw_socket, data, reason)
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
			if newStream._raw_socket and not newStream._dont_read then	-- the socket may have been closed on Stream.destroy
				--newStream._raw_socket:read()	-- issue another async read
				newStream:_readImpl()
			end
		end
	end
	
	return newStream
end

ReadStream.isTTY = true

function ReadStream:_emitKey (s)
	console.log("key", s)
end


-- WriteStream class
WriteStream = Class.InheritsFrom(Socket)

WriteStream.isTTY = true

function WriteStream:cursorTo (x, y)
	if type(x) ~= "number" and type(y) ~= "number" then return end
	
	if type(y) ~= "number" then
		error("Can't set cursor row without also setting it's column")
	end
	
	if type(x) == "number" then
		self:write('\x1b[' .. (x + 1) .. 'G')
	else
		self:write('\x1b[' .. (y + 1) .. ';' .. (x + 1) .. 'H')
	end
end

function WriteStream:moveCursor (dx, dy)
	if dx < 0 then
		self:write('\x1b[' .. (-dx) .. 'D')
	elseif dx > 0 then
		self:write('\x1b[' .. dx .. 'C')
	end
	
	if dy < 0 then
		self:write('\x1b[' .. (-dy) .. 'A')
	elseif dy > 0 then
		self:write('\x1b[' .. dy .. 'B')
	end
end

function WriteStream:clearLine (dir)
	if dir < 0 then
		-- to the beginning
			self:write("\x1b[1K")
	elseif dir > 0 then
		-- to the end
		self:write("\x1b[0K")
	else
		-- the entire line
		self:write("\x1b[2K")
	end
end

