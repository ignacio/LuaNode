#include "stdafx.h"
#include "lua_vm.h"
#include "blogger.h"
#include "luanode.h"
#include <assert.h>
#include <string>

long CLuaVM::s_nextID = 0;


//////////////////////////////////////////////////////////////////////
// Constructor
CLuaVM::CLuaVM(/*IHostVirtualMachine& vmHost*/) :
	//m_vmHost(vmHost),
	////Pm_ID(InterlockedIncrement(&s_nextID)),
	m_ID(++s_nextID),
	////Pm_timestampLastUsed(GetTickCount())
	m_timestampLastUsed(0)	// until no equivalent function available
{
	LogDebug("CLuaVM::CLuaVM (%p)", this);
	lua_atpanic(m_L, OnPanic);
}

//////////////////////////////////////////////////////////////////////
// Destructor
CLuaVM::~CLuaVM() {
	LogDebug("CLuaVM::~CLuaVM (%p)", this);
}

//////////////////////////////////////////////////////////////////////////
///
long CLuaVM::GetID() const {
	return m_ID;
}

//////////////////////////////////////////////////////////////////////////
///
void CLuaVM::UpdateTimestampLastUse() {
	////Pm_timestampLastUsed = GetTickCount();
	m_timestampLastUsed = 0;
}
unsigned int CLuaVM::GetTimestampOfLastUse() const {
	return m_timestampLastUsed;
}

//////////////////////////////////////////////////////////////////////////
/// If neccesarry, add additional stuff here
bool CLuaVM::SetupEnvironment() {
	//lua_State* L = m_L;

	return true;
}

//////////////////////////////////////////////////////////////////////////
///
int CLuaVM::OnPanic(lua_State* L) {
	LogFatal("PANIC!!!!\r\n%s", lua_tostring(L, -1));
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// Logs a stack trace with the available information
int CLuaVM::OnError(bool hasStackTrace) const {
	std::string errorMessage;

	if(hasStackTrace) {
		if(lua_isstring(m_L, -1)) {
			errorMessage = lua_tostring(m_L, -1);
			errorMessage += "\r\n";
		}
		else {
			errorMessage = "(error object is not a string)";
		}
	}
	else {
		if(lua_isstring(m_L, -1)) {
			errorMessage = lua_tostring(m_L, -1);
			errorMessage += "\r\n";
		}
		errorMessage += "Stack Traceback\n===============\n\r";
		// TODO: add something meaningfull here ?
		//errorMessage += InternalStackTrace(m_L, 0, true);
	}

	if(LuaNode::FatalError(m_L, errorMessage.c_str())) {
		return 1;
	}

	lua_getfield(m_L, LUA_GLOBALSINDEX, "console");
	if(lua_istable(m_L, -1)) {
		lua_getfield(m_L, -1, "error");
		if(lua_type(m_L, -1) == LUA_TFUNCTION) {
			lua_pushstring(m_L, "%s");
			lua_pushlstring(m_L, errorMessage.c_str(), errorMessage.length());
			lua_call(m_L, 2, 0);
		}
		else {
			fprintf(stderr, "%s\n", errorMessage.c_str());
			lua_pop(m_L, 1);
		}
	}
	else {
		fprintf(stderr, "%s\n", errorMessage.c_str());
	}
	lua_pop(m_L, 1);

	LogError("%s", errorMessage.c_str());
	return 1;
}
