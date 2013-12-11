#if !defined(AFX_LUARUNTIME_H__5E316F4C_EE73_4483_B0F0_6619A9D7C653__INCLUDED_)
#define AFX_LUARUNTIME_H__5E316F4C_EE73_4483_B0F0_6619A9D7C653__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include <lua.hpp>

//extern int CollectTraceback(lua_State* L);	// función para obtener stacktraces cuando hay errores

template <typename TBase>
class CLuaRuntime
{
public:
	CLuaRuntime() : m_owner(true), m_error_handler(LUA_NOREF) {
		m_L = lua_open();
		if(m_L) {
			static_cast<TBase*>(this)->Initialize();
		}
	}
	CLuaRuntime(lua_State* L) : m_owner(false), m_error_handler(LUA_NOREF) {
		m_L = L;
	}
	virtual ~CLuaRuntime() {
		if(m_owner) {
			lua_close(m_L);
		}
	}

protected:
	// por defecto, abre todas las librerías
	void Initialize() {
		luaL_openlibs(m_L);
	};
	// por defecto, manda el string de error a la consola
	int OnError() {
		const char* strErr = lua_tostring(m_L, -1);
		fprintf(stderr, "%s", strErr);
		return 0;
	};

public:
	inline operator lua_State* () const { return m_L; };

	inline int loadstring(const char* s) {
		int iRet = luaL_loadstring(m_L, s);
		if(iRet != 0) {
			TBase* pT = static_cast<TBase*>(this);
			pT->OnError(false);
		}
		return iRet;
	}

	inline int dostring(const char* s, int params = 0) {
		int base = lua_gettop(m_L) - params;  /* index of arguments*/
		int iRet = luaL_loadstring(m_L, s);
		if(iRet == 0) {
			lua_insert(m_L, base + 1);	/* move chunk below arguments */
			pushErrorHandler();		/* push traceback function */
			lua_insert(m_L, base + 1);  /* put it under chunk and args */
   			iRet = lua_pcall(m_L, params, LUA_MULTRET, base + 1);
			if(iRet != 0) {
				TBase* pT = static_cast<TBase*>(this);
				pT->OnError(true);	// ya obtuve un stack trace, no intentar obtener uno porque no va a existir
			}
			lua_remove(m_L, base + 1);  /* remove traceback function */
		}
		else {
			TBase* pT = static_cast<TBase*>(this);
			pT->OnError(false);
			lua_pop(m_L, params);
		}
		return iRet;
	}

	inline int dofile(const char* filename) {
		int iRet = luaL_loadfile(m_L, filename);
		if(iRet == 0) {
			int base = lua_gettop(m_L);  /* function index */
			pushErrorHandler();		/* push traceback function */
			lua_insert(m_L, base);  /* put it under chunk and args */
   			iRet = lua_pcall(m_L, 0, LUA_MULTRET, base);
			if(iRet != 0) {
				TBase* pT = static_cast<TBase*>(this);
				pT->OnError(true);	// ya obtuve un stack trace, no intentar obtener uno porque no va a existir
			}
			lua_remove(m_L, base);  /* remove traceback function */
		}
		else {
			TBase* pT = static_cast<TBase*>(this);
			pT->OnError(false);
		}
		return iRet;
	}

	inline int loadfile(const char* filename) {
		int iRet = luaL_loadfile(m_L, filename);
		if(iRet != 0) {
			TBase* pT = static_cast<TBase*>(this);
			pT->OnError(false);
		}
		return iRet;
	}

	// sets the error handler we'll use
	void setErrorHandler(int reference) {
		m_error_handler = reference;
	}

	// pushes the error handler on the stack
	void pushErrorHandler() {
		if(m_error_handler != LUA_NOREF) {
			lua_rawgeti(m_L, LUA_REGISTRYINDEX, m_error_handler);
		}
		else {
			lua_getfield(m_L, LUA_GLOBALSINDEX, "debug");
			lua_getfield(m_L, -1, "traceback");
			m_error_handler = luaL_ref(m_L, LUA_REGISTRYINDEX);
			lua_pop(m_L, 1);
			pushErrorHandler();
		}
	}

	int call(int params, int returns) {
		int base = lua_gettop(m_L) - params;  /* function index */
		pushErrorHandler();			/* push traceback function */
		lua_insert(m_L, base);  /* put it under chunk and args */
   		int iRet = lua_pcall(m_L, params, returns, base);
		if(iRet != 0) {
			lua_remove(m_L, base);  /* remove traceback function */
			TBase* pT = static_cast<TBase*>(this);
			pT->OnError(true);	// ya obtuve un stack trace, no intentar obtener uno porque no va a existir
			return iRet;
		}
		lua_remove(m_L, base);  /* remove traceback function */
		return iRet;
	}

	int cpcall(lua_CFunction function, void* ud) {
		//int base = lua_gettop(m_L) - params;  /* function index */
		//lua_pushcfunction(m_L, CollectTraceback);  /* push traceback function */
		//lua_insert(m_L, base);  /* put it under chunk and args */
		int iRet = lua_cpcall(m_L, function, ud);
		if(iRet != 0) {
			TBase* pT = static_cast<TBase*>(this);
			pT->OnError(true);	// ya obtuve un stack trace, no intentar obtener uno porque no va a existir
			return 0;
		}
		//lua_remove(m_L, base);  /* remove traceback function */
		return iRet;
	}

	int PerformGC(bool full = false) {
		if(!full) {
			return lua_gc(m_L, LUA_GCCOLLECT, 0);
		}
		int ret = 0;
		int oldCount = 0;
		int count = lua_gc(m_L, LUA_GCCOUNT, 0);
		while(oldCount != count) {
			ret = lua_gc(m_L, LUA_GCCOLLECT, 0);
			oldCount = count;
			count = lua_gc(m_L, LUA_GCCOUNT, 0);
		}
		return ret;
	}
private:
	bool m_owner;
protected:
	lua_State* m_L;
	int m_error_handler;
};

#endif // !defined(AFX_LUARUNTIME_H__5E316F4C_EE73_4483_B0F0_6619A9D7C653__INCLUDED_)
