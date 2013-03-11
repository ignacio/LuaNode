#pragma once

#include <lua.hpp>
#include "../deps/luacppbridge51/lcbHybridObjectWithProperties.h"

namespace LuaNode {

namespace Stdio {

	void RegisterFunctions (lua_State* L);
	void OnExit (/*lua_State* L*/);

	void Flush ();

}

}
