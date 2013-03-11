#ifndef __lcbBridgeConfig_h__
#define __lcbBridgeConfig_h__

#pragma once

namespace LuaCppBridge {

static int __ActualLibraryInitialization(lua_State* L);

/**
Initializes the library. Leaves a table on top of the stack where we'll put the stuff that comprises this library.
*/
static void InitializeBridge(lua_State* L, const char* libraryName, const luaL_Reg* reg = NULL)
{
	// since we're setting an environment, we need to call through Lua to set it up
	// Maybe drop this some time? won't work with coroutines
	lua_pushcfunction(L, __ActualLibraryInitialization);
	lua_pushstring(L, libraryName);
	lua_pushlightuserdata(L, (void*)reg);
	lua_call(L, 2, 1);
}

//////////////////////////////////////////////////////////////////////////
/// This method should not be used unless necessary (compatibility with older code)
/// Copies all methods from the library to the global table
/// The library table must be at the top of the stack
static void ExposeAsGlobal(lua_State* L) {
	int libraryTable = lua_gettop(L);
	luaL_checktype(L, libraryTable, LUA_TTABLE);	// must have library table on top of the stack

	lua_pushvalue(L, libraryTable);
	int table = lua_gettop(L);
	lua_pushnil(L);							// stack: table, nil
	while(lua_next(L, table)) { 			// stack: table, key, value
		lua_pushvalue(L, -2);				// stack: table, key, value, key
		lua_insert(L, -2);					// stack: table, key, key, value
		lua_rawset(L, LUA_GLOBALSINDEX);	// stack: table, key
	}
	lua_pop(L, 1);
}

/**
Performs the actual initialization of the library. This function should only be called through InitializeBridge
*/
static int __ActualLibraryInitialization(lua_State* L) {
	const char* libraryName = luaL_checkstring(L, 1);
	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	const luaL_Reg* reg = (const luaL_Reg*)lua_touserdata(L, 2);

	static const struct luaL_reg dummy[] = {
		{NULL, NULL},
	};
	
	// register module functions. This leaves a table on top of the stack
	if(reg) {
		luaL_register(L, libraryName, reg);
	}
	else {
		luaL_register(L, libraryName, dummy);
	}
	return 1;
}

// disgusting compiler hack for gcc. do never call this function
inline void foo() {
	InitializeBridge(NULL, NULL, NULL);
	ExposeAsGlobal(NULL);
}

} // end of the namespace

#endif