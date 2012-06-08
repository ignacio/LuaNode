#include "stdafx.h"

#include "luanode.h"
#include "platform.h"

#include <io.h>
#include <direct.h>	//< contigo seguro que voy a tener problemas


using namespace LuaNode;


int Platform::SetProcessTitle(lua_State* L) {
	::SetConsoleTitle(luaL_checkstring(L, 1));
	return 0;
}
void Platform::SetProcessTitle(const char* title) {
	::SetConsoleTitle(title);
}

const char* Platform::GetProcessTitle(int *len) {
	static char title[64];
	::GetConsoleTitleA(title, 64);
	*len = strlen(title);
	return title;
}

int Platform::GetProcessTitle(lua_State* L) {
	int len;
	const char* title = GetProcessTitle(&len);
	lua_pushlstring(L, title, len);
	return 1;
}

int Platform::GetExecutablePath(char* buffer, size_t* size) {
	*size = GetModuleFileName(NULL, buffer, *size - 1);
	if(*size <= 0) {
		return -1;
	}
	buffer[*size] = '\0';
	return 0;
}

const char* Platform::GetPlatform() {
	return "windows";
}

bool Platform::Initialize() {
	SetConsoleOutputCP(CP_UTF8);
	return true;
}

//////////////////////////////////////////////////////////////////////////
/// Retrieves the current working directory
int Platform::Cwd(lua_State* L) {
	char getbuf[2048];
	char *r = _getcwd(getbuf, sizeof(getbuf) - 1);
	if (r == NULL) {
		luaL_error(L, strerror(errno));
	}

	getbuf[sizeof(getbuf) - 1] = '\0';
	lua_pushstring(L, getbuf);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// Given a file descriptor, try to guess its type (tty, file or pipe).
/// Code taken from libuv.
int Platform::GetHandleType (lua_State* L) {
	HANDLE handle;
	DWORD mode;
	
	int file = luaL_checkinteger(L, 1);

	if (file < 0) {
		lua_pushnil(L);
		lua_pushstring(L, "Unknown handle");
		return 2;
	}

	handle = (HANDLE)_get_osfhandle(file);

	switch (::GetFileType(handle)) {
	
		case FILE_TYPE_CHAR: // The specified file is a character file, typically an LPT device or a console.
			if (::GetConsoleMode(handle, &mode)) {
				lua_pushstring(L, "TTY");
				return 1;
			}
			else {
				lua_pushstring(L, "FILE");
				return 1;
			}
		break;

		case FILE_TYPE_PIPE: // The specified file is a socket, a named pipe, or an anonymous pipe.
			lua_pushstring(L, "PIPE");
			return 1;
		break;

		case FILE_TYPE_DISK: // The specified file is a disk file.
			lua_pushstring(L, "FILE");
			return 1;
		break;

		default: // Either the type of the specified file is unknown, or the function failed.
			lua_pushnil(L);
			lua_pushstring(L, "Unknown handle");
			return 2;
		break;
	}
}
