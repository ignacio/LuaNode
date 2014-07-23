#ifndef __luaCppBridge_BaseObject_h__
#define __luaCppBridge_BaseObject_h__

#include <lua.hpp>
#include "lcbBridgeConfig.h"
#include "lcbException.h"
#include "lcbTypeChecks.h"

#if defined(ENABLE_TRACE)
	#include <typeinfo>
#endif

namespace LuaCppBridge {

typedef void* ReferenceKey;

/**
BaseObject is the base class for Lua wrappers.
It is instanced with T (the class to export) and Base (the wrapper to use).

For all created objects a reference can be stored in Lua, so when the C++ side can call GetSelf when it needs to
retrieve a reference to the object.
This behaviour is disabled by default. If needed, just call Class::EnableTracking() before Class::Register()
*/
template <typename T, typename Base>
class BaseObject {
public:
	typedef struct { T* pT; bool collectable; } userdataType;
	typedef int (T::*mfp)(lua_State* L);
	struct RegType {
		const char* name;
		mfp mfunc;
	};

	static bool s_trackingEnabled;
	static int s_trackingIndex;

	static void EnableTracking (lua_State* L) {
		s_trackingEnabled = true;
		// creates a table where we'll do the tracking of objects. The table will be weak, so Lua can
		// collect the objects in there.
		lua_newtable(L);
		int weakTable = lua_gettop(L);
		lua_pushvalue(L, weakTable);	// table is its own metatable
		
		lua_pushliteral(L, "__mode");
		lua_pushliteral(L, "v");	// objects in this table have weak references
		lua_settable(L, weakTable);
		lua_setmetatable(L, weakTable);
		
		s_trackingIndex = luaL_ref(L, LUA_REGISTRYINDEX);
	}

	// Deals with calling new, pushing the new object to Lua and if enabled, track the object
	static T* Construct (lua_State* L, bool gc = false) {
		T* newObject = new T(L);	// call constructor for T objects
		Base::push(L, newObject, gc); // gc_T will delete this object
		if(s_trackingEnabled) {
			newObject->KeepTrack(L);
		}
		return newObject;
	}
	
public:
	// call named lua method from userdata method table
	static int call (lua_State* L, const char* method, int nargs = 0, int nresults = LUA_MULTRET)
	{
		int base = lua_gettop(L) - nargs;		// userdata index
		if(!checkudata(L, base, T::className)) {
			lua_settop(L, base - 1);			// drop userdata and args
			return error(L, "not a valid %s userdata", T::className);
		}
		
		lua_pushstring(L, method);				// method name
		lua_gettable(L, base);					// get method from userdata
		if(lua_isnil(L, -1)) {					// no method?
			lua_settop(L, base - 1);			// drop userdata and args
			return -1;
		}
		lua_insert(L, base);					// put method under userdata, args
												// now the stack is: method, self, args
		
		lua_call(L, 1 + nargs, nresults);		// call method
		return lua_gettop(L) - base + 1;		// number of results
	}
	
	// pcall named lua method from userdata method table
	static int pcall (lua_State* L, const char* method, int nargs = 0, int nresults = LUA_MULTRET, int errfunc = 0)
	{
		int base = lua_gettop(L) - nargs;		// userdata index
		if(!checkudata(L, base, T::className)) {
			lua_settop(L, base - 1);			// drop userdata and args
			return error(L, "not a valid %s userdata", T::className);
		}
		
		lua_pushstring(L, method);				// method name
		lua_gettable(L, base);					// get method from userdata
		if(lua_isnil(L, -1)) {					// no method?
			lua_settop(L, base - 1);			// drop userdata and args
			return -1;
		}
		lua_insert(L, base);					// put method under userdata, args
												// so the stack now is: method, self, args
		
		int status = lua_pcall(L, 1 + nargs, nresults, errfunc);	// call method
		if(status) {
			const char* msg = lua_tostring(L, -1);
			if(msg == NULL) {
				msg = "(error with no message)";
			}
			lua_pushfstring(L, "%s:%s status = %d\n%s", T::className, method, status, msg);
			lua_remove(L, base);				// remove old message
			return -1;
		}
		return lua_gettop(L) - base + 1;		// number of results
	}
	
