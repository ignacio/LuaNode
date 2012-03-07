--var util = require('util');
local Class = require "luanode.class"
local net = require "luanode.net"
local EventEmitter = require "luanode.event_emitter"
local stream = require "luanode.stream"
local FreeList = require "luanode.free_list"
local HTTPParser = process.HTTPParser

-- TODO: sacar el seeall
module(..., package.seeall)

-- Classes exported by this module:
-- IncomingMessage
-- OutgoingMessage
-- ServerResponse
-- ClientRequest
-- Server
-- Client

local CRLF = "\r\n"
-- HTTP status codes
status_codes = {
	[100] = "Continue",
	[101] = "Switching Protocols",
	[102] = "Processing",						-- RFC 2518, obsoleted by RFC 4918
	[200] = "OK",
	[201] = "Created",
	[202] = "Accepted",
	[203] = "Non-Authoritative Information",
	[204] = "No Content",
	[205] = "Reset Content",
	[206] = "Partial Content",
	[207] = "Multi-Status",						-- RFC 4918
	[300] = "Multiple Choices",
	[301] = "Moved Permanently",
	[302] = "Found",
	[303] = "See Other",
	[304] = "Not Modified",
	[305] = "Use Proxy",
	[307] = "Temporary Redirect",
	[400] = "Bad Request",
	[401] = "Unauthorized",
	[402] = "Payment Required",
	[403] = "Forbidden",
	[404] = "Not Found",
	[405] = "Method Not Allowed",
	[406] = "Not Acceptable",
	[407] = "Proxy Authentication Required",
	[408] = "Request Time-out",
	[409] = "Conflict",
	[410] = "Gone",
	[411] = "Length Required",
	[412] = "Precondition Failed",
	[413] = "Request Entity Too Large",
	[414] = "Request-URI Too Large",
	[415] = "Unsupported Media Type",
	[416] = "Requested range not satisfiable",
	[417] = "Expectation Failed",
	[418] = "I'm a teapot",						-- RFC 2324
	[422] = "Unprocessable Entity",				-- RFC 4918
	[423] = "Locked",							-- RFC 4918
	[424] = "Failed Dependency",				-- RFC 4918
	[425] = "Unordered Collection",				-- RFC 4918
	[426] = "Upgrade Required",					-- RFC 2817
	[500] = "Internal Server Error",
	[501] = "Not Implemented",
	[502] = "Bad Gateway",
	[503] = "Service Unavailable",
	[504] = "Gateway Time-out",
	[505] = "HTTP Version not supported",
	[506] = "Variant Also Negotiates",			-- RFC 2295
	[507] = "Insufficient Storage",				-- RFC 4918
	[509] = "Bandwidth Limit Exceeded",
	[510] = "Not Extended"						-- RFC 2774
}


-- Abstract base class for ServerRequest and ClientResponse.
-- Public:
IncomingMessage = Class.InheritsFrom(stream.Stream)

function IncomingMessage:__init(socket)
	local newMessage = Class.construct(IncomingMessage)

	-- TODO: Remove one of these eventually.
	newMessage.socket = socket
	newMessage.connection = socket 	-- This is the preferred name
	
	newMessage.paused = false
	newMessage._eventQueue = {}

	newMessage.httpVersion = nil
	newMessage.complete = false
	newMessage.headers = {}
	newMessage.trailers = {}
	
	newMessage.readable = true

	-- request (server) only
	newMessage.url = ""

	newMessage.method = nil

	-- response (client) only
	newMessage.statusCode = nil
	newMessage.client = newMessage.socket
	
	return newMessage
end

--
function IncomingMessage:destroy(err)
	self.socket:destroy(err)
end

--
--
function IncomingMessage:setEncoding(encoding)
	-- TODO: implementar
	local StringDecoder = nil--
	--var StringDecoder = require("string_decoder").StringDecoder; // lazy load
	--this._decoder = new StringDecoder(encoding);
end

