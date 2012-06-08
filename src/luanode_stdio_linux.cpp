#include "stdafx.h"

#include "luanode.h"
#include "luanode_stdio.h"

#include "blogger.h"

#include "detail/posix/tty_stream.h"
#include "luanode_posix_stream.h"

#include <signal.h>


using namespace LuaNode::detail::posix;

//////////////////////////////////////////////////////////////////////////
/// TODO: this is the same on luanode_stdio_win32.cpp
static int IsATTY (lua_State* L) {
	int fd = luaL_checkinteger(L, 1);

	lua_pushboolean(L, isatty(fd));

	return 1;
}


//////////////////////////////////////////////////////////////////////////
///
void LuaNode::Stdio::Flush () {
}

//////////////////////////////////////////////////////////////////////////
///
static void HandleSIGCONT (int signum) {
	fprintf(stderr, "HandleSIGCONT\n");
	/*if (rawmode) {
		rawmode = 0;
		EnableRawMode(STDIN_FILENO);
	}*/
	TtyStream::Reset();
}

/////////////////////////////////////////////////////////////////////////
///
void LuaNode::Stdio::RegisterFunctions (lua_State* L) {

	luaL_Reg methods[] = {
		{ "isatty", IsATTY },
		{ 0, 0 }
	};
	luaL_register(L, "Stdio", methods);
	int table = lua_gettop(L);

	lua_pushinteger(L, STDOUT_FILENO);
	lua_setfield(L, table, "stdoutFD");

	lua_pushinteger(L, STDIN_FILENO);
	lua_setfield(L, table, "stdinFD");

	lua_pushinteger(L, STDERR_FILENO);
	lua_setfield(L, table, "stderrFD");
	lua_pop(L, 1);

	struct sigaction sa;
	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = HandleSIGCONT;
	sigaction(SIGCONT, &sa, NULL);

	LuaNode::Posix::Stream::Register(L, NULL, true);
	TtyStream::Register(L, NULL, true);
}

//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Stdio::OnExit (/*lua_State* L*/) {
	TtyStream::Reset();
}
