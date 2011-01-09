#include "preloader.h"

static int luaopen_LuaNode_Class(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/Class.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_ChildProcess(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/child_process.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Crypto(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/Crypto.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B2,sizeof(B2),"LuaNode.Crypto");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Dns(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/Dns.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B3,sizeof(B3),"LuaNode.Dns");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_EventEmitter(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/event_emitter.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_FreeList(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/free_list.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B5,sizeof(B5),"LuaNode.FreeList");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Fs(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/Fs.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B6,sizeof(B6),"LuaNode.Fs");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Http(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/Http.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B7,sizeof(B7),"LuaNode.Http");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Net(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/Net.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B8,sizeof(B8),"LuaNode.Net");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Path(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/Path.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B9,sizeof(B9),"LuaNode.Path");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_QueryString(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/Querystring.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B10,sizeof(B10),"LuaNode.QueryString");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Stream(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/Stream.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B11,sizeof(B11),"LuaNode.Stream");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Url(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/Url.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B12,sizeof(B12),"LuaNode.Url");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Timers(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/Timers.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B13,sizeof(B13),"LuaNode.Net.Timeout");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Console(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/console.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B13,sizeof(B13),"LuaNode.Console");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Utils(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/Utils.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B13,sizeof(B13),"LuaNode.Console");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_StackTracePlus(lua_State* L) {
	int extension_status = 1;
	int arg = lua_gettop(L);
	#include "../build/temp/StackTracePlus.precomp"
	if(extension_status) {
		return lua_error(L);
	}
	//luaL_loadbuffer(L,(const char*)B13,sizeof(B13),"StackTracePlus");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}


void PreloadModules(lua_State* L) {
	luaL_findtable(L, LUA_GLOBALSINDEX, "package.preload", 1);
	//int preload = lua_gettop(L);

	lua_pushcfunction(L, luaopen_LuaNode_Class);
	lua_setfield(L, -2, "luanode.class");

	lua_pushcfunction(L, luaopen_LuaNode_ChildProcess);
	lua_setfield(L, -2, "luanode.child_process");
	
	lua_pushcfunction(L, luaopen_LuaNode_Crypto);
	lua_setfield(L, -2, "luanode.crypto");
	
	lua_pushcfunction(L, luaopen_LuaNode_Dns);
	lua_setfield(L, -2, "luanode.dns");
	
	lua_pushcfunction(L, luaopen_LuaNode_EventEmitter);
	lua_setfield(L, -2, "luanode.event_emitter");
	
	lua_pushcfunction(L, luaopen_LuaNode_FreeList);
	lua_setfield(L, -2, "luanode.free_list");
	
	lua_pushcfunction(L, luaopen_LuaNode_Fs);
	lua_setfield(L, -2, "luanode.fs");
	
	lua_pushcfunction(L, luaopen_LuaNode_Http);
	lua_setfield(L, -2, "luanode.http");
	
	lua_pushcfunction(L, luaopen_LuaNode_Net);
	lua_setfield(L, -2, "luanode.net");
	
	lua_pushcfunction(L, luaopen_LuaNode_Path);
	lua_setfield(L, -2, "luanode.path");
	
	lua_pushcfunction(L, luaopen_LuaNode_QueryString);
	lua_setfield(L, -2, "luanode.querystring");
	
	lua_pushcfunction(L, luaopen_LuaNode_Stream);
	lua_setfield(L, -2, "luanode.stream");
	
	lua_pushcfunction(L, luaopen_LuaNode_Url);
	lua_setfield(L, -2, "luanode.url");
	
	lua_pushcfunction(L, luaopen_LuaNode_Timers);
	lua_setfield(L, -2, "luanode.timers");
	
	lua_pushcfunction(L, luaopen_LuaNode_Console);
	lua_setfield(L, -2, "luanode.console");

	lua_pushcfunction(L, luaopen_LuaNode_Utils);
	lua_setfield(L, -2, "luanode.utils");

	lua_pop(L, 1);
}

//////////////////////////////////////////////////////////////////////////
/// 
void PreloadAdditionalModules(lua_State* L) {
	luaL_findtable(L, LUA_GLOBALSINDEX, "package.preload", 1);
	//int preload = lua_gettop(L);

	lua_pushcfunction(L, luaopen_StackTracePlus);
	lua_setfield(L, -2, "stacktraceplus");

	lua_pop(L, 1);
}