--
--
function IncomingMessage:_emit(...)
	if self.paused then
		self._eventQueue[#self._eventQueue + 1] = {...}
	else
		self:emit(...)
	end
end

--
--
function IncomingMessage:pause()
	self.paused = true
	self.socket:pause()
end

--
--
function IncomingMessage:resume()
	self.paused = false
	
	if #self._eventQueue > 0 then
		for i, arguments in ipairs(self._eventQueue) do
			self:emit( unpack(arguments) )
		end
		self._eventQueue = {}
	end
	self.socket:resume()
end

-- Add the given (field, value) pair to the message
--
-- Per RFC2616, section 4.2 it is acceptable to join multiple instances of the
-- same header with a ', ' if the header in question supports specification of
-- multiple values this way. If not, we declare the first instance the winner
-- and drop the second. Extended header fields (those beginning with 'x-') are
-- always joined.
function IncomingMessage:_addHeaderLine (field, value)
	local dest
	if self.complete then
		dest = self.trailers
	else
		dest = self.headers
	end
	local function comma_separate(dest, field, value)
		local header = dest[field]
		if header then
			dest[field] = header .. ", " .. value
		else
			dest[field] = value
		end
	end
	local mappings = {
		["set-cookie"] = function(dest, field, value)
			local header = dest[field]
			if header then
				header[#header + 1] = value
			else
				dest[field] = { value }
			end
		end,
		
		["accept"] = comma_separate,
		["accept-charset"] = comma_separate,
		["accept-encoding"] = comma_separate,
		["accept-language"] = comma_separate,
		["connection"] = comma_separate,
		["cookie"] = comma_separate
	}
	
	if not mappings[field] then
		if field:match("^x%-") then
			-- except for x-
			comma_separate(dest, field, value)
		else
			-- drop duplicates
			if not dest[field] then
				dest[field] = value
			end
		end
	else
		mappings[field](dest, field, value)
	end
end



-- Public:
OutgoingMessage = Class.InheritsFrom(stream.Stream)

function OutgoingMessage:__init (socket)
	local newMessage = Class.construct(OutgoingMessage)
	
	-- TODO Remove one of these eventually.
	newMessage.socket = socket
	newMessage.connection = socket

	newMessage.output = {}
	newMessage.outputEncodings = {}
	
	newMessage.writable = true

	newMessage._last = false
	newMessage.chunkedEncoding = false
	newMessage.shouldKeepAlive = true
	newMessage.useChunkedEncodingByDefault = true
	newMessage.shouldSendDate = false

	newMessage._hasBody = true
	newMessage._trailer = ""

	newMessage.finished = false
	
	return newMessage
end

--
--
function OutgoingMessage:destroy(err)
	self.socket:destroy(err)
end

-- This abstract either writing directly to the socket or buffering it.
function OutgoingMessage:_send (data, encoding)
	-- This is a shameful hack to get the headers and first body chunk onto
	-- the same packet. Future versions of Node (ehem, LuaNode :D) are going to take care of
	-- this at a lower level and in a more general way.
	if not self._headerSent then
		if type(data) == "string" then
			data = self._header .. data
		else
			self.output.unshift(self._header)	-- TODO: equivalente en Lua?
			self.outputEncodings.unshift("ascii")	-- TODO: remove me
		end
		self._headerSent = true
	end
	
	return self:_writeRaw(data, encoding)
end

--
--
function OutgoingMessage:_writeRaw(data, encoding)
	if self.connection._outgoing[1] == self and self.connection.writable then
		-- There might be pending data in the self.output buffer
		while #self.output > 0 do
			if not self.connection.writable then
				self:_buffer(data, encoding)
				return false
			end
			local c = table.remove(self.output, 1)
			local e = table.remove(self.outputEncodings, 1)
			self.connection:write(c, e)
		end
		
		-- Directly write to the socket
		return self.connection:write(data, encoding)
	else
		self:_buffer(data, encoding)
		return false
	end
end

--
--
function OutgoingMessage:_buffer (data, encoding)
	if #data == 0 then return end

	local length = #self.output

	if length == 0 or type(data) ~= "string" then
		self.output[length + 1] = data
		encoding = encoding or "ascii"
		self.outputEncodings[#self.outputEncodings + 1] = encoding
		return false
	end

	local lastEncoding = self.outputEncodings[length]
	local lastData = self.output[length]

	-- TODO: data.constructor ??? 
	if lastEncoding == encoding or (not encoding and data.constructor == lastData.constructor) then
		self.output[length] = lastData .. data
		return false
	end

	self.output[#self.output + 1] = data
	encoding = encoding or "ascii"
	self.outputEncodings[#self.outputEncodings + 1] = encoding

	return false
end

--
--
function OutgoingMessage:_storeHeader (firstLine, headers)
	local sentConnectionHeader = false
	local sentContentLengthHeader = false
	local sentTransferEncodingHeader = false
	local sentExpect = false
	local sentDateHeader = false

	-- firstLine in the case of request is: "GET /index.html HTTP/1.1\r\n"
	-- in the case of response it is: "HTTP/1.1 200 OK\r\n"
	local messageHeader = firstLine
	local field, value

	local function store(field, value)
		messageHeader  = messageHeader .. field .. ": " .. value .. CRLF

		field = field:lower()
		if field:match("connection") then
			value = value:lower()
			sentConnectionHeader = true
			if value:match("close") then
				self._last = true
			else
				self.shouldKeepAlive = true
			end

		elseif field:match("transfer%-encoding") then
			sentTransferEncodingHeader = true
			value = value:lower()
			if value:match("chunk") then self.chunkedEncoding = true end

		elseif field:match("content%-length") then
			sentContentLengthHeader = true
		
		elseif field:match("date") then
			sentDateHeader = true
		
		elseif field:match("expect") then
			sentExpect = true
		end
	end

	if headers then
		--[[
		local keys = Object.keys(headers)
		local isArray = (Array.isArray(headers))
		local i, l

		for (i = 0, l = keys.length; i < l; i++) {
			var key = keys[i];
			if (isArray) {
				field = headers[key][0];
				value = headers[key][1];
			} else {
				field = key;
				value = headers[key];
			}

			if (Array.isArray(value)) {
				for (i = 0, l = value.length; i < l; i++) {
					store(field, value[i]);
				}
			} else {
				store(field, value);
			}
		end
		--]]
		local isArray = headers[1] ~= nil
		for k,v in pairs(headers) do
			if isArray then
				field = v[1]
				value = v[2]
			else
				field = k
				value = v
			end
			
			if type(value) == "table" then
				for i,j in ipairs(value) do
					store(field, j)
				end
			else
				store(field, value)
			end
		end
	end

	-- Date header
	if self.shouldSendDate and not sentDateHeader then
		messageHeader = messageHeader .. "Date: " .. os.date("!%a, %d %b %Y %H:%M:%S GMT") .. "\r\n"
	end
	
	-- keep-alive logic
	if sentConnectionHeader == false then
		if self.shouldKeepAlive and (sentContentLengthHeader or self.useChunkedEncodingByDefault) then
			messageHeader = messageHeader .. "Connection: keep-alive\r\n"
		else
			self._last = true
			messageHeader = messageHeader .. "Connection: close\r\n"
		end
	end

	if sentContentLengthHeader == false and sentTransferEncodingHeader == false then
		if self._hasBody then
			if self.useChunkedEncodingByDefault then
				messageHeader = messageHeader .. "Transfer-Encoding: chunked\r\n"
				self.chunkedEncoding = true
			else
				self._last = true
			end
		else
			-- Make sure we don't end the 0\r\n\r\n at the end of the message.
			self.chunkedEncoding = false
		end
	end

	self._header = messageHeader .. CRLF
	self._headerSent = false
	-- wait until the first body chunk, or close(), is sent to flush,
	-- UNLESS we're sending Expect: 100-continue
	if sentExpect then
		self:_send("")
	end
end

--
--
function OutgoingMessage:write (chunk, encoding)
	if not self._header then
		error("You have to call writeHead() before write()")
	end

	if not self._hasBody then
		console.error("This type of response MUST NOT have a body. Ignoring write() calls.")
		return true
	end

	-- TODO: fixme
	if type(chunk) ~= "string" then--and
		--&& !Buffer.isBuffer(chunk)
		--&& !Array.isArray(chunk)) then
		--throw new TypeError("first argument must be a string, Array, or Buffer");
		error("first argument must be a string, Array, or Buffer")
	end

	if #chunk == 0 then return false end

	local ret
	if self.chunkedEncoding then
		if type(chunk) == 'string' then
			local chunk = ("%x"):format(#chunk) .. CRLF .. chunk .. CRLF
			--LogDebug('string chunk = ' .. util.inspect(chunk))
			ret = self:_send(chunk, encoding)
		else
			-- buffer
			self:_send( ("%s"):format(#chunk) .. CRLF)
			self:_send(chunk)
			ret = self:_send(CRLF)
		end
	else
		ret = self:_send(chunk, encoding)
	end

	LogDebug('write ret = %s', ret)
	return ret
end

--
-- TODO: fixme, por que estoy reinventando wsapi ?
function OutgoingMessage:addTrailers (headers)
	self._trailer = ""
	
	local field, value
	local isArray = headers[1] ~= nil
	for k,v in pairs(headers) do
		if isArray then
			field = v[1]
			value = v[2]
		else
			field = k
			value = v
		end
		
		self._trailer = self._trailer .. field .. ": " .. value .. CRLF
	end
end

--
--
function OutgoingMessage:finish (data, encoding)
	local ret

	local hot = self._headerSent == false
				and type(data) == "string"
				and #data > 0
				and #self.output == 0
				and self.connection.writable
				and self.connection._outgoing[1] == self

	if hot then
		-- Hot path. They're doing
		--   res.writeHead();
		--   res.end(blah);
		-- HACKY.
		if self.chunkedEncoding then
			local l = string.format("%x", #data) 	--local l = Buffer.byteLength(data, encoding).toString(16)
			ret = self.connection:write( self._header
									.. l
									.. CRLF
									.. data
									.. "\r\n0\r\n"
									.. self._trailer
									.. "\r\n"
									, encoding
									)
		else
			ret = self.connection:write(self._header .. data, encoding)
		end
		self._headerSent = true

	elseif data then
		-- Normal body write.
		ret = self:write(data, encoding)
	end

	if not hot then
		if self.chunkedEncoding then
			ret = self:_send('0\r\n' .. self._trailer .. '\r\n') -- Last chunk.
		else
			-- Force a flush, HACK.
			ret = self:_send('')
		end
	end

	self.finished = true

	-- There is the first message on the outgoing queue, and we've sent
	-- everything to the socket.
	if #self.output == 0 and self.connection._outgoing[1] == self then
		LogDebug('outgoing message end. shifting because was flushed')
		self.connection:_onOutgoingSent()
	end

	return ret
end


ServerResponse = Class.InheritsFrom(OutgoingMessage)

function ServerResponse:__init (req)
	local newResponse = Class.construct(ServerResponse, req.socket)
	
	if req.method == "HEAD" then
		newResponse._hasBody = false
	end
	
	newResponse.shouldSendDate = true
	
	if req.httpVersionMajor < 1 or req.httpVersionMinor < 1 then
		newResponse.useChunkedEncodingByDefault = false
		newResponse.shouldKeepAlive = false
	end
	
	return newResponse
end

--
--
function ServerResponse:writeContinue()
	self:_writeRaw("HTTP/1.1 100 Continue" .. CRLF .. CRLF, "ascii")
	self._sent100 = true
end

--
--
function ServerResponse:writeHead (statusCode, reasonPhrase, headers)
	local headers, headerIndex
	
	if type(reasonPhrase) == "table" then
		headers = reasonPhrase
		reasonPhrase = status_codes[statusCode] or "unknown"
	elseif not reasonPhrase then
		reasonPhrase = status_codes[statusCode] or "unknown"
	end
	
	headers = (type(headers) == "table" and headers) or {}
	
	local statusLine = "HTTP/1.1 " .. tostring(statusCode) .. " " .. reasonPhrase .. CRLF
	
	if statusCode == 204 or statusCode == 304 or (statusCode >= 100 and statusCode <= 199) then
		-- RFC 2616, 10.2.5:
		-- The 204 response MUST NOT include a message-body, and thus is always
		-- terminated by the first empty line after the header fields.
		-- RFC 2616, 10.3.5:
		-- The 304 response MUST NOT contain a message-body, and thus is always
		-- terminated by the first empty line after the header fields.
		-- RFC 2616, 10.1 Informational 1xx:
		-- This class of status code indicates a provisional response,
		-- consisting only of the Status-Line and optional headers, and is
		-- terminated by an empty line.
		self._hasBody = false
	end
	
	-- don't keep alive connections where the client expects 100 Continue
	-- but we sent a final status; they may put extra bytes on the wire.
	if self._expect_continue and not self._sent100 then
		self.shouldKeepAlive = false
	end
	
	self:_storeHeader(statusLine, headers)
end

--
--
function ServerResponse:writeHeader (...)
	return self:writeHead(...)
end


-- TODO: anda esto ??
ClientRequest = Class.InheritsFrom(OutgoingMessage)

--
--
function ClientRequest:__init (socket, method, url, headers)
	local newRequest = Class.construct(ClientRequest, socket)
	
	method = method:upper()
	newRequest.method = method
	newRequest.shouldKeepAlive = false
	
	if method == "GET" or method == "HEAD" then
		newRequest.useChunkedEncodingByDefault = false
	else
		newRequest.useChunkedEncodingByDefault = true
	end
	
	newRequest._last = true
	
	newRequest:_storeHeader(method .. " " .. url .. " HTTP/1.1\r\n", headers)
	
	return newRequest
end

--
--
function ClientRequest:finish (...)
	-- TODO: no agregar este método y que se llame directamente a la base
	return OutgoingMessage.finish(self, ...)
end

--
--
function outgoingFlush (socket)
	-- This logic is probably a bit confusing. Let me explain a bit:
	--
	-- In both HTTP servers and clients it is possible to queue up several
	-- outgoing messages. This is easiest to imagine in the case of a client.
	-- Take the following situation:
	--
	--    req1 = client.request('GET', '/');
	--    req2 = client.request('POST', '/');
	--
	-- The question is what happens when the user does
	--
	--   req2.write("hello world\n");
	--
	-- It's possible that the first request has not been completely flushed to
	-- the socket yet. Thus the outgoing messages need to be prepared to queue
	-- up data internally before sending it on further to the socket's queue.
	--
	-- This function, outgoingFlush(), is called by both the Server
	-- implementation and the Client implementation to attempt to flush any
	-- pending messages out to the socket.
	local message = socket._outgoing[1]
	if not message then return end

	local ret

	while (#message.output > 0) do
		if not socket.writable then return end -- XXX Necessary?

		local data = table.remove(message.output, 1)
		local encoding = table.remove(message.outputEncodings, 1)

		ret = socket:write(data, encoding)
	end

	if message.finished then
		socket:_onOutgoingSent()
	elseif ret then
		message:emit('drain')
	end
end


--
--
local function httpSocketSetup (socket)
	-- An array of outgoing messages for the socket. In pipelined connections we 
	-- need to keep track of the order they were sent.
	socket._outgoing = {}
	socket.__destroyOnDrain = false
	
	-- NOTE: be sure not to use ondrain elsewhere in this file!
	socket.ondrain = function()
		local message = socket._outgoing[1]
		if message then message:emit("drain") end
		if socket.__destroyOnDrain then
			socket:destroy()
			socket.__destroyOnDrain = nil
		end
	end
end

parsers = FreeList.new("parsers", 1000, function ()
	local parser = HTTPParser("request")
	
	parser.onMessageBegin = function (self)
		self.incoming = IncomingMessage(self.socket)
		self.field = nil
		self.value = nil
	end
	
	-- Only servers will get URL events
	--[[parser.onURL = function (self, b, start, len)
		local slice = b.toString("ascii", start, start + len)
		if parser.incoming.url then
			parser.incoming.url = parser.incoming.url .. slice
		else
			-- Almost always will branch here
			parser.incoming.url = slice
		end
	end]]
	parser.onURL = function (self, data)
		if #self.incoming.url ~= 0 then
			self.incoming.url = self.incoming.url .. data
		else
			-- Almost always will branch here
			self.incoming.url = data
		end
	end
	
	--[[
	parser.onHeaderField = function (b, start, len)
		local slice = b.toString("ascii", start, start + len):lower()
		if parser.value then
			parser.incoming._addHeaderLine(parser.field, parser.value)
			parser.field = nil
			parser.value = nil
		end
		if parser.field then
			parser.field = parser.field .. slice
		else
			parser.field = slice
		end
	end
	--]]
	parser.onHeaderField = function (self, data)
		data = data:lower()
		if self.value then
			self.incoming:_addHeaderLine(self.field, self.value)
			self.field = nil
			self.value = nil
		end
		if self.field then
			self.field = self.field .. data
		else
			self.field = data
		end
	end
	
	--[[
	parser.onHeaderValue = function (b, start, len)
		local slice = b.toString("ascii", start, start + len)
		if parser.value then
			parser.value = parser.value .. slice
		else
			parser.value = slice
		end
	end
	--]]
	parser.onHeaderValue = function (self, data)
		if self.value then
			self.value = self.value .. data
		else
			self.value = data
		end
	end
	
	parser.onHeadersComplete = function (self, info)
		if self.field and self.value then
			self.incoming:_addHeaderLine(self.field, self.value)
			self.field = nil
			self.value = nil
		end
		
		self.incoming.httpVersionMajor = info.versionMajor
		self.incoming.httpVersionMinor = info.versionMinor
		self.incoming.httpVersion = info.versionMajor .. "." .. info.versionMinor
		
		if info.method then
			-- server only
			self.incoming.method = info.method
		else
			-- client only
			self.incoming.statusCode = info.statusCode
		end
		
		self.incoming.upgrade = info.upgrade
		
		local isHeadResponse = false
		
		if not info.upgrade then
			-- For upgraded connections, we'll emit this after parser.execute
			-- so that we can capture the first part of the new protocol
			isHeadResponse = self:onIncoming(self.incoming, info.shouldKeepAlive)
		end
		
		return isHeadResponse
	end
	
	parser.onBody = function (self, b, start, len)
		-- TODO: body encoding?
		--local slice = b.slice(start, start + len)
		local slice = b
		if self.incoming._decoder then
			local string = self.incoming._decoder:write(slice)
			if #string then self.incoming:_emit("data", string) end
		else
			self.incoming:_emit("data", slice)
		end
	end
	
	parser.onMessageComplete = function (self)
		self.incoming.complete = true
		if self.field and self.value then
			self.incoming:_addHeaderLine(self.field, self.value)
		end
		if not self.incoming.upgrade then
			-- For upgraded connections, also emit this after parser.execute
			self.incoming:_emit("end")
		end
	end
	
	return parser
end)







--
--
local function connectionListener (server, socket)
	LogDebug("SERVER new http connection")
	
	httpSocketSetup(socket)
	
	socket:setTimeout(2 * 60 * 1000)	-- 2 minute timeout
	socket:addListener("timeout", function (self)
		socket:destroy()
	end)
	
	local parser = parsers:alloc()
	parser:reinitialize("request")
	parser.socket = socket
	
	if server.secure then
		socket:setSecure(server.secureContext)
	end
	
	socket:addListener("error", function (self, e)
		server:emit("clientError", e)
	end)
	
	socket.ondata = function (self, d, start, finish)
		-- TODO: fixme
		start = start or 0
		finish = finish or #d
		local ret, err = parser:execute(d, start, finish - start)
		if not ret then
			socket:destroy()
		elseif parser.incoming and parser.incoming.upgrade then
			local bytesParsed = ret
			socket.ondata = nil
			socket.onend = nil
			
			local req = parser.incoming
			
			local upgradeHead = d:sub(bytesParsed + 1)
			
			if not server:emit("upgrade", req, req.socket, upgradeHead) then
				-- got upgrade header, but haven't catched it.
				socket:destroy()
			end
		end
	end
	
	socket.onend = function (self)
		parser:finish()
		
		if #socket._outgoing > 0 then
			socket._outgoing[#socket._outgoing]._last = true
			outgoingFlush(socket)
		else
			socket:finish()
		end
	end
	
	socket:addListener("close", function (self)
		-- unref the parser for easy gc
		parsers:free(parser)
		-- clean up data we may have stored in the parser
		parser.incoming = nil
		parser.field = nil
		parser.value = nil
		parser.socket = nil
		parser.onIncoming = nil
	end)
	
	-- At the end of each response message, after it has been flushed to the
	-- socket.  Here we insert logic about what to do next.
	socket._onOutgoingSent = function (self, message)
		local message = table.remove(socket._outgoing, 1)
		LogDebug("_onOutgoingSent: message._last = %s", message._last)
		if message._last then
			-- No more messages to be pushed out
			
			-- HACK: need way to do this with socket interface
			if #socket._writeQueue > 0 then
				socket.__destroyOnDrain = true
				socket._dont_read = true
			else
				-- TODO: si no cierro el socket, anda el test case "test-http-expect-continue" y "test-http-proxy"
				-- TODO: todo esto merece una revisada. Supuestamente esto es HTTP 1.1 y cierra la conexión a prepo !
				socket:destroy()
			end
		
		elseif #socket._outgoing > 0 then
			-- Push out the next message
			outgoingFlush(socket)
		end
	end
	
	-- The following callback is issued after the headers have been read on a
	-- new message. In this callback we setup the response object and pass it
	-- to the user.
	parser.onIncoming = function (self, req, shouldKeepAlive)
		local res = ServerResponse(req)
		LogDebug("server response shouldKeepAlive: %s", shouldKeepAlive)
		res.shouldKeepAlive = shouldKeepAlive
		socket._outgoing[#socket._outgoing + 1] = res
		
		if req.headers.expect and req.httpVersionMajor == 1 and req.httpVersionMinor == 1 and req.headers.expect:lower():match("100%-continue") then
			res._expect_continue = true
			if #server:listeners("checkContinue") > 0 then
				server:emit("checkContinue", req, res)
			else
				res:writeContinue()
				server:emit("request", req, res)
			end
		else
			server:emit("request", req, res)
		end
		return false	-- Not a HEAD response. (Not even a response!)
	end
end


-- Server Class
Server = Class.InheritsFrom(net.Server)

function Server:__init (requestListener)
	local newServer = Class.construct(Server)
	
	if requestListener then
		newServer:addListener("request", requestListener)
	end
	
	newServer:addListener("connection", connectionListener)

	return newServer
end

function Server:setSecure(context)
	self.secure = true
	self.secureContext = context
end

--
--
function createServer (requestListener)
	return Server(requestListener)
end




-- Client Class
Client = Class.InheritsFrom(net.Socket)

--
--
function Client:__init()
	local newClient = Class.construct(Client)
	
	-- Possible states:
	-- - disconnected
	-- - connecting
	-- - connected
	self._state = "disconnected"
	
	httpSocketSetup(newClient)
	
	local function onData (self, d, start, finish)
		if not self.parser then
			error("parser not initialized prior to Client.ondata call")
		end
		-- TODO: fixme
		start = start or 0
		finish = finish or #d
		local ret, err = self.parser:execute(d, start, finish - start)
		if not ret then
			LogDebug("parse error")
			newClient:destroy(err)
		elseif self.parser.incoming and self.parser.incoming.upgrade then
			-- TODO: fixme, esto esta mal, asume que cuando el parser ve el upgrade, los datos para el evento upgrade tambien fueron leidos
			-- Hay que empezar a acumular en algun lado
			local bytesParsed = ret
			newClient.ondata = nil
			newClient.onend = nil
			
			local req = self.parser.incoming
			local upgradeHead = d:sub(bytesParsed + 1)
			
			if not newClient:emit("upgrade", req, newClient, upgradeHead) then
				-- got upgrade header, but haven't catched it.
				newClient:destroy()
			end
		end
	end
	
	local function onEnd (self)
		if self.parser then
			self.parser:finish()
		end
		LogDebug("CLIENT got end closing. state = %s", newClient._state)
		newClient:finish()
	end
	
	newClient:addListener("connect", function (self)
		LogDebug("CLIENT connected")
		
		self.ondata = onData
		self.onend = onEnd
		
		self._state = "connected"
		
		if self.https then
			self:setSecure(self.secureContext)
		else
			self:_initParser()
			LogDebug("CLIENT requests: ")
			for k,v in pairs(self._outgoing or {}) do
				LogDebug(v.method)
			end
			outgoingFlush(self)
		end
	end)
	
	newClient:addListener("secure", function (self)
		self:_initParser()
		LogDebug('CLIENT requests: ')-- + util.inspect(self._outgoing));
		outgoingFlush(newClient)
	end)
	
	newClient:addListener("close", function (self, e)
		self._state = "disconnected"
		if e then return end
		
		LogDebug("CLIENT onClose. state = %s", newClient._state)
		
		-- finally done with the request
		table.remove(newClient._outgoing, 1)
		
		-- If there are more requests to handle, reconnect
		if #newClient._outgoing > 0 then
			newClient:_ensureConnection()
		elseif self.parser then
			parsers:free(self.parser)
			self.parser = nil
		end
	end)
		
	return newClient
end

--
--
function createClient (port, host, https, context)
	local c = Client()
	c.port = port
	c.host = host
	c.https = https
	c.secureContext = context
	
	return c
end

--
--
function Client:_initParser ()
	if not self.parser then
		self.parser = parsers:alloc()
	end
	self.parser:reinitialize("response")
	self.parser.socket = self
	self.parser.onIncoming = function (parser, res)
		LogDebug("incoming response!")
		
		local req = self._outgoing[1]
		
		-- Responses to HEAD requests are AWFUL. Ask Ryan.
		-- A major oversight in HTTP. Hence this nastiness.
		local isHeadResponse = (req.method == "HEAD")
		LogDebug("CLIENT isHeadResponse %s", tostring(isHeadResponse))
		
		if res.statusCode == 100 then
			-- restart the parser, as this is a continue message
			req:emit("continue")
			return true
		end
		
		if req.shouldKeepAlive and res.headers.connection == "close" then
			req.shouldKeepAlive = false
		end
		
		res:addListener("end", function (response)
			LogDebug("CLIENT request complete disconnecting. state = %s", self._state)
			-- For the moment we reconnect for every request. FIXME!
			-- All that should be required for keep-alive is to not reconnect,
			-- but outgoingFlush instead.
			if req.shouldKeepAlive then
				outgoingFlush(self)
				table.remove(self._outgoing, 1)
				outgoingFlush(self)
			else
				self:finish()
			end
		end)
		
		req:emit("response", res)
		
		return isHeadResponse
	end
end

--
-- This is called each time a request has been pushed completely to the
-- socket. The message that was sent is still sitting at client._outgoing[0]
-- it is our responsibility to shift it off.
--
-- We have to be careful when it we shift it because once we do any writes
-- to other requests will be flushed directly to the socket.
--
-- At the moment we're implement a client which connects and disconnects on
-- each request/response cycle so we cannot shift off the request from
-- client._outgoing until we're completely disconnected after the response
-- comes back.
function Client:_onOutgoingSent (message)
	-- We've just finished a message. We don't end/shutdown the connection here
	-- because HTTP servers typically cannot handle half-closed connections
	-- (Node servers can).
	--
	-- Instead, we just check if the connection is closed, and if so
	-- reconnect if we have pending messages.
	if #self._outgoing > 0 and self:readyState() == "closed" then
		LogDebug("CLIENT request flush. ensure connection.  state = %s", self._state)
		self:_ensureConnection()
	end
end

--
--
function Client:_ensureConnection ()
	if self._state == "disconnected" then
		LogDebug("CLIENT reconnecting state = %s", self._state)
		self:connect(self.port, self.host)
		self._state = "connecting"
	end
end

--
--
function Client:request (method, url, headers)
	if type(url) ~= "string" then
		-- assume method was omitted, shift arguments
		headers = url
		url = method
		method = "GET"
	end
	local req = ClientRequest(self, method, url, headers)
	self._outgoing[#self._outgoing + 1] = req
	if self:readyState() == 'closed' then
		self:_ensureConnection()
	end
	return req
end

--
--
function cat (url, encoding_, headers_, callback_)
	local encoding = "utf-8"
	local headers  = {}
	local callback

	-- parse the arguments for the various options... very ugly (indeed)
	if type(encoding_) == "string" then
		encoding = encoding_
		if type(headers_) == "table" then
			headers = headers_
			if type(callback_) == "function" then callback = callback_ end
		else
			if type(headers_) == "function" then callback = headers_ end
		end
	else
		-- didn't specify encoding
		if type(encoding_) == "table" then
			headers = encoding_
			callback = headers_
		else
			callback = encoding_
		end
	end

	local url = require("luanode.url").parse(url)

	local hasHost = false
	for k,v in pairs(headers) do
		if k:lower() == "host" then
			hasHost = true
			break
		end
	end
	
	if not hasHost then
		if not url.host then
			error("Missing host")
		end
		headers.Host = url.host
	end

	local content = ""

	local client = createClient(url.port or 80, url.host)
	local req = client:request((url.pathname or "/") .. (url.search or "") .. (url.hash or ""), headers)
	
	if url.protocol == "https:" then
		client.https = true
	end

	local callbackSent = false

	req:addListener("response", function (self, res)
		if res.statusCode < 200 or res.statusCode >= 300 then
			if callback and not callbackSent then
				callback(res, res.statusCode)
				callbackSent = true
			end
			client:finish()
			return
		end
		res:setEncoding(encoding)
		res:addListener("data", function (self, chunk)
			content = content .. chunk
		end)
		res:addListener("end", function (self)
			if callback and not callbackSent then
				callback(self, nil, content)
				callbackSent = true
			end
		end)
	end)

	client:addListener("error", function (self, err)
		if callback and not callbackSent then
			callback(self, err)
			callbackSent = true
		end
	end)

	client:addListener("close", function ()
		if callback and not callbackSent then
			callback(self, "Connection closed unexpectedly")
			callbackSent = true
		end
	end)
	req:finish()
end
