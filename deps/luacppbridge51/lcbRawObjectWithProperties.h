#ifndef __luaCppBridge_RawObjectWithProperties_h__
#define __luaCppBridge_RawObjectWithProperties_h__

#include <lua.hpp>
#include "lcbBaseObject.h"
#include "lcbException.h"
#include "lcbTypeChecks.h"

#define LCB_ROWP_DECLARE_EXPORTABLE(classname) \
	static const LuaCppBridge::RawObjectWithProperties< classname >::RegType methods[];\
	static const LuaCppBridge::RawObjectWithProperties< classname >::RegType setters[];\
	static const LuaCppBridge::RawObjectWithProperties< classname >::RegType getters[];\
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
A RawObjectWithProperties is a C++ class exposed to Lua as a userdata. This prevents adding additional methods and
members. Only the functions exposed from C++ will be available.
Also, properties can be defined with setters and getters for each.

TO DO:
Inheritance won't work with this class. I couldn't make it see its parent's properties, so I disabled the whole thing.
*/
template <typename T, bool is_disposable = false>
class RawObjectWithProperties : public BaseObject<T, RawObjectWithProperties<T> > {
private:
	typedef BaseObject<T, RawObjectWithProperties<T> > base_type;
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

protected:
	/**
	* __index metamethod. Looks for a property, then for a method.
	* upvalues:	1 = table with get properties
	* 			2 = table with methods
	* initial stack: self (userdata), key
	*/
	static int thunk_index (lua_State* L) {
		// stack: userdata, key
		try {
			T* obj = base_type::check(L, 1); 	// get 'self', or if you prefer, 'this'
			lua_pushvalue(L, 2);				// stack: userdata, key key
			lua_rawget(L, lua_upvalueindex(1));	// upvalue 1 = getters table
			if(lua_isnil(L, -1)) {				// not a property, look for a method
				lua_pop(L, 1);					// stack: userdata, key (arguments??)
				lua_pushvalue(L, 2);			// userdata, key, argumentos ... key
				lua_rawget(L, lua_upvalueindex(2));
				if(!lua_isnil(L, -1)) {
					// leave the thunk on the stack so Lua will call it
					return 1;
				}
				else {
					lua_pop(L, 1);
					// I should keep looking up in the parent's metatable, (if I'm inheriting something) but I
					// don't know how its done.
					// Issue an error
					error(L, "__index: the value '%s' does not exist", lua_tostring(L, 2));
					return 1; // shut up the compiler
				}
			}
			else {
				// stack: userdata, key, getter (RegType*)
				RegType* l = static_cast<RegType*>(lua_touserdata(L, -1));
				lua_settop(L, 1);
				return (obj->*(l->mfunc))(L);	// call member function
			}
			return 0;
		}
		catch(std::exception& e) {
			lua_pushstring(L, e.what());
		}
		return lua_error(L);
	}
	
	static int thunk_newindex (lua_State* L) {
		try {
			// stack: userdata, key, value
			T* obj = base_type::check(L, 1);	// get 'self', or if you prefer, 'this'
			lua_pushvalue(L, 2);				// stack: userdata, key, value, key
			lua_rawget(L, lua_upvalueindex(1));	// upvalue 1 = setters table
			if(!lua_isnil(L, -1)) {
												// stack: userdata, key, value, setter
				RegType* p = static_cast<RegType*>(lua_touserdata(L, -1));
				lua_pop(L, 1);					// stack: userdata, key, value
				return (obj->*(p->mfunc))(L);	// call member function
			}
			else {
				error(L, "__newindex: el valor '%s' no existe", lua_tostring(L, 2));
				/*// Esto es opcional. Si lo dejo, le puedo agregar funciones
				// a un objeto trabajando sobre una instancia, sino tengo que agregarlas
				// a la clase
				if(lua_type(L, 3) == LUA_TFUNCTION) {
					lua_pop(L, 1);	// stack: userdata, clave, valor
					lua_rawset(L, lua_upvalueindex(2));
				}
				else {
					lua_pop(L, 1);	// stack: userdata, clave, valor
					lua_rawset(L, lua_upvalueindex(2));
				}*/
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
		bool isCreatableByLua = lua_toboolean(L, 2) != 0;
		
		int whereToRegister = 1;
		const RegType* l;
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
		
		lua_pushliteral(L, "__index");
		lua_newtable(L);
		int index = lua_gettop(L);
		for (l = T::getters; l->name; l++) {
			lua_pushstring(L, l->name);
			lua_pushlightuserdata(L, (void*)l);
			lua_settable(L, index);
		}
		lua_pushvalue(L, methods);
		lua_pushcclosure(L, T::thunk_index, 2);
		lua_settable(L, metatable);
		
		lua_pushliteral(L, "__newindex");
		lua_newtable(L);
		int newindex = lua_gettop(L);
		for (l = T::setters; l->name; l++) {
			lua_pushstring(L, l->name);
			lua_pushlightuserdata(L, (void*)(l));
			lua_settable(L, newindex);
		}
		
		lua_pushcclosure(L, T::thunk_newindex, 1);
		lua_settable(L, metatable);
		
		
		lua_pushcfunction(L, T::tostring_T);
		base_type::set(L, metatable, "__tostring");
		
		lua_pushcfunction(L, T::gc_T);
		base_type::set(L, metatable, "__gc");

		lua_pushstring(L, T::className);
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
		for(l = T::methods; l->name; l++) {
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
