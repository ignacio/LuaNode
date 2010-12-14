--local util = require "util"		--var util = require("util");
local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"
local stream = require "luanode.stream"
local Timers = require "luanode.timers"

-- TODO: arreglar el despelote de los fd's

-- TODO: sacar el seeall
module(..., package.seeall)

local dns = require "luanode.dns"		-- var dns = require("dns");

local kMinPoolSpace = 128
local kPoolSize = 40 * 1024

--local Buffer = require "buffer"
local FreeList = require "luanode.free_list"

local Net = require "Net"--process.Net

local IOWatcher   = process.IOWatcher
local assert      = assert

--[=[
local socket      = binding.socket;
local bind        = binding.bind;
local connect     = binding.connect;
local listen      = binding.listen;
local accept      = binding.accept;
local close       = binding.close;
local shutdown    = binding.shutdown;
local read        = binding.read;
local write       = binding.write;
local toRead      = binding.toRead;
local setNoDelay  = binding.setNoDelay;
local setKeepAlive= binding.setKeepAlive;
local socketError = binding.socketError;
local getsockname = binding.getsockname;
local errnoException = binding.errnoException;
local sendMsg     = binding.sendMsg;
local recvMsg     = binding.recvMsg;
local EINPROGRESS = binding.EINPROGRESS;
local ENOENT      = binding.ENOENT;
local EMFILE      = binding.EMFILE;
local END_OF_FILE = 42;
--]=]
local END_OF_FILE = {}

-- Do we have openssl crypto?
local SecureContext = process.SecureContext
local SecureStream = process.SecureStream
local have_crypto = (SecureContext and SecureStream and true) or false

--
-- Public:
isIP = Net.isIP

function isIPv4(input)
	local isIP, kind = Net.isIP(input)
	if isIP and kind == 4 then
		return true
	end
	return false
end

function isIPv6(input)
	local isIP, kind = Net.isIP(input)
	if isIP and kind == 6 then
		return true
	end
	return false
end

local function toPort(x)
	local num = tonumber(x)
	if num and num >= 0 then return x else return false end
	--return (x = Number(x)) >= 0 ? x : false
end

-- esta venia de Node, a ver si la puedo reimplementar con luasocket ??
-- kind = tcp, tcp4, tcp6, unix, unix_dgram, udp, udp4, udp6
local function socket(kind)
	local skt = assert(process.Socket(kind))
	return skt
end

--
-- Creates an Acceptor, that is, a socket that can listen
local function acceptor(kind)
	local skt = assert(process.Acceptor(kind))
	return skt
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
	local ok, err, msg = socket:bind(ip, port)
	if not ok then
		console.error("bind('%s', '%s', '%s') failed with error: %s\r\n%s", socket, port, ip, err, msg)
		return false, err, msg
	end
	return true	-- TODO: homogeneizar el manejo de errores
end


-- Stream Class
Stream = Class.InheritsFrom(stream.Stream)

-- FIXME: tengo que guardar las conexiones en algun lado. Y eventualmente las tengo que sacar
local m_opened_streams = {}

