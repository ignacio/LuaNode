#include "preloader.h"

static int luaopen_LuaNode_Class(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "../build/temp/Class.precomp"
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
		#include "../build/temp/child_process.precomp"
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
		#include "../build/temp/Crypto.precomp"
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
		#include "../build/temp/Dns.precomp"
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
		#include "../build/temp/event_emitter.precomp"
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
		#include "../build/temp/free_list.precomp"
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
		#include "../build/temp/Fs.precomp"
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
		#include "../build/temp/Http.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.http")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Net(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "../build/temp/Net.precomp"
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
		#include "../build/temp/Datagram.precomp"
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
		#include "../build/temp/Path.precomp"
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
		#include "../build/temp/Querystring.precomp"
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
		#include "../build/temp/Stream.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.stream")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

static int luaopen_LuaNode_Url(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "../build/temp/Url.precomp"
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
		#include "../build/temp/Timers.precomp"
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
		#include "../build/temp/console.precomp"
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
		#include "../build/temp/Utils.precomp"
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
		#include "../build/temp/Script.precomp"
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
		#include "../build/temp/Tty.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.tty")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}

#if defined(_WIN32)
static int luaopen_LuaNode_Tty_win(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "../build/temp/Tty_win.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.tty_win")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}
#else
static int luaopen_LuaNode_Tty_posix(lua_State* L) {
	int arg = lua_gettop(L);
	static const unsigned char code[] = {
		#include "../build/temp/Tty_posix.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode.tty_posix")) {
		return lua_error(L);
	}
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}
#endif

static int luaopen_LuaNode_Repl(lua_State* L) {
	static const unsigned char code[] = {
		#include "../build/temp/Repl.precomp"
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
		#include "../build/temp/Readline.precomp"
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
		#include "../build/temp/StackTracePlus.precomp"
	};
	if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"StackTracePlus")) {
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

	lua_pushcfunction(L, luaopen_LuaNode_Tty);
	lua_setfield(L, -2, "luanode.tty");

#if defined (_WIN32)
	lua_pushcfunction(L, luaopen_LuaNode_Tty_win);
	lua_setfield(L, -2, "luanode.tty_win");
#else
	lua_pushcfunction(L, luaopen_LuaNode_Tty_posix);
	lua_setfield(L, -2, "luanode.tty_posix");
#endif

	lua_pushcfunction(L, luaopen_LuaNode_Repl);
	lua_setfield(L, -2, "luanode.repl");

	lua_pushcfunction(L, luaopen_LuaNode_Readline);
	lua_setfield(L, -2, "luanode.readline");

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