	// push onto the Lua stack a userdata containing a pointer to T object
	static int push (lua_State* L, T* obj, bool gc = false) {
		if(!obj) {
			lua_pushnil(L);
			return 0;
		}
		getmetatable(L, T::className);	// look for the metatable
		if(lua_isnil(L, -1)) {
			return error(L, "%s missing metatable", T::className);
		}
		int mt = lua_gettop(L);
		subtable(L, mt, "userdata", "v");
		userdataType* ud = static_cast<userdataType*>(pushuserdata(L, obj, sizeof(userdataType)));
		if(ud) {
			ud->pT = obj;	// store pointer to object in userdata
			lua_pushvalue(L, mt);
			lua_setmetatable(L, -2);
			ud->collectable = gc;
		}
		lua_replace(L, mt);
		lua_settop(L, mt);
		return mt;	// index of userdata containing pointer to T object
	}
	
	// push onto the Lua stack a userdata containing a pointer to T object. The object is not collectable and is unique
	// (two calls to push_unique will yield two different userdata)
	static int push_unique (lua_State* L, T* obj) {
		if(!obj) {
			lua_pushnil(L);
			return 0;
		}
		getmetatable(L, T::className);	// look for the metatable
		if(lua_isnil(L, -1)) {
			return error(L, "%s missing metatable", T::className);
		}
		int mt = lua_gettop(L);
		userdataType *ud = static_cast<userdataType*>(lua_newuserdata(L, sizeof(userdataType))); // create new userdata
		if(ud) {
			ud->pT = obj;	// store pointer to object in userdata
			ud->collectable = false;
			lua_pushvalue(L, mt);
			lua_setmetatable(L, -2);
		}
		lua_replace(L, mt);
		lua_settop(L, mt);
		return mt;	// index of userdata containing pointer to T object
	}
	
	// when you push an object and you can't guarantee its lifetime, you should 'unpush' it
	static void unpush (lua_State* L, T* obj) {
		int top = lua_gettop(L);
		if(!obj) {
			return;
		}
		getmetatable(L, T::className);	// look for the metatable
		if(lua_isnil(L, -1)) {
			lua_settop(L, top);	// restore the stack
			error(L, "%s missing metatable", T::className);
			return;
		}
		// get the 'userdata' table
		int mt = lua_gettop(L);
		subtable(L, mt, "userdata", "v");
		int userdata_table = lua_gettop(L);

		// get the userdata
		lua_pushlightuserdata(L, obj);
		lua_gettable(L, userdata_table);
		int userdata = lua_gettop(L);
		if(lua_isnil(L, userdata)) {
			lua_settop(L, top);	// restore the stack
			return;
		}
		const userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, -1));
		if(ud->collectable) {
			lua_settop(L, top);	// restore the stack
			error(L, "unpush on a collectable object of type '%s' is forbidden", T::className);
		}
		
		// remove the userdata
		lua_pushlightuserdata(L, obj);
		lua_pushnil(L);
		lua_settable(L, userdata_table);		// userdata[key] = nil
		
		lua_settop(L, top);	// restore the stack
	}
	
	// if 'narg' is the index of a non-nil value, checks its type. Else returns NULL.
	static T* checkopt (lua_State* L, int narg) {
		if(!lua_isnil(L, narg)) {
			return check(L, narg);
		}
		return NULL;
	}
	
	// get userdata from Lua stack and return pointer to T object
	static T* check (lua_State* L, int narg) {
		userdataType* ud = static_cast<userdataType*>(checkudata(L, narg, T::className));
		if(!ud) {
			typerror(L, narg, T::className);
			return NULL;
		}
		return ud->pT;	// pointer to T object
	}
	
	// test if the value in the given position in the stack is a T object
	static bool test (lua_State* L, int narg) {
		void* p = lua_touserdata(L, narg);
		if (p != NULL) {							/* value is a userdata? */
			if (lua_getmetatable(L, narg)) {		/* does it have a metatable? */
				lua_pushlightuserdata(L, (void*)T::className);
				lua_rawget(L, LUA_REGISTRYINDEX);	/* get correct metatable */
				if (lua_rawequal(L, -1, -2)) {		/* does it have the correct mt? */
					lua_pop(L, 2);					/* remove both metatables */
					return true;
				}
			}
		}
		return false;
	}