local function setImplmentationMethods(self)
	if self.type == "unix" then
		error("not yet implemented")
	else
		self._writeImpl = function(self, buf, off, len, fd, flags)
			return self._stream:write(buf, off, len)
		end
		
		self._readImpl = function(self, buf, off, len, calledByIOWatcher)
			return self._stream:read(buf, off, len)
		end
	end
	
	self._shutdownImpl = function()
		self._stream:shutdown("write")
	end
	
	--[====[
	if self.secure then
		local oldWrite = self._writeImpl
		self._writeImpl = function(self, buf, off, len, fd, flags)
			self._stream:write(buf)
			--[[
			assert(buf)
			assert(self.secure)
			local bytesWritten = self.secureStream:clearIn(buf, off, len)
			
			if not securePool then
				allocNewSecurePool()
			end
			
			local secureLen = self.secureStream:encOut(securePool, 0, #securePool)
			if secureLen == -1 then
				-- Check our read again for secure handshake
				self._readWatcher.callback()
			else
				oldWrite(securePool, 0, secureLen, fd, flags)
			end
			
			if not self.secureEstablished and self.secureStream:isInitFinished() then
				self.secureEstablished = true

				if self._events and self._events.secure then
					self:emit("secure")
				end
			end
			
			return bytesWritten
			]]
		end
		
		local oldRead = self._readImpl
		self._readImpl = function (self, buf, off, len, calledByIOWatcher)
			assert(self.secure)

			local bytesRead = 0
			local secureBytesRead

			if not securePool then
				allocNewSecurePool()
			end

			if calledByIOWatcher then
				secureBytesRead = oldRead(securePool, 0, securePool.length)
				self.secureStream:encIn(securePool, 0, secureBytesRead)
			end

			local chunkBytes
			while ((chunkBytes > 0) and (pool.used + bytesRead < pool.length)) do
				chunkBytes = self.secureStream:clearOut(pool,
										pool.used + bytesRead,
										pool.length - pool.used - bytesRead)
				bytesRead = bytesRead + chunkBytes
			--while ((chunkBytes > 0) and (pool.used + bytesRead < pool.length))
			end

			if bytesRead == 0 and not calledByIOWatcher then
				return -1
			end

			if self.secureStream:clearPending() then
				process.nextTick(function ()
					if self._readWatcher then
						self._readWatcher.callback()
					end
				end)
			end

			if not self.secureEstablished then
				if self.secureStream.isInitFinished() then
					self.secureEstablished = true
					if self._events and self._events.secure then
						self:emit("secure")
					end
				end
			end

			if calledByIOWatcher and secureBytesRead == nil and not self.server then
				-- Client needs to write as part of handshake
				self._writeWatcher.start();
				return -1
			end

			if bytesRead == 0 and secureBytesRead > 0 then
				-- Deal with SSL handshake
				if self.server then
					self:_checkForSecureHandshake()
				else
					if self.secureEstablised then
						self:flush()
					else
						self:_checkForSecureHandshake()
					end
				end

				return -1
			end

			return bytesRead
		end
		
		local oldShutdown = self._shutdownImpl
		self._shutdownImpl = function ()
			self.secureStream:shutdown()

			if not securePool then
				allocNewSecurePool()
			end

			local len = self.secureStream:encOut(securePool, 0, securePool.length)

			--try {
				self:oldWrite(securePool, 0, len)
			--} catch (e) { }

			self:oldShutdown()
		end
	end
	--]====]
end

function Stream:__init(fd, kind)
	-- http.Client llama acá sin socket. Conecta luego.
	local newStream = Class.construct(self)
	
	newStream.fd = nil
	newStream.kind = kind
	newStream.secure = false
	newStream._EOF_inserted = false	-- signals when we called 'finish' on the stream
									-- but the underlying socket is not closed yet
	
	setImplmentationMethods(newStream)
	
	m_opened_streams[newStream] = newStream
	
	--[[
	if not fd then
		-- I don't know which type of stream yet
		-- to be determined later
		return newStream
	end
	--]]
	
	if getmetatable(fd) == process.Socket then
		-- TODO: chequear que no este causando algo que no se lo pueda llevar el gc
		--fd.owner = newStream
		fd._stream = newStream
		newStream._stream = fd
		--newStream:open(fd, kind)	-- esto se hace mas adelante
		return newStream
	end
	
	if tonumber(fd or 0) > 0 then
		--newStream:open(fd, kind)
	else
		setImplmentationMethods(newStream)	-- ojo con el typo :D
	end
	
	return newStream
end


function Stream:setSecure(context)
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
		verifyRemote = (self.server ~= nil)
	else
		verifyRemote = self.secureContext.verifyRemote
	end
	--local s = process.SecureSocket(self._stream)
	local oldStream = self._stream
	self._stream = process.SecureSocket(self._stream, self.secureContext, self.server and true or false, verifyRemote)
	-- me copio los callbacks
	self._stream.read_callback = oldStream.read_callback
	self._stream.write_callback = oldStream.write_callback
	self._stream._stream = self
	-- mmm, disgusting...
	self.__old_stream = oldStream
	--self._stream = self
	
	
	self._stream.handshake_callback = function(stream)
		self.secureEstablished = true

		if self._events and self._events.secure then
			self:emit("secure")
		end
		stream:read()
	end

	setImplmentationMethods(self)

	if not self.server then
		-- If client, trigger handshake
		self:_checkForSecureHandshake()
	end
end

function Stream:verifyPeer()
	assert(self.secure, "Stream is not a secure stream.")
	return self._stream:verifyPeer(self.secureContext)
end

function Stream:_checkForSecureHandshake()
	if not self.writable then
		return
	end

	-- Do an empty write to see if we need to write out as part of handshake
	self._stream:doHandShake()
	--if not emptyBuffer) allocEmptyBuffer();
	--self:write("")
end

function Stream:getPeerCertificate()
	assert(self.secure, "Stream is not a secure stream.")
	return self._stream:getPeerCertificate(self.secureContext)
end

function Stream:getCipher()
	error("not implemented")
end

-- paso socket o stream
local function _doFlush(socket, stream)
	--local stream = server._stream
	-- Stream becomes writable on connect() but don't flush if there's
	-- nothing actually to write
	-- hack, lo tendria que mandar ya yo como un stream? (la tabla stream)
	if not stream then
		stream = socket._stream
	end
	if stream then
		if stream:flush() then
			if stream._events and stream._events["drain"] then
				stream:emit("drain")
			end
			if stream.ondrain then
				stream:ondrain() -- Optimization
			end
		end
	end
end

local function initStream(self)
	self.readable = false
	
	-- en lugar de usar _readWatcher, recibo los eventos de read en _stream.read_callback
	--self._readWatcher = {}
	--self._readWatcher.callback = function()
	
	-- @param stream is the socket
	-- @param data is the data that has been read or nil if the socket has been closed
	-- @param reason is present when the socket is closed, with the reason
	self._stream.read_callback = function(stream, data, reason)
		if not data or #data == 0 then
			self.readable = false
			--if reason == "eof" or reason == "closed" or reason == "aborted" or reason == "reset" then
				if not self.writable then
					self:destroy()
					-- note: 'close' not emitted until nextTick
				end
				self:emit("end")
				if type(self.onend) == "function" then
					self:onend()
				end
			--end
		elseif #data > 0 then
			if self._stream then	-- the stream may have been closed on Stream.destroy
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
			if self._stream and not self._dont_read then	-- the stream may have been closed on Stream.destroy
				--self._stream:read()	-- issue another async read
				self:_readImpl()
			end
		end
	end
	
	-- Queue of buffers and string that need to be written to socket.
	self._writeQueue = {}
	self._writeQueueEncoding = {}
	self._writeQueueFD = {}

	--self._writeWatcher = ioWatchers.alloc()
	--self._writeWatcher.socket = self
	--self._writeWatcher.callback = _doFlush
	
	-- en lugar de usar _writeWatcher, recibo los eventos de write en _stream.write_callback
	self.writable = false
	self._stream.write_callback = _doFlush
end

function Stream:open(fd, kind)
	initStream(self)	-- en nodejs alloca un iowatcher para readwatcher
	
	self.fd = fd
	self.type = kind
	self.readable = true
	
	setImplmentationMethods(self)
	
	--self._writeWatcher.set(self.fd, false, true)
	self.writable = true
end

function Stream:readyState()
	if self._connecting then
		return "opening"
	elseif self.readable and (self.writable and not self._EOF_inserted) then
		--assert(type(self.fd) == "number")	-- en nodejs no estan comentados
		return "open"
	elseif self.readable and (not self.writable or self._EOF_inserted) then
		--assert(type(self.fd) == "number")
		return "readOnly"
	elseif not self.readable and self.writable then
		--assert(type(self.fd) == "number")
		return "writeOnly"
	else
		--assert(type(self.fd) == "number")
		return "closed"
	end
