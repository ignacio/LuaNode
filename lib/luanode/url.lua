local assert = assert

if process.platform == "windows" then
	--require "luarocks.require"
	-- TODO: traerse esto para adentro
end
local Url = require "socket.url"

-- TODO: sacar el seeall
module(..., package.seeall)



function parse (url, parseQueryString, slashesDenoteHost)
	local parsed = Url.parse(url)
	parsed.href = url
	parsed.pathname = parsed.path
	parsed.protocol = (parsed.scheme and parsed.scheme .. ":")
	
	if parsed.fragment then
		parsed.hash = "#"..parsed.fragment
	end
	
	return parsed
end

function format (parsed_url)
	if not parsed_url.scheme then
		parsed_url.scheme = parsed_url.protocol
	end
	return Url.build(parsed_url)
end

function resolve (source, relative)
end

function resolveObject (source, relative)
end

function parseHost (host)
end