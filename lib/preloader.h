#pragma once

#include "../../../packages/lua5.1/include/lua.hpp"

void PreloadModules(lua_State* L);
void PreloadAdditionalModules(lua_State* L);