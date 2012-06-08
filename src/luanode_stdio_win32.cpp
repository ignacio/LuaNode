#include "stdafx.h"

#include "luanode.h"
#include "luanode_stdio.h"

#include "detail/windows/windows_tty.h"

#include <stdio.h>

#include <io.h>	/* needed for _isatty, _close, _get_osfhandle */
#include <boost/thread.hpp>
#include <boost/make_shared.hpp>

#include "detail/windows/input_tty.h"
#include "detail/windows/output_tty.h"


using namespace LuaNode::detail::windows;

//////////////////////////////////////////////////////////////////////////
/// TODO: this is the same on luanode_stdio_linux.cpp
static int IsATTY (lua_State* L) {
	int fd = luaL_checkinteger(L, 1);

	lua_pushboolean(L, _isatty(fd));

	return 1;
}

/*
 * Flush stdout and stderr on LuaNode exit
 * Not necessary on windows, so a no-op
 */
void LuaNode::Stdio::Flush() {
}

/////////////////////////////////////////////////////////////////////////
/// Based on a 'readable' flag, it constructs an input or output tty stream
/// ie. TtyStream(fd, readable)
static int createTtyStream (lua_State* L) {
	luaL_checkinteger(L, 1);
	if(lua_toboolean(L, 2)) {
		InputTtyStream* stream = InputTtyStream::Construct(L, true);
		stream->PostConstruct(L);
	}
	else {
		OutputTtyStream* stream = OutputTtyStream::Construct(L, true);
		stream->PostConstruct(L);
	}
	return 1;
}

/////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Stdio::RegisterFunctions (lua_State* L) {
	lua_pushcfunction(L, createTtyStream);
	lua_setfield(L, -2, "TtyStream");	// process.TtyStream = createTtyStream

	luaL_Reg methods[] = {
		{ "isatty", IsATTY },
		{ 0, 0 }
	};
	luaL_register(L, "Stdio", methods);
	int table = lua_gettop(L);

	lua_pushinteger(L, _fileno(stdout));
	lua_setfield(L, table, "stdoutFD");

	lua_pushinteger(L, _fileno(stdin));
	lua_setfield(L, table, "stdinFD");

	lua_pushinteger(L, _fileno(stderr));
	lua_setfield(L, table, "stderrFD");
	lua_pop(L, 1);

	InputTtyStream::Register(L, NULL, true);
	OutputTtyStream::Register(L, NULL, true);
}

//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Stdio::OnExit (/*lua_State* L*/) {
	/*fprintf(stderr, "LuaNode::Stdio::OnExit\n");*/
}
