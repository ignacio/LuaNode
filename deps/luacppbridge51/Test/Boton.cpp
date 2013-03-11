#include "stdafx.h"

// override para que no tome los luaIncludes del bridge (por tema paths)
#define __LUA_INCLUDES_H__
extern "C" {
#include "..\..\..\..\..\packages\Lua5.1\include\lua.h"
#include "..\..\..\..\..\packages\Lua5.1\include\lualib.h"
#include "..\..\..\..\..\packages\lua5.1\include\lauxlib.h"
}

#include "Boton.h"

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

const char* CBoton::className = "Boton";
const CBoton::RegType CBoton::methods[] = {
	{"GetLabel", &CBoton::GetLabel},
	//{"RetornaNuevaInstanciaConGC", ClaseHibrida::RetornaNuevaInstanciaConGC},
	//{"RetornaNuevaInstanciaSinGC", ClaseHibrida::RetornaNuevaInstanciaSinGC},
	//{"RetornaThisSinGC", ClaseHibrida::RetornaThisSinGC},
	{0}
};

CBoton::CBoton(lua_State* L)
{

}

CBoton::~CBoton()
{

}

//////////////////////////////////////////////////////////////////////////
/// 
int CBoton::GetLabel(lua_State* L) {
	luaL_typename(L, 1);
	lua_pushstring(L, "el label del botón");
	return 1;
}
