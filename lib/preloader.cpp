#include "preloader.h"

static int luaopen_LuaNode_Class(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "class.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.class")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_ChildProcess(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "child_process.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.child_process")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Crypto(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "crypto.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.crypto")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Dns(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "dns.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.dns")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_EventEmitter(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "event_emitter.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.event_emitter")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_FreeList(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "free_list.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.freelist")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Fs(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "fs.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.fs")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Http(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "http.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.http")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Https(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "https.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.https")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Net(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "net.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.net")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Datagram(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "datagram.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.datagram")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Path(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "path.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.path")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_QueryString(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "querystring.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.querystring")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Stream(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "stream.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.stream")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Tls(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "tls.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.tls")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Url(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "url.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.url")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Timers(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "timers.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.timers")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Console(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "console.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.console")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Utils(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "utils.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.utils")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Script(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "script.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.script")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Tty(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "tty.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.tty")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Repl(lua_State* L) {
	static const unsigned char code[] = {
		#include "repl.precomp"
	};
	int arg = lua_gettop(L);
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.repl")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Readline(lua_State* L) {
	static const unsigned char code[] = {
		#include "readline.precomp"
	};
	int arg = lua_gettop(L);
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.readline")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_StackTracePlus(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "StackTracePlus.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"StackTracePlus")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Private_Url (lua_State* L)
{
	static const unsigned char code[] = {
		#include "__private_url.precomp"
	};
	int arg = lua_gettop(L);
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.__private_url")) {
		return lua_error(L);
	}
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

	lua_pushcfunction(L, luaopen_LuaNode_Https);
	lua_setfield(L, -2, "luanode.https");
	
	lua_pushcfunction(L, luaopen_LuaNode_Net);
	lua_setfield(L, -2, "luanode.net");

	lua_pushcfunction(L, luaopen_LuaNode_Datagram);
	lua_setfield(L, -2, "luanode.datagram");
	
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

	lua_pushcfunction(L, luaopen_LuaNode_Script);
	lua_setfield(L, -2, "luanode.script");

	lua_pushcfunction(L, luaopen_LuaNode_Tls);
	lua_setfield(L, -2, "luanode.tls");

	lua_pushcfunction(L, luaopen_LuaNode_Tty);
	lua_setfield(L, -2, "luanode.tty");

	lua_pushcfunction(L, luaopen_LuaNode_Repl);
	lua_setfield(L, -2, "luanode.repl");

	lua_pushcfunction(L, luaopen_LuaNode_Readline);
	lua_setfield(L, -2, "luanode.readline");

	lua_pushcfunction(L, luaopen_LuaNode_Private_Url);
	lua_setfield(L, -2, "luanode.__private_url");

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
