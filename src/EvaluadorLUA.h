#ifndef EVALUADOR_LUA__H
#define EVALUADOR_LUA__H

#include "LuaRuntime.h"
//#include <NodeList.h>
//#include "IHostVirtualMachine.h"

class CEvaluadorLua :
	public CLuaRuntime<CEvaluadorLua>//,
	//public InconcertTools::CNodeList::Node
{
public:
	CEvaluadorLua(/*IHostVirtualMachine& vmHost*/);
	virtual ~CEvaluadorLua();

public:
	int OnError(bool hasStackTrace) const; // por defecto, manda el string de error a la consola
	virtual bool SetupEnvironment();

	long GetID() const;
	void UpdateTimestampLastUse();
	unsigned int GetTimestampOfLastUse() const;


	static int OnPanic(lua_State* L);

	// helpers
	static void PushPathArray(const CBStringList& paths, lua_State* L);

protected:
	//IHostVirtualMachine& m_vmHost;
	long m_ID;	// a numeric ID
	unsigned int m_timestampLastUsed;

private:
	static long s_nextID;
};

#endif
