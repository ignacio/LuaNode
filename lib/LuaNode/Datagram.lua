local Class = require "luanode.class"
--var util = require('util')
--var fs = require('fs')
local EventEmitter = require "luanode.event_emitter"
local dns = require "luanode.dns"
local Net = require "luanode.net"

module(..., package.seeall)
--var IOWatcher = process.binding('io_watcher').IOWatcher
--var constants = process.binding('constants')

--var ENOENT = constants.ENOENT

--function isPort(x) { return parseInt(x) >= 0 }
local function toPort(x)
	local num = tonumber(x)
	if num and num >= 0 then return x else return false end
	--return (x = Number(x)) >= 0 ? x : false
end
local pool = nil

function getPool()
	-- TODO: this effectively limits you to 8kb maximum packet sizes 
	local minPoolAvail = 1024 * 8

	local poolSize = 1024 * 64

	if not pool or (pool.used + minPoolAvail > pool.length) then
		--pool = new Buffer(poolSize)
		pool.used = 0
	end

	return pool
end

function dnsLookup(kind, hostname, callback)
	local family = kind and (kind == "udp6" and 6 or 4) or nil --local family = (type ? ((type === 'udp6') ? 6 : 4) : null)
	dns.lookup(hostname, family, function(err, ip, addressFamily)
		if not err and family and addressFamily ~= family then
			err = 'no address found in family ' .. kind .. ' for ' .. hostname
		end
		callback(err, ip, addressFamily)
	end)
end

-- Socket Class
Socket = Class.InheritsFrom(EventEmitter)

function Socket:__init(kind, listener)
	local newSocket = Class.construct(Socket)

	newSocket.kind = kind
	if kind == 'unix_dgram' or kind == 'udp4' or kind == 'udp6' then
		newSocket.fd = process.UdpSocket(newSocket.kind)
	else
		error('Bad socket kind specified.  Valid kinds are: unix_dgram, udp4, udp6')
	end

	if type(listener) == 'function' then
		newSocket:on('message', listener)
	end

	--newSocket.watcher = new IOWatcher()
	--newSocket.watcher.host = newSocket
	--newSocket.watcher.callback = function() {
	newSocket.fd.read_callback = function(fd_, data, reason)
		-- TODO, actually leer algo
		if not data then
			console.error("%s", reason)
		else
			console.error("TODO, actually leer algo")
		end
		--[[
		while (newSocket.fd) {
			var p = getPool()
			var rinfo = recvfrom(newSocket.fd, p, p.used, p.length - p.used, 0)

			if (!rinfo) return

			newSocket.emit('message', p.slice(p.used, p.used + rinfo.size), rinfo)

			p.used += rinfo.size
		}
		--]]
	end

	--if newSocket.kind == 'udp4' or newSocket.kind == 'udp6' then
		--newSocket:_startWatcher()
	--end
	
	return newSocket
end

--
--
function createSocket (kind, listener)
	return Socket(kind, listener)
end


function Socket:bind (port, address)

	if self.kind == 'unix_dgram' then
		-- bind(path)
		local path = port
		if type(path) ~= 'string' then
			error('unix_dgram sockets must be bound to a path in the filesystem')
		end
		self.path = path

		-- unlink old file, OK if it doesn't exist
		fs.unlink(self.path, function(err)
			if err and err.errno ~= ENOENT then
				error(err)
			else
				--try {
					self.fd:bind(self.path)
					self:_startWatcher()
					self:emit('listening')
				--} catch (err) {
					--console.log('Error in unix_dgram bind of ' + self.path)
					--console.log(err.stack)
					--throw err
				--}
			end
		end)
	elseif self.kind == 'udp4' or self.kind == 'udp6' then
		-- bind(port, [address])
		if not address then
			-- Not bind()ing a specific address. Use INADDR_ANY and OS will pick one.
			-- The address can be found with server.address()
			self.fd:bind(port)
			self:_startWatcher()
			self:emit('listening')
		else
			-- the first argument is the port, the second an address
			self.port = port
			dnsLookup(self.kind, address, function(err, ip, addressFamily)
				if err then
					self:emit('error', err)
				else
					self.ip = ip
					self.fd:bind(self.port, ip)
					self:_startWatcher()
					self:emit('listening')
				end
			end)
		end
	end
end

function Socket:_startWatcher ()
	if not self._watcherStarted then
		-- listen for read ready, not write ready
		--self.watcher.set(self.fd, true, false)
		--self.watcher.start()
		self.fd:read()
		self._watcherStarted = true
	end
end

function Socket:address () 
	return binding.getsockname(self.fd)
end

function Socket:setBroadcast (value)
	return self.fd:setoption("broadcast", value)
end

function Socket:setTTL (newttl)
	if newttl > 0 and newttl < 256 then
		return self.fd:setoption("ttl", newttl)
	else
		error('New TTL must be between 1 and 255')
	end
end

-- translate arguments from JS API into C++ API, possibly after DNS lookup
function Socket:send (buffer, offset, length, ...)

	if type(offset) ~= 'number' or type(length) ~= 'number' then
		error('send takes offset and length as args 2 and 3')
	end

	if (self.kind == 'unix_dgram') then
		-- send(buffer, offset, length, path [, callback])
		local path, callback = select('1', ...), select('2', ...)
		if type(path) ~= 'string' then
			error('unix_dgram sockets must send to a path in the filesystem')
		end

		self:sendto(buffer, offset, length, path, nil, callback)
	elseif self.kind == 'udp4' or self.kind == 'udp6' then
		-- send(buffer, offset, length, port, address [, callback])
		local port, address, callback = select('1', ...), select('2', ...), select('3', ...)
		if type(address) ~= 'string' then
			error(self.kind .. ' sockets must send to port, address')
		end

		if (Net.isIP(address)) then
			self:sendto(buffer, offset, length, port, address, callback)
		else
			dnsLookup(self.kind, address, function(err, ip, addressFamily)
				if err then  -- DNS error
					if callback then
						callback(err)
					end
					self:emit('error', err)
					return
				end
				self:sendto(buffer, offset, length, port, ip, callback)
			end)
		end
	end
end

function Socket:sendto (buffer,
						offset,
						length,
						port,
						addr,
						callback)
	--try {
		local bytes = self.fd:sendto(buffer, offset, length, 0, port, addr, callback)
	--} catch (err) {
		--if (callback) {
--			callback(err)
		--}
		--return
	--}
	--console.warn("callback", callback)
	--if callback then
		--callback(nil, bytes)
	--end
end

function Socket:close ()

	if not self.fd then error('Not running') end

	self.fd:close()
	self.fd = nil
	--self.watcher.stop()
	self._watcherStarted = false

	--close(self.fd)
	--self.fd = nil

	if self.kind == 'unix_dgram' and self.path then
		fs.unlink(self.path, function()
			self:emit('close')
		end)
	else
		self:emit('close')
	end
end

