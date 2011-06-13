#ifndef _LUA_VM__H_
#define _LUA_VM__H_

#include "lua_runtime.h"

class CLuaVM :
	public CLuaRuntime<CLuaVM>
{
public:
	CLuaVM();
	virtual ~CLuaVM();

public:
	int OnError(bool hasStackTrace) const; // sends the error string to the console by default
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
