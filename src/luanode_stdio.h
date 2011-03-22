#pragma once

#include <lua.hpp>
#include "../deps/LuaCppBridge51/lcbHybridObjectWithProperties.h"

namespace LuaNode {

namespace Stdio {

	void RegisterFunctions (lua_State* L);
	void OnExit (lua_State* L);

	void DisableRawMode (int fd);

	void Flush ();

/*class Binding : public LuaCppBridge::HybridObjectWithProperties<Binding> {

};*/

}

}
