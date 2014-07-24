#pragma once

#include "../deps/luacppbridge51/lcbHybridObjectWithProperties.h"

namespace LuaNode {

class ChildProcess : public LuaCppBridge::HybridObjectWithProperties<ChildProcess>
{
public: 
	ChildProcess(lua_State* L);
	~ChildProcess();

public:
	LCB_HOWP_DECLARE_EXPORTABLE(ChildProcess);
	static const char* get_full_class_name_T();

	int New(lua_State* L);
	int Spawn(lua_State* L);
	int Kill(lua_State* L);

private:
	lua_State* m_L;
};

}
