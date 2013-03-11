#include "stdafx.h"

// override para que no tome los luaIncludes del bridge (por tema paths)
#define __LUA_INCLUDES_H__
extern "C" {
#include "..\..\..\..\..\packages\Lua5.1\include\lua.h"
#include "..\..\..\..\..\packages\Lua5.1\include\lualib.h"
#include "..\..\..\..\..\packages\lua5.1\include\lauxlib.h"
}

#include "Ventana.h"

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

const char* CVentana::className = "Ventana";
const CVentana::RegType CVentana::methods[] = {
	{"GetRect", &CVentana::GetRect},
	//{"RetornaNuevaInstanciaConGC", ClaseHibrida::RetornaNuevaInstanciaConGC},
	//{"RetornaNuevaInstanciaSinGC", ClaseHibrida::RetornaNuevaInstanciaSinGC},
	//{"RetornaThisSinGC", ClaseHibrida::RetornaThisSinGC},
	{0}
};

CVentana::CVentana(lua_State* L)
{

}

CVentana::~CVentana()
{

}

//////////////////////////////////////////////////////////////////////////
/// 
int CVentana::GetRect(lua_State* L) {
	lua_newtable(L);
	int t = lua_gettop(L);

	lua_pushnumber(L, 10);
	lua_setfield(L, t, "top");

	lua_pushnumber(L, 10);
	lua_setfield(L, t, "left");

	lua_pushnumber(L, 100);
	lua_setfield(L, t, "width");

	lua_pushnumber(L, 20);
	lua_setfield(L, t, "height");

	return 1;
}