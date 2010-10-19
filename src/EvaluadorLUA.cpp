#include "stdafx.h"
#include <supportLib/bstring/bstrwrap.h>
#include "EvaluadorLUA.h"
//#include <supportLib/support.h>
#include "blogger.h"
#include <assert.h>

extern int redirected_print(lua_State* L);

extern CBString InternalStackTrace(lua_State* L, int startLevel, bool traverseInDepth);

long CEvaluadorLua::s_nextID = 0;

//////////////////////////////////////////////////////////////////////////
/// Toma una lista de strings y la convierte a un array Lua. Asume que
/// hay una tabla Lua al tope del stack.
/*static*/ void CEvaluadorLua::PushPathArray(const CBStringList& paths, lua_State* L) {
	assert(lua_istable(L, -1));

	CBStringList::const_iterator iter;
	int i;
	lua_createtable(L, paths.size(), 0);

	for(iter = paths.begin(), i = 1;
		iter != paths.end(); ++iter, ++i)
	{
		lua_pushnumber(L, i);
		lua_pushstring(L, *iter);
		lua_settable(L, -3);
	}
}


//////////////////////////////////////////////////////////////////////
// Constructor
CEvaluadorLua::CEvaluadorLua(/*IHostVirtualMachine& vmHost*/) :
	//m_vmHost(vmHost),
	////Pm_ID(InterlockedIncrement(&s_nextID)),
	m_ID(++s_nextID),	// hasta que no tenga funciones para incrementar atómicamente
	////Pm_timestampLastUsed(GetTickCount())
	m_timestampLastUsed(0)	// hasta que no tenga una función equivalente
{
	lua_atpanic(m_L, OnPanic);

	// para testear los scripts, expongo una variable que indica si estoy en release o debug
#ifdef _DEBUG
	//lua_pushboolean(m_L, true);
	lua_pushboolean(m_L, false);
#else
	lua_pushboolean(m_L, false);
#endif
	lua_setfield(m_L, LUA_GLOBALSINDEX, "debug_executable");

	// si está Decoda presente, seteamos el nombre de la VM
	lua_pushfstring(m_L, "CEvaluadorLua (%p)", this);
	lua_setglobal(m_L, "decoda_name");

	// redirect the 'print' function
	lua_pushcfunction(m_L, redirected_print);
	lua_setfield(m_L, LUA_GLOBALSINDEX, "print");
}

//////////////////////////////////////////////////////////////////////
// Destructor
CEvaluadorLua::~CEvaluadorLua() {
	LogDebug("CEvaluadorLua::~CEvaluadorLua");
}

//////////////////////////////////////////////////////////////////////////
///
long CEvaluadorLua::GetID() const {
	return m_ID;
}

//////////////////////////////////////////////////////////////////////////
///
void CEvaluadorLua::UpdateTimestampLastUse() {
	////Pm_timestampLastUsed = GetTickCount();
	m_timestampLastUsed = 0;
}
unsigned int CEvaluadorLua::GetTimestampOfLastUse() const {
	return m_timestampLastUsed;
}

//////////////////////////////////////////////////////////////////////////
/// Si es necesario, agrego cosas acá, funciones, etc
/// Estas funciones serían aplicables para todos los usos (introspection, web, etc)
bool CEvaluadorLua::SetupEnvironment() {
	//lua_State* L = m_L;

	return true;
}

//////////////////////////////////////////////////////////////////////////
///
int CEvaluadorLua::OnPanic(lua_State* L) {
	LogFatal("PANIC!!!!\r\n%s", lua_tostring(L, -1));
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// Muestra el error de lua en un messagebox y además loguea un stack trace
/// con la información disponible.
int CEvaluadorLua::OnError(bool hasStackTrace) const {
	char* luaErrorMessage = NULL;
	CBString errorMessage;

	if(hasStackTrace) {
		luaErrorMessage = _strdup(lua_tostring(m_L, -1));
		errorMessage = luaErrorMessage;
		errorMessage += "\n\r";
	}
	else {
		if(lua_isstring(m_L, -1)) {
			luaErrorMessage = _strdup(lua_tostring(m_L, -1));
			errorMessage += luaErrorMessage;
			errorMessage += "\n\r";
		}
		errorMessage += "Stack Traceback\n===============\n\r";
		errorMessage += InternalStackTrace(m_L, 0, true);
	}

	lua_getglobal(m_L, "LogError");
	if(lua_type(m_L, -1) == LUA_TFUNCTION) {
		lua_pushstring(m_L, "%s");
		lua_pushstring(m_L, (const char*)errorMessage);
		lua_call(m_L, 2, 0);
	}
	else {
		fprintf(stderr, "%s\n", (const char*)errorMessage);
	}

	if(luaErrorMessage) {
		LogError("%s", luaErrorMessage);
		free(luaErrorMessage);
	}
	return 1;
}
