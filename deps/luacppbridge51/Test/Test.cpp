#include "stdafx.h"

// override para que no tome los luaIncludes del bridge (por tema paths)
#define __LUA_INCLUDES_H__
extern "C" {
#include "..\..\..\..\..\packages\Lua5.1\include\lua.h"
#include "..\..\..\..\..\packages\Lua5.1\include\lualib.h"
#include "..\..\..\..\..\packages\lua5.1\include\lauxlib.h"
}

#include <stdexcept>

#include "..\luaIncludes.h"
#include "..\lcbBridgeConfig.h"
#include "ClaseHibrida.h"
#include "ClaseHibridaConProps.h"
#include "RawWithProps.h"
#include "Ventana.h"
#include "Boton.h"

LuaCppBridge::Config LuaCppBridge::g_luaCppBridge_config;


int main(int argc, char* argv[]) {
	printf("main\r\n");
	lua_State* L = lua_open();
	luaL_openlibs(L);

	try {
	LuaCppBridge::InitializeBridge(L, "Test");
	int t = lua_gettop(L);
	ClaseHibrida::EnableTracking(L);
	ClaseHibrida::Register(L, NULL);
	RawWithProps::Register(L);
	CVentana::Register(L, NULL);
	CBoton::Register(L, "Ventana");
	ClaseHibridaConProps::Register(L, "pepe");

	ClaseHibridaConProps* foo = new ClaseHibridaConProps(L);
	ClaseHibridaConProps::push(L, foo);
	ClaseHibridaConProps::call(L, "RetornaString");
	std::string s = luaL_checkstring(L, -1);
	if(s != "this is a hybrid object") {
		throw std::runtime_error("error");
	}
	lua_pop(L, 1);

	ClaseHibridaConProps::push(L, foo);
	ClaseHibridaConProps::push(L, foo);
	ClaseHibridaConProps::unpush(L, foo);

	//ClaseHibridaConProps::push(L, foo, false);
	//ClaseHibridaConProps::unpush(L, foo);

	//ClaseHibridaConProps::push_unique(L, foo);
	//ClaseHibridaConProps::pcall(L, "RetornaString");
	//lua_pop(L, 1);
	t = lua_gettop(L);
	
	t = lua_gettop(L);

	
	ClaseHibridaConProps::push(L, new ClaseHibridaConProps(L), false);
	delete foo;

	//RawWithProps::push(L, new RawWithProps(L), true);
	//RawWithProps::push(L, new RawWithProps(L), false);

	//lua_getfield(L, LUA_ENVIRONINDEX, "foo");

	int ret = luaL_dofile(L, "run.lua");
	if(ret != 0) {
		const char* errmsg = lua_tostring(L, -1);
		printf("%s\n", errmsg);
	}

	}
	catch(std::runtime_error& e) {
		printf("%s\n", e.what());
	}

	lua_close(L);
	return 0;
}

