#include "stdafx.h"

#include "LuaNode.h"
#include "platform.h"


using namespace LuaNode;


int Platform::GetExecutablePath(char* buffer, size_t* size) {
	*size = readlink("/proc/self/exe", buffer, *size - 1);
	if (*size <= 0) return -1;
	buffer[*size] = '\0';
	return 0;
}

const char* Platform::GetPlatform() {
	return "linux";
}

int Platform::SetConsoleForegroundColor(lua_State* L) {
	const char* color = luaL_checkstring(L, 1);
	printf("%s", color);
	return 0;
}

int Platform::SetConsoleBackgroundColor(lua_State* L) {
	const char* color = luaL_checkstring(L, 1);
	printf("%s", color);
	return 0;
}

bool Platform::Initialize() {
	return true;
}

//////////////////////////////////////////////////////////////////////////
/// Retrieves the current working directory
int Platform::Cwd(lua_State* L) {
	char getbuf[2048];
	char *r = getcwd(getbuf, sizeof(getbuf) - 1);
	if (r == NULL) {
		luaL_error(L, strerror(errno));
	}

	getbuf[sizeof(getbuf) - 1] = '\0';
	lua_pushstring(L, getbuf);
	return 1;
}