protected:
	static int forbidden_new_T (lua_State* L) {
		return luaL_error(L, "Constructing objects of type '%s' is not allowed from the Lua side", T::className);
	}

	// member function dispatcher
	static int thunk_methods (lua_State* L) {
		try {
			// stack has userdata, followed by method args
			T* obj = Base::check(L, 1);	// get 'self', or if you prefer, 'this'
			// get member function from upvalue
			RegType* l = static_cast<RegType*>(lua_touserdata(L, lua_upvalueindex(1)));
			return (obj->*(l->mfunc))(L);	// call member function
		}
		catch(std::exception& e) {
			lua_pushstring(L, e.what());
		}
		return lua_error(L);
	}
	
	// create a new T object and push onto the Lua stack a userdata containing a pointer to T object
	static int new_T (lua_State* L) {
		try {
			lua_remove(L, 1);	// use classname:new(), instead of classname.new()
			T* obj = new T(L);	// call constructor for T objects
			push(L, obj, true);	// gc_T will delete this object
			if(s_trackingEnabled) {
				obj->KeepTrack(L);
			}
			return 1;			// userdata containing pointer to T object
		}
		catch(std::exception& e) {
			lua_pushstring(L, e.what());
		}
		return lua_error(L);
	}

	// garbage collection metamethod, comes with the userdata on top of the stack
	static int gc_T (lua_State* L) {
#ifdef ENABLE_TRACE
		char buff[256];
		sprintf(buff, "attempting to collect object of type '%s'\n", T::className);
		OutputDebugString(buff);
#endif
		const userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, -1));
		if(!ud->collectable) {
			return 0;
		}
#ifdef ENABLE_TRACE
			sprintf(buff, "collected %s (%p)\n", T::className, ud->pT);
			OutputDebugString(buff);
