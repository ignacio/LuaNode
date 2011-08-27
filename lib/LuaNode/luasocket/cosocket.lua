---
-- CoSocket: Module that implements a LuaSocket compatible TCP layer. Blocking operations are simulated using 
-- coroutines.
--
-- Note: Most documentation here was taken verbatim from 
--   http://w3.impa.br/~diego/software/luasocket/reference.html
--
-- 

local Class = require "luanode.class"
local Timers = require "luanode.timers"
local Dns = require "luanode.dns"

module(..., package.seeall)

---
-- CoSocket Class
CoSocket = Class()

--
-- helper function that captures the running coroutine. Will resume it when called.
local function make_yield_function ()
	local co = assert(coroutine.running())
	return function(...)
		-- assert(coroutine.resume(co, ...)) -- assert won't work if error is not a string
		local ok, err = coroutine.resume(co, ...)
		if not ok then error(err) end
	end
end

---
-- Error translation function
--
local err_strings = {
	[process.constants.EADDRINUSE] = "address already in use",
	[process.constants.EISCONN] = "already connected",
	[process.constants.EACCES] = "permission denied",
	[process.constants.ECONNREFUSED] = "connection refused",
	[process.constants.ECONNABORTED] = "closed",
	[process.constants.ECONNRESET] = "closed",
	[process.constants.ETIMEDOUT] = "timeout",
	[process.constants.EOF] = "closed",

	[process.constants.EINTR] = "Interrupted system call",
	[process.constants.EACCES] = "Permission denied",
	[process.constants.EFAULT] = "Bad address",
	[process.constants.EINVAL] = "Invalid argument",
	[process.constants.EMFILE] = "Too many open files",
	[process.constants.EWOULDBLOCK] = "Resource temporarily unavailable",
	[process.constants.EINPROGRESS] =  "Operation now in progress",
	[process.constants.EALREADY] =  "Operation already in progress",
	[process.constants.ENOTSOCK] =  "Socket operation on nonsocket",
	[process.constants.EDESTADDRREQ] =  "Destination address required",
	[process.constants.EMSGSIZE] =  "Message too long",
	[process.constants.EPROTOTYPE] =  "Protocol wrong type for socket",
	[process.constants.ENOPROTOOPT] =  "Bad protocol option",
	[process.constants.EPROTONOSUPPORT] =  "Protocol not supported",
	[process.constants.ESOCKTNOSUPPORT] =  "Socket type not supported",
	[process.constants.EOPNOTSUPP] =  "Operation not supported",
	[process.constants.EPFNOSUPPORT] =  "Protocol family not supported",
	[process.constants.EAFNOSUPPORT] =  "Address family not supported by protocol family", 
	[process.constants.EADDRINUSE] =  "Address already in use",
	[process.constants.EADDRNOTAVAIL] =  "Cannot assign requested address",
	[process.constants.ENETDOWN] =  "Network is down",
	[process.constants.ENETUNREACH] =  "Network is unreachable",
	[process.constants.ENETRESET] =  "Network dropped connection on reset",
	[process.constants.ECONNABORTED] =  "Software caused connection abort",
	[process.constants.ECONNRESET] =  "Connection reset by peer",
	[process.constants.ENOBUFS] =  "No buffer space available",
	[process.constants.EISCONN] =  "Socket is already connected",
	[process.constants.ENOTCONN] =  "Socket is not connected",
	[process.constants.ESHUTDOWN] =  "Cannot send after socket shutdown",
	[process.constants.ETIMEDOUT] =  "Connection timed out",
	[process.constants.ECONNREFUSED] =  "Connection refused",
	[process.constants.EHOSTDOWN] =  "Host is down",
	[process.constants.EHOSTUNREACH] =  "No route to host",
	----case WSASYSNOTREADY =  "Network subsystem is unavailable",
	----case WSAVERNOTSUPPORTED =  "Winsock.dll version out of range",
	----case WSANOTINITIALISED =  "Successful WSAStartup not yet performed",

	---
	--[process.constants.HOST_NOT_FOUND] =  "Host not found",
	--[process.constants.TRY_AGAIN] =  "Nonauthoritative host not found",
	--[process.constants.NO_RECOVERY] =  "Nonrecoverable name lookup error", 
	--[process.constants.NO_DATA] =  "Valid name, no data record of requested type",
}
if process.constants.EPROCLIM then
	err_strings[process.constants.EPROCLIM] =  "Too many processes"
