#include "stdafx.h"

// override para que no tome los luaIncludes del bridge (por tema paths)
#define __LUA_INCLUDES_H__
extern "C" {
#include "..\..\..\..\..\packages\Lua5.1\include\lua.h"
#include "..\..\..\..\..\packages\Lua5.1\include\lualib.h"
#include "..\..\..\..\..\packages\lua5.1\include\lauxlib.h"
}

#include "ClaseHibrida.h"

const char* ClaseHibrida::className = "ClaseHibrida";
const LuaCppBridge::HybridObject<ClaseHibrida>::RegType ClaseHibrida::methods[] = {
	{"RetornaString", &ClaseHibrida::RetornaString},
	{"RetornaNuevaInstanciaConGC", &ClaseHibrida::RetornaNuevaInstanciaConGC},
	{"RetornaNuevaInstanciaSinGC", &ClaseHibrida::RetornaNuevaInstanciaSinGC},
	{"RetornaThisSinGC", &ClaseHibrida::RetornaThisSinGC},
	{0}
};

ClaseHibrida::ClaseHibrida(lua_State* L) : 
	m_newInstance(NULL)
{

}

ClaseHibrida::~ClaseHibrida()
{

}

//////////////////////////////////////////////////////////////////////////
/// 
int ClaseHibrida::RetornaString(lua_State* L) {
	lua_pushstring(L, "hola que tal");
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int ClaseHibrida::RetornaNuevaInstanciaConGC(lua_State* L) {
	ClaseHibrida* newInstance = new ClaseHibrida(L);
	push(L, newInstance, true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int ClaseHibrida::RetornaNuevaInstanciaSinGC(lua_State* L) {
	if(m_newInstance) {
		luaL_error(L, "ya devolví una instancia");
	}
	m_newInstance = new ClaseHibrida(L);
	push(L, m_newInstance, false);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int ClaseHibrida::RetornaThisSinGC(lua_State* L) {
	push(L, this, false);
	return 1;
}