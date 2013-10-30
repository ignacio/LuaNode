local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"
local luanode_stream = require "luanode.stream"
local Timers = require "luanode.timers"
local Utils = require "luanode.utils"
local assert = assert

local function noop() end

local _M = {
	_NAME = "luanode.net",
	_PACKAGE = "luanode."
}

-- Make LuaNode 'public' modules available as globals.
luanode.net = _M

local Net = require "Net"  --process.Net

-- forward references
local initSocketHandle

local END_OF_FILE = {}

-- Do we have openssl crypto?
local SecureContext = process.SecureContext
local SecureStream = process.SecureStream
local have_crypto = (SecureContext and SecureStream and true) or false

local function isPipeName (s)
	return type(s) == "string" and not tonumber(s)
end

local function createPipe ()
	error("not implemented")
end

--
-- Public:
_M.isIP = Net.isIP

function _M.isIPv4 (input)
	local isIP, kind = Net.isIP(input)
	return (isIP and kind == 4)
end

function _M.isIPv6 (input)
	local isIP, kind = Net.isIP(input)
	return (isIP and kind == 6)
end

---
-- Returns options or options, cb
-- It is the same as the argument of Socket.connect
local function normalizeConnectArgs (...)
	local options = {}
	
	local args = Utils.pack(...)

	if type(args[1]) == "table" then
		-- connect(options, [cb])
		options = args[1]
	elseif isPipeName(args[1]) then
		-- connect(path, [cb])
		options.path = args[1]
	else
		-- connect(port, [host], [cb])
		options.port = args[1]
		if type(args[2]) == "string" then
			options.host = args[2]
		end
	end
	local cb = args[ args.n ]
	if type(cb) == "function" then
		return options, cb
	end
	return options
end

--
-- Bind with UNIX
--   t.bind(fd, "/tmp/socket")
-- Bind with TCP
--   t.bind(fd, 80, "192.168.11.2")
--   t.bind(fd, 80)
local function bind(socket, port, ip)
	assert(socket and port, "Must pass fd and port / path")
	
	if not ip then
		ip = "0.0.0.0"
	end
	-- disgusting hack. In 
	if process.platform ~= "windows" then
		socket:setoption("reuseaddr", true)
	end
	local ok, err_msg, err_code = socket:bind(ip, port)
	if not ok then
		console.error("bind('%s', '%s', '%s') failed with error: %s\r\n%s", socket, port, ip, err_msg, err_code)
		return false, err_msg, err_code
	end
	return true
end


-- Socket Class
local Socket = Class.InheritsFrom(luanode_stream.Stream)
_M.Socket = Socket

-- FIXME: tengo que guardar las conexiones en algun lado. Y eventualmente las tengo que sacar
local m_opened_sockets = {}

--[[
local function setImplementationMethods(self)
	if self.type == "unix" then
		error("not yet implemented")
	else
		self._writeImpl = function(self, buf, off, len, fd, flags)
			return self._handle:write(buf, off, len)
		end
		
		self._readImpl = function(self, buf, off, len, calledByIOWatcher)
			return self._handle:read(buf, off, len)
		end
	end
	
	self._shutdownImpl = function()
		self._handle:shutdown("write")
	end
end
--]]


-- paso raw_socket o socket
--[=[
local function _doFlush(raw_socket, ok, socket, err_code)
	-- Socket becomes writable on connect() but don't flush if there's
	-- nothing actually to write
	-- hack, lo tendria que mandar ya yo como un socket? (la tabla socket)
	if not ok then
		console.error("%s: %s - %s, %s", ok, socket, raw_socket, err_code)
		local err = socket
		local socket = raw_socket._owner
		--socket.writable = false
		socket:destroy(err, err_code)
		console.error(socket)
		if socket then
			socket:emit("error", ok, err_code)
		end
		return
	end
	if not socket then
		socket = raw_socket._owner
	end
	if socket then
		if socket:flush() then
			if socket._events and socket._events["drain"] then
				socket:emit("drain")
			end
			if socket.ondrain then
				socket:ondrain() -- Optimization
			end
		end
	end
end
--]=]

-- @param raw_socket is the socket
-- @param data is the data that has been read or nil if the socket has been closed
-- @param reason is present when the socket is closed, with the reason
local function onread (raw_socket, data, err_msg, err_code)
	local self = raw_socket.owner
	assert(raw_socket == self._handle, "handle != self._handle")

	-- TODO: check que el error sea EOF
	if not data or #data == 0 then
		-- EOF
		self.readable = false

		assert(not self._flags["FLAG_GOT_EOF"])
		self._flags["FLAG_GOT_EOF"] = true

		-- We call destroy() before end(). 'close' not emitted until nextTick so
		-- the 'end' event will come first as required.
		if not self.writable then
			self:destroy()
		end

		if not self.allowHalfOpen then
			self:finish()
		end
		if self._events and self._events["end"] then
			self:emit("end")
		end
		if type(self.onend) == "function" then
			self:onend()
		end
		-- TODO: falta manejar ECONNRESET
		--if (errno == 'ECONNRESET') {
		--	self._destroy();
		--} else {
		--	self._destroy(errnoException(errno, 'read'));
		--}

	elseif #data > 0 then

		self._handle.reading = false
		
		if self.readable then	-- the socket may have been closed on Stream.destroy
			Timers.Active(self)
		end

		if self._decoder then
			-- Emit a string
			local string = self._decoder:write(data)
			if #string > 0 then self:emit("data", string) end
		else
			-- emit buffer
			self:emit("data", data)
		end

		self.bytesRead = self.bytesRead + #data

		-- Optimization: emit the original buffer with end points
		if self.ondata then
			self:ondata(data)
		end
		
		-- TODO: revisar esto
		if self.readable and not self._dont_read then	-- the socket may have been closed on Stream.destroy
			--self._raw_socket:read()	-- issue another async read
			--self:_readImpl()
			-- libuv has readStart(), which continuously read from a socket
			-- we need to issue another read after each read callback
			-- so proetct from "double reads" (see Socket:resume)
			if not self._handle.reading then
				self._handle.reading = true
				self._handle:read()
			end
		end
	end
end

---
-- 
function Socket:setEncoding (encoding)
	--error("not implemented")
	-- como que acá en Lua no aplica mucho esto
