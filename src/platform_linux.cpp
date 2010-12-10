#include "stdafx.h"

#include "LuaNode.h"
#include "platform.h"


//static HANDLE m_hConsole = GetStdHandle(STD_OUTPUT_HANDLE);

/*static CONSOLE_SCREEN_BUFFER_INFO CConsoleGetInfo() {
	CONSOLE_SCREEN_BUFFER_INFO csbi = {0};

	GetConsoleScreenBufferInfo(m_hConsole, &csbi);
	return csbi;
}*/


namespace LuaNode {


	int OS::GetExecutablePath(char* buffer, size_t* size) {
		*size = readlink("/proc/self/exe", buffer, *size - 1);
		if (*size <= 0) return -1;
		buffer[*size] = '\0';
		return 0;
	}

	const char* OS::GetPlatform() {
		return "linux";
	}

	int OS::SetConsoleForegroundColor(lua_State* L) {
		const char* color = luaL_checkstring(L, 1);
		printf(color);
		return 0;
	}

	int OS::SetConsoleBackgroundColor(lua_State* L) {
		const char* color = luaL_checkstring(L, 1);
		printf(color);
		return 0;
	}

	bool OS::PlatformInit() {
		//SetConsoleOutputCP(CP_UTF8);
		return true;
	}

	//////////////////////////////////////////////////////////////////////////
	/// Retrieves the current working directory
	int OS::Cwd(lua_State* L) {
		char getbuf[2048];
		char *r = getcwd(getbuf, sizeof(getbuf) - 1);
		if (r == NULL) {
			luaL_error(L, strerror(errno));
		}

		getbuf[sizeof(getbuf) - 1] = '\0';
		lua_pushstring(L, getbuf);
		return 1;
	}


}  // namespace LuaNode