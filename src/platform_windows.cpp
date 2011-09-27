#include "stdafx.h"

#include "luanode.h"
#include "platform.h"

#include <direct.h>	//< contigo seguro que voy a tener problemas

// I don't think I should cache this...
static HANDLE m_hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
static HANDLE m_hConsoleError = GetStdHandle(STD_ERROR_HANDLE);

static const char* console_output_options[] = {
	"stdout",
	"stderr",
	NULL
};

static CONSOLE_SCREEN_BUFFER_INFO CConsoleGetInfo() {
	CONSOLE_SCREEN_BUFFER_INFO csbi = {0};

	GetConsoleScreenBufferInfo(m_hConsole, &csbi);
	return csbi;
}


using namespace LuaNode;

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

int Platform::SetConsoleForegroundColor(lua_State* L) {
	WORD wRGBI = (WORD)lua_tointeger(L, 1);
	CONSOLE_SCREEN_BUFFER_INFO csbi = CConsoleGetInfo();
	csbi.wAttributes &= BACKGROUND_BLUE | BACKGROUND_GREEN | BACKGROUND_RED | BACKGROUND_INTENSITY;
	csbi.wAttributes |= wRGBI; 
	
	SetConsoleTextAttribute(
		(luaL_checkoption(L, 2, "stdout", console_output_options) == 0) ? m_hConsole : m_hConsoleError,
		csbi.wAttributes);
	return 0;
}

int Platform::SetConsoleBackgroundColor(lua_State* L) {
	WORD wRGBI = (WORD)lua_tointeger(L, 1);
	CONSOLE_SCREEN_BUFFER_INFO csbi = CConsoleGetInfo();
	csbi.wAttributes &= FOREGROUND_BLUE | FOREGROUND_GREEN | FOREGROUND_RED | FOREGROUND_INTENSITY;
	csbi.wAttributes |= wRGBI; 

	SetConsoleTextAttribute(
		(luaL_checkoption(L, 2, "stdout", console_output_options) == 0) ? m_hConsole : m_hConsoleError,
		csbi.wAttributes);
	return 0;
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