end

function Socket:remoteAddress ()
	return self._remoteAddress, self._remotePort
end

--- 
-- 
function Socket:write (data, encoding, cb)
	-- If we are still connecting, then buffer this for later.
	if self._connecting then
		self._connectQueueSize = self._connectQueueSize + #data
		if self._connectQueue then
			self._connectQueue[#self._connectQueue + 1] = { data, encoding, cb }
		else
			self._connectQueue = { { data, encoding, cb } }
		end
		return false
	end

	return self:_write(data, encoding, cb)
	--[[
	if self._connecting or (self._writeQueue and #self._writeQueue > 0) then
		if not self._writeQueue then
			self._writeQueue = {}
			self._writeQueueEncoding = {}
			self._writeQueueFD = {}
		end
		-- Slow. There is already a write queue, so let's append to it.
		if self:_writeQueueLast() == END_OF_FILE then
			error('Socket:finish() called already; cannot write.')
		end
		
		if type(data) == "string" and #self._writeQueue > 0 and 
			type(self._writeQueue[#self._writeQueue]) == "string" and
			self._writeQueueEncoding[#self._writeQueueEncoding] == encoding
		then
			-- optimization - concat onto last
			self._writeQueue[#self._writeQueue] = self._writeQueue[#self._writeQueue] .. data
		else
			table.insert(self._writeQueue, data)
			table.insert(self._writeQueueEncoding, encoding)
		end
		
		-- TODO
		--if (fd != undefined) {
			--this._writeQueueFD.push(fd);
		--}
		return false
	else
		-- Fast.
		-- The most common case. There is no write queue. Just push the data directly to the socket.
		return self:_writeOut(data, encoding, fd)
	end
	--]]
end

--local function afterWrite (status, handle, req)
local function afterWrite (raw_socket, ok, socket, err_code)
	local self = raw_socket.owner 	--local self = handle.owner

	-- callback may come after call to destroy
	if self.destroyed then
		return
	end

	if not ok then
		--console.error("%s: %s - %s, %s", ok, socket, raw_socket, err_code)
		local err = socket
		self:_destroy(err, err_code)
		return
	end

	Timers.Active(self)

	while self._writeQueue and #self._writeQueue > 0 do
		local data = table.remove(self._writeQueue, 1)
		local encoding = table.remove(self._writeQueueEncoding, 1)
		local cb = table.remove(self._writeQueueCB, 1)
		
		if data == END_OF_FILE then
			self:_shutdown()
			--return true
		end
		self:_write(data, encoding, cb)
		break

		--local flushed = self:_writeOut(data, encoding, fd)
		--if not flushed then
			--return false
		--end
	end

	self._pendingWriteReqs = self._pendingWriteReqs - 1
	if self._pendingWriteReqs == 0 then
		self:emit("drain")
	end

	if self._pendingWriteReqs == 0 and self._flags["FLAG_DESTROY_SOON"] then
		self:_destroy()
	end

	--[[
	if status then
		self:_destroy( error("write"), req.cb)
		return
	end

	Timers.Active(self)

	self._pendingWriteReqs = self._pendingWriteReqs - 1

	if self._pendingWriteReqs == 0 then
		self:emit("drain")
	end

	if req.cb then
		req.cb()
	end

	if self._pendingWriteReqs == 0 and self._flags["FLAG_DESTROY_SOON"] then
		self:_destroy()
	end
	--]]
end

function Socket:_write (data, encoding, cb)
	Timers.Active(self)

	if not self._handle then
		self:_destroy( error("This socket is closed"), cb )
		return false
	end

	--[[
	local writeReq
	writeReq = self._handle:write(data)

	if not writeReq or type(writeReq) ~= "table" then
		self:_destroy(error("write"), cb)
		return false
	end
	writeReq.oncomplete = afterWrite
	writeReq.cb = cb

	self._pendingWriteReqs = self._pendingWriteReqs + 1
	self._bytesDispatched = self._bytesDispatched + writeReq.bytes

	return self._handle.writeQueueSize == 0
	--]]
	-- yo estoy devolviendo true o false si el write se pudo hacer o no
	local couldWrite = self._handle:write(data)
	if couldWrite then
		self._pendingWriteReqs = self._pendingWriteReqs + 1
		self._bytesDispatched = self._bytesDispatched + #data --writeReq.bytes
		-- TODO; writeQueueSize siempre devuelve 0 (arreglar)
		return self._handle.writeQueueSize == 0
	end

	-- encolar data, encoding y cb
	if not self._writeQueue then
		self._writeQueue = {}
		self._writeQueueEncoding = {}
		self._writeQueueCB = {}
	end
	-- Restore it back into the queue
	--table.insert(self._writeQueue, 1, data)
	--table.insert(self._writeQueueEncoding, 1, encoding)
	--table.insert(self._writeQueueCB, 1, cb)
	--[[
	if type(data) == "string" and #self._writeQueue > 0 and 
		type(self._writeQueue[#self._writeQueue]) == "string" and
		self._writeQueueEncoding[#self._writeQueueEncoding] == encoding
	then
		-- optimization - concat onto last
		self._writeQueue[#self._writeQueue] = self._writeQueue[#self._writeQueue] .. data
		-- y aca que pasa con el callback?
	else
		table.insert(self._writeQueue, data)
		table.insert(self._writeQueueEncoding, encoding)
		table.insert(self._writeQueueCB, cb)
	end
	--]]
	table.insert(self._writeQueue, data)
	table.insert(self._writeQueueEncoding, encoding)
	table.insert(self._writeQueueCB, cb)
	return false
end

-- 
-- 
--[=[
function Socket:_writeOut(data, encoding, fd)
	--error("not implemented")
	if not self.writable then
		error("Socket is not writable")
	end
	-- por ahora, escribo derecho
	--self._raw_socket:write(data)
	--local bytesWritten = self:_writeImpl(buffer, off, len, fd, 0);
	local couldWrite = self:_writeImpl(data)
	
	Timers.Active(self)
	
	if not couldWrite then
		-- encolar data, encoding y fd en los buffers
		if not self._writeQueue then
			self._writeQueue = {}
			self._writeQueueEncoding = {}
			self._writeQueueFD = {}
		end
		-- Restore it back into the queue
		table.insert(self._writeQueue, 1, data)
		table.insert(self._writeQueueEncoding, 1, encoding)
		--[[
		-- Slow. There is already a write queue, so let's append to it.
		if type(data) == "string" and #self._writeQueue > 0 and 
			type(self._writeQueue[#self._writeQueue]) == "string" and
			self._writeQueueEncoding[#self._writeQueueEncoding] == encoding
		then
			-- optimization - concat onto last
			self._writeQueue[#self._writeQueue] = self._writeQueue[#self._writeQueue] .. data
		else
			table.insert(self._writeQueue, 1, data)
			table.insert(self._writeQueueEncoding, 1, encoding)
		end
		--]]
	end
	
	return couldWrite
end
--]=]


local function afterConnect (status, handle, req, readable, writable)
	local self = handle.owner

	-- callback may come after call to destroy
	if self.destroyed then
		return
	end

	assert(handle == self._handle, "handle ~= self._handle")

	LogDebug("afterConnect")

	assert(self._connecting)
	self._connecting = false

	if status == 0 then
		self.readable = readable
		self.writable = writable
		Timers.Active(self)

		if self.readable and not self._paused then
			handle:readStart()
		end

		if self._connectQueue then
			LogDebug("Drain the connect queue")

			local connectQueue = self._connectQueue
			for _, m in ipairs(self._connectQueue) do
				self:_write(m)
			end
			self:_connectQueueCleanUp()
		end

		self:emit("connect")

		if self._flags["FLAG_SHUTDOWN_QUEUED"] then
			-- end called before connected - call end now with no data
			self._flags["FLAG_SHUTDOWN_QUEUED"] = nil
			self:finish()
		end
	else
		self:_connectQueueCleanUp()
		self:_destroy( error("connect") )
	end
end

---
-- Declare this helper outside of connect_callback in order to create only one copy of it
local function drainConnectQueue (socket)
	local connectQueue = socket._connectQueue
	for _, m in ipairs(socket._connectQueue) do
		socket:_write(m[1], m[2])
	end
	socket:_connectQueueCleanUp()
end

-- Declare the connect callback outside of doConnect, in order to create only one copy of it
local connect_callback = function(handle, ok, err_msg, err_code)
	handle.connect_callback = nil
	local socket = assert(handle.owner)
	
	-- callback may come after call to destroy
	if socket.destroyed then
		LogWarning("Socket '%s' connected but was closed in the meantime", handle)
		return
	end

	assert(handle == socket._handle, "handle ~= socket._handle")
	socket._connecting = false

	if ok then
		socket.readable = true
		socket.readable = true
		Timers.Active(socket)

		if socket._connectQueue then
			if not socket.secure then
				drainConnectQueue(socket)
			else
				-- if the socket is secure, we need to wait until the ssl handshake is done
				-- to write data
				socket:once("secure", drainConnectQueue)
			end
		end

		local ok, err, err_code = pcall(socket.emit, socket, "connect")
		if not ok then
			socket:destroy(err, err_code)
			return
		end

		if socket._flags["FLAG_SHUTDOWN_QUEUED"] then
			-- end called before connected - call end now with no data
			socket._flags["FLAG_SHUTDOWN_QUEUED"] = nil
			socket.writable = true
			socket:finish()
			return
		end
		
		-- we need to perform this read stuff here after "connect" or else the TLS stuff breaks
		if socket.readable and not socket._paused then
			--handle:readStart()
			-- only do an initial read if the socket is not secure (we need to wait till the handshake is done)
			if not socket.secure then
				socket:resume()
			end
		end

		--[[
		if socket._handle then
			socket.readable = true
			socket.writable = true
			socket._handle.write_callback = _doFlush
		end
		local ok, err = pcall(socket.emit, socket, "connect")
		if not ok then
			socket:destroy(err)
		end
		
		if socket._writeQueue and #socket._writeQueue > 0 and not socket.secure then
			-- Flush socket in case any writes are queued up while connecting.
			-- ugly
			_doFlush(nil, true, socket)
		end
		-- only do an initial read if the socket is not secure (we need to wait till the handshake is done)
		if socket.readable and not socket.secure then
			socket:resume()
		end
		return
		--]]
	else
		socket:_connectQueueCleanUp()
		local msg = ("Failed to connect to %s:%d - %s"):format(socket._remoteAddress, socket._remotePort, err_msg)
		socket:_destroy(msg, err_code)
	end
end

local function connect (self, address, port, addressType, localAddress)
	-- TODO return promise from Socket.prototype.connect which
	-- wraps _connectReq.

	assert(self._connecting)

	if localAddress then
		local ok, err_msg, err_code = bind(self._handle, port, address)
		if not ok then
			self:_destroy(err_msg, err_code)
		end
	end

	local connectReq
	--connectReq = 
	local ok, err_msg, err_code = self._handle:connect(address, port)
	if not ok then
		local msg = ("Failed to connect to %s:%d - %s"):format(address, port, err_msg)
		self:_destroy(msg, err_code)
		return
	end
	LogDebug("connecting to %s:%d", address, port)
	self._remoteAddress = address
	self._remotePort = port

	self._handle.connect_callback = connect_callback

	--if connectReq then
	--	connectReq.oncomplete = afterConnect
	--else
		--self:_destroy( "connect" )
	--end
end

-- var socket = new Socket()
-- socket.connect(80)               - TCP connect to port 80 on the localhost
-- socket.connect(80, 'nodejs.org') - TCP connect to port 80 on nodejs.org
-- socket.connect('/tmp/socket')    - UNIX connect to socket specified by path

-- ojo! Http crea el stream y entra derecho por acá, no llama a net.createConnection
--function Socket:connect (port, host, callback)
function Socket:connect (options, callback, ...)

	if type(options) ~= "table" then
		local args, cb = normalizeConnectArgs(options, callback, ...)
		return self:connect(args, cb)
	end

	local pipe = not not options.path

	-- TODO: estoy condicionando a que sea un pipe
	-- ojo con reconectar
	if pipe and self.destroyed or not self._handle then
		if pipe then
			self._handle = createPipe()	--or process.Socket("tcp4")--createTCP()
			initSocketHandle(self)
		end
	end

	if type(callback) == "function" then
		self:once("connect", callback)
	end

	Timers.Active(self)

	self._connecting = true
	self.writable = true

	if pipe then
		connect(self, options.path)
	elseif not options.host then
		LogDebug("connect: missing host")
		self._handle = process.Socket("tcp4")
		initSocketHandle(self)
		connect(self, "127.0.0.1", options.port, 4)
	else
		local host = options.host or "127.0.0.1"
		-- TODO: fixme: no estoy escuchando en ipv6 !
		if host:lower() == "localhost" then
			host = "127.0.0.1"
		end
		LogDebug("connect: find host %s", host)
		require("luanode.dns").lookup(host, function (err, address, hostname)
			-- It's possible we were destroyed while looking this up.
			if not self._connecting then return end

			if err then
				-- net.createConnection() creates a net.Socket object and
				-- immediately calls net.Socket.connect() on it (that's us).
				-- There are no event listeners registered yet so defer the
				-- error event to the next tick.
				process.nextTick(function()
					self:emit('error', err)
					self:_destroy()
				end)
			else
				if not self._handle then
					local kind = (address.family == 6 and "tcp6") or (address.family == 4 and "tcp4") or error("unknown address family" .. tostring(address.family))
					self._handle = process.Socket(kind)
					initSocketHandle(self)
				end

				Timers.Active(self)
				
				--self.kind = (address.family == 6 and "tcp6") or (address.family == 4 and "tcp4") or error("unknown address family" .. tostring(address.family))
				--local socket, err_msg, err_code = process.Socket(self.kind)
				connect(self, address.address, options.port, address.family, options.localAddress)
				--[[
				self.kind = (address.family == 6 and "tcp6") or (address.family == 4 and "tcp4") or error("unknown address family" .. tostring(address.family))
				local socket, err_msg, err_code = process.Socket(self.kind)
				if not socket then
					self:emit('error', err_msg, err_code)
				else
					self._handle = socket
					self._handle._owner = self
					initSocket(self)
					if not self._handle.read_callback then error("No read_callback") end
					doConnect(self, port, address.address)
				end
				--]]
			end
		end)
	end

	return self

	--[=[
	if self.fd then error("Socket already opened") end
	
	--if not self._handle.read_callback then error("No read_callback") end
	
	Timers.Active(self)	-- ver cómo
	self._connecting = true	--set false in doConnect
	self.writable = true
	
	if type(host) == "function" and not callback then
		callback = host
		host = nil
	end
	
	if type(callback) == "function" then
		self:on("connect", callback)
	end
	
	if type(port) == "string" and not tonumber(port) then
		--unix path, cagamos
		local path = port
		error("UNIX domain sockets not implemented yet")
		self.fd = socket("unix")
		self.type = "unix"
		
		setImplementationMethods(self)
		doConnect(self, port)
	else
		-- TODO: por ahora asumo que es siempre una ip x.x.x.x
		local ip = host or "127.0.0.1"
		local port = tonumber(port)
		assert(type(port) == "number", "missing port")
		assert(port >= 0 and port <= 65535, "port number out of range")
		---[[
			-- TODO: fixme: no estoy escuchando en ipv6 !
			if ip:lower() == "localhost" then
				ip = "127.0.0.1"
			end
			dns.lookup(ip, function (err, address, hostname)
				if err then
					self:emit('error', err)
				else
					self.kind = (address.family == 6 and "tcp6") or (address.family == 4 and "tcp4") or error("unknown address family" .. tostring(address.family))
					local socket, err_msg, err_code = process.Socket(self.kind)
					if not socket then
						self:emit('error', err_msg, err_code)
					else
						self._handle = socket
						self._handle._owner = self
						initSocket(self)
						if not self._handle.read_callback then error("No read_callback") end
						doConnect(self, port, address.address)
					end
				end
			end)
		--]]
		--[[
		-- if no underlying socket was created, do it now
		if not self._raw_socket then
			if ip:lower() == "localhost" then
				ip = "127.0.0.1"
			end
			local is_ip, version = isIP(ip)
			if not is_ip then
				error(version)
			end
			self.kind = (version == 6 and "tcp6") or (version == 4 and "tcp4") or error("unknown IP version")
			self._raw_socket = process.Socket(self.kind)
		end
		initSocket(self)
		if not self._raw_socket.read_callback then error("No read_callback") end
		doConnect(self, port, ip)
		--]]
	end
	--]=]
end

--[=[
local function initSocket(self)
	-- en lugar de usar _readWatcher, recibo los eventos de read en _raw_socket.read_callback
	--self._readWatcher = {}
	--self._readWatcher.callback = function()
	self._pendingWriteReqs = 0
	self._flags = {}
	self._connectQueueSize = 0
	self.errorEmitted = false
	self.bytesRead = 0
	self._bytesDispatched = 0

	self.readable = false
	self.destroyed = false
	
	-- @param raw_socket is the socket
	-- @param data is the data that has been read or nil if the socket has been closed
	-- @param reason is present when the socket is closed, with the reason
	self._raw_socket.read_callback = function(raw_socket, data, err_msg, err_code)
		if not data or #data == 0 then
			self.readable = false
			if not self.writable then
				self:destroy()
				-- note: 'close' not emitted until nextTick
			end
			self:emit("end")
			if type(self.onend) == "function" then
				self:onend()
			end

		elseif #data > 0 then
			if self.readable then	-- the socket may have been closed on Stream.destroy
				Timers.Active(self)
			end
			
			if self._decoder then
				-- emit String
				local s = self._decoder:write(data)--pool.slice(start, end))
				if #s > 0 then self:emit("data", s) end
			else
				-- emit buffer
				self:emit("data", data)	-- emit slice self.emit('data', pool.slice(start, end))
			end
			-- Optimization: emit the original buffer with end points
			if self.ondata then
				--self.ondata(pool, start, end)
				self:ondata(data)
			end
			if self.readable and not self._dont_read then	-- the socket may have been closed on Stream.destroy
				--self._raw_socket:read()	-- issue another async read
				self:_readImpl()
			end
		end
	end

	--self._writeWatcher = ioWatchers.alloc()
	--self._writeWatcher.socket = self
	--self._writeWatcher.callback = _doFlush

	self._raw_socket.write_callback = _doFlush
end
--]=]

---
-- called when creating a new Socket, or when re-using a closed Socket
initSocketHandle = function (socket)
	socket._pendingWriteReqs = 0
	socket._flags = {}
	socket._connectQueueSize = 0
	socket.destroyed = false
	socket.errorEmitted = false
	socket.bytesRead = 0
	socket._bytesDispatched = 0

	-- Handle creation may be deferred to bind() or connect() time.
	if socket._handle then
		socket._handle.owner = socket
		socket._handle.read_callback = assert(onread)
		socket._handle.write_callback = assert(afterWrite)
	end
end

function Socket:__init (options)
	-- http.Client llama acá sin socket. Conecta luego.
	local newSocket = Class.construct(Socket)

	if type(options) == "number" then
		options = { fd = options }	-- Legacy interface
	elseif not options then
		options = {}
	end

	if not options.fd then
		newSocket._handle = options.handle
	else
		newSocket._handle = createPipe()
		newSocket._handle:open(options.fd)
		newSocket.readable = true
		newSocket.readable = true
	end
	
	initSocketHandle(newSocket)
	newSocket.allowHalfOpen = not not options.allowHalfOpen

	return newSocket
	
	--[=[
	newSocket.fd = nil
	newSocket.kind = kind
	newSocket.secure = false
	newSocket._EOF_inserted = false	-- signals when we called 'finish' on the stream
									-- but the underlying socket is not closed yet
									
	-- Queue of buffers and string that need to be written to socket.
	newSocket._writeQueue = {}
	newSocket._writeQueueEncoding = {}
	newSocket._writeQueueFD = {}
	
	newSocket.readable = false
	-- en lugar de usar _writeWatcher, recibo los eventos de write en _raw_socket.write_callback
	newSocket.writable = false
	
	setImplementationMethods(newSocket)
	
	m_opened_sockets[newSocket] = newSocket
	
	--[[
	if not fd then
		-- I don't know which type of stream yet
		-- to be determined later
		return newSocket
	end
	--]]
	
	--[[
	if getmetatable(fd) == process.Socket then
		fd._owner = newSocket
		newSocket._raw_socket = fd
		--newSocket:open(fd, kind)	-- esto se hace mas adelante
		return newSocket
	end
	
	if tonumber(fd or 0) > 0 then
		--newSocket:open(fd, kind)
	else
		setImplementationMethods(newSocket)
	end
	
	return newSocket
	--]=]
end

function Socket:listen (cb)
	self:on("connection", cb)
	listen(self)
end

function Socket:setTimeout (msecs, callback)
	if msecs > 0 then
		Timers.Enroll(self, msecs)
		if self._handle then
			Timers.Active(self)
		end
		if callback then
			self:once("timeout", callback)
		end
	elseif msecs == 0 then
		Timers.Unenroll(self)
		if callback then
			self:removeListener("timeout", callback)
		end
	end
end

function Socket:_onTimeout ()
	LogDebug("_onTimeout")
	self:emit("timeout")
end

function Socket:setNoDelay (v)
	-- backwards compatibility: assume true when 'v' is omitted
	if self._handle and self._handle.setoption then
		v = not not v
		self._handle:setoption("nodelay", v)
	end
end

function Socket:setKeepAlive (enable, time, interval)
	if self._handle and self._handle.setoption then
		self._handle:setoption("keepalive", enable, time, interval)
	end
end

function Socket:address ()
	if self._handle and self._handle.getsockname then
		return self._handle:getsockname()
	end
	return nil
end

function Socket:readyState ()
	if self._connecting then
		return "opening"
	elseif self.readable and self.writable then
		return "open"
	elseif self.readable and not self.writable then
		return "readOnly"
	elseif not self.readable and self.writable then
		return "writeOnly"
	else
		return "closed"
	end
end

function Socket:bufferSize ()
	if self._handle then
		return self._handle.writeQueueSize + self._connectQueueSize
	end
end

function Socket:pause ()
	self._paused = true
	if self._handle and not self._connecting then
		--self._handle:readStop()
		-- we just set a flag and don't issue a read
	end
end

---
-- At the moment, just issue an async read (if no read was already been made)
function Socket:resume ()
	self._paused = false
	if self._handle and not self._connecting then
		-- all it does is issuing an initial read
		--self._handle:readStart()	-- libuv
		--self:_readImpl()

		-- libuv has readStart(), which continuously reads from a socket
		-- we need to issue another read after each read callback
		-- so proetct from "double reads" (see Socket:resume)
		if not self._handle.reading then
			self._handle.reading = true
			self._handle:read()
		end
	end
end

local function afterShutdown (status, handle, req)
	local self = handle.owner

	assert(self._flags["FLAG_SHUTDOWN"])
	assert(not self.writable)

	-- callback may come after call to destroy
	if self.destroyed then
		return
	end

	if self._flags["FLAG_GOT_EOF"] or not self.readable then
		self:_destroy()
	end
end

-- esta es Socket.end
function Socket:finish (data, encoding)
	if self._connecting and not self._flags["FLAG_SHUTDOWN_QUEUED"] then
		-- still connecting, add data to buffer
		if data then
			self:write(data, encoding)
		end
		self.writable = false
		self._flags["FLAG_SHUTDOWN_QUEUED"] = true
	end

	if not self.writable then return end
	self.writable = false

	if data then self:write(data, encoding) end

	if not self.readable then
		self:destroySoon()
	else
		self._flags["FLAG_SHUTDOWN"] = true
		--[[
		local shutdownReq = self._handle:shutdown("write")

		if not shutdownReq then
			self:_destroy("shutdown")	--this._destroy(errnoException(errno, 'shutdown'));
			return false
		end

		shutdownReq.oncomplete = assert(afterShutdown)
		--]]
		local ok, err_msg, err_code = self._handle:shutdown("write")
		if not ok then
			self:_destroy(err_msg, err_code)
			return false
		end
		self._handle.shutdown_callback = function()
			--local self = handle.owner

			assert(self._flags["FLAG_SHUTDOWN"])
			assert(not self.writable)

			-- callback may come after call to destroy
			if self.destroyed then
				return
			end

			if self._flags["FLAG_GOT_EOF"] or not self.readable then
				self:_destroy()
			end
			--if err_msg then
				--self:emit("error", err_msg, err_code)
				--self:emit("close", err_msg, err_code)
			--else
				--self:emit("close", false)
			--end
			--self._raw_socket = nil
		end
	end
	return true
	--[[
	if self.writable then
		if data then
			self:write(data, encoding)
		end
		if self:_writeQueueLast() ~= END_OF_FILE then
			table.insert(self._writeQueue, END_OF_FILE)
			self._EOF_inserted = true
			if not self._connecting then
				self:flush()
			end
		end
	end
	--]]
end

---
--
function Socket:destroySoon ()
	self.writable = false
	self._flags["FLAG_DESTROY_SOON"] = true

	if self._pendingWriteReqs == 0 then
		self:_destroy()
	end
end

function Socket:_connectQueueCleanUp (err_msg, err_code)
	self._connecting = false
	self._connectQueueSize = 0
	self._connectQueue = nil
end

---
--
function Socket:_destroy (err_msg, err_code, callback)
	local function fireErrorCallbacks()
		if callback then callback(self, err_msg, err_code) end
		if err_msg and not self.errorEmitted then
			process.nextTick(function()
				self:emit("error", err_msg, err_code)
			end)
			self.errorEmitted = true
		end
	end

	if self.destroyed then
		fireErrorCallbacks()
		return
	end

	self:_connectQueueCleanUp()

	LogDebug("destroy")

	self.readable = false
	self.writable = false

	Timers.Unenroll(self)

	LogDebug("close")
	if self._handle then
		self._handle:close()
		self._handle.read_callback = noop
		self._handle = nil
	end

	fireErrorCallbacks()

	process.nextTick(function()
		self:emit("close", err_msg and true or false)
	end)

	self.destroyed = true

	if self.server then
		self.server._connections = self.server._connections - 1
		if self.server._emitCloseIfDrained then
			self.server:_emitCloseIfDrained()
		end
	end
end

--
--
function Socket:destroy (err_msg, err_code)
	self:_destroy(err_msg, err_code)
	--[[
	-- pool is shared between sockets, so don't need to free it here.
	-- TODO would like to set _writeQueue to null to avoid extra object alloc,
	-- but lots of code assumes this._writeQueue is always an array.
	self._writeQueue = {}
	
	self.writable = false
	self.readable = false

	if self._writeWatcher then
		self._writeWatcher:stop()
		--ioWatchers.free(this._writeWatcher)
		self._writeWatcher = nil
	end

	-- TODO: si hay algun pending read, deberia cancelarlo
	--if self._raw_socket then
		--self._raw_socket:stop()
		--ioWatchers.free(this._readWatcher)
		--self._readWatcher = nil
	--end

	Timers.Unenroll(self)

	-- not necessary, asio does it
	--if self.secure then
		--self.secureStream:close()
	--end

	-- TODO: por qué es el socket el que tiene que updatear esto que es del server ?
	if self.server and not self.destroyed then
		self.server._connections = self.server._connections - 1
		
		self.server.clients[self] = nil
	end
	
	-- Issue a close call once (avoids errors with multiple destroy calls)
	-- That is, it IS possible to get multiple destroy calls, see test-http-parser-reuse
	if self._raw_socket then
		-- setup a callback that will be called when the socket is actually closed
		self._raw_socket.close_callback = function()
			if err_msg then
				self:emit("error", err_msg, err_code)
				self:emit("close", err_msg, err_code)
			else
				self:emit("close", false)
			end
			self._raw_socket = nil
		end
		self._raw_socket:close()
	end
	
	self.secureContext = nil	-- todo: why Net does have to deal with this?

	m_opened_sockets[self] = nil

	self.destroyed = true
	--]]
end


function Socket:setSecure(context)
	-- Do we have openssl crypto?
	local SecureContext = process.SecureContext
	--local SecureStream = process.SecureStream
	-- TODO: chequear que haya sido compilado openssl
	local crypto = require("luanode.crypto")
	self.secure = true
	self.secureEstablished = false
	-- If no secure context given, create a new one for just this Stream
	if not context then
		self.secureContext = crypto.createContext()
	else
		self.secureContext = context
	end
	
	-- Determine default value. Don't overwrite this.secureContext because the 
	-- same context might be shared by a client and a server with different 
	-- default values.
	local verifyRemote
	if self.secureContext.verifyRemote == nil then
		-- For clients, default to verify. For servers, default to off.
		verifyRemote = (self.server == nil)
	else
		verifyRemote = self.secureContext.verifyRemote
	end
	--local s = process.SecureSocket(self._raw_socket)
	local oldStream = self._handle
	self._handle = process.SecureSocket(self._handle, self.secureContext, self.server and true or false, verifyRemote)
	-- me copio los callbacks
	self._handle.read_callback = oldStream.read_callback
	self._handle.write_callback = oldStream.write_callback
	self._handle.owner = self
	-- mmm, disgusting...
	self.__old_stream = oldStream
	--self._raw_socket = self
	
	
	self._handle.handshake_callback = function(raw_socket)
		self.secureEstablished = true

		if self._events and self._events.secure then
			self:emit("secure")
		end
		--raw_socket:read()
		self:resume()
		
		-- Flush socket in case any writes are queued up while connecting.
		-- ugly
		--_doFlush(raw_socket, true)
	end

	----P setImplementationMethods(self)

	if not self.server then
		-- If client, trigger handshake
		self:_checkForSecureHandshake()
	end
end

function Socket:verifyPeer()
	assert(self.secure, "Socket is not a secure socket.")
	if not self._handle then
		return false, "Socket is closed."
	end
	return self._handle:verifyPeer(self.secureContext)
end

function Socket:_checkForSecureHandshake()
	if not self.writable then
		return
	end

	-- Do an empty write to see if we need to write out as part of handshake
	self._handle:doHandShake()
	--if not emptyBuffer) allocEmptyBuffer();
	--self:write("")
end

function Socket:getPeerCertificate()
	assert(self.secure, "Socket is not a secure socket.")
	if not self._handle then
		return false, "Socket is closed."
	end
	return self._handle:getPeerCertificate(self.secureContext)
end

function Socket:getCipher()
	error("not implemented")
end

--[[
function Socket:open(fd, kind)
	--initSocket(self)	-- en nodejs alloca un iowatcher para readwatcher
	
	self.fd = fd
	self.type = kind
	self.readable = true
	error("WAT")
	
	----P setImplementationMethods(self)
	
	--self._writeWatcher.set(self.fd, false, true)
	self.writable = true
end
--]]

-- 
-- If there is a pending chunk to be sent, flush it
--[=[
function Socket:flush()
	while self._writeQueue and #self._writeQueue > 0 do
		local data = table.remove(self._writeQueue, 1)
		local encoding = table.remove(self._writeQueueEncoding, 1)
		local fd = table.remove(self._writeQueueFD, 1)
		
		if data == END_OF_FILE then
			self:_shutdown()
			return true
		end
		
		local flushed = self:_writeOut(data, encoding, fd)
		if not flushed then
			return false
		end
	end
	
	if self._writeWatcher then
		self._writeWatcher:stop()
	end
	return true
end
--]=]

-- 
-- Returns the last element in the write queue
--[=[
function Socket:_writeQueueLast()
	return (#self._writeQueue > 0) and self._writeQueue[ #self._writeQueue ] or nil
end
--]=]


--[[
local function doConnect(socket, port, host)
	if socket.destroyed then return end
	
	local ok, err_msg, err_code = socket._handle:connect(host, port)
	if not ok then
		local msg = ("Failed to connect to %s:%d - %s"):format(host, port, err_msg)
		socket:destroy(msg, err_code)
		return
	end
	
	LogDebug("connecting to %s:%d", host, port)
	socket._remoteAddress = host
	socket._remotePort = port

	-- Don't start the read watcher until connection is established
	--socket._readWatcher.set(socket.fd, true, false)
	
	socket._handle.connect_callback = connect_callback
end
--]]

function Socket:_shutdown()
	if not self.writable then
		error("The connection is not writable")
	else
		-- readable and writable
		if self.readable then
			self.writable = false
			
			self:_shutdownImpl()
		else
			-- writable but not readable
			self:destroy()
		end
	end
end

--
--
_M.createConnection = function(...) -- (port, host)
	--[==[
	local newSocket
	-- determine the required socket type
	if type(port) == "string" and not tonumber(port) then
		-- unix path, cagamos
		local path = port
		error("UNIX domain sockets not implemented yet")
	else
		local ip = host or "127.0.0.1"
		local port = tonumber(port)
		-- TODO: fixme: no estoy escuchando en ipv6 !
		if ip:lower() == "localhost" then
			ip = "127.0.0.1"
		end
		dns.lookup(ip, function (err, address, hostname)
			if err then
				self:emit('error', err)
			else
				local kind = (address.family == 6 and "tcp6") or (address.family == 4 and "tcp4") or error("unknown address family" .. tostring(address.family))
				--self._raw_socket = process.Socket(self.kind)
				newSocket = Socket:new( process.Socket(kind), kind )
				newSocket:connect(port, ip)
			end
		end)
		return newSocket
		--[[
		-- TODO: por ahora asumo que es siempre una ip x.x.x.x
		local ip = host or "127.0.0.1"
		local port = tonumber(port)
		assert(port >= 0 and port <= 65535, "port number out of range")
		-- hack
		if ip:lower() == "localhost" then
			ip = "127.0.0.1"
		end
		local is_ip, version = isIP(ip)
		if not is_ip then
			error(version)
		end
		local kind = (version == 6 and "tcp6") or (version == 4 and "tcp4") or error("unknown IP version")
		newSocket = Socket:new( process.Socket(kind), kind )
		newSocket:connect(port, ip)
		return newSocket
		]]
	end
		]==]
	--local socket = Socket()
	--socket:connect(port, host)
	--return socket
	
	--local socket = Socket()
	--socket:connect({ port = port, host = host })
	--return socket
	
	local args, cb = normalizeConnectArgs(...)
	local s = Socket()	-- args[0]
	return s:connect(args, cb)
end

_M.connect = _M.createConnection



-- Server Class
local Server = Class.InheritsFrom(EventEmitter)
_M.Server = Server

-- Last time we've issued a EMFILE warning
local lastEMFILEWarning = 0

function Server:__init (options, listener)
	local newServer = Class.construct(Server)
	
	if type(options) == "function" then
		listener = options
		options = {}
	else
		options = options or {}
	end
	if type(listener) == "function" then
		newServer:on("connection", listener)
	end
	
	newServer.clients = {}
	
	newServer._connections = 0
	
	newServer.allowHalfOpen = not not options.allowHalfOpen --or false
	newServer._handle = nil
	
	return newServer
end

function Server:connections ()
	-- TODO: usar MT para resolver como una property
	return self._connections
end

local function createServerHandle (address, port, addressType, fd)

	-- assign handle in listen, and clean up if bind or listen fails
	local handle

	if type(fd) == "number" and fd >= 0 then
		local fd_type = process.guess_handle_type(fd)
		if fd_type == "PIPE" then
			LogDebug("listen pipe fd=%d", fd)
			error("pipes are not supported yet")
			return
		else
			-- Not a fd we can listen on.  This will trigger an error.
			LogDebug("listen invalid fd=%d type=%s", fd, fd_type)
			handle = nil
			error("EINVAL")	-- TODO: fix this
		end
	
	elseif port == -1 and addressType == -1 then
		error("pipes are not supported yet")
	else
		handle = process.Acceptor()
	end

	if address or port then
		LogDebug("Bind to %s", address)
		local type = (addressType == 6 and "tcp6") or (addressType == 4 and "tcp4") or error("unknown IP version")
		handle:open(type)
		local ok, err, msg = bind(handle, port, address)
		if not ok then
			handle:close()
			handle = nil
			return false, err, msg
		end
	end

	return handle
end

--
--
_M.createServer = function(options, callback)
	return Server(options, callback)
end

local function listen (self, address, port, addressType, backlog, fd)
	self:_listen2(address, port, addressType, backlog, fd)
end

-- 
-- server.listen (port, [host], [callback])
-- Begin accepting connections on the specified port and host. If the host is omitted, the server will accept 
-- connections directed to any IPv4 address (INADDR_ANY).
-- This function is asynchronous. The last parameter callback will be called when the server has been bound.
function Server:listen (port, host, callback)
	LogDebug("Server:listen %s, %s, %s", port, host, callback)
	
	if type(host) == "function" and not callback then
		callback = host
		host = nil
	end
	if type(callback) == "function" then
		self:once("listening", callback)
	end

	
	if type(port) == "string" and not tonumber(port) then
		-- unix path, cagamos
		local path = port
		error("UNIX domain sockets not implemented yet")
	elseif not port then
		-- Don't bind(). OS will assign a port with INADDR_ANY.
		-- The port can be found with server.address()
		--self.type = "tcp4"
		--self.acceptor:open(self.type)
		--self:_doListen(port, ip)
		listen(self, '0.0.0.0', 0, nil, backlog)
	else
		local ip = host or "0.0.0.0"
		local port = tonumber(port)
		assert(port >= 0 and port <= 65535, "port number out of range")
		if ip:lower() == "localhost" then
			ip = "127.0.0.1"
		end
		require("luanode.dns").lookup(ip, function (err, address, hostname)
			if err then
				self:emit("error", err)
			else
				listen(self, address.address, port, address.family, 128)
				--self.kind = (address.family == 6 and "tcp6") or (address.family == 4 and "tcp4") or error("unknown address family" .. tostring(address.family))
				--self.acceptor:open(self.kind)
				--self:_doListen(port, ip)
			end
		end)
	end

	return self
end

---
--
function Server:_listen2 (address, port, addressType, backlog, fd)

	if not self._handle then
		local err_msg, err_code
		self._handle, err_msg, err_code = createServerHandle(address, port, addressType, fd)
		if not self._handle then
			process.nextTick(function()
				self:emit("error", err_msg, err_code)
			end)
			return
		end
	end

	self._handle.owner = self
	--self._handle.callback = onconnection
	-- TODO: the callback must pass self
	self._handle.callback = function(err, peer)	-- self must be the handle

		LogDebug("onconnection")
		if err then
			-- an error occurred. If it is EMFILE try to deal with it
			-- If it is ENCANCELED, ignore it
			local err_code = peer
			if err_code == process.constants.ECANCELED then
				return

			elseif err_code == process.constants.EMFILE then
				local now = os.time()
				if now - lastEMFILEWarning > 5 then
					console.error([[(LuaNode) Hit max file limit. Increase "ulimit -n"]])
					lastEMFILEWarning = now
				end
				setTimeout(function()
					-- try to accept another connection (unless the server was explicitly closed)
					if self._handle then	-- self is server
						self._handle:accept()
					end
				end, 1000)
				
			else
				self:emit("error", err, err_code)
			end
			return
		end

		local handle = self._handle
		local server = self._handle.owner

		if server.maxConnections and server._connections >= server.maxConnections then
			peer.socket:close()
			handle:accept()
			return
		end

		local socket = Socket({ handle = peer.socket, allowHalfOpen = server.allowHalfOpen })
		--local socket = Socket(peer.socket, addressType) -- esto cambia luego
		--socket:open(peer.socket, addressType)	-- esto cambia luego
		socket.readable = true
		socket.writable = true

		socket._remoteAddress = peer.address
		socket._remotePort = peer.port

		--peer:readStart()

		server._connections = server._connections + 1
		socket.server = server

		server:emit("connection", socket)
		socket:emit("connect")

		if not socket.destroyed then
			if socket.secure then
				socket._handle:doHandShake()
			else
				socket:resume()
			end
		end

		-- accept another connection (unless the server was explicitly closed)
		if server._handle then
			server._handle:accept()
		end
	end

	-- Use a backlog of 512 entries. We pass 511 to the listen() call because
	-- the kernel does: backlogsize = roundup_pow_of_two(backlogsize + 1);
	-- which will thus give us a backlog of 512 entries.
	local ok, err_msg, err_code = self._handle:listen(backlog or 511)
	if not ok then
		self._handle:close()
		self._handle = nil
		process.nextTick(function()
			self:emit("error", err_msg, err_code)
		end)
		return
	end

	-- generate connection key, this should be unique to the connection
	self._connectionKey = addressType .. ":" .. address .. ":" .. port

	process.nextTick(function()
		self._handle:accept()
		self:emit("listening")
	end)
end

--[[
function Server:_doListen(port, ip)
	local ok, err_msg, err_code = bind(self.acceptor, port, ip)
	if not ok then
		self:emit("error", err_msg, err_code)
		return false
	end
	process.nextTick(function()
		if not self.acceptor then
			-- was closed before started listening?
			return
		end
		-- It could be that server.close() was called between the time the
		-- original listen command was issued and this. Bail if that's the case.
		-- See test/simple/test-net-eaddrinuse.js
		local ok, err_msg, err_code = self.acceptor:listen(self._backlog or 128)	-- el backlog
		if not ok then
			self:emit("error", err_msg, err_code)
			--error( console.error("listen() failed with error: %s", err) )
			return
		end

		self:_startWatcher()
	end)
end
--]]

--[[
function Server:_startWatcher()
	--this.watcher.set(this.fd, true, false)
	--this.watcher.start()
	--this.emit("listening")
	self.acceptor:accept()
	self:emit("listening")
end
--]]

-- returns the address and port of the server
function Server:address ()
	if self._handle and self._handle.getsockname then
		return self._handle:getsockname()
	elseif self._pipeName then
		return self._pipeName
	else
		return nil
	end
end

---
--
function Server:close (callback)
	if not self._handle then
		error('Not running')
	end

	if callback then
		self:once("close", callback)
	end

	self._handle:close()
	self._handle = nil
	self:_emitCloseIfDrained()
	
	--[[
	if self.type == "unix" then
		fs.unlink(self.path, function ()
			self:emit("close")
		end)
	else
		self:emit("close")
	end
	--]]
	return self
end

---
--
function Server:_emitCloseIfDrained ()
	if self._handle or self._connections then return end

	process.nextTick(function()
		self:emit("close")
	end)
end







--[[
function new()
	local t = setmetatable({}, { __index = _M })
	return t
end
--]]

return _M
