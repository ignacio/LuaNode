package = "StackTracePlus"
version = "0.1.0-1"
source = {
	url = "https://github.com/ignacio/StackTracePlus/archive/0.1.0-1.tar.gz",
	dir = "StackTracePlus-0.1.0-1"
}
description = {
	summary = "StackTracePlus provides enhanced stack traces for Lua",
	detailed = [[
StackTracePlus can be used as a replacement for debug.traceback. It gives detailed information about locals, tries to guess 
function names when they're not available, etc.
]],
	license = "MIT/X11",
	homepage = "http://github.com/ignacio/StackTracePlus"
}

dependencies = { "lua >= 5.1" }

build = {
	type = "builtin",
	modules = {
		 StackTracePlus = "src/StackTracePlus.lua"
	}
}