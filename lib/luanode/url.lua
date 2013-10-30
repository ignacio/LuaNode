local Url = require "luanode.__private_url"

local _M = {
	_NAME = "luanode.url",
	_PACKAGE = "luanode."
}

-- Make LuaNode 'public' modules available as globals.
luanode.url = _M

function _M.parse (url, parseQueryString, slashesDenoteHost)
	local parsed = Url.parse(url)
	parsed.href = url
	parsed.pathname = parsed.path
	parsed.protocol = (parsed.scheme and parsed.scheme .. ":")
	
	if parsed.fragment then
		parsed.hash = "#"..parsed.fragment
	end
	
	return parsed
end

function _M.format (parsed_url)
	if not parsed_url.scheme then
		parsed_url.scheme = parsed_url.protocol
	end
	return Url.build(parsed_url)
end

function _M.resolve (source, relative)
end

function _M.resolveObject (source, relative)
end

function _M.parseHost (host)
end

return _M
