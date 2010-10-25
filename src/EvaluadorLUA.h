#ifndef EVALUADOR_LUA__H
#define EVALUADOR_LUA__H

#include "LuaRuntime.h"

class CEvaluadorLua :
	public CLuaRuntime<CEvaluadorLua>
{
public:
	CEvaluadorLua();
	virtual ~CEvaluadorLua();

public:
	int OnError(bool hasStackTrace) const; // por defecto, manda el string de error a la consola
	virtual bool SetupEnvironment();

	long GetID() const;
	void UpdateTimestampLastUse();
	unsigned int GetTimestampOfLastUse() const;


	static int OnPanic(lua_State* L);

protected:
	long m_ID;	// a numeric ID
	unsigned int m_timestampLastUsed;

private:
	static long s_nextID;
};

#endif
