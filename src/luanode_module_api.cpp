#include "StdAfx.h"
#include "blogger.h"
#include "LuaNode.h"
#include "luanode_module_api.h"
#include <boost/bind.hpp>

static LuaNodeModuleInterface interface;

static int postbackCallback = LUA_NOREF;

//////////////////////////////////////////////////////////////////////////
/// 
static void HandleModuleCallback(const char* module_name, const char* function_name, int key, void* userdata) {
	CEvaluadorLua& eval = LuaNode::GetLuaEval();
	lua_State* L = eval;

	if(postbackCallback == LUA_NOREF) {
		lua_getfield(L, LUA_GLOBALSINDEX, "process");
		lua_getfield(L, -1, "_postBackToModule");
		postbackCallback = luaL_ref(L, LUA_REGISTRYINDEX);
		lua_pop(L, 1);
	}
	// I'd previously stored the callback in the registry
	lua_rawgeti(eval, LUA_REGISTRYINDEX, postbackCallback);
	
	lua_pushstring(L, module_name);
	lua_pushstring(L, function_name);
	lua_pushinteger(L, key);
	lua_pushlightuserdata(L, userdata);
	eval.call(4, LUA_MULTRET);

	lua_settop(eval, 0);
};

//////////////////////////////////////////////////////////////////////////
/// 
static bool LuaNode_Post (const char* module_name, const char* function_name, int key, void* userdata) {
	LogDebug("LuaNode_Post: module name: '%s', function name: '%s', key: '%d'",
		module_name, function_name, key);

	LuaNode::GetIoService().post(
		boost::bind(HandleModuleCallback, module_name, function_name, key, userdata)
		);
	return true;
}

//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::ModuleApi::Register(lua_State* L, int table) {
	interface.interface_version = 1;
	interface.luanode_post = LuaNode_Post;

	LuaNodeModuleInterface* pInterf = (LuaNodeModuleInterface*)lua_newuserdata(L, sizeof(LuaNodeModuleInterface));
	memcpy(pInterf, &interface, sizeof(LuaNodeModuleInterface));

	lua_setfield(L, table, "module_api");
}