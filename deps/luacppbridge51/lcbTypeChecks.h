#ifndef __luaCppBridge_TypeChecks_h__
#define __luaCppBridge_TypeChecks_h__

#pragma once

#include <lua.hpp>
#include "lcbException.h"
#include <string.h>

#ifdef __GNUC__
# define UNUSED __attribute__((unused))
#else
# define UNUSED
#endif

namespace LuaCppBridge
{
	UNUSED
	static int error (lua_State *L, const char *fmt, ...) {
		va_list argp;
		va_start(argp, fmt);
		luaL_where(L, 1);
		lua_pushvfstring(L, fmt, argp);
		va_end(argp);
		lua_concat(L, 2);
		throw Type_error(L, true);
	}

	UNUSED
	static int argerror (lua_State *L, int narg, const char *extramsg) {
		lua_Debug ar;
		if (!lua_getstack(L, 0, &ar)) {  /* no stack frame? */
			return error(L, "bad argument #%d (%s)", narg, extramsg);
		}
		lua_getinfo(L, "n", &ar);
		if (strcmp(ar.namewhat, "method") == 0) {
			narg--;  /* do not count `self' */
			if (narg == 0) { /* error is in the self argument itself? */
				return error(L, "calling " LUA_QS " on bad self (%s)", ar.name, extramsg);
			}
		}
		if (ar.name == NULL) {
			ar.name = "?";
		}
		return error(L, "bad argument #%d to " LUA_QS " (%s)", narg, ar.name, extramsg);
	}

	UNUSED
	static int typerror (lua_State *L, int narg, const char *tname) {
		const char* msg = lua_pushfstring(L, "%s expected, got %s", tname, luaL_typename(L, narg));
		return argerror(L, narg, msg);
	}

	namespace detail {
		UNUSED
		static void tag_error (lua_State *L, int narg, int tag) {
			typerror(L, narg, lua_typename(L, tag));
		}
	}
	
	UNUSED
	static const char* checklstring (lua_State *L, int narg, size_t *len) {
		const char *s = lua_tolstring(L, narg, len);
		if (!s) {
			detail::tag_error(L, narg, LUA_TSTRING);
		}
		return s;
	}
	
	UNUSED
	static lua_Number checknumber (lua_State *L, int narg) {
		lua_Number d = lua_tonumber(L, narg);
		if (d == 0 && !lua_isnumber(L, narg)) {  /* avoid extra test when d is not 0 */
			detail::tag_error(L, narg, LUA_TNUMBER);
		}
		return d;
	}
	
	UNUSED
	static lua_Integer checkinteger (lua_State *L, int narg) {
		lua_Integer d = lua_tointeger(L, narg);
		if (d == 0 && !lua_isnumber(L, narg)) { /* avoid extra test when d is not 0 */
			detail::tag_error(L, narg, LUA_TNUMBER);
		}
		return d;
	}
	
	UNUSED
	static lua_Integer optinteger (lua_State *L, int narg, lua_Integer def) {
		return luaL_opt(L, checkinteger, narg, def);
	}
	
	UNUSED
	static void checkstack (lua_State *L, int sz, const char *msg) {
		if (!lua_checkstack(L, sz)) {
			error(L, "stack overflow (%s)", msg);
		}
	}
	
	UNUSED
	static void checktype (lua_State *L, int narg, int t) {
		if (lua_type(L, narg) != t) {
			detail::tag_error(L, narg, t);
		}
	}
	
	UNUSED
	static void checkany (lua_State *L, int narg) {
		if (lua_type(L, narg) == LUA_TNONE) {
			argerror(L, narg, "value expected");
		}
	}
	
	UNUSED
	static void *luaL_checkudata (lua_State *L, int ud, const char *tname) {
		void *p = lua_touserdata(L, ud);
		if (p != NULL) {  /* value is a userdata? */
			if (lua_getmetatable(L, ud)) {  /* does it have a metatable? */
				lua_getfield(L, LUA_REGISTRYINDEX, tname);  /* get correct metatable */
				if (lua_rawequal(L, -1, -2)) {  /* does it have the correct mt? */
					lua_pop(L, 2);  /* remove both metatables */
					return p;
				}
			}
		}
		typerror(L, ud, tname);  /* else error */
		return NULL;  /* to avoid warnings */
	}
	
	UNUSED
	static const char* optlstring (lua_State *L, int narg, const char *def, size_t *len) {
		if (lua_isnoneornil(L, narg)) {
			if (len) {
				*len = (def ? strlen(def) : 0);
			}
			return def;
		}
		return checklstring(L, narg, len);
	}

	UNUSED
	static const char* checkstring (lua_State *L, int narg) {
		return checklstring(L, narg, NULL);
	}
	
	UNUSED
	static const char* optstring (lua_State *L, int narg, const char *def) {
		return optlstring(L, narg, def, NULL);
	}
	
	UNUSED
	static lua_Integer checkint (lua_State *L, int narg) {
		return checkinteger(L, narg);
	}
	
	UNUSED
	static lua_Integer checkint (lua_State *L, int narg, lua_Integer def) {
		return optinteger(L, narg, def);
	}
	
	UNUSED
	static lua_Integer checklong (lua_State *L, int narg) {
		return checkinteger(L, narg);
	}
	
	UNUSED
	static lua_Integer optlong (lua_State *L, int narg, lua_Integer def) {
		return optinteger(L, narg, def);
	}
	
	UNUSED
	static int checkoption (lua_State *L, int narg, const char *def, const char *const lst[]) {
		const char *name = (def) ? optstring(L, narg, def) : checkstring(L, narg);
		int i;
		for (i=0; lst[i]; i++) {
			if (strcmp(lst[i], name) == 0) {
				return i;
			}
		}
		return argerror(L, narg, lua_pushfstring(L, "invalid option " LUA_QS, name));
	}
}

#endif