end
if process.constants.EDISCON then
	err_strings[process.constants.EDISCON] =  "Graceful shutdown in progress"
end

local function socket_strerror (num)
	return err_strings[num] or "Unknown error ("..tostring(num)..")"
end


---
--
local function doConnect (socket, port, host)
	local ok, err, err_num = socket._raw_socket:connect(host, port)
	if not ok then
		socket:close()
		return nil, socket_strerror(err_num)
	end
	
	LogDebug("connecting to %s:%d", host, port)
	
	socket._raw_socket.connect_callback = make_yield_function()
	local raw_socket, ok, err, err_num = coroutine.yield()
	socket._raw_socket.connect_callback = nil
	
	socket._connecting = false
	
	if ok then
		socket.readable = true
		socket.writable = true
		
		-- Now, 'socket' will become an instance of Client
		-- This is a bit fragile. If you add something to Client:__init, need to replicate that here.
		if getmetatable(socket) ~= Client then
			setmetatable(socket, Client)
		end
		return true
	else
		socket:close()
		return nil, socket_strerror(err_num)
	end
end


--
-- Bind with UNIX
--   t.bind(fd, "/tmp/socket")
-- Bind with TCP
--   t.bind(fd, 80, "192.168.11.2")
--   t.bind(fd, 80)
local function bind (socket, port, ip)
	assert(socket and port, "Must pass fd and port / path")
	
	if not ip or ip == "*" then
		ip = "0.0.0.0"
	end
	-- disgusting hack. In 
	if process.platform ~= "windows" then
		socket:setoption("reuseaddr", true)
	end
	local is_ip, version = Net.isIP(ip)
	if not is_ip then
		return nil, ("%q is not a valid ip address"):format(ip)
	end
	local ok, err_msg, err_code = socket:open("tcp" .. version)
	if not ok then
		console.error("bind('%s', '%s', '%s') failed with error: %s\r\n%s", socket, port, ip, err_msg, err_code)
		return nil, socket_strerror(err_code)
	end
	ok, err_msg, err_code = socket:bind(ip, port)
	if not ok then
		console.error("bind('%s', '%s', '%s') failed with error: %s\r\n%s", socket, port, ip, err_msg, err_code)
		return nil, socket_strerror(err_code)
	end
	return true
end

---
-- Constructor: Builds a master object. It will become a server or a client later.
function CoSocket:__init (fd, kind)
	local newSocket = Class.base.rawnew(CoSocket, {})
	
	newSocket._raw_socket = nil
	newSocket.kind = kind
	newSocket.secure = false
	
	newSocket.readable = false
	newSocket.writable = false
	
	if getmetatable(fd) == process.Socket then
		-- TODO: chequear que no este causando algo que no se lo pueda llevar el gc
		fd._owner = newSocket
		newSocket._raw_socket = fd
		--newSocket:open(fd, kind)	-- esto se hace mas adelante
		return newSocket
	end
	
	return newSocket
end

---
-- connect(host, port)
-- 
function CoSocket:connect (host, port)
	if self._raw_socket then error("Socket already opened") end
	
	self._connecting = true		-- set false in doConnect
	self.writable = true
	
	if type(port) == "string" and not tonumber(port) then
		-- unix path, not there yet...
	else
		local ip = host or "127.0.0.1"
		local port = tonumber(port)
		assert(type(port) == "number", "missing port")
		assert(port >= 0 and port <= 65535, "port number out of range")
		
		if ip:lower() == "localhost" then
			ip = "127.0.0.1"
		end

		Dns.lookup(ip, make_yield_function())
		local err, address, hostname = coroutine.yield()
		if err then
			return nil, socket_strerror(address)
		end
		ip = address.address
		-- Now it is a client 
		self.kind = "tcp" .. address.family
		self._raw_socket = process.Socket(self.kind)
		self._raw_socket._owner = self
		return doConnect(self, port, ip)
	end	
