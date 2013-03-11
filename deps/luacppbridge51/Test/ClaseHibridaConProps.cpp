#include "stdafx.h"

// override para que no tome los luaIncludes del bridge (por tema paths)
#define __LUA_INCLUDES_H__
extern "C" {
#include "..\..\..\..\..\packages\Lua5.1\include\lua.h"
#include "..\..\..\..\..\packages\Lua5.1\include\lualib.h"
#include "..\..\..\..\..\packages\lua5.1\include\lauxlib.h"
}

#include "ClaseHibridaConProps.h"

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

const char* ClaseHibridaConProps::className = "ClaseHibridaConProperties";
const ClaseHibridaConProps::RegType ClaseHibridaConProps::methods[] = {
	{"RetornaString", &ClaseHibridaConProps::RetornaString},
	{"Test_Test", &ClaseHibridaConProps::Test_test},
	{"Test_Check", &ClaseHibridaConProps::Test_check},
	{"Test_PushNewCollectable", &ClaseHibridaConProps::Test_PushNewCollectable},
	{"Test_PushNewNonCollectable", &ClaseHibridaConProps::Test_PushNewNonCollectable},
	{0}
};

const ClaseHibridaConProps::RegType ClaseHibridaConProps::getters[] = {
	LCB_ADD_GET(ClaseHibridaConProps, builtin_property),
	LCB_ADD_GET(ClaseHibridaConProps, readonly_property),
	{0}
};

const ClaseHibridaConProps::RegType ClaseHibridaConProps::setters[] = {
	LCB_ADD_SET(ClaseHibridaConProps, builtin_property),
	LCB_ADD_SET(ClaseHibridaConProps, writeonly_property),
	{0}
};

ClaseHibridaConProps::ClaseHibridaConProps(lua_State* L)
{
	printf("Constructed ClaseHibridaConProps (%p)\n", this);

	m_builtin_property = "this is a property of a hybrid object";
	m_readonly_property = "this property is readonly";
}

ClaseHibridaConProps::~ClaseHibridaConProps()
{
	printf("Destructed ClaseHibridaConProps (%p)\n", this);
}

//////////////////////////////////////////////////////////////////////////
/// create a new T object and push onto the Lua stack a userdata containing a pointer to T object
int ClaseHibridaConProps::new_T(lua_State* L) {
	lua_remove(L, 1);	// use classname:new(), instead of classname.new()
	ClaseHibridaConProps* obj = new ClaseHibridaConProps(L);	// call constructor for T objects
	int newObject = push(L, obj, true); // gc_T will delete this object
	if(s_trackingEnabled) {
		obj->KeepTrack(L);
	}
	
	// if this method was called with a table as parameter, then copy its values to the newly created object
	if(lua_gettop(L) == 2 && lua_istable(L, 1)) {
		lua_pushnil(L);					// stack: table, newObject, nil
		while(lua_next(L, 1)) {			// stack: table, newObject, key, value
			lua_pushvalue(L, -2);		// stack: table, newObject, key, value, key
			lua_insert(L, -2);			// stack: table, newObject, key, key, value
			lua_settable(L, newObject);	// stack: table, newObject, key
		}
	}
		
	// last step in the creation of the object. call a method that can access the userdata that will be sent 
	// back to Lua
	obj->PostConstruct(L);
	return 1;			// userdata containing pointer to T object
}

//////////////////////////////////////////////////////////////////////////
/// 
int ClaseHibridaConProps::tostring_T(lua_State* L) {
	lua_pushstring(L, "overridden tostring (ClaseHibridaConProps)");
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int ClaseHibridaConProps::RetornaString(lua_State* L) {
	lua_pushstring(L, "this is a hybrid object");
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
LCB_IMPL_GET(ClaseHibridaConProps, builtin_property) {
	lua_pushstring(L, m_builtin_property.c_str());
	return 1;
}

LCB_IMPL_SET(ClaseHibridaConProps, builtin_property) {
	m_builtin_property = luaL_checkstring(L, 3);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
LCB_IMPL_GET(ClaseHibridaConProps, readonly_property) {
	lua_pushstring(L, m_readonly_property.c_str());
	return 1;
}

LCB_IMPL_SET(ClaseHibridaConProps, writeonly_property) {
	m_writeonly_property = luaL_checkstring(L, 3);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// Lo uso para testear el método ::test
int ClaseHibridaConProps::Test_test(lua_State* L) {
	//int eq = lua_rawequal(L, 1, 2);
	//int t = lua_gettop(L);
	lua_pushboolean(L, test(L, -1));
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// Lo uso para testear el método ::check
int ClaseHibridaConProps::Test_check(lua_State* L) {
	check(L, -1);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int ClaseHibridaConProps::Test_PushNewCollectable(lua_State* L) {
	push(L, new ClaseHibridaConProps(L), true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int ClaseHibridaConProps::Test_PushNewNonCollectable(lua_State* L) {
	push(L, new ClaseHibridaConProps(L), false);
	return 1;
}