end

-- 
-- 
function Stream:write(data, encoding, fd)
	if self._connecting or (self._writeQueue and #self._writeQueue > 0) then
		if not self._writeQueue then
			self._writeQueue = {}
			self._writeQueueEncoding = {}
			self._writeQueueFD = {}
		end
		-- Slow. There is already a write queue, so let's append to it.
		if self:_writeQueueLast() == END_OF_FILE then
			error('Stream:finish() called already; cannot write.')
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
end

-- 
-- 
function Stream:_writeOut(data, encoding, fd)
	--error("not implemented")
	if not self.writable then
		error("Stream is not writable")
	end
	-- por ahora, escribo derecho
	--self._stream:write(data)
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

-- 
-- If there is a pending chunk to be sent, flush it
function Stream:flush()
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

-- 
-- Returns the last element in the write queue
function Stream:_writeQueueLast()
	return (#self._writeQueue > 0) and self._writeQueue[ #self._writeQueue ] or nil
end

-- 
-- 
function Stream:setEncoding(encoding)
	--error("not implemented")
	-- como que acá en Lua no aplica mucho esto
end

local function doConnect(stream, port, host)
	local ok, err = stream._stream:connect(host, port)
	if not ok then
		stream:destroy(err)
		return
	end
	
	LogDebug("connecting to %s:%d", host, port)

	-- Don't start the read watcher until connection is established
	--socket._readWatcher.set(socket.fd, true, false)
	
	stream._stream.connect_callback = function(socket, ok, err)
		stream._stream.connect_callback = nil
		if ok then
			stream._connecting = false
			--stream:resume()
			stream.readable = true
			stream.writable = true
			stream._stream.write_callback = _doFlush
			local ok, err = pcall(stream.emit, stream, "connect")
			if not ok then
				stream:destroy(err)
			end
			
			if stream._writeQueue and #stream._writeQueue > 0 then
				-- Flush socket in case any writes are queued up while connecting.
				-- ugly
				_doFlush(nil, stream)
			end
			-- only do an initial read if the stream is not secure (we need to wait till the handshake is done)
			if stream.readable and not stream.secure then
				stream:resume()
			end
			return
		else
			stream:destroy(err)
		end
	end
end

-- var stream = new Stream()
-- stream.connect(80)               - TCP connect to port 80 on the localhost
-- stream.connect(80, 'nodejs.org') - TCP connect to port 80 on nodejs.org
-- stream.connect('/tmp/socket')    - UNIX connect to socket specified by path

-- ojo! Http crea el stream y entra derecho por acá, no llama a net.createConnection
function Stream:connect(port, host)
	if self.fd then error("Stream already opened") end
	--if not self._stream.read_callback then error("No read_callback") end
	
	Timers.Active(self)	-- ver cómo
	self._connecting = true	--set false in doConnect
	self.writable = true
	if type(port) == "string" and not tonumber(port) then
		--unix path, cagamos
		local path = port
		error("UNIX domain sockets not implemented yet")
		self.fd = socket("unix")
		self.type = "unix"
		
		setImplmentationMethods(self)
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
					self._stream = process.Socket(self.kind)
					self._stream._stream = self
					initStream(self)
					if not self._stream.read_callback then error("No read_callback") end
					doConnect(self, port, address.address)
				end
			end)
		--]]
		--[[
		-- if no underlying socket was created, do it now
		if not self._stream then
			if ip:lower() == "localhost" then
				ip = "127.0.0.1"
			end
			local is_ip, version = isIP(ip)
			if not is_ip then
				error(version)
			end
			self.kind = (version == 6 and "tcp6") or (version == 4 and "tcp4") or error("unknown IP version")
			self._stream = process.Socket(self.kind)
		end
		initStream(self)
		if not self._stream.read_callback then error("No read_callback") end
		doConnect(self, port, ip)
		--]]
	end
