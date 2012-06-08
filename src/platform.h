#ifndef LUANODE_PLATFORM_H_
#define LUANODE_PLATFORM_H_

namespace LuaNode {

class Platform {
public:
	static char** SetupArgs(int argc, char *argv[]);
	static void SetProcessTitle(const char *title);
	static int SetProcessTitle(lua_State* L);
	static const char* GetProcessTitle(int *len);
	static int GetProcessTitle(lua_State* L);

	static int GetMemory(size_t *rss, size_t *vsize);
	static int GetExecutablePath(char* buffer, size_t* size);

	static int GetWorkingDirectory();

	static const char* GetPlatform();

	static bool Initialize();

	static int Cwd(lua_State* L);

	static int GetHandleType (lua_State* L);
};


}  // namespace LuaNode
#endif  // LUANODE_PLATFORM_H_