end

---
-- Closes a TCP object. The internal socket used by the object is closed and the local address to which the object was 
-- bound is made available to other application. No further operations (except for further calls to the close method) 
-- are allowed on a closed socket. Note: It is important to close all used sockets once they are not needed, sinc, in 
-- many systems, each socket uses a file descriptor, which are limited system resources. Garbage-collected objects are 
-- automatically closed before destruction, though.
--
function CoSocket:close ()
	self.writable = false
	self.readable = false
	if self._raw_socket then
		self._raw_socket:close()
		self._raw_socket._owner = nil
		self._raw_socket = nil
	end
end

---
-- master:listen(backlog)
--
-- Specifies the socket is willing to receive connections, transforming the object into a server object. Server objects 
-- support the accept, getsockname, setoption, settimeout, and close methods.
--
-- The parameter backlog specifies the number of client connections that can be queued waiting for service. If the 
-- queue is full and another client attempts connection, the connection is refused.
--
-- In case of success, the method returns 1. In case of error, the method returns nil followed by an error message.
--
function CoSocket:listen (backlog)
	local ok, err_msg, err_code = self._raw_socket:listen(backlog)
	if not ok then return nil, socket_strerror(err_code) end
	
	-- Now, 'socket' will become an instance of Server
	-- This is a bit fragile. If you add something to Server:__init, need to replicate that here.
	if getmetatable(self) ~= Server then
		setmetatable(self, Server)
	end
	
	return 1
end

---
-- client:shutdown(mode)
-- Shuts down part of a full-duplex connection.

-- Mode tells which way of the connection should be shut down and can take the value:

-- "both": disallow further sends and receives on the object. This is the default mode;
-- "send": disallow further sends on the object;
-- "receive": disallow further receives on the object.
-- This function returns 1.
-- 
function CoSocket:shutdown (mode)
	local ok, err_msg, err_code = self._raw_socket:shutdown(mode)
	if ok then return 1 end
	return nil, socket_strerror(err_code)
end

---
-- getpeername()
--
-- Returns information about the remote side of a connected client object.
-- 
-- Returns a string with the IP address of the peer, followed by the port number that peer is using for the connection. 
-- In case of error, the method returns nil.
function CoSocket:getpeername ()
	return self._raw_socket:getpeername()
end

---
-- getsockname()
--
-- Returns the local address information associated to the object.
--
-- The method returns a string with local IP address and a number with the port. In case of error, the method returns 
-- nil.
function CoSocket:getsockname ()
	return self._raw_socket:getsockname()
end

---
-- master:getstats()
-- 
-- Returns accounting information on the socket, useful for throttling of bandwidth.
--
-- The method returns the number of bytes received, the number of bytes sent, and the age of the socket object in 
-- seconds.
--
function CoSocket:getstats ()
	return 0, 0, 0 -- nice, uh?
end

---
-- server:setstats(received, sent, age)
-- 
-- Resets accounting information on the socket, useful for throttling of bandwidth.
--
-- Received is a number with the new number of bytes received. Sent is a number with the new number of bytes sent. 
-- Age is the new age in seconds.
-- 
-- The method returns 1 in case of success and nil otherwise.
--
function CoSocket:setstats (received, sent, age)
	return 1
end

