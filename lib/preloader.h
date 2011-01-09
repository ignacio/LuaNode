#pragma once

#include <lua.hpp>

void PreloadModules(lua_State* L);
void PreloadAdditionalModules(lua_State* L);
