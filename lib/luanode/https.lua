local Tls = require "luanode.tls"
local Http = require "luanode.http"
local Url = require "luanode.url"
local Class = require "luanode.class"

local _M = {
	_NAME = "luanode.https",
	_PACKAGE = "luanode."
}

-- Make LuaNode 'public' modules available as globals.
luanode.https = _M

-- Classes exported by this module:
-- Server
-- Agent


-- Server Class
local Server = Class.InheritsFrom(Tls.Server)

--
-- public
_M.Server = Server

function Server:__init (options, requestListener)
	local newServer = Class.construct(Server, options, Http._connectionListener)

	if requestListener then
		newServer:on("request", requestListener)
	end
	
	-- Similar option to this. Too lazy to write my own docs.
	-- http://www.squid-cache.org/Doc/config/half_closed_clients/
	-- http://wiki.squid-cache.org/SquidFaq/InnerWorkings#What_is_a_half-closed_filedescriptor.3F
	newServer.httpAllowHalfOpen = false

	newServer:on("clientError", function(self, err, conn)
		conn:destroy(err)
	end)

	return newServer
end

--
-- public
_M.createServer = function (options, requestListener)
	return Server(options, requestListener)
end


---
-- HTTPS Agents.
--

local function createConnection (options)
	return Tls.connect(options)
end

local Agent = Class.InheritsFrom(Http.Agent)
--
-- public
_M.Agent = Agent

function Agent:__init (options)
	local newAgent = Class.construct(Agent, options)
	newAgent.createConnection = createConnection
	newAgent.defaulPort = newAgent.defaulPort or 443
	return newAgent
end

--
-- public
local globalAgent = Agent()
_M.globalAgent = globalAgent

--
-- public
_M.request = function (options, cb)
	if type(options) == "string" then
		options = Url.parse(options)
	end

	if options.protocol and options.protocol ~= "https:" then
		error("Protocol: " .. options.protocol .. " not supported.")
	end

	options.defaultPort = options.defaultPort or 443
	options.createConnection = createConnection

	if options.agent == nil then
		if  options.ca == nil and
			options.cert == nil and
			options.ciphers == nil and
			options.key == nil and
			options.passphrase == nil and
			options.pfx == nil and
			options.rejectUnauthorized == nil
		then
			options.agent = globalAgent
		else
			options.agent = Agent(options)
		end

	end

	return Http.ClientRequest(options, cb)
end

--
-- public
_M.get = function (options, cb)
	local req = _M.request(options, cb)
	req:finish()
	return req
end

return _M
