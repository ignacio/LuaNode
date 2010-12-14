#include "stdafx.h"
#include "LuaNode.h"
#include "luanode_file_win32.h"
#include <sys/types.h>

#include <boost/asio.hpp>
#include <boost/asio/windows/stream_handle.hpp>



using namespace LuaNode::Fs;

//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Fs::RegisterFunctions(lua_State* L) {
	luaL_Reg methods[] = {
		//{ "isIP", LuaNode::Net::IsIP },
		//{ "read", LuaNode::Fs::Read },
		{ 0, 0 }
	};
	luaL_register(L, "Fs", methods);
	lua_pop(L, 1);
}