#endif
		if(ud->pT) delete ud->pT; // call destructor for T objects
		return 0;
	}
	
	static int tostring_T (lua_State* L) {
		userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
		T* obj = ud->pT;
		lua_pushfstring(L, "%s (%p)", T::className, obj);
		return 1;
	}

	static int dispose_T (lua_State* L)
	{
		userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
		if(!ud->collectable) {
			return luaL_error(L, "Disposing uncollectable objects of type '%s' is forbidden from the Lua side", T::className);
		}
		T* obj = ud->pT;
		if(s_trackingEnabled) {
			lua_rawgeti(L, LUA_REGISTRYINDEX, s_trackingIndex);			// stack-> self, instances
			lua_pushlightuserdata(L, obj->m_selfReference);	 			// remove the reference from the registry
			lua_pushnil(L);
			lua_settable(L, -3);										// registry[m_selfReference] = nil
			lua_pop(L, 1);												// stack-> self
		}
		// Delete it and mark it as not collectable
		gc_T(L);
		ud->collectable = false;
		return 0;
	}

	static void set (lua_State* L, int table_index, const char* key) {
		lua_pushstring(L, key);
		lua_insert(L, -2);	// swap value and key
		lua_settable(L, table_index);
	}

	static void weaktable (lua_State* L, const char* mode) {
		lua_newtable(L);
		lua_pushvalue(L, -1);	// table is its own metatable
		lua_setmetatable(L, -2);
		lua_pushliteral(L, "__mode");
		lua_pushstring(L, mode);
		lua_settable(L, -3);	// metatable.__mode = mode
	}

	// adds a weak subtable (named 'name') to the table at index 'tindex' and returns it at the top of the stack.
	static void subtable (lua_State* L, int tindex, const char* name, const char* mode) {
		lua_pushstring(L, name);
		lua_gettable(L, tindex);
		if (lua_isnil(L, -1)) {
#ifdef ENABLE_TRACE
			char buffer[128];
			const char* typeName = typeid(T).name();
			sprintf(buffer, "creating new subtable (%s) with mode '%s' for '%s'\n", name, mode, typeName);
			OutputDebugString(buffer);
#endif
			lua_pop(L, 1);
			lua_checkstack(L, 3);
			weaktable(L, mode);
			lua_pushstring(L, name);
			lua_pushvalue(L, -2);
			lua_settable(L, tindex);
		}
	}

	// if the table at the top of the stack has a userdata with a given key, puts it on the stack and returns it.
	// else, creates a new userdata, store it in that table with the given key, puts it on the stack and returns it.
	// (it returns non null when it has created a new userdata)
	static void* pushuserdata (lua_State* L, void* key, size_t sz) {
		void* ud = 0;
		lua_pushlightuserdata(L, key);
		lua_gettable(L, -2);				// lookup[key]
		if(lua_isnil(L, -1)) {
			lua_pop(L, 1);					// drop nil
			lua_checkstack(L, 3);
			ud = lua_newuserdata(L, sz);	// create new userdata
			lua_pushlightuserdata(L, key);
			lua_pushvalue(L, -2);			// dup userdata
			lua_settable(L, -4);			// lookup[key] = userdata
		}
		return ud;
	}

	// if the table at the top of the stack has a table with a given key and puts it on the stack.
	// else, creates a table, store it in that table with the given key and puts it on the stack.
	// In both cases returns the index of the stack top.
	static int pushtable (lua_State* L, void* key) {
		lua_pushlightuserdata(L, key);
		lua_gettable(L, -2);
		if(lua_isnil(L, -1)) {		// if not found on the table
			lua_pop(L, 1);
			lua_checkstack(L, 3);
			lua_newtable(L);
			lua_pushlightuserdata(L, key);
			lua_pushvalue(L, -2);	// copy the table
			lua_settable(L, -4);	// lookup[key] = table
		}
		return lua_gettop(L);
	}
	
	// like luaL_newmetatable, except it converts the key to a lightuserdata
	static int newmetatable (lua_State* L, const char* key) {
		lua_pushlightuserdata(L, (void*)key);
		lua_rawget(L, LUA_REGISTRYINDEX);	/* get registry.name */
		if (!lua_isnil(L, -1)) {			/* name already in use? */
			return 0;	/* leave previous value on top, but return 0 */
		}
		lua_pop(L, 1);
		lua_newtable(L);	/* create metatable */
		lua_pushlightuserdata(L, (void*)key);
		lua_pushvalue(L, -2);
		lua_rawset(L, LUA_REGISTRYINDEX);	/* registry.name = metatable */
		return 1;
	}

	// like luaL_checkudata, except it converts the key to a lightuserdata
	static void* checkudata (lua_State* L, int ud, const char* key) {
		void* p = lua_touserdata(L, ud);
		if (p != NULL) {	/* value is a userdata? */
			if (lua_getmetatable(L, ud)) {	/* does it have a metatable? */
				lua_pushlightuserdata(L, (void*)key);
				lua_rawget(L, LUA_REGISTRYINDEX);	/* get correct metatable */
				if (lua_rawequal(L, -1, -2)) {		/* does it have the correct mt? */
					lua_pop(L, 2);	/* remove both metatables */
					return p;
				}
			}
		}
		typerror(L, ud, key);	/* else error */
		return NULL;	/* to avoid warnings */
	}

	// like luaL_getmetatable, except it converts the key to a lightuserdata
	static void getmetatable (lua_State* L, const char* key) {
		lua_pushlightuserdata(L, (void*)key);
		lua_rawget(L, LUA_REGISTRYINDEX);
	}

