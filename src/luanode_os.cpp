#include "StdAfx.h"
#include "LuaNode.h"
#include "luanode_os.h"
#include <boost/bind.hpp>

using namespace LuaNode;

//////////////////////////////////////////////////////////////////////////
/// 
static void GetHostname_callback(lua_State* L, int callback, int result, std::string hostname) {
	lua_rawgeti(L, LUA_REGISTRYINDEX, callback);
	luaL_unref(L, LUA_REGISTRYINDEX, callback);

	if(result < 0) {
		lua_pushnil(L);
		lua_call(L, 1, 0);
	}
	else {
		lua_pushlstring(L, hostname.c_str(), hostname.length());
		lua_call(L, 1, 0);
	}
	lua_settop(L, 0);
}

//////////////////////////////////////////////////////////////////////////
/// 
static int GetHostname(lua_State* L) {
	luaL_checktype(L, 1, LUA_TFUNCTION);
	int callback = luaL_ref(L, LUA_REGISTRYINDEX);

	char hostname[255];

	// TODO: gethostname is blocking, should run it in some kind of thread pool
	int result = gethostname(hostname, 255);
	LuaNode::GetIoService().post( boost::bind(GetHostname_callback, L, callback, result, std::string(hostname)) );

	return 0;
}

/*static int GetCurrentIP(lua_State* L) {
	WSADATA sockInfo;	// information about Winsock
	HOSTENT hostinfo;	// information about an Internet host
	CBString ipString;	// holds a human-readable IP address string
	in_addr address;
	DWORD retval;		// generic return value

	ipString = "";

	// Get information about the domain specified in txtDomain.
	hostinfo = *gethostbyname("");
	if(hostinfo.h_addrtype != AF_INET) {
		lua_pushnil(L);
		lua_pushstring(strerror(errno));
		return 2;
	}
	else {
		// Convert the IP address into a human-readable string.
		memcpy(&address, hostinfo.h_addr_list[0], 4);
		ipString = inet_ntoa(address);
	}
	// Close the Winsock session.
	WSACleanup();
	return ipString;
}*/

//////////////////////////////////////////////////////////////////////////
/// 
void OS::RegisterFunctions(lua_State* L) {
	luaL_Reg methods[] = {
		{ "getHostname", GetHostname },
		{ 0, 0 }
	};
	luaL_register(L, "luanode.os", methods);
	lua_pop(L, 1);
}