end

function Stream:address()
	return self._stream:getsockname()
end

function Stream:remoteAddress()
	return self._stream:getpeername()
end

function Stream:setNoDelay(v)
	self._stream:setoption("nodelay", v)
end

function Stream:setKeepAlive(enable, time, interval)
	self._stream:setoption("keepalive", enable, time, interval)
end

function Stream:setTimeout(msecs)
	if msecs > 0 then
		Timers.Enroll(self, msecs)
		if self._stream then
			Timers.Active(self)
		end
	elseif msecs == 0 then
		Timers.Unenroll(self)
	end
end

function Stream:pause()
	error("not implemented")
	-- maybe just set a flag and don't issue a read
end

--
-- At the moment, just issue an async read
function Stream:resume()
	if not self._stream then
		error("Cannot resume() closed Stream.")
	end
	-- all it does is issuing an initial read
	self:_readImpl()
	--self._stream:read()
	
--self._readWatcher.
	--if (this.fd === null) throw new Error('Cannot resume() closed Stream.')
	--this._readWatcher.set(this.fd, true, false)
	--this._readWatcher.start()
end

--
--
function Stream:destroy (exception)
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
	--if self._stream then
		--self._stream:stop()
		--ioWatchers.free(this._readWatcher)
		--self._readWatcher = nil
	--end

	Timers.Unenroll(self)

	-- not necessary, asio does it
	--if self.secure then
		--self.secureStream:close()
	--end

	-- TODO: por qué es el stream el que tiene que updatear esto que es del server ?
	if self.server then
		self.server.connections = self.server.connections - 1
		
		self.server.clients[self] = nil
	end
	
	-- No puedo cerrar enseguida ?
	if self._stream then
		self._stream:close()
		self._stream = nil
		m_opened_streams[self] = nil
		process.nextTick(function()
			if exception then self:emit("error", exception) end
			self:emit("close", exception and true or false)
			--self.server.clients[self] = nil
		end)
	end
end

function Stream:_shutdown()
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

-- esta es Stream.end
function Stream:finish(data, encoding)
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
end

function Stream:_onTimeout ()
	self:emit("timeout")
end

--
--
createConnection = function(port, host)
	--[==[
	local newStream
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
				--self._stream = process.Socket(self.kind)
				newStream = Stream:new( process.Socket(kind), kind )
				newStream:connect(port, ip)
			end
		end)
		return newStream
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
		newStream = Stream:new( process.Socket(kind), kind )
		newStream:connect(port, ip)
		return newStream
		]]
	end
		]==]
	local newStream = Stream()
	newStream:connect(port, host)
	return newStream
end



-- Server Class
Server = Class.InheritsFrom(EventEmitter)

function Server:__init(listener)
	local newServer = Class.construct(self)
	
	if listener then
		newServer:addListener("connection", listener)
	end
	
	newServer.clients = {}
	
	newServer.connections = 0
	
	newServer.acceptor = process.Acceptor()
	newServer.acceptor.host = newServer	-- TODO: checkear! ojo que acá estoy creando un ciclo... Net no se destruye hasta que no se destruya este server
	newServer.acceptor.callback = function(peer)
		if newServer.maxConnections and newServer.connections >= newServer.maxConnections then
			peer.socket:close()
			if newServer.acceptor then
				newServer.acceptor:accept()
			end
			return
		end
		
		newServer.connections = newServer.connections + 1
		local s = Stream(peer.socket, newServer.type)
		s:open(peer.socket, newServer.type) --newServer:open(fd, kind)
		--s.remoteAddress = peer.address
		s.remotePort = peer.port
		s.server = newServer
		newServer.clients[s] = s
		
		newServer:emit("connection", s)	-- termina invocando a "listener"
		
		-- The 'connect' event  probably should be removed for server-side
		-- sockets. It's redundant.
		--try {
			s:emit("connect")
		--} catch (e) {
			--s.destroy(e)
			--return
		--}
		
		if s.secure then
			s._stream:doHandShake()
		else
			s:resume()
		end
		
		-- accept another connection (unles the server was explicitly closed)
		if newServer.acceptor then
			newServer.acceptor:accept()
		end
	end
	
	return newServer
