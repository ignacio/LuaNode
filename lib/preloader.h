#ifndef __LUANODE_PRELOADER_H__
#define __LUANODE_PRELOADER_H__

#pragma once

#include <lua.hpp>

void PreloadModules(lua_State* L);
void PreloadAdditionalModules(lua_State* L);

#endif