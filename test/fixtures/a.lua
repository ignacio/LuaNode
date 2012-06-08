common.debug("load fixtures/a.lua")

local str = "A"

local _M = {}

_M.SomeClass = c.SomeClass

_M.A = function()
	return str
end

_M.C = function()
	return c.C()
end

_M.D = function()
	return c.D()
end

_M.number = 42

process:on("exit", function()
	str = "A done"
end)

return _M
