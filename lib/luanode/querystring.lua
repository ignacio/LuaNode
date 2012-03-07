-- TODO: traerse esto para adentro
local Url = require "socket.url"

-- TODO: sacar el seeall
module(..., package.seeall)

-- Query String Utilities

--var QueryString = exports;
--var urlDecode = process.binding("http_parser").urlDecode;

--// a safe fast alternative to decodeURIComponent
--QueryString.unescape = urlDecode;

--QueryString.escape = function (str) {
--  return encodeURIComponent(str);
--};

--var stringifyPrimitive = function(v) {
--  switch (typeof v) {
--    case "string":
--      return v;
--
--    case "boolean":
--      return v ? "true" : "false";
--
--    case "number":
--      return isFinite(v) ? v : "";
--
--    default:
--      return "";
--  }
--};

--[[
/**
 * <p>Converts an arbitrary value to a Query String representation.</p>
 *
 * <p>Objects with cyclical references will trigger an exception.</p>
 *
 * @method stringify
 * @param obj {Variant} any arbitrary value to convert to query string
 * @param sep {String} (optional) Character that should join param k=v pairs together. Default: "&"
 * @param eq  {String} (optional) Character that should join keys to their values. Default: "="
 * @param name {String} (optional) Name of the current key, for handling children recursively.
 * @static
 */
QueryString.stringify = QueryString.encode = function (obj, sep, eq, name) {
  sep = sep || "&";
  eq = eq || "=";
  obj = (obj === null) ? undefined : obj;

  switch (typeof obj) {
    case "object":
      return Object.keys(obj).map(function(k) {
        if (Array.isArray(obj[k])) {
          return obj[k].map(function(v) {
            return QueryString.escape(stringifyPrimitive(k)) +
                   eq +
                   QueryString.escape(stringifyPrimitive(v));
          }).join(sep);
        } else {
          return QueryString.escape(stringifyPrimitive(k)) + 
                 eq +
                 QueryString.escape(stringifyPrimitive(obj[k]));
        }
      }).join(sep);

    default:
      return (name) ?
        QueryString.escape(stringifyPrimitive(name)) + eq +
          QueryString.escape(stringifyPrimitive(obj)) :
        "";
  }
};

// Parse a key=val string.
QueryString.parse = QueryString.decode = function (qs, sep, eq) {
  sep = sep || "&";
  eq = eq || "=";
  var obj = {};

  if (typeof qs !== 'string') {
    return obj;
  }

  qs.split(sep).forEach(function(kvp) {
    var x = kvp.split(eq);
    var k = QueryString.unescape(x[0], true);
    var v = QueryString.unescape(x.slice(1).join(eq), true);

    if (!(k in obj)) {
        obj[k] = v;
    } else if (!Array.isArray(obj[k])) {
        obj[k] = [obj[k], v];
    } else {
        obj[k].push(v);
    }
  });

  return obj;
};
--]]


--
-- Encodes the key-value pairs of a table according the application/x-www-form-urlencoded content type.
function url_encode_arguments(arguments)
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
function url_decode(str)
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
function url_encode(str)
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

function parse(qs, tab, overwrite)
  tab = tab or {}
  if type(qs) == "string" then
    local url_decode = url_decode
    for key, val in string.gmatch(qs, "([^&=]+)=([^&=]*)&?") do
      insert_field(tab, url_decode(key), url_decode(val), overwrite)
    end
  elseif qs then
    error("WSAPI Request error: invalid query string")
  end
  return tab
end