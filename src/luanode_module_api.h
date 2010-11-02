#ifndef _LUANODE_API_H_
#define _LUANODE_API_H_

#include "../luanode_api.h"
#include <luacppbridge51/luaIncludes.h>

namespace LuaNode {

namespace ModuleApi {

	void Register(lua_State* L, int table);

}

}

#endif