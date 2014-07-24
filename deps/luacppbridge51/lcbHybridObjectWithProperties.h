#ifndef __luaCppBridge_HybridObjectWithProperties_h__
#define __luaCppBridge_HybridObjectWithProperties_h__

#include <lua.hpp>
#include "lcbBaseObject.h"
#include "lcbException.h"
#include "lcbTypeChecks.h"

#define LCB_HOWP_DECLARE_EXPORTABLE(classname) \
	static const LuaCppBridge::HybridObjectWithProperties< classname >::RegType methods[];\
	static const LuaCppBridge::HybridObjectWithProperties< classname >::RegType setters[];\
	static const LuaCppBridge::HybridObjectWithProperties< classname >::RegType getters[];\
	static const char* className

/**
Some useful macros when defining properties.
*/
#define LCB_DECL_SETGET(fieldname) int set_##fieldname (lua_State* L); int get_##fieldname (lua_State*L)
#define LCB_DECL_GET(fieldname) int get_##fieldname (lua_State* L)
#define LCB_DECL_SET(fieldname) int set_##fieldname (lua_State* L)
#define LCB_ADD_SET(classname, fieldname) { #fieldname , &classname::set_##fieldname }
#define LCB_ADD_GET(classname, fieldname) { #fieldname , &classname::get_##fieldname }
#define LCB_IMPL_SET(classname, fieldname) int classname::set_##fieldname (lua_State* L)
#define LCB_IMPL_GET(classname, fieldname) int classname::get_##fieldname (lua_State* L)

namespace LuaCppBridge {

/**
An HybridObjectWithProperties is a C++ class exposed to Lua as a table. It differs from a RawObjectWithProperties
in that additional methods and properties can be added dynamically to its instances.

There are some things to take into account.
For instance, if a property has only a getter method, then it is read-only. Any attempt to write to it will issue an error.
  print(obj.test) -- gives the 'internal' value
  obj.test = "something"	-- error!


TO DO:
Inheritance won't work with this class. I couldn't make it see its parent's properties, so I disabled the whole thing.
*/
template <typename T, bool is_disposable = false>
class HybridObjectWithProperties : public BaseObject<T, HybridObjectWithProperties<T> > {
private:
	typedef BaseObject<T, HybridObjectWithProperties<T> > base_type;
public:
	typedef typename base_type::RegType RegType;
	typedef typename base_type::userdataType userdataType;

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
		if(T::s_trackingEnabled) {
			obj->KeepTrack(L);
		}
		
		// if this method was called with a table as parameter, then copy its values to the newly created object
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
		return 1;			// userdata containing pointer to T object
	}
	
	// push onto the Lua stack a userdata containing a pointer to T object
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
		userdataType* ud = static_cast<userdataType*>(base_type::pushuserdata(L, obj, sizeof(userdataType)));
		if(ud) {
			// set up a table as the userdata environment
			lua_newtable(L);
			lua_setfenv(L, -2);
			ud->pT = obj;	// store pointer to object in userdata
			lua_pushvalue(L, metatable);
			lua_setmetatable(L, -2);	// set metatable for userdata
			ud->collectable = gc;
		}
		// leave userdata on top of the stack
		lua_replace(L, metatable);
		lua_settop(L, metatable);
		return metatable;	// index of userdata containing pointer to T object
	}

	// push onto the Lua stack a userdata containing a pointer to T object. The object is not collectable and is unique
	// (two calls to push_unique will yield two different userdata)
	static int push_unique (lua_State* L, T* obj) {
		if(!obj) {
			lua_pushnil(L);
			return 0;
		}
		base_type::getmetatable(L, T::className);	// look for the metatable
		if(lua_isnil(L, -1)) {
			return error(L, "%s missing metatable", T::className);
		}
		int mt = lua_gettop(L);
		userdataType* ud = static_cast<userdataType*>(lua_newuserdata(L, sizeof(userdataType)));	// create new userdata
		if(ud) {
			// set up a table as the userdata environment
			lua_newtable(L);
			lua_setfenv(L, -2);
			ud->pT = obj;	// store pointer to object in userdata
			ud->collectable = false;
			lua_pushvalue(L, mt);
			lua_setmetatable(L, -2);
		}
		lua_replace(L, mt);
		lua_settop(L, mt);
		return mt;	// index of userdata containing pointer to T object
	}
	