public:
	mutable ReferenceKey m_selfReference;
	void KeepTrack (lua_State* L) const {
		m_selfReference = (ReferenceKey)this;
		lua_rawgeti(L, LUA_REGISTRYINDEX, s_trackingIndex);		// stack-> self, instances
		lua_pushlightuserdata(L, m_selfReference);	 			// uses 'this' as key // stack-> self, instances, key
		lua_pushvalue(L, -3);									// stack-> self, instances, key, self
		lua_settable(L, -3);									// stack-> self, instances
		lua_pop(L, 1);											// stack-> self
	}

	ReferenceKey GetSelfReference () const {
		return m_selfReference;
	}

	/**
	Looks for the table (or userdata) associated to a given instance of a class
	*/
	void GetSelf (lua_State* L) {
		if(!s_trackingEnabled) {
			error(L, "class %s is not being tracked", T::className);
		}
		lua_rawgeti(L, LUA_REGISTRYINDEX, s_trackingIndex);
		lua_assert(lua_istable(L, -1));
		lua_pushlightuserdata(L, m_selfReference);
		lua_gettable(L, -2);
		if(lua_isnil(L, -1)) {
			error(L, "'%p' has no bound userdata or table", m_selfReference);
			return;
		}
		lua_remove(L, -2);	// remove the instances table
		// leave the table or userdata associated with the given instance on top of the stack
	}

	/**
	Looks for the table or userdata associated with the given reference and leaves it on the stack
	*/
	static void GetReference (lua_State* L, ReferenceKey key) {
#ifdef ENABLE_TRACE
		char buffer[128];
		const char* typeName = typeid(T).name();
		sprintf(buffer, "retrieving reference to '%p' as type '%s'\n", key, typeName);
		OutputDebugString(buffer);
#endif
		lua_rawgeti(L, LUA_REGISTRYINDEX, s_trackingIndex);
		lua_pushlightuserdata(L, key);
		lua_gettable(L, -2);
		if(lua_isnil(L, -1)) {
#ifdef ENABLE_TRACE
			while(lua_next(L, -2) != 0) {
				char clave[256];
				char valor[256];
				switch(lua_type(L, -2)) {
				case LUA_TSTRING:
					strcpy(clave, lua_tostring(L, -2));
					break;
				case LUA_TNUMBER:
					sprintf(clave, "%d", (int)lua_tonumber(L, -2));
					//itoa((int)lua_tonumber(L, -2), clave, 10);
					break;
				case LUA_TTABLE:
					sprintf(clave, "table: (%p)", lua_topointer(L, -2));
					break;
				case LUA_TUSERDATA:
					sprintf(clave, "userdata: (%p)", lua_topointer(L, -2));
					break;
				case LUA_TLIGHTUSERDATA:
					sprintf(clave, "lightuserdata: (%p)", lua_topointer(L, -2));
					break;
				default:
					strcpy(clave, lua_typename(L, lua_type(L, -2)));
					break;
				}
				switch(lua_type(L, -1)) {
				case LUA_TSTRING:
					strcpy(valor, lua_tostring(L, -1));
					break;
				case LUA_TNUMBER:
					sprintf(valor, "%d", (int)lua_tonumber(L, -1));
					//itoa((int)lua_tonumber(L, -1), valor, 10);
					break;
				case LUA_TTABLE:
					sprintf(valor, "table: (%p)", lua_topointer(L, -1));
					break;
				case LUA_TUSERDATA:
					sprintf(valor, "userdata: (%p)", lua_topointer(L, -1));
					break;
				case LUA_TLIGHTUSERDATA:
					sprintf(valor, "lightuserdata: (%p)", lua_topointer(L, -1));
					break;
				default:
					strcpy(valor, lua_typename(L, lua_type(L, -1)));
					break;
				}
				sprintf(buffer, "'%s', '%s'\n", clave, valor);
				OutputDebugString(buffer);
				lua_pop(L, 1);
			}
#endif
			error(L, "'%p' has no bound userdata or table", key);
			return;
		}
		lua_remove(L, -2);	// remove the instances table
		// leave the table or userdata associated with the given instance on top of the stack
	}
};

template <typename T, typename Base>
bool BaseObject<T, Base>::s_trackingEnabled = false;

template <typename T, typename Base>
int BaseObject<T, Base>::s_trackingIndex = LUA_NOREF;

} // end of the namespace

#endif
