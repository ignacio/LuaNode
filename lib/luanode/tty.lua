local pairs, require, process, Stdio = pairs, require, process, Stdio

module((...))

local tty
if process.platform == "windows" then
	tty = require "luanode.tty_win"
else
	tty = require "luanode.tty_posix"
end

for k,v in pairs(tty) do
	if k ~= "_NAME" and k ~= "_M" and k ~= "_PACKAGE" then
		_M[k] = v
	end
end

_M.isatty = function (fd)
	return Stdio.isatty(fd)
end

_M.setRawMode = function (flag)
	if process.platform == "windows" then
		Stdio.setRawMode(flag)
	else
		tty.setRawMode(flag)
	end
end

_M.getWindowSize = function ()
	return Stdio.getWindowSize()
end

_M.setWindowSize = function ()
	--Stdio.setWindowSize()
end

return _M
