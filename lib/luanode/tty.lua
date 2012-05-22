local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"

-- TODO: sacar el seeall
module(..., package.seeall)

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

_M.isatty = Stdio.isatty
_M.setRawMode = Stdio.setRawMode
_M.getWindowSize = Stdio.getWindowSize
_M.setWindowSize = Stdio.setWindowSize

return _M