---
-- setoption(option [, value])
-- 
-- Sets options for the TCP object. Options are only needed by low-level or time-critical applications. You should 
-- only modify an option if you are sure you need it.
-- 'option' is a string with the option name, and 'value' depends on the option being set:
--   - 'keepalive': Setting this option to true enables the periodic transmission of messages on a connected socket. 
--     Should the connected party failt to respond to these messages, the connection is considered broken and processes 
--     using this socket are notified;
--   - 'linger': Controls the action taken when unsent data is queued on a socket and a close is performed. The value is 
--     a table with a boolean entry 'on' and a numeric entry for the time interval 'timeout' in seconds. If the 
--     'on' field is set to true, the system will block the process on the close attempt until it is able to transmit 
--     the data or until 'timeout' has passed.
--     If 'on' is false and a close is issued, the system will process the close in a manner that allows the process to 
--     continue as quickly as possible. I do not advise you to set this to anything other than zero;
--   - 'reuseaddr': Setting this option indicates that the rules used in validating address supplied in a call to 'bind' 
--     should allow reuse of local addresses;
--   - 'tcp-nodelay': Setting this option to true disables the Nagle's algorithm for the connection.
--
--  The method returns 1 in case of success or nil otherwise.
function CoSocket:setoption (option, value)
	option = option:lower()
	local ok, err_msg, err_code
	if option == "tcp-nodelay" or option == "nodelay" then
		ok, err_msg, err_code = self._raw_socket:setoption("nodelay", value)
	elseif option == "keepalive" then
		error("not properly implemented yet")	-- TODO: implement this
		ok, err_msg, err_code = self._raw_socket:setoption("keepalive", value, 1, 1)	-- me falta sacar esos valores de algun lado
	elseif option == "linger" then
		error("not implemented yet")	-- TODO: implement this
		--return self._raw_socket:setoption
	elseif option == "reuseaddr" then
		ok, err_msg, err_code = self._raw_socket:setoption("reuseaddr", value)
	else
		error("unknown option " .. tostring(option))
	end
	if ok then return 1 end
	return nil, socket_strerror(err_code)
end


---
-- Client Class
Client = Class.InheritsFrom(CoSocket)

function Client:__init (fd, kind)
	return Class.construct(Client, fd, kind)
end

---
-- send(data [, i [, j]])
-- 
-- Sends 'data' through client object.
-- 'Data' is the string to be sent. The optional arguments i and j work exactly like the standard 'string.sub' Lua 
-- function to allow the selection of a substring to be sent.
--
-- If successful, the method returns the index of the last byte within [i, j] that has been sent. Notice that, if i is 
-- 1 or absent, this is effectively the total number of bytes sent. In case of error, the method returns nil, followed 
-- by an error message, followed by the index of the last byte within [i, j] that has been sent. You might want to try 
-- again from the byte following that. The error message can be 'closed' in case the connection was closed before the 
-- transmission was completed or the string 'timeout' in case there was a timeout during the operation.
--
-- Note: Output is not buffered. For small strings, it is always better to concatenate them in Lua (with the '..' 
-- operator) and send the result in one call instead of calling the method several times.
function Client:send (data, encoding, fd)
	-- TODO: hacer que el metodo corresponda a lo que dice la documentacion :D
	assert(not self._connecting, "not yet connected?")
	if not self.writable then
		error("Socket is not writable")
	end
	
	self._raw_socket.write_callback = make_yield_function()
	local ok, err_msg, err_code = self._raw_socket:write(data, encoding, fd)
	if not ok then return nil, socket_strerror(err_code), 0 end
	
	local _, ok, err_msg, err_code = coroutine.yield()
	if not ok then
		return nil, socket_strerror(err_code)
	end
	return #data
end

Client.write = Client.send

