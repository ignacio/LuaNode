#ifndef LUANODE_PLATFORM_H_
#define LUANODE_PLATFORM_H_

namespace LuaNode {

class OS {
public:
	static char** SetupArgs(int argc, char *argv[]);
	static void SetProcessTitle(char *title);
	static const char* GetProcessTitle(int *len);

	static int GetMemory(size_t *rss, size_t *vsize);
	static int GetExecutablePath(char* buffer, size_t* size);

	static int GetWorkingDirectory();

	static const char* GetPlatform();

	static int SetConsoleForegroundColor(lua_State* L);
	static int SetConsoleBackgroundColor(lua_State* L);

	static bool PlatformInit();

	static int Cwd(lua_State* L);
};


}  // namespace LuaNode
#endif  // LUANODE_PLATFORM_H_
