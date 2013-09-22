local Class = require "luanode.class"
local net = require "luanode.net"
local EventEmitter = require "luanode.event_emitter"
local stream = require "luanode.stream"
local FreeList = require "luanode.free_list"
local HTTPParser = process.HTTPParser
local Utils = require "luanode.utils"
local Url = require "luanode.url"

local END_OF_FILE = {}

-- TODO: sacar el seeall
module(..., package.seeall)

-- Classes exported by this module:
-- IncomingMessage
-- OutgoingMessage
-- ServerResponse
-- ClientRequest
-- Server
-- Client


local function parserOnMessageBegin (parser)
	parser.incoming = IncomingMessage(parser.socket)
	parser.field = nil
	parser.value = nil
end

local function parserOnURL (parser, data)
	if #parser.incoming.url ~= 0 then
		parser.incoming.url = parser.incoming.url .. data
	else
		-- Almost always will branch here
		parser.incoming.url = data
	end
end

local function parserOnHeaderField (parser, data)
	data = data:lower()
	if parser.value then
		parser.incoming:_addHeaderLine(parser.field, parser.value)
		parser.field = nil
		parser.value = nil
	end
	if parser.field then
		parser.field = parser.field .. data
	else
		parser.field = data
	end
end

local function parserOnHeaderValue (parser, data)
	if parser.value then
		parser.value = parser.value .. data
	else
		parser.value = data
	end
end

-- Only called in the slow case where slow means
-- that the request headers were either fragmented
-- across multiple TCP packets or too large to be
-- processed in a single run. This method is also
-- called to process trailing HTTP headers.
--[[
local function parserOnHeaders (parser, headers, url)
	-- Once we exceeded headers limit - stop collecting them
	if parser.maxHeaderPairs <= 0 or #parser._headers < parser.maxHeaderPairs then
		parser._headers = table.conact(parser._headers)
	end
	parser._url = parser._url .. url
	error()
end
--]]

-- info.headers and info.url are set only if .onHeaders()
-- has not been called for this request.
--
-- info.url is not set for response parsers but that's not
-- applicable here since all our parsers are request parsers.
local function parserOnHeadersComplete (parser, info)

	if parser.field and parser.value then
		parser.incoming:_addHeaderLine(parser.field, parser.value)
		parser.field = nil
		parser.value = nil
	end
	
	parser.incoming.httpVersionMajor = info.versionMajor
	parser.incoming.httpVersionMinor = info.versionMinor
	parser.incoming.httpVersion = info.versionMajor .. "." .. info.versionMinor
	
	if info.method then
		-- server only
		parser.incoming.method = info.method
	else
		-- client only
		parser.incoming.statusCode = info.statusCode
	end
	
	parser.incoming.upgrade = info.upgrade
	
	local skipBody = false	-- response to HEAD or CONNECT

	if not info.upgrade then
		-- For upgraded connections and CONNECT method request,
		-- we'll emit this after parser.execute
		-- so that we can capture the first part of the new protocol
		skipBody = parser:onIncoming(parser.incoming, info.shouldKeepAlive)
	end
	
	return skipBody
end

