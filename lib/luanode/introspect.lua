local _M = {
	_NAME = "luanode.introspect",
	_PACKAGE = "luanode."
}

-- Make LuaNode 'public' modules available as globals.
luanode.introspect = _M

_M.counters = { net = {}, crypto = {} }

-- this table will be populated with C functions defined in LuaNode core itself
process.__internal.populate_introspect_counters(_M)

process.__internal.populate_introspect_counters = nil

---
-- See what data is around. Walks the VM and returns a table with a summary of what has been found.
--
function _M.dump_vm (options)
	options = options or {}
	-- options.ignore is an optional array with stuff to exclude when dumping stats
	return (require("luanode.__private_luastate")).dump_stats(options)
end

return _M
