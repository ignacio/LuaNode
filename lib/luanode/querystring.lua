local Url = require "luanode.__private_url"

local _M = {
	_NAME = "luanode.querystring",
	_PACKAGE = "luanode."
}

--
-- Encodes the key-value pairs of a table according the application/x-www-form-urlencoded content type.
function _M.url_encode_arguments(arguments)
	local body = {}
	for k,v in pairs(arguments) do
		body[#body + 1] = Url.escape(tostring(k)) .. "=" .. Url.escape(tostring(v))
	end
	return table.concat(body, "&")
end


-- Taken from wsapi (TODO: add proper attribution)
----------------------------------------------------------------------------
-- Decode an URL-encoded string (see RFC 2396)
----------------------------------------------------------------------------
function _M.url_decode(str)
	if not str then return nil end
	str = string.gsub (str, "+", " ")
	str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
	str = string.gsub (str, "\r\n", "\n")
	return str
end

-- Taken from wsapi (TODO: add proper attribution)
----------------------------------------------------------------------------
-- URL-encode a string (see RFC 2396)
----------------------------------------------------------------------------
function _M.url_encode(str)
	if not str then return nil end
	str = string.gsub (str, "\n", "\r\n")
	str = string.gsub (str, "([^%w ])",
		function (c) return string.format ("%%%02X", string.byte(c)) end)
	str = string.gsub (str, " ", "+")
	return str
end


-- Taken from wsapi (TODO: add proper attribution)

local function insert_field (tab, name, value, overwrite)
	if overwrite or not tab[name] then
		tab[name] = value
	else
		local t = type (tab[name])
		if t == "table" then
			table.insert (tab[name], value)
		else
			tab[name] = { tab[name], value }
		end
	end
end

function _M.parse(qs, tab, overwrite)
	tab = tab or {}
	if type(qs) == "string" then
		local url_decode = _M.url_decode
		for key, val in string.gmatch(qs, "([^&=]+)=([^&=]*)&?") do
			insert_field(tab, url_decode(key), url_decode(val), overwrite)
		end
	elseif qs then
		error("luanode.querystring.parse: invalid query string")
	end
	return tab
end

return _M
