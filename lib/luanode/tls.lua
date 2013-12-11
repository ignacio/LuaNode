local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"
local luanode_stream = require "luanode.stream"
local Timers = require "luanode.timers"
local Utils = require "luanode.utils"
local Crypto = require "luanode.crypto"
local Net = require "luanode.net"
local assert = assert
local function noop() end

-- TODO: avoid duplicating code between this and net.Socket

local _M = {
	_NAME = "luanode.tls",
	_PACKAGE = "luanode."
}

-- Make LuaNode 'public' modules available as globals.
luanode.tls = _M

local SecureContext = process.SecureContext
local SecureSocket = process.SecureSocket

-- forward references
local initSocketHandle
local setSecure

local function isPipeName (s)
	return type(s) == "string" and not tonumber(s)
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

-- Socket Class
--local Socket = Class.InheritsFrom(luanode_stream.Stream)
local Socket = Class.InheritsFrom(Net.Socket)
_M.Socket = Socket

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
--[[
function Socket:setEncoding (encoding)
	--error("not implemented")
	-- como que acá en Lua no aplica mucho esto
end
--]]

--[[
function Socket:remoteAddress ()
	return self._remoteAddress, self._remotePort
end
--]]

--- 
-- 
--[[
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
end
--]]

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
	end

	self._pendingWriteReqs = self._pendingWriteReqs - 1
	if self._pendingWriteReqs == 0 then
		self:emit("drain")
	end

	if self._pendingWriteReqs == 0 and self._flags["FLAG_DESTROY_SOON"] then
		self:_destroy()
	end

end

--[=[
function Socket:_write (data, encoding, cb)
	Timers.Active(self)

	if not self._handle then
		self:_destroy( error("This socket is closed"), cb )
		return false
	end

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
		
		-- Determine default value. Don't overwrite this.secureContext because the 
		-- same context might be shared by a client and a server with different 
		-- default values.
		local verifyRemote
		if socket.secureContext.verifyRemote == nil then
			-- For clients, default to verify. For servers, default to off.
			verifyRemote = (socket.server == nil)
		else
			verifyRemote = socket.secureContext.verifyRemote
		end
		
		Timers.Active(socket)
		
		setSecure(socket)

		--local ok, err, err_code = pcall(socket.emit, socket, "connect")
		--if not ok then
			--socket:destroy(err, err_code)
			--return
		--end

		if socket._flags["FLAG_SHUTDOWN_QUEUED"] then
			-- end called before connected - call end now with no data
			socket._flags["FLAG_SHUTDOWN_QUEUED"] = nil
			socket.writable = true
			socket:finish()
			return
		end

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

	--local connectReq
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
end

-- var socket = new Socket()
-- socket.connect(443)               - TCP connect to port 442 on the localhost
-- socket.connect(443, 'nodejs.org') - TCP connect to port 443 on nodejs.org
-- socket.connect('/tmp/socket')     - UNIX connect to socket specified by path

-- ojo! Http crea el stream y entra derecho por acá, no llama a net.createConnection
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
		self:once("secureConnect", callback)
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
			end
		end)
	end

	return self
end

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
	
	newSocket.secure = true
	newSocket.secureEstablished = false
	if not options.context then
		newSocket.secureContext = Crypto.createContext()
	else
		newSocket.secureContext = options.context
	end

	return newSocket
end

--[[
function Socket:listen (cb)
	self:on("connection", cb)
	listen(self)
end
--]]

--[[
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
--]]

--[[
function Socket:_onTimeout ()
	LogDebug("_onTimeout")
	self:emit("timeout")
end
--]]

--[[
function Socket:setNoDelay (v)
	-- backwards compatibility: assume true when 'v' is omitted
	if self._handle and self._handle.setoption then
		v = not not v
		self._handle:setoption("nodelay", v)
	end
end
--]]

--[[
function Socket:setKeepAlive (enable, time, interval)
	if self._handle and self._handle.setoption then
		self._handle:setoption("keepalive", enable, time, interval)
	end
end
--]]

--[[
function Socket:address ()
	if self._handle and self._handle.getsockname then
		return self._handle:getsockname()
	end
	return nil
end
--]]

--[[
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
--]]

--[[
function Socket:bufferSize ()
	if self._handle then
		return self._handle.writeQueueSize + self._connectQueueSize
	end
end
--]]

--[[
function Socket:pause ()
	self._paused = true
	if self._handle and not self._connecting then
		--self._handle:readStop()
		-- we just set a flag and don't issue a read
	end
end
--]]

---
-- At the moment, just issue an async read (if no read was already been made)
--[[
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
--]]

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
--[=[
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
end
--]=]

---
--
--[[
function Socket:destroySoon ()
	self.writable = false
	self._flags["FLAG_DESTROY_SOON"] = true

	if self._pendingWriteReqs == 0 then
		self:_destroy()
	end
end
--]]

--[[
function Socket:_connectQueueCleanUp (err_msg, err_code)
	self._connecting = false
	self._connectQueueSize = 0
	self._connectQueue = nil
end
--]]

---
--
--[[
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
--]]

--
--
--[[
function Socket:destroy (err_msg, err_code)
	self:_destroy(err_msg, err_code)
end
--]]


-- Private
setSecure = function (self, context)

	-- We need a socket here in order to make it secure
	if not self._handle then
		error("Socket is closed.")
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
	
	
	self._handle.handshake_callback = function(raw_socket)
		self.secureEstablished = true

		if self._events and self._events.secureConnect then
			self:emit("secureConnect")
		end

		if self._connectQueue then
			-- when the ssl handshake is done we can send the data
			drainConnectQueue(self)
		end

		self:resume()
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
--]]

