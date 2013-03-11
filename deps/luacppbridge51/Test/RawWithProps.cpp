#include "stdafx.h"

// override para que no tome los luaIncludes del bridge (por tema paths)
#define __LUA_INCLUDES_H__
extern "C" {
#include "..\..\..\..\..\packages\Lua5.1\include\lua.h"
#include "..\..\..\..\..\packages\Lua5.1\include\lualib.h"
#include "..\..\..\..\..\packages\lua5.1\include\lauxlib.h"
}
#include "RawWithProps.h"

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

const char* RawWithProps::className = "RawWithProps";
const LuaCppBridge::RawObjectWithProperties<RawWithProps>::RegType RawWithProps::methods[] = {
	{"TestMethod1", &RawWithProps::TestMethod1},
	{0}
};

const LuaCppBridge::RawObjectWithProperties<RawWithProps>::RegType RawWithProps::getters[] = {
	{0}
};

const LuaCppBridge::RawObjectWithProperties<RawWithProps>::RegType RawWithProps::setters[] = {
	{0}
};

RawWithProps::RawWithProps(lua_State* L)
{

}

RawWithProps::~RawWithProps()
{

}

int RawWithProps::TestMethod1(lua_State* L) {
	lua_pushstring(L, "called RawWithProps::TestMethod1");
	return 1;
}