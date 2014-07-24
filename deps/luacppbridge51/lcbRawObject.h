#ifndef __luaCppBridge_RawObject_h__
#define __luaCppBridge_RawObject_h__

#include <lua.hpp>
#include "lcbBaseObject.h"
#include "lcbException.h"

#define LCB_RO_DECLARE_EXPORTABLE(classname) \
	static const LuaCppBridge::RawObject< classname >::RegType methods[];\
	static const char* className

// No inheritance here... check() is the culprit...

namespace LuaCppBridge {

/**
A RawObject is a C++ class exposed to Lua as a userdata. This prevents adding additional methods and members.
Only the functions exposed from C++ will be available.

TO DO:
Inheritance won't work with this class. The 'check' method when used with inheritance will fail because the userdata
on the stack is not what it is expecting and fails. So, we could:
 - remove the check (con: it could blow up if called with userdata belonging to a different class) or
 - check against some kind of type hierarchy
*/


template <typename T, bool is_disposable = false> class RawObject : public BaseObject<T, RawObject<T> > {
private:
	typedef BaseObject<T, RawObject<T> > base_type;
public:
	typedef typename base_type::RegType RegType;
	typedef typename base_type::userdataType userdataType;

public:
	static void Register (lua_State* L) {
		Register(L, true);
	}

	static void Register (lua_State* L, bool isCreatableByLua)
	{
		int libraryTable = lua_gettop(L);
		luaL_checktype(L, libraryTable, LUA_TTABLE);	// must have library table on top of the stack
		lua_pushcfunction(L, RegisterLua);
		lua_pushvalue(L, libraryTable);
		lua_pushboolean(L, isCreatableByLua);
		lua_call(L, 2, 0);
	}

private:
	static int RegisterLua (lua_State* L) {
		luaL_checktype(L, 1, LUA_TTABLE);	// must pass a table
		bool isCreatableByLua = lua_toboolean(L, 2) != 0;
		
		int whereToRegister = 1;
		lua_newtable(L);
		int methods = lua_gettop(L);
		
		base_type::newmetatable(L, T::className);
		int metatable = lua_gettop(L);
		
		// store method table in globals so that scripts can add functions written in Lua.
		lua_pushstring(L, T::className);
		lua_pushvalue(L, methods);
		lua_settable(L, whereToRegister);
		
		// make getmetatable return the methods table
		lua_pushvalue(L, methods);
		lua_setfield(L, metatable, "__metatable");
		
		lua_pushliteral(L, "__index");
		lua_pushvalue(L, methods);
		lua_settable(L, metatable);
		
		lua_pushliteral(L, "__tostring");
		lua_pushcfunction(L, T::tostring_T);
		lua_settable(L, metatable);
		
		lua_pushliteral(L, "__gc");
		lua_pushcfunction(L, T::gc_T);
		lua_settable(L, metatable);

		lua_pushstring(L, T::get_full_class_name_T());
		lua_setfield(L, metatable, "__name");
		
		if(isCreatableByLua) {
			// Make Classname() and Classname:new() construct an instance of this class
			lua_newtable(L);							// mt for method table
			lua_pushcfunction(L, T::new_T);
			lua_pushvalue(L, -1);						// dup new_T function
			base_type::set(L, methods, "new");			// add new_T to method table
			base_type::set(L, -3, "__call");			// mt.__call = new_T
			lua_setmetatable(L, methods);
		}
		else {
			// Both Make Classname() and Classname:new() will issue an error
			lua_newtable(L);							// mt for method table
			lua_pushcfunction(L, base_type::forbidden_new_T);
			lua_pushvalue(L, -1);						// dup new_T function
			base_type::set(L, methods, "new");			// add new_T to method table
			base_type::set(L, -3, "__call");			// mt.__call = new_T
			lua_setmetatable(L, methods);
		}
		
		// fill method table with methods from class T
		for(const RegType* l = T::methods; l->name; l++) {
			lua_pushstring(L, l->name);
			lua_pushlightuserdata(L, (void*)l);
			lua_pushcclosure(L, base_type::thunk_methods, 1);
			lua_settable(L, methods);
		}

		if(isCreatableByLua && is_disposable) {
			lua_pushcfunction(L, T::dispose_T);
			base_type::set(L, methods, "dispose");
		}
		
		lua_pop(L, 2);	// drop metatable and method table
		return 0;
	}
};

} // end of the namespace

#endif

