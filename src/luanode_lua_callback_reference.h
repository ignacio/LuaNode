#ifndef __LUANODE_LUA_CALLBACK_REFERENCE_H__
#define __LUANODE_LUA_CALLBACK_REFERENCE_H__

#include <boost/shared_ptr.hpp>

namespace LuaNode {

/**
Holds a reference to a given value (usually a function) and to the thread that 
issued the call (only if it is not the main thread).

(TODO: Rethink this. How this interact with coroutines and so on.)
*/
	
class LuaCallbackRef {
public:
	typedef boost::shared_ptr<LuaCallbackRef> Ptr;

public:
	LuaCallbackRef(lua_State* thread, int ref_index) :
		m_thread(thread)
	{
		lua_pushvalue(thread, ref_index);
		m_callback_reference = luaL_ref(thread, LUA_REGISTRYINDEX);

		if(lua_pushthread(thread) == 1) {
			lua_pop(thread, 1);
			m_thread_reference = LUA_NOREF;
		}
		else {
			m_thread_reference = luaL_ref(thread, LUA_REGISTRYINDEX);
		}
	}
	~LuaCallbackRef() {
		// remove both references, if present
		if(m_thread_reference != LUA_NOREF) {
			luaL_unref(m_thread, LUA_REGISTRYINDEX, m_thread_reference);
		}
		luaL_unref(m_thread, LUA_REGISTRYINDEX, m_callback_reference);
	}

	/**
	Pushes the callback on the stack and returns the Lua thread to be used.
	*/
	lua_State* PushCallback() {
		lua_rawgeti(m_thread, LUA_REGISTRYINDEX, m_callback_reference);
		return m_thread;
	}

private:
	int m_thread_reference;
	int m_callback_reference;
	lua_State* m_thread;
};

}

#endif