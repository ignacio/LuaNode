local debug = debug
local type = type
local path = require "luanode.path"

module((...))

--
-- Returns the directory name of the script that contains the given function or the caller script or nil if 
-- the function can't be resolved to any file.
function dirname(fun)
	fun = (type(fun) ~= "function" and 2) or fun
	local dirname = debug.getinfo(fun, "S").source:match("^@(.+)")
	if not dirname then return nil end
	return path.dirname( dirname )
end

--
-- Returns the full name of the script that contains the given function or the caller script or nil if 
-- the function can't be resolved to any file.
function filename(fun)
	fun = (type(fun) ~= "function" and 2) or fun
	local filename = debug.getinfo(fun, "S").source:match("^@(.+)")
	return filename
end