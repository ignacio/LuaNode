#ifndef _LUANODE_API_H
#define _LUANODE_API_H

typedef struct LuaNodeModuleInterface {
	int interface_version;

	bool (*luanode_post) (const char* module_name, const char* function_name, int key, void* userdata);
} LuaNodeModuleInterface;

#endif