#ifndef __LUA_STACK_CHECKER_H__
#define __LUA_STACK_CHECKER_H__


class CLuaStackChecker {
public:
	CLuaStackChecker(lua_State* L) : m_L(L), m_acceptedDifference(0) {
		m_topInicio = lua_gettop(L);
	}
	CLuaStackChecker(lua_State* L, int difference) : m_L(L), m_acceptedDifference(difference) {
		m_topInicio = lua_gettop(L);
	}
	~CLuaStackChecker() {
		int currentTop = lua_gettop(m_L);
		if(currentTop - m_topInicio != m_acceptedDifference) {
			LogFatal("Lua stack is unbalanced!!");
			throw std::exception("Lua stack is unbalanced!!");	// que explote todo!
		}
	}
private:
	int m_topInicio;
	int m_acceptedDifference;
	lua_State* m_L;
};


#endif