_M.connect = function (...) -- (port, host, options, callback)
	local args, cb = normalizeConnectArgs(...)
	local s = Socket()
	return s:connect(args, cb)
end



-- Socket Class
local Server = Class.InheritsFrom(Net.Server)
-- public
_M.Server = Server

function Server:__init (options, listener)
	local newServer, sharedCreds
	
	-- create a server and supply a function to create sockets
	
	newServer = Class.construct(Server, {
		allowHalfOpen = options.allowHalfOpen,
		createConnection = function(options)
			local opts = {}
			for k,v in pairs(options) do opts[k] = v end
			opts.context = sharedCreds
			return Socket(opts)
		end
	})

	newServer._contexts = {}

	-- Handle option defaults
	newServer:setOptions(options)

	if not newServer.pfx and (not newServer.cert or not newServer.key) then
		error("Missing PFX or certificate plus private key")
	end

	--local sharedCreds = Crypto.createCredentials{
	sharedCreds = Crypto.createContext{
		pfx = newServer.pfx,
		key = newServer.key,
		passphrase = newServer.passphrase,
		cert = newServer.cert,
		ca = newServer.ca,
		ciphers = newServer.ciphers or DEFAULT_CIPHERS,
		secureProtocol = newServer.secureProtocol,
		secureOptions = newServer.secureOptions,
		crl = newServer.crl,
		sessionIdContext = newServer.sessionIdContext
	}

	local timeout = options.handshakeTimeout or (120 * 1000)
	assert(type(timeout) == "number", "handshakeTimeout must be a number")

	newServer:on("connection", function(self, socket)
		setSecure(socket)
		socket:_checkForSecureHandshake()
		
		-- once the connection has been handshaken, emit the secureConnection event
		socket:on("secureConnect", function(socket)
			newServer:emit("secureConnection")
		end)
	end)

	if listener then
		newServer:on("secureConnection", listener)
	end

	return newServer
end


function Server:setOptions (options)
	if type(options.requestCert) == "boolean" then
		self.requestCert = options.requestCert
	else
		self.requestCert = false
	end

	if type(options.rejectUnauthorized) == "boolean" then
		self.rejectUnauthorized = options.rejectUnauthorized
	else
		self.rejectUnauthorized = false
	end

	if options.pfx then self.pfx = options.pfx end
	if options.key then self.key = options.key end
	if options.passphrase then self.passphrase = options.passphrase end
	if options.cert then self.cert = options.cert end
	if options.ca then self.ca = options.ca end
	if options.secureProtocol then self.secureProtocol = options.secureProtocol end
	if options.crl then self.crl = options.crl end
	if options.ciphers then self.ciphers = options.ciphers end

	if options.sessionIdContext then
		self.sessionIdContext = options.sessionIdContext
	else
		self.sessionIdContext = Crypto.createHash("md5"):update( table.concat(process.argv) ):final("hex")
	end
end

-- public
_M.createServer = function(options, listener)
	return Server(options, listener)
end



return _M