---
-- read([pattern [, prefix]])
-- 
-- Reads data from a client object, according to the specified read pattern. 
-- Patterns follow the Lua file I/O format, and the difference in performance between all patterns is negligible.
-- 
-- 'Pattern' can be any of the following:
--   - '*a': reads from the socket until the connection is closed. No end-of-line translation is performed;
--   - '*l': reads a line of text from the socket. The line is terminated by a LF character (ASCII 10), optionally 
--     preceded by a CR character (ASCII 13). The CR and LF characters are not included in the returned line. In fact, 
--     all CR characters are ignored by the pattern. This is the default pattern;
--   - number: causes the method to read a specified number of bytes from the socket.
--
-- 'Prefix' is an optional string to be concatenated to the beginning of any received data before return.
--
-- If successful, the method returns the received pattern. In case of error, the method returns nil followed by an 
-- error message which can be the string 'closed' in case the connection was closed before the transmission was 
-- completed or the string 'timeout' in case there was a timeout during the operation. Also, after the error message, 
-- the function returns the partial result of the transmission.
--
function Client:read (pattern, prefix)
	pattern = pattern or "*l"
	assert(pattern == "*l" or pattern == "*a" or type(pattern) == "number", "invalid receive pattern")
	
	self._raw_socket.read_callback = make_yield_function()
	
	-- please, refactor me
	self._raw_socket:read(pattern)
	
	local sock, data, err_msg, err_code, partial = coroutine.yield()
	if not data then
		if pattern == "*a" and err_code == process.constants.EOF and partial then
			return (prefix and partial .. result or partial)
		else
			return nil, socket_strerror(err_code), partial
		end
	end
	
	local result = data
	if pattern == "*l" then
		data = data:gsub("\r", "")
		result = data:match("[^\n]+")
	end
	
	if prefix then
		result = prefix .. result
	end
	return result, err_code and socket_strerror(err_code)
end

Client.receive = Client.read



---
-- Server Class
Server = Class.InheritsFrom(CoSocket)

function Server:__init (fd, kind)
	return Class.construct(Server)
end

---
-- master:bind(address, port)
--
-- Binds a master object to 'address' and 'port' on the local host. 'Address' can be an IP address or a host name. 
-- 'Port' must be an integer number in the range [0 .. 64K). If 'address' is "*", the system binds to all local 
-- interfaces using the INADDR_ANY constant. If 'port' is 0, the system automatically chooses an ephemeral port.
--
-- In case of success, the method returns 1. In case of error, the method returns nil followed by an error message.
--
-- Note: The function socket.bind is available and is a shortcut for the creation of server sockets.
-- 
function Server:bind (address, port)
	if self._raw_socket then error("Socket already opened") end
	
	self.readable = true
	
	if type(port) == "string" and not tonumber(port) then
		-- unix path, not there yet...
	else
		local ip = (type(address) == "string" and address) or "*"
		local port = tonumber(port) or 0
		assert(type(port) == "number", "missing port")
		assert(port >= 0 and port <= 65535, "port number out of range")
		
		if ip:lower() == "localhost" then
			ip = "127.0.0.1"
		elseif ip == "*" then
			ip = "0.0.0.0"
		end
		
		Dns.lookup(ip, make_yield_function())
		local err, address, hostname = coroutine.yield()
		if err then
			return nil, socket_strerror(address)
		end
		ip = address.address
		-- Now it is a server
		self.kind = "tcp" .. address.family
		self._raw_socket = process.Acceptor(self.kind)
		self._raw_socket._owner = self
		return bind(self._raw_socket, port, ip)
	end	
end

---
-- server:accept()
-- 
-- Waits for a remote connection on the server object and returns a client object representing that connection.
-- 
-- If a connection is successfully initiated, a client object is returned. If a timeout condition is met, the method 
-- returns nil followed by the error string 'timeout'. Other errors are reported by nil followed by a message 
-- describing the error.
-- 
-- Note: calling socket.select with a server object in the recvt parameter before a call to accept does not guarantee 
-- accept will return immediately. Use the settimeout method or accept might block until another client shows up.
--
function Server:accept ()
	self._raw_socket.callback = make_yield_function()
	
	self._raw_socket:accept()
	local peer = coroutine.yield()
	-- peer.socket, peer.address, peer.port
	local s = Client(peer.socket, self.kind)
	--s:open(peer.socket, self.kind) --newServer:open(fd, kind)
	s.remotePort = peer.port
	s.server = self
	
	return s
end