local function parserOnBody (parser, b, start, len)
	-- TODO: body encoding?
	--local slice = b.slice(start, start + len)
	local slice = b
	if parser.incoming._paused or #parser.incoming._pendings > 0 then
		parser.incoming._pendings[#parser.incoming._pendings + 1] = slice
	else
		parser.incoming:_emitData(slice)
	end
end

local function parserOnMessageComplete (parser)
	parser.incoming.complete = true

	-- deal with trailing headers
	if parser.field and parser.value then
		parser.incoming:_addHeaderLine(parser.field, parser.value)
	end

	if not parser.incoming.upgrade then
		-- For upgraded connections, also emit this after parser.execute
		if parser.incoming._paused or #parser.incoming._pendings > 0 then
			parser.incoming._pendings[#parser.incoming._pendings + 1] = END_OF_FILE
		else
			parser.incoming.readable = false
			parser.incoming:_emitEnd()
		end
	end

	if parser.socket.readable then
		-- force to read the next incoming message
		parser.socket:resume()
	end
end


parsers = FreeList.new("parsers", 1000, function ()
	local parser = HTTPParser("request")

	parser._headers = {}
	parser._url = ""
	
	--parser.onHeaders = parserOnHeaders
	parser.onHeadersComplete = assert(parserOnHeadersComplete)

	parser.onMessageBegin = assert(parserOnMessageBegin)
	parser.onURL = assert(parserOnURL)
	
	parser.onHeaderField = assert(parserOnHeaderField)
	parser.onHeaderValue = assert(parserOnHeaderValue)
	
	parser.onBody = assert(parserOnBody)
	parser.onMessageComplete = assert(parserOnMessageComplete)
	
	return parser
end)


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
	[505] = "HTTP Version Not Supported",
	[506] = "Variant Also Negotiates",			-- RFC 2295
	[507] = "Insufficient Storage",				-- RFC 4918
	[509] = "Bandwidth Limit Exceeded",
	[510] = "Not Extended",						-- RFC 2774,
	[511] = "Network Authentication Required"	-- RFC 6585
}


-- Abstract base class for ServerRequest and ClientResponse.
-- Public:
IncomingMessage = Class.InheritsFrom(stream.Stream)

function IncomingMessage:__init (socket)
	local newMessage = Class.construct(IncomingMessage)

	-- TODO: Remove one of these eventually.
	newMessage.socket = socket
	newMessage.connection = socket 	-- This is the preferred name

	newMessage.httpVersion = nil
	newMessage.complete = false
	newMessage.headers = {}
	newMessage.trailers = {}
	
	newMessage.readable = true

	newMessage._paused = false
	newMessage._pendings = {}

	newMessage._endEmitted = false

	-- request (server) only
	newMessage.url = ""

	newMessage.method = nil

	-- response (client) only
	newMessage.statusCode = nil
	newMessage.client = socket
	
	return newMessage
end

---
--
function IncomingMessage:destroy (err)
	if self.socket then
		self.socket:destroy(err)
	end
end

---
--
function IncomingMessage:setEncoding (encoding)
	-- TODO: implementar
	--local StringDecoder = nil--
	--var StringDecoder = require("string_decoder").StringDecoder; // lazy load
	--this._decoder = new StringDecoder(encoding);
end

---
--
function IncomingMessage:pause ()
	self._paused = true
	self.socket:pause()
end

---
--
function IncomingMessage:resume ()
	self._paused = false
	if self.socket then
		self.socket:resume()
	end

	self:_emitPending()
end

---
--
function IncomingMessage:_emitPending (callback)
	if #self._pendings > 0 then
		process.nextTick(function()
			while not self._paused and #self._pendings > 0 do
				local chunk = table.remove(self._pendings, 1)
				if chunk ~= END_OF_FILE then
					self:_emitData(chunk)
				else
					assert(#self._pendings == 0)
					self.readable = false
					self:_emitEnd()
				end
			end

			if callback then
				callback(self)
			end
		end)
	elseif callback then
		callback(self)
	end
end

---
--
function IncomingMessage:_emitData (data)
	if self._decoder then
		local string = self._decoder:write(data)
		if #string > 0 then self:emit("data", string) end
	else
		self:emit("data", data)
	end
end

---
--
function IncomingMessage:_emitEnd ()
	if not self._endEmitted then
		self:emit("end")
	end

	self._endEmitted = true
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
		["cookie"] = comma_separate,
		["pragma"] = comma_separate,
		["link"] = comma_separate,
		["www-authenticate"] = comma_separate,
		["proxy-authenticate"] = comma_separate,
		["sec-websocket-extensions"] = comma_separate,
		["sec-websocket-protocol"] = comma_separate
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
	
	newMessage.output = {}
	newMessage.outputEncodings = {}

	-- TODO Remove one of these eventually.
	--newMessage.socket = socket
	--newMessage.connection = socket
	
	newMessage.writable = true

	newMessage._last = false
	newMessage.chunkedEncoding = false
	newMessage.shouldKeepAlive = true
	newMessage.useChunkedEncodingByDefault = true
	newMessage.sendDate = false

	newMessage._hasBody = true
	newMessage._trailer = ""

	newMessage.finished = false
	newMessage._hangupClose = false
	
	return newMessage
end

---
--
function OutgoingMessage:destroy (err)
	if self.socket then
		self.socket:destroy(err)
	else
		self:once("socket", function(_, socket)
			socket:destroy(err)
		end)
	end
end

---
-- This abstracts either writing directly to the socket or buffering it.
function OutgoingMessage:_send (data, encoding)
	-- This is a shameful hack to get the headers and first body chunk onto
	-- the same packet. Future versions of Node (ehem, LuaNode :D) are going to take care of
	-- this at a lower level and in a more general way.
	if not self._headerSent then
		if type(data) == "string" then
			data = self._header .. data
		else
			table.insert(self.output, 1, self._header)
			table.insert(self.outputEncodings, 1, "ascii")
		end
		self._headerSent = true
	end
	
	return self:_writeRaw(data, encoding)
end

---
--
function OutgoingMessage:_writeRaw (data, encoding)
	if #data == 0 then
		return true
	end

	if  self.connection and
		self.connection._httpMessage == self and
		self.connection.writable and
		not self.connection.destroyed
	then
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

	elseif self.connection and self.connection.destroyed then
		-- The socket was destroyed.  If we're still trying to write to it,
		-- then something bad happened, but it could be just that we haven't
		-- gotten the 'close' event yet.
		--
		-- In v0.10 and later, this isn't a problem, since ECONNRESET isn't
		-- ignored in the first place.  We'll probably emit 'close' on the
		-- next tick, but just in case it's not coming, set a timeout that
		-- will emit it for us.
		if not self._hangupClose and not self.socket._hangupClose then
			local socket = self.socket
			socket._hangupClose = true
			self._hangupClose = true
			local timer = setTimeout(function()
				socket:emit("close")
			end)
			socket:once("close", function()
				clearTimeout(timer)
			end)
		end
		return false
	else
		-- buffer, as long as we're not destroyed
		self:_buffer(data, encoding)
		return false
	end
end

---
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

---
--
function OutgoingMessage:_storeHeader (firstLine, headers)
	local sentConnectionHeader = false
	local sentContentLengthHeader = false
	local sentTransferEncodingHeader = false
	local sentDateHeader = false
	local sentExpect = false

	-- firstLine in the case of request is: "GET /index.html HTTP/1.1\r\n"
	-- in the case of response it is: "HTTP/1.1 200 OK\r\n"
	local messageHeader = firstLine
	local field, value

	local function store(field, value)
		messageHeader = messageHeader .. field .. ": " .. value .. CRLF

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
		--local isArray = headers[1] ~= nil
		local isArray = Utils.isArray(headers)
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
	if self.sendDate and not sentDateHeader then
		messageHeader = messageHeader .. "Date: " .. os.date("!%a, %d %b %Y %H:%M:%S GMT") .. CRLF
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

---
--
function OutgoingMessage:setHeader (name, value)
	assert(name and value, "'name' and 'value' are required for setheader().")

	if self._header then
		error("Can't set headers after they are sent.")
	end

	local key = name:lower()
	self._headers = self._headers or {}
	self._headerNames = self._headerNames or {}
	self._headers[key] = value
	self._headerNames[key] = name
end

---
--
function OutgoingMessage:getHeader (name)
	assert(name, "'name' is required for getHeader().")

	if not self._headers then return end

	local key = name:lower()
	return self._headers[key]
end

---
--
function OutgoingMessage:removeHeader (name)
	assert(name, "'name' is required for removeHeader().")

	if self._header then
		error("Can't remove headers after they are sent.")
	end

	if not self._headers then return end

	local key = name:lower()
	self._headers[key] = nil
	self._headerNames[key] = nil
end

---
--
function OutgoingMessage:_renderHeaders ()
	if self._header then
		error("Can't render headers after they are sent to the client.")
	end

	if not self._headers then return {} end

	local headers = {}
	for key, value in pairs(self._headers) do
		headers[self._headerNames[key]] = self._headers[key]
	end
	return headers
end

---
--
function OutgoingMessage:write (chunk, encoding)
	if not self._header then
		self:_implicitHeader()
	end

	if not self._hasBody then
		console.error("This type of response MUST NOT have a body. Ignoring write() calls.")
		return true
	end

	-- TODO: fixme
	if type(chunk) ~= "string" then	--and
		--&& !Buffer.isBuffer(chunk)
		--throw new TypeError("first argument must be a string or Buffer");
		error("first argument must be a string or Buffer")
	end

	if #chunk == 0 then return false end

	local ret
	if self.chunkedEncoding then
		if type(chunk) == "string" then
			local chunk = ("%x"):format(#chunk) .. CRLF .. chunk .. CRLF
			--LogDebug('string chunk = ' .. util.inspect(chunk))
			ret = self:_send(chunk, encoding)
		else
			-- buffer
			self:_send( ("%x"):format(#chunk) .. CRLF)
			self:_send(chunk)
			ret = self:_send(CRLF)
		end
	else
		ret = self:_send(chunk, encoding)
	end

	LogDebug("write ret = %s", ret)
	return ret
end

---
--
function OutgoingMessage:addTrailers (headers)
	self._trailer = ""
	
	local field, value
	local isArray = Utils.isArray(headers)	-- headers[1] ~= nil
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

---
--
function OutgoingMessage:finish (data, encoding)
	if self.finished then
		return false
	end

	if not self._header then
		self:_implicitHeader()
	end

	if data and not self._hasBody then
		console.error("This type of response MUST NOT have a body. Ignoring data passed to finish().")
		data = false
	end

	local ret

	local hot = self._headerSent == false
				and type(data) == "string"
				and #data > 0
				and #self.output == 0
				and self.connection
				and self.connection.writable
				and self.connection._httpMessage == self

	if hot then
		-- Hot path. They're doing
		--   res.writeHead();
		--   res.end(blah);
		-- HACKY.
		
		if self.chunkedEncoding then
			local l = string.format("%x", #data)
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
			ret = self:_send("0\r\n" .. self._trailer .. "\r\n") -- Last chunk.
		else
			-- Force a flush, HACK.
			ret = self:_send("")
		end
	end

	self.finished = true

	-- There is the first message on the outgoing queue, and we've sent
	-- everything to the socket.
	LogDebug("outgoing message end.")
	if #self.output == 0 and self.connection._httpMessage == self then
		self:_finish()
	end

	return ret
end

---
--
function OutgoingMessage:_finish ()
	assert(self.connection)

	-- TODO: distinguir si esto en un ServerResponse o un ClientRequest
	self:emit("finish")
end

---
--
function OutgoingMessage:_flush ()
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
	-- This function, outgoingFlush(), is called by both the Server and Client
	-- to attempt to flush any pending messages out to the socket.

	if not self.socket then return end

	local ret

	while #self.output > 0 do
		if not self.socket.writable then return end -- XXX Necessary?

		local data = table.remove(self.output, 1)
		local encoding = table.remove(self.outputEncodings, 1)

		ret = self.socket:write(data, encoding)
	end

	if self.finished then
		-- This is a queue to the server or client to bring in the next this.
		self:_finish()
	elseif ret then
		-- This is necessary to prevent https from breaking
		message:emit('drain')
	end
end


---
--
ServerResponse = Class.InheritsFrom(OutgoingMessage)

function ServerResponse:__init (req)
	local newResponse = Class.construct(ServerResponse, req.socket)
	
	if req.method == "HEAD" then
		newResponse._hasBody = false
	end
	
	newResponse.sendDate = true
	
	if req.httpVersionMajor < 1 or req.httpVersionMinor < 1 then
		newResponse.useChunkedEncodingByDefault = false
		newResponse.shouldKeepAlive = false
	end

	newResponse.statusCode = 200
	
	return newResponse
end

local function onServerResponseClose (self)
	-- EventEmitter.emit makes a copy of the 'close' listeners array before
	-- calling the listeners. detachSocket() unregisters onServerResponseClose
	-- but if detachSocket() is called, directly or indirectly, by a 'close'
	-- listener, onServerResponseClose is still in that copy of the listeners
	-- array. That is, in the example below, b still gets called even though
	-- it's been removed by a:
	--
	--   var obj = new events.EventEmitter;
	--   obj.on('event', a);
	--   obj.on('event', b);
	--   function a() { obj.removeListener('event', b) }
	--   function b() { throw "BAM!" }
	--   obj.emit('event');  -- throws
	--
	-- Ergo, we need to deal with stale 'close' events and handle the case
	-- where the ServerResponse object has already been deconstructed.
	-- Fortunately, that requires only a single if check. :-)
	if self._httpMessage then
		self._httpMessage:emit("close")
	end
end

---
--
function ServerResponse:assignSocket (socket)
	--LogWarning("ServerResponse:assignSocket - %s - socket %s, response %s", socket._handle, socket, self)
	assert(not socket._httpMessage)
	socket._httpMessage = self
	socket:on("close", assert(onServerResponseClose))
	self.socket = socket
	self.connection = socket
	self:_flush()
end

---
--
function ServerResponse:detachSocket (socket)
	assert(socket._httpMessage == self)
	--LogWarning("ServerResponse:detachSocket - %s - socket %s, response %s", self.connection._handle, socket, self)
	socket:removeListener("close", assert(onServerResponseClose))
	socket._httpMessage = nil
	self.socket = nil
	self.connection = nil
end

---
--
function ServerResponse:writeContinue ()
	self:_writeRaw("HTTP/1.1 100 Continue" .. CRLF .. CRLF, "ascii")
	self._sent100 = true
end

---
--
function ServerResponse:_implicitHeader ()
	self:writeHead(self.statusCode)
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
	self.statusCode = statusCode
	
	headers = (type(headers) == "table" and headers) or {}
	local obj = headers

	if headers and self._headers then
		-- slow-case: when progressive API and header fields are passed
		headers = self:_renderHeaders()

		if obj[1] ~= nil then 	-- handle array case
			error("This is deprecated")
		else
			for k,v in pairs(obj) do
				headers[k] = obj[k]
			end
		end
	
	elseif (self._headers) then
		-- only progressive api is used
		headers  = self:_renderHeaders()
	else
		-- only writeHead() called
		headers = obj
	end
	
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



---
-- New Agent code.

-- The largest departure from the previous implementation is that
-- an Agent instance holds connections for a variable number of host:ports.
-- Surprisingly, this is still API compatible as far as third parties are
-- concerned. The only code that really notices the difference is the
-- request object.

-- Another departure is that all code related to HTTP parsing is in
-- ClientRequest.onSocket(). The Agent is now *strictly*
-- concerned with managing a connection pool.

---
--
Agent = Class.InheritsFrom(EventEmitter)

function Agent:__init (options)
	local new = Class.construct(Agent)

	new.options = options or {}
	new.requests = {}
	new.sockets = {}
	new.maxSockets = new.options.maxSockets or Agent.defaultMaxSockets
	new:on("free", function(_, socket, host, port, localAddress)
		local name = host .. ":" .. port
		if localAddress then
			name = name .. ":" .. localAddress
		end

		if not socket.destroyed and new.requests[name] and #new.requests[name] then
			local req = table.remove(new.requests[name], 1)
			req:onSocket(socket)
			if #new.requests[name] == 0 then
				-- don't leak
				new.requests[name] = nil
			end
		else
			-- If there are no pending requests just destroy the
			-- socket and it will get removed from the pool. This
			-- gets us out of timeout issues and allows us to
			-- default to Connection:keep-alive.
			socket:destroy()
		end
	end)
	new.createConnection = net.createConnection
	new.defaultPort = 80

	return new
end

Agent.defaultMaxSockets = 5

function Agent:addRequest (req, host, port, localAddress)
	local name = host .. ":" .. port
	if localAddress then
		name = name .. ":" .. localAddress
	end
	if not self.sockets[name] then
		self.sockets[name] = { length = 0 }
	end
	if self.sockets[name].length < self.maxSockets then
		-- If we are under maxSockets create a new one.
		req:onSocket(self:createSocket(name, host, port, localAddress, req))
	else
		-- We are over limit so we'll add it to the queue.
		if not self.requests[name] then
			self.requests[name] = {}
		end
		table.insert(self.requests[name], req)
	end
end

function Agent:createSocket (name, host, port, localAddress, req)
	local options = {}
	for k,v in pairs(self.options) do
		options[k] = v
	end
	
	options.port = port
	options.host = host
	options.localAddress = localAddress

	options.servername = host
	if req then
		local hostHeader = req:getHeader("host")
		if hostHeader then
			options.servername = hostHeader:gsub(":.*$", "") --.replace(/:.*$/, '')
		end
	end

	local socket = self.createConnection(options)
	if not self.sockets[name] then
		self.sockets[name] = { length = 0 }
	end
	self.sockets[name][socket] = socket
	self.sockets[name].length = self.sockets[name].length + 1
	--table.insert(self.sockets[name], socket)

	local function onFree ()
		self:emit("free", socket, host, port, localAddress)
	end
	socket:on("free", onFree)
	local function onClose (_, err)
		-- This is the only place where sockets get removed from the Agent.
		-- If you want to remove a socket from the pool, just close it.
		-- All socket errors end in a close event anyway.
		self:removeSocket(socket, name, host, port, localAddress)
	end
	socket:on("close", onClose)
	local function onRemove ()
		-- We need this function for cases like HTTP 'upgrade'
		-- (defined by WebSockets) where we need to remove a socket from the pool
		--  because it'll be locked up indefinitely
		self:removeSocket(socket, name, host, port, localAddress)
		socket:removeListener("close", onClose)
		socket:removeListener("free", onFree)
		socket:removeListener("agentRemove", onRemove)
	end
	socket:on("agentRemove", onRemove)
	return socket
end

---
--
function Agent:removeSocket (socket, name, host, port, localAddress)
	if self.sockets[name] then
		if self.sockets[name][socket] then
			self.sockets[name][socket] = nil
			self.sockets[name].length = self.sockets[name].length - 1
		end
		--local index = self.sockets[name].indexOf(socket)
		--if index ~= -1 then
			--self.sockets[name].splice(index, 1)
			--if #self.sockets[name] == 0 then
			if self.sockets[name].length == 0 then
				self.sockets[name].length = nil
				assert(not next(self.sockets[name]) )	-- no more sockets there
				-- don't leak
				self.sockets[name] = nil
			end
		--end
	end
	if self.requests[name] and #self.requests[name] then
		local req = self.requests[name][1]
		-- If we have pending requests and a socket gets closed a new one
		self:createSocket(name, host, port, localAddress, req):emit("free")
	end
end

local agent = Agent()
globalAgent = agent

---
--
ClientRequest = Class.InheritsFrom(OutgoingMessage)

--
--
--function ClientRequest:__init (socket, method, url, headers)
function ClientRequest:__init (options, callback)
	local newRequest = Class.construct(ClientRequest) --local newRequest = Class.construct(ClientRequest, socket)
	
	newRequest.agent = (options.agent == nil and globalAgent) or options.agent

	local defaultPort = options.defaultPort or 80

	local port = options.port or defaultPort
	local host = options.hostname or options.host or "localhost"

	local setHost
	if not options.setHost then
		setHost = true
	end

	newRequest.socketPath = options.socketPath

	local method = (options.method or "GET"):upper()
	newRequest.method = method

	newRequest.path = options.path or "/"
	if callback then
		newRequest:once("response", callback)
	end

	if options.headers then
		if Utils.isArray(options.headers) then
			for _,v in ipairs(options.headers) do
				newRequest:setHeader(v[1], v[2])
			end
		else
			for k,v in pairs(options.headers) do
				newRequest:setHeader(k, v)
			end
		end
	end
	if host and not newRequest:getHeader("host") and setHost then
		local hostHeader = host
		if port and port ~= defaultPort then
			hostHeader = hostHeader .. ":" .. port
		end
		newRequest:setHeader("Host", hostHeader)
	end

	if options.auth and not newRequest:getHeader("Authorization") then
		-- basic auth
		error("falta implementar la conversion a base64")
		newRequest:setHeader("Authorization", "Basic " .. options.auth)
	end

	if method == "GET" or method == "HEAD" or method == "CONNECT" then
		newRequest.useChunkedEncodingByDefault = false
	else
		newRequest.useChunkedEncodingByDefault = true
	end

	--if options.headers and options.headers[1] ~= nil then -- array?
	if Utils.isArray(options.headers) then
		newRequest:_storeHeader(newRequest.method .. " " .. newRequest.path .. " HTTP/1.1\r\n", options.headers)

	elseif newRequest:getHeader("expect") then
		newRequest:_storeHeader(newRequest.method .. " " .. newRequest.path .. " HTTP/1.1\r\n", newRequest:_renderHeaders())
	end

	if newRequest.socketPath then
		newRequest._last = true
		newRequest.shouldKeepAlive = false
		if options.createConnection then
			newRequest:onSocket(options.createConnection(newRequest.socketPath))
		else
			newRequest:onSocket(net.createConnection(newRequest.socketPath))
		end
	
	elseif newRequest.agent then
		-- If there is an agent we should default to Connection:keep-alive
		newRequest._last = false
		newRequest.shouldKeepAlive = true
		newRequest.agent:addRequest(newRequest, host, port, options.localAddress)

	else
		-- No agent, default to Connection:close.
		local conn
		newRequest._last = true
		newRequest.shouldKeepAlive = false
		if options.createConnection then
			options.port = port
			options.host = host
			conn = options.createConnection(options)
		else
			conn = net.createConnection({
				port = port,
				host = host,
				localAddress = options.localAddress
			})
		end
		newRequest:onSocket(conn)
	end

	newRequest:_deferToConnect(nil, function()
		newRequest:_flush()
		newRequest = nil
	end)

	return newRequest

	--[[


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
	--]]
end

---
--
function ClientRequest:_implicitHeader ()
	self:_storeHeader( self.method .. " " .. self.path .. " HTTP/1.1\r\n", self:_renderHeaders() )
end

function ClientRequest:abort ()
	if self.socket then
		-- in-progress
		self.socket:destroy()
	else
		-- haven't been assigned a socket yet.
		-- this could be more efficient, it could
		-- remove itself from the pending requests
		self._deferToConnect("destroy")
	end
end


--[[
--
--
function ClientRequest:finish (...)
	-- TODO: no agregar este método y que se llame directamente a la base
	return OutgoingMessage.finish(self, ...)
end
--]]

--
--
--[=[
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
--]=]


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





local function createHangUpError ()
	local err_msg = "socket hang up"
	local err_code = process.constants.ECONNRESET

	return err_msg, err_code
end



---
-- Free the parser and also break any links that it
-- might have to any other things.
-- TODO: All parser data should be attached to a
-- single object, so that it can be easily cleaned
-- up by doing `parser.data = {}`, which should
-- be done in FreeList.free.  `parsers.free(parser)`
-- should be all that is needed.
--
local function freeParser(parser, req)
	if parser then
		parser._headers = {}
		parser.onIncoming = nil
		if parser.socket then
			parser.socket.onend = nil
			parser.socket.ondata = nil
			parser.socket.parser = nil
		end
		-- clean up data we may have stored in the parser
		parser.socket = nil
		parser.incoming = nil
		-- unref the parser for easy gc
		parsers:free(parser)
		parser = nil
	end
	if req then
		req.parser = nil
	end
end
		-- unref the parser for easy gc
		--parsers:free(parser)
		-- clean up data we may have stored in the parser
		--parser.incoming = nil
		--parser.field = nil
		--parser.value = nil
		--parser.socket = nil
		--parser.onIncoming = nil

---
--
local function socketCloseListener (socket)

	local parser = socket.parser
	local req = socket._httpMessage
	LogDebug("HTTP socket close")
	req:emit("close")

	if req.res and req.res.readable then
		-- Socket closed before we emitted the 'end' below
		req.res:emit("aborted")
		local res = req.res
		req.res:_emitPending(function()
			res:_emitEnd()
			res:emit("close")
			res = nil
		end)

	elseif not req.res and not req._hadError then
		-- This socket error fired before we started to
		-- receive a response. The error needs to
		-- fire on the request
		req:emit("error", createHangUpError())
		req._hadError = true
	end

	-- Too bad. That output wasn't getting written.
	-- This is pretty terrible that it doesn't rise an error.
	-- Fixed better in Node.js v0.10
	if req.output then
		req.output = {}
	end

	if req.outputEncodings then
		req.outputEncodings = {}
	end

	if parser then
		parser:finish()
		freeParser(parser, req)
	end
end

local function socketErrorListener (socket, err, err_code)
	local parser = socket.parser
	local req = socket._httpMessage
	LogDebug("HTTP SOCKET ERROR: %s\n%s", err.message, err.stack)

	if req then
		req:emit("error", err, err_code)
		-- For safety. Some additional error might fire later on
		-- and we need to make sure we don't double-fire the error event.
		req._hadError = true
	end

	if parser then
		parser:finish()
		freeParser(parser, req)
	end
	socket:destroy()
end

local function socketOnEnd (socket)
	local req = socket._httpMessage
	local parser = socket.parser

	if not req.res then
		-- If we don't have a response then we know that the socket
		-- ended prematurely and we need to emit an error on the request.
		req:emit("error", createHangUpError())
		req._hadError = true
	end
	if parser then
		parser:finish()
		freeParser(parser, req)
	end
	socket:destroy()
end

local function socketOnData (socket, d, start, finish)
	local req = socket._httpMessage
	local parser = socket.parser

	start = start or 0
	finish = finish or #d

	local ret, err = parser:execute(d, start, finish - start)
	if not ret then
		LogDebug("parse error")
		freeParser(parser, req)
		socket:destroy()
		req:emit("error", err or "parse error")
		req._hadError = true

	elseif parser.incoming and parser.incoming.upgrade then
		-- Upgrade or CONNECT
		local bytesParsed = ret
		local res = parser.incoming
		req.res = res
		
		socket.ondata = nil
		socket.onend = nil
		parser:finish()

		-- This is start + byteParsed
		local bodyHead = d:sub(bytesParsed + 1)

		local eventName = (req.method == "CONNECT" and "connect") or "upgrade"
		if #req:listeners(eventName) > 0 then
			req.upgradeOrConnect = true
			-- detach the socket
			socket:emit("agentRemove")
			socket:removeListener("close", socketCloseListener)
			socket:removeListener("error", socketErrorListener)

			req:emit(eventName, res, socket, bodyHead)
			req:emit("close")
		else
			-- Got upgrade header or CONNECT method, but have no handler.
			socket:destroy()
		end
		freeParser(parser, req)
	
	elseif parser.incoming and parser.incoming.complete and parser.incoming.statusCode ~= 100 then
		-- When the status code is 100 (Continue), the server will
		-- send a final response after this client sends a request
		-- body. So, we must not free the parser.
		freeParser(parser, req)
	end
end

local function responseOnEnd (res)
	local req = res.req
	local socket = req.socket

	if not req.shouldKeepAlive then
		if socket.writable then
			LogDebug("AGENT socket.destroySoon()")
			socket:destroySoon()
		end
		assert(not socket.writable)
	else
		LogDebug("AGENT socket keep-alive")
		if req.timeoutCb then
			socket:setTimeout(0, req.timeoutCb)
			req.timeoutCb = nil
		end
		socket:removeListener("close", socketCloseListener)
		socket:removeListener("error", socketErrorListener)
		socket:emit("free")
	end
end

local function parserOnIncomingClient (parser, res, shouldKeepAlive)
	local socket = parser.socket
	local req = socket._httpMessage

	-- propagate "domain" setting...
	if req.domain and not res.domain then
		LogDebug("setting 'res.domain'")
		res.domain = req.domain
	end

	LogDebug("AGENT incoming response!")

	if req.res then
		-- We already have a response object, this means the server
		-- sent a double response
		socket:destroy()
		return
	end
	req.res = res

	-- Responses to CONNECT request is handled as Upgrade
	if req.method == "CONNECT" then
		res.upgrade = true
		return true	-- skip body
	end

	-- Responses to HEAD requests are crazy.
	-- HEAD responses aren't allowed to have an entity-body
	-- but *can* have a content-length which actually corresponds
	-- to the content-length of the entity-body had the request
	-- been a GET
	local isHeadResponse = req.method == "HEAD"
	LogDebug("AGENT isHeadResponse %s", isHeadResponse)

	if res.statusCode == 100 then
		-- restart the parser, as this is a continue message
		req.res = nil	-- Clear res so that we don't hit double-responses.
		req:emit("continue")
		return true
	end

	if req.shouldKeepAlive and not shouldKeepAlive and not req.upgradeOrConnect then
		-- Server MUST respond with Connection:keep-alive for us to enable it.
		-- If we've been upgraded (via WebSocket) we also shouldn't try to
		-- keep the connection open.
		req.shouldKeepAlive = false
	end

	req:emit("response", res)
	req.res = res
	res.req = req

	res:on("end", assert(responseOnEnd))

	return isHeadResponse
end

---
--
function ClientRequest:onSocket (socket)
	local req = self

	process.nextTick(function()
		local parser = parsers:alloc()
		req.socket = socket
		req.connection = socket
		parser:reinitialize("response")
		parser.socket = socket
		parser.incoming = nil
		req.parser = parser

		socket.parser = parser
		socket._httpMessage = req

		-- Setup "drain" propagation
		httpSocketSetup(socket)

		-- Propagate headers limit from request object to parser
		if type(req.maxHeadersCount) == "number" then
			parser.maxHeaderPairs = req.maxHeadersCount * 2
		else
			-- Set default value because parser may be reused from FreeList
			parser.maxHeaderPairs = 2000
		end

		socket:on("error", assert(socketErrorListener))
		socket.ondata = assert(socketOnData)
		socket.onend = assert(socketOnEnd)
		socket:on("close", assert(socketCloseListener))
		parser.onIncoming = assert(parserOnIncomingClient)
		req:emit("socket", socket)
	end)
end

---
--
--function ClientRequest:_deferToConnect (method, arguments_, cb)
function ClientRequest:_deferToConnect (method, ...)
	-- This function is for calls that need to happen once the socket is
	-- connected and writable. It's an important promisy thing for all the socket
	-- calls that happen either now (when a socket is assigned) or
	-- in the future (when a socket gets assigned out of the pool and is
	-- eventually writable).
	local arguments = Utils.pack(...)
	
	local cb = arguments[arguments.n]
	if type(cb) ~= "function" then
		cb = nil
	end

	local function onSocket( )
		if self.socket.writable then
			if method then
				self.socket[method](self.socket, unpack(arguments, arguments.n))
			end
			if cb then
				cb()
			end
		else
			self.socket:once("connect", function()
				if method then
					self.socket[method](self.socket, unpack(arguments, arguments.n))
				end
				if cb then
					cb()
				end
			end)
		end
	end

	if not self.socket then
		self:once("socket", onSocket)
	else
		onSocket()
	end
end

---
--
function ClientRequest:setTimeout (msecs, callback)
	if callback then
		self:once("timeout", callback)
	end

	local function emitTimeout()
		self:emit("timeout")
	end

	if self.socket and self.socket.writable then
		if self.timeoutCb then
			self.socket.setTimeout(0, self.timeoutCb)
		end
		self.timeoutCb = emitTimeout
		self.socket:setTimeout(msecs, emitTimeout)
		return
	end

	if self.socket then
		self.socket:once("connect", function()
			self:setTimeout(msecs, emitTimeout)
		end)
		return
	end

	self:once("socket", function(_, sock)
		self:setTimeout(msecs, emitTimeout)
	end)
end

function ClientRequest:setNoDelay (...)
	self:_deferToConnect("setNoDelay", ...)
end

function ClientRequest:setSocketKeepAlive (...)
	self:_deferToConnect("setKeepAlive", ...)
end

function ClientRequest:clearTimeout (cb)
	self:setTimeout(0, cb)
end

--
-- public
request = function(options, cb)
	if type(options) == "string" then
		options = Url.parse(options)
	end

	if options.protocol and options.protocol ~= "http:" then
		error("Protocol: " .. options.protocol .. " not supported.")
	end
	return ClientRequest(options, cb)
end

--
-- public
get = function(options, cb)
	local req = request(options, cb)
	req:finish()
	return req
end

local function ondrain (self)
	if self._httpMessage then
		self._httpMessage:emit("drain")
	end
end

local function httpSocketSetup (socket)
	socket:removeListener("drain", ondrain)
	socket:on("drain", ondrain)
end



--
--
local function connectionListener (server, socket)

	local outgoing = {}
	local incoming = {}

	local function abortIncoming ()
		while #incoming > 0 do
			local req = table.remove(incoming, 1)
			req:emit("aborted")
			req:emit("close")
		end
		-- abort socket._httpMessage ?
	end

	local function serverSocketCloseListener (socket)
		LogDebug("server socket close")
		-- mark this parser as reusable
		if socket.parser then
			freeParser(socket.parser)
		end
		abortIncoming()
	end

	LogDebug("SERVER new http connection")
	
	httpSocketSetup(socket)
	
	socket:setTimeout(2 * 60 * 1000)	-- 2 minute timeout
	socket:once("timeout", function (self)
		socket:destroy()
	end)
	
	local parser = parsers:alloc()
	parser:reinitialize("request")
	parser.socket = socket
	socket.parser = parser
	parser.incoming = nil
	
	-- Propagate headers limit from server instance to parser
	if type(socket.maxHeadersCount) == "number" then
		parser.maxHeaderPairs = server.maxHeadersCount * 2
	else
		-- Set default value because parser may be reused from FreeList
		parser.maxHeaderPairs = 2000
	end

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
			LogDebug("parse error in:\n%s", d)
			socket:destroy(err)

		elseif parser.incoming and parser.incoming.upgrade then
			-- Upgrade or CONNECT
			local bytesParsed = ret
			local req = parser.incoming
			
			socket.ondata = nil
			socket.onend = nil
			socket:removeListener("close", serverSocketCloseListener)
			parser:finish()
			freeParser(parser, req)
			
			local bodyHead = d:sub(bytesParsed + 1)

			local eventName = (req.method == "CONNECT" and "connect") or "upgrade"
			if #server:listeners(eventName) > 0 then
				server:emit(eventName, req, req.socket, bodyHead)
			else
				-- Got upgrade header or CONNECT method, but have no handler.
				socket:destroy()
			end
		end
	end
	
	socket.onend = function (self)
		local err = parser:finish()
		
		if err then
			LogDebug("parse error", err)
			socket:destroy(err)
			return
		end

		if not server.httpAllowHalfOpen then
			abortIncoming()
			if socket.writable then
				socket:finish()
			end

		elseif #outgoing > 0 then
			outgoing[#outgoing]._last = true

		elseif socket._httpMessage then
			socket._httpMessage._last = true
		
		else
			if socket.writable then
				socket:finish()
			end
		end
	end

	socket:addListener("close", serverSocketCloseListener)
	
	--[[
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
	--]]
	
	-- At the end of each response message, after it has been flushed to the
	-- socket.  Here we insert logic about what to do next.
	--[[
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
	--]]
	
	-- The following callback is issued after the headers have been read on a
	-- new message. In this callback we setup the response object and pass it
	-- to the user.
	parser.onIncoming = function (self, req, shouldKeepAlive)
		incoming[#incoming + 1] = req

		local res = ServerResponse(req)
		LogDebug("server response shouldKeepAlive: %s", shouldKeepAlive)
		res.shouldKeepAlive = shouldKeepAlive

		if socket._httpMessage then
			-- There are already pending outgoing res, append.
			outgoing[#outgoing + 1] = res
		else
			res:assignSocket(socket)
		end

		-- When we're finished writing the response, check if this is the last
		-- respose, if so destroy the socket.
		res:on("finish", function()
			-- Usually the first incoming element should be our request.  it may
			-- be that in the case abortIncoming() was called that the incoming
			-- array will be empty.
			assert(#incoming == 0 or incoming[1] == req)

			table.remove(incoming, 1)

			res:detachSocket(socket)

			if res._last then
				socket:destroySoon()
			else
				-- start sending the next message
				local m = table.remove(outgoing, 1)
				if m then
					m:assignSocket(socket)
				end
			end
		end)
		
		if req.headers.expect and
			(req.httpVersionMajor == 1 and req.httpVersionMinor == 1) and
			req.headers.expect:lower():match("100%-continue")
		then
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
--
-- public
_connectionListener = connectionListener


-- Server Class
Server = Class.InheritsFrom(net.Server)

function Server:__init (requestListener)
	local newServer = Class.construct(Server, { allowHalfOpen = true })
	
	if requestListener then
		newServer:addListener("request", requestListener)
	end
	
	-- Similar option to this. Too lazy to write my own docs.
	-- http://www.squid-cache.org/Doc/config/half_closed_clients/
	-- http://wiki.squid-cache.org/SquidFaq/InnerWorkings#What_is_a_half-closed_filedescriptor.3F
	newServer.httpAllowHalfOpen = false

	newServer:addListener("connection", assert(connectionListener))

	return newServer
end

function Server:setSecure (context)
	self.secure = true
	self.secureContext = context
end

--
--
function createServer (requestListener)
	return Server(requestListener)
end

-- Legacy Interface
Client = Class.InheritsFrom(EventEmitter)

function Client:__init (port, host)
	console.warn("http.Client will be removed soon. Do not use it.")

	local newClient = Class.construct(Client)

	host = host or "localhost"
	port = port or 80

	newClient.host = host
	newClient.port = port
	newClient.agent = Agent({ host = host, port = port, maxSockets = 1 })

	return newClient
end

function Client:request (method, path, headers)
	local options = {}

	options.host = self.host
	options.port = self.port
	if method:sub(1,1) == "/" then
		headers = path
		path = method
		method = "GET"
	end
	options.method = method
	options.path = path
	options.headers = headers
	options.agent = self.agent
	local c = ClientRequest(options)
	c:on("error", function(_, e, ...)
		self:emit("error", e, ...)
	end)
	-- The old Client interface emitted 'end' on socket end.
	-- This doesn't map to how we want things to operate in the future
	-- but it will get removed when we remove this legacy interface.
	c:on("socket", function(_, s)
		if self.https then
			s.secure = true
			function self:verifyPeer()
				return s:verifyPeer()
			end
			function self:getPeerCertificate()
				return s:getPeerCertificate()
			end
		end
		s:on("connect", function()
			if self.https then
				s:setSecure(self.secureContext)
			end
			self:emit("connect")
		end)

		s:on("secure", function()
			self:emit("secure")
		end)

		s:on("end", function()
			self:emit("end")
		end)
	end)
	return c
end

function Client:finish()
	-- noop
end


function createClient (port, host, https, context)
	console.warn("http.createClient is deprecated. Use 'http.request' instead.")
	local c = Client(port, host)
	c.port = port
	c.host = host
	c.https = https
	c.secureContext = context
	
	return c
end

--[=[
-- Client Class
Client = Class.InheritsFrom(net.Socket)

--
--
function Client:__init ()
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
--]=]
--
--
--[[
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
--]]