end

--
--
createServer = function(listener)
	return Server(listener)
end

-- 
-- server.listen (port, [host], [callback])
-- Begin accepting connections on the specified port and host. If the host is omitted, the server will accept 
-- connections directed to any IPv4 address (INADDR_ANY).
-- This function is asynchronous. The last parameter callback will be called when the server has been bound.
function Server:listen (port, host, callback)
	LogDebug("Server:listen %s, %s, %s", port, host, callback)
	
	if self.fd then
		error("Server already opened")
	end
	
	if type(host) == "function" and not callback then
		callback = host
		host = nil
	end
	if type(callback) == "function" then
		self:addListener("listening", callback)
	end

	
	if type(port) == "string" and not tonumber(port) then
		-- unix path, cagamos
		local path = port
		error("UNIX domain sockets not implemented yet")
	elseif not port then
		-- Don't bind(). OS will assign a port with INADDR_ANY.
		-- The port can be found with server.address()
		self.type = "tcp4"
		self.acceptor:open(self.type)
		self:_doListen(port, ip)
	else
		local ip = host or "0.0.0.0"
		local port = tonumber(port)
		assert(port >= 0 and port <= 65535, "port number out of range")
		if ip:lower() == "localhost" then
			ip = "127.0.0.1"
		end
		dns.lookup(ip, function (err, address, hostname)
			if err then
				self:emit('error', err)
			else
				self.kind = (address.family == 6 and "tcp6") or (address.family == 4 and "tcp4") or error("unknown address family" .. tostring(address.family))
				self.acceptor:open(self.kind)
				self:_doListen(port, ip)
			end
		end)
		--[[
		dns.lookup(arguments[1], function (err, ip, addressType) {
			if (err) {
				self.emit("error", err)
			} else {
				self.type = addressType == 4 ? "tcp4" : "tcp6"
				self.fd = socket(self.type)
				bind(self.fd, port, ip)
				self._doListen()
			}
		})
		--]]
		--[[
		-- TODO: por ahora asumo que es siempre una ip x.x.x.x
		local ip = host or "0.0.0.0"
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
		self.type = (version == 6 and "tcp6") or (version == 4 and "tcp4") or error("unknown IP version")
		self.acceptor:open(self.type)
		local ok, err, msg = bind(self.acceptor, port, ip)
		if not ok then
			self:emit("error", err, msg)
			return false
		end
		process.nextTick(function ()
			self:_doListen()
		end)
		--]]
	end
end

function Server:_doListen(port, ip)
	local ok, err = bind(self.acceptor, port, ip)
	if not ok then
		self:emit("error", err)
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
		local ok, err = self.acceptor:listen(self._backlog or 128)	-- el backlog
		if not ok then
			self:emit("error", err)
			--error( console.error("listen() failed with error: %s", err) )
			return
		end

		self:_startWatcher()
	end)
end

function Server:_startWatcher()
	--this.watcher.set(this.fd, true, false)
	--this.watcher.start()
	--this.emit("listening")
	self.acceptor:accept()
	self:emit("listening")
end

-- returns the address and port of the server
function Server:address()
	return self.acceptor:getsockname()
end

--
--
function Server:close()
	if not self.acceptor then error('Not running') end

	--self.watcher:stop()

	self.acceptor:close()
	self.acceptor = nil
	
	if self.type == "unix" then
		fs.unlink(self.path, function ()
			self:emit("close")
		end)
	else
		self:emit("close")
	end
end










function new()
	local t = setmetatable({}, { __index = _M })
	return t
end