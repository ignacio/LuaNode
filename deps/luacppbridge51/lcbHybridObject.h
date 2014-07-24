#ifndef __luaCppBridge_HybridObject_h__
#define __luaCppBridge_HybridObject_h__

#include <lua.hpp>
#include "lcbBaseObject.h"
#include "lcbException.h"
#include "lcbTypeChecks.h"

#define LCB_HO_DECLARE_EXPORTABLE(classname) \
	static const LuaCppBridge::HybridObject< classname >::RegType methods[];\
	static const char* className

namespace LuaCppBridge {

/**
An HybridObject is a C++ class whose instances are exposed to Lua as tables. It differs from RawObject
in that additional methods and members can be added dynamically to its instances.
*/
template <typename T, bool is_disposable = false> class HybridObject : public BaseObject<T, HybridObject<T> > {
private:
	typedef BaseObject<T, HybridObject<T> > base_type;
public:
	typedef typename base_type::RegType RegType;
	typedef typename base_type::userdataType userdataType;

	typedef struct ObjectWrapper {
		T* wrappedObject;
		bool collectable;
	} ObjectWrapper;

public:
	static void Register (lua_State* L, const char* parentClassName) {
		Register(L, parentClassName, true);
	}

	static void Register (lua_State* L, const char* parentClassName, bool isCreatableByLua)
	{
		int libraryTable = lua_gettop(L);
		luaL_checktype(L, libraryTable, LUA_TTABLE);	// must have library table on top of the stack
		lua_pushcfunction(L, RegisterLua);
		lua_pushvalue(L, libraryTable);
		lua_pushstring(L, parentClassName);
		lua_pushboolean(L, isCreatableByLua);
		lua_call(L, 3, 0);
	}
	
	// create a new T object and push onto the Lua stack a table containing a userdata which itself contains a pointer
	// to T object
	static int new_T (lua_State* L) {
		lua_remove(L, 1);	// use classname:new(), instead of classname.new()
		T* obj = new T(L);	// call constructor for T objects
		int newTable = push(L, obj, true); // gc_T will delete this object
		if(base_type::s_trackingEnabled) {
			obj->KeepTrack(L);
		}
		
		// if this method was called with a table as parameter, copy its values to the newly created object
		if(lua_gettop(L) == 2 && lua_istable(L, 1)) {
			lua_pushnil(L);
			while(lua_next(L, 1)) {
				lua_pushvalue(L, -2);
				lua_insert(L, -2);
				lua_settable(L, newTable);
			}
		}
		// last step in the creation of the object. call a method that can access the userdata that will be sent
		// back to Lua
		obj->PostConstruct(L);
		return 1;
	}
	
	// push onto the Lua stack a table containing a userdata which itself contains a pointer to T object
	static int push (lua_State* L, T* obj, bool gc = false) {
		if(!obj) {
			lua_pushnil(L);
			return 0;
		}
		base_type::getmetatable(L, T::className);	// look for the metatable
		if(lua_isnil(L, -1)) {
			return error(L, "%s missing metatable", T::className);
		}
		// stack: metatable
		int metatable = lua_gettop(L);
		base_type::subtable(L, metatable, "userdata", "v");
		// stack: metatable, table userdata
		ObjectWrapper* wrapper = static_cast<ObjectWrapper*>(lua_newuserdata(L, sizeof(ObjectWrapper)));
		if(wrapper) {
			// set up a table as the userdata environment
			lua_newtable(L);
			lua_setfenv(L, -2);
			wrapper->wrappedObject = obj;	// store pointer to object in userdata
			lua_pushvalue(L, metatable);
			lua_setmetatable(L, -2);	// set metatable for userdata
			wrapper->collectable = gc;
		}
		// leave userdata on top of the stack
		lua_replace(L, metatable);
		lua_settop(L, metatable);
		return metatable;	// index of userdata containing pointer to T object
	}
	
	// get userdata from Lua stack and return pointer to T object
	// this is somewhat permissive, does not check for correct metatable (beware!)
	static T* check (lua_State* L, int narg) {
		checktype(L, narg, LUA_TUSERDATA);
		T* pT = static_cast<ObjectWrapper*>(lua_touserdata(L, narg))->wrappedObject;
		if(!pT) {
			typerror(L, narg, T::className);
		}
		return pT;	// pointer to T object
	}

	// test if the value in the given position in the stack is a T object
	// this is somewhat permissive, does not check for correct metatable (beware!)
	static bool test (lua_State* L, int narg) {
		if(!lua_isuserdata(L, narg)) {
			return false;
		}
		T* pT = static_cast<ObjectWrapper*>(lua_touserdata(L, narg))->wrappedObject;
		if(!pT) {
			return false;
		}
		return true;
	}
	
protected:
	/**
	__index metamethod. Looks for a dynamic property, then for a method.
	upvalues:
			1 = table with methods
	initial stack: self (userdata), key
	*/
	static int thunk_index(lua_State* L) {
		base_type::check(L, 1);	// get 'self', or if you prefer, 'this'
		lua_getfenv(L, 1);					// stack: userdata, key, userdata_env

		// Look in the userdata's environment
		lua_pushvalue(L, 2);				// stack: userdata, key, userdata_env, key
		lua_rawget(L, 3);
		if(!lua_isnil(L, -1)) {
			// found something, return it
			return 1;
		}
		lua_pop(L, 2);						// stack: userdata, key

		lua_pushvalue(L, 2);				// stack: userdata, key, key
		
		// not a property, look for a method up the inheritance hierarchy
		lua_gettable(L, lua_upvalueindex(1));
		if(!lua_isnil(L, -1)) {
			// found the method, return it
			return 1;
		}
		else {
			// nothing was found
			lua_pushnil(L);
			return 1;
		}
		return 0;
	}

	/**
	__newindex metamethod. Looks for a set property, else it sets the value as a dynamic property.
	initial stack: self (userdata), key, value
	*/
	static int thunk_newindex (lua_State* L) {
		base_type::check(L, 1);	// get 'self', or if you prefer, 'this'

		lua_getfenv(L, 1);					// stack: userdata, key, value, userdata_env
		lua_replace(L, 1);					// stack: userdata_env, key, value
		lua_rawset(L, 1);
		
		return 0;
	}

private:
	static int RegisterLua (lua_State* L) {
		luaL_checktype(L, 1, LUA_TTABLE);	// must pass a table
		const char* parentClassName = luaL_optstring(L, 2, NULL);
		bool isCreatableByLua = lua_toboolean(L, 3) != 0;

		int whereToRegister = 1;
		// creo una tabla para los métodos
		lua_newtable(L);
		int methods = lua_gettop(L);
			
		base_type::newmetatable(L, T::className);
		int metatable = lua_gettop(L);
			
		// store method table in module so that scripts can add functions written in Lua.
		lua_pushvalue(L, methods);
		base_type::set(L, whereToRegister, T::className);
		
		// make getmetatable return the methods table
		lua_pushvalue(L, methods);
		lua_setfield(L, metatable, "__metatable");
			
		// set __index and __newindex metamethods
		lua_pushvalue(L, methods);
		lua_pushcclosure(L, T::thunk_index, 1);
		base_type::set(L, metatable, "__index");

		lua_pushcfunction(L, T::thunk_newindex);
		base_type::set(L, metatable, "__newindex");
			
		lua_pushcfunction(L, T::tostring_T);
		base_type::set(L, metatable, "__tostring");
			
		lua_pushcfunction(L, T::gc_T);
		base_type::set(L, metatable, "__gc");

		lua_pushstring(L, T::get_full_class_name_T());
		base_type::set(L, metatable, "__name");
			
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
		// If a parent class was supplied, make it inherit from it
		if(parentClassName) {
			// do this:
			// getmetatable(T::className).__index = className
			// ie: getmetatable(VbButton).__index = CVbCtrlObj
			lua_getmetatable(L, methods);
			lua_pushliteral(L, "__index");
			lua_getfield(L, whereToRegister, parentClassName);
			if(lua_isnil(L, -1)) {
				return luaL_error(L, "class %s is not defined", parentClassName);
			}
			lua_rawset(L, -3);
			lua_pop(L, 1);
		}

		if(isCreatableByLua && is_disposable) {
			lua_pushcfunction(L, T::dispose_T);
			base_type::set(L, methods, "dispose");
		}
		
		lua_pop(L, 2);	// drop metatable and method table
		return 0;
	}
	
public:
	void PostConstruct (lua_State* L) {};
};

} // end of the namespace

#endif