protected:
	/**
	__index metamethod. Looks for a a dynamic property, then for a property, then for a method.
	upvalues:	1 = table with get properties
				2 = table with methods
	initial stack: self (userdata), key
	*/
	static int thunk_index(lua_State* L) {
		try {
			T* obj = base_type::check(L, 1);	// get 'self', or if you prefer, 'this'
			lua_getfenv(L, 1);					// stack: userdata, key, userdata_env

			// Look in the userdata's environment
			lua_pushvalue(L, 2);				// stack: userdata, key, userdata_env, key
			lua_rawget(L, 3);
			if(!lua_isnil(L, -1)) {
				// found something, return it
				return 1;
			}
			lua_pop(L, 2);						// stack: userdata, key

			// Look in getters table
			lua_pushvalue(L, 2);				// stack: userdata, key, key
			lua_rawget(L, lua_upvalueindex(1));
			if(!lua_isnil(L, -1)) {				// found a property
				// stack: userdata, key, getter (RegType*)
				RegType* l = static_cast<RegType*>(lua_touserdata(L, -1));
				lua_settop(L, 1);
				return (obj->*(l->mfunc))(L);  	// call member function
			}
			else {
				lua_pop(L, 1);					// stack: userdata, key
				lua_pushvalue(L, 2);			// stack: userdata, key, key
				
				// not a property, look for a method up the inheritance hierarchy
				lua_gettable(L, lua_upvalueindex(2));
				if(!lua_isnil(L, -1)) {
					// found the method, return it
					return 1;
				}
				else {
					// nothing was found
					lua_pushnil(L);
					return 1;
				}
			}
			return 0;
		}
		catch(std::exception& e) {
			lua_pushstring(L, e.what());
		}
		return lua_error(L);
	}
	
	/**
	__newindex metamethod. Looks for a set property, else it sets the value as a dynamic property.
	upvalues:	1 = table with set properties
	initial stack: self (userdata), key, value
	*/
	static int thunk_newindex (lua_State* L) {
		try {
			T* obj = base_type::check(L, 1);	// get 'self', or if you prefer, 'this'

			// look if there is a setter for 'key'
			lua_pushvalue(L, 2);				// stack: userdata, key, value, key
			lua_rawget(L, lua_upvalueindex(1));
			if(!lua_isnil(L, -1)) {
												// stack: userdata, key, value, setter
				RegType* p = static_cast<RegType*>(lua_touserdata(L, -1));
				lua_pop(L, 1);					// stack: userdata, key, value
				return (obj->*(p->mfunc))(L);	// call member function
			}
			else {
				// there is no setter. If there is a getter, then this property is read only.
												// stack: userdata, key, value, nil
				lua_pop(L, 1);					// stack: userdata, key, value
				lua_pushvalue(L, 2);			// stack: userdata, key, value, key
				lua_rawget(L, lua_upvalueindex(2));	// stack: userdata, key, value, getter?
				if(!lua_isnil(L, -1)) {
					lua_pop(L, 1);
					return error(L, "trying to write to read only property '%s'", lua_tostring(L, 2));
				}
				// sets 'value' in the environment
				lua_pop(L, 1);					// stack: userdata, key, value
				lua_getfenv(L, 1);				// stack: userdata, key, value, userdata_env
				lua_replace(L, 1);				// stack: userdata_env, key, value
				lua_rawset(L, 1);
			}
			return 0;
		}
		catch(std::exception& e) {
			lua_pushstring(L, e.what());
		}
		return lua_error(L);
	}

private:
	static int RegisterLua (lua_State* L) {
		luaL_checktype(L, 1, LUA_TTABLE);	// must pass a table
		//const char* parentClassName = luaL_optstring(L, 2, NULL);
		bool isCreatableByLua = lua_toboolean(L, 3) != 0;
		
		int whereToRegister = 1;
		lua_newtable(L);
		int methods = lua_gettop(L);
		
		base_type::newmetatable(L, T::className);
		int metatable = lua_gettop(L);
		
		// store method table in globals so that scripts can add functions written in Lua.
		lua_pushvalue(L, methods);
		base_type::set(L, whereToRegister, T::className);
		
		// make getmetatable return the methods table
		lua_pushvalue(L, methods);
		lua_setfield(L, metatable, "__metatable");
		
		// lunar mio
		lua_newtable(L);								// getters, "__index"
		int getters_index = lua_gettop(L);
		lua_pushliteral(L, "__index");					// getters, "__index"
		lua_pushvalue(L, getters_index);				// getters, "__index", getters
		for(const RegType* l = T::getters; l->name; l++) {
			lua_pushstring(L, l->name);					// getters, "__index", getters, name
			lua_pushlightuserdata(L, (void*)l); 		// getters, "__index", getters, name, property implementation
			lua_settable(L, getters_index);				// getters, "__index", getters
		}
		lua_pushvalue(L, methods);						// getters, "__index", getters, methods
		lua_pushcclosure(L, T::thunk_index, 2);			// getters, "__index", thunk
		lua_settable(L, metatable);						// getters
		
		
		lua_pushliteral(L, "__newindex");				// getters, "__newindex"
		lua_newtable(L);								// getters, "__newindex", setters
		int newindex = lua_gettop(L);
		for (const RegType* setter = T::setters; setter->name; setter++) {
			lua_pushstring(L, setter->name);			// getters, "__newindex", setters, name
			lua_pushlightuserdata(L, (void*)(setter));	// getters, "__newindex", setters, name, property implementation
			lua_settable(L, newindex);					// getters, "__newindex", setters
		}
		lua_pushvalue(L, getters_index);				// getters, "__newindex", setters, getters
		lua_pushcclosure(L, T::thunk_newindex, 2);		// getters, "__newindex", thunk
		lua_settable(L, metatable);						// getters
		lua_pop(L, 1);									// remove the getters table
		
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
		for (const RegType* method = T::methods; method->name; method++) {
			lua_pushstring(L, method->name);
			lua_pushlightuserdata(L, (void*)method);
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

public:
	void PostConstruct(lua_State* L) {};
};

} // end of the namespace

#endif
