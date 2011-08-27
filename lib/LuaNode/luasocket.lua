local cosocket = require "luanode.luasocket.cosocket"

module(..., package.seeall)

---
-- socket.tcp()
-- 
-- Creates and returns a TCP master object. A master object can be transformed into a server object with the method 
-- listen (after a call to bind) or into a client object with the method connect. The only other method supported by 
-- a master object is the close method.
-- 
-- In case of success, a new master object is returned. In case of error, nil is returned, followed by an error message.
--
function _M.tcp ()
	local socket = cosocket.CoSocket()
	return socket
end

---
-- socket.bind(address, port [, backlog])
--
-- This function is a shortcut that creates and returns a TCP server object bound to a local address and port, ready 
-- to accept client connections. Optionally, a user can also specify the backlog argument to the listen method 
-- (defaults to 32).
--
-- Note: The server object returned will hace the option "reuseaddr" set to true.
-- 
function _M.bind (address, port, backlog)
	local socket = cosocket.Server()
	local ok, err, msg = socket:bind(address, port)
	if not ok then
		--console.error("bind('%s', '%s', '%s') failed with error: %s\r\n%s", socket, port, ip, err, msg)
		return nil, err, msg
	end
	socket:listen(backlog or 32)
	ok, err, msg = socket:setoption("reuseaddr", true)
	if not ok then
		return nil, err
	end
	
	return socket
end

---
-- socket.connect(address, port [, locaddr, locport])
--
-- This function is a shortcut that creates and returns a TCP client object connected to a remote 'host' at a given 'port'. Optionally, the user can also specify the local address and port to bind ('locaddr' and 'locport').
-- 
function _M.connect (address, port, locaddr, locport)
	local socket = cosocket.Client()
	local ok, err = socket:connect(address, port)
	if not ok then
		return nil, err
	end
	
	return socket
end
