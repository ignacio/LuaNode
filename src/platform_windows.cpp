#include "stdafx.h"

#include "LuaNode.h"
#include "platform.h"

static HANDLE m_hConsole = GetStdHandle(STD_OUTPUT_HANDLE);

static CONSOLE_SCREEN_BUFFER_INFO CConsoleGetInfo() {
	CONSOLE_SCREEN_BUFFER_INFO csbi = {0};

	GetConsoleScreenBufferInfo(m_hConsole, &csbi);
	return csbi;
}


namespace LuaNode {


int OS::GetExecutablePath(char* buffer, size_t* size) {
	*size = GetModuleFileName(NULL, buffer, *size - 1);
	if(*size <= 0) {
		return -1;
	}
	buffer[*size] = '\0';
	return 0;
}

const char* OS::GetPlatform() {
	return "windows";
}

int OS::SetConsoleForegroundColor(lua_State* L) {
	WORD wRGBI = (WORD)lua_tointeger(L, 1);
	CONSOLE_SCREEN_BUFFER_INFO csbi = CConsoleGetInfo();
	csbi.wAttributes &= BACKGROUND_BLUE | BACKGROUND_GREEN | BACKGROUND_RED | BACKGROUND_INTENSITY;
	csbi.wAttributes |= wRGBI; 
	SetConsoleTextAttribute(m_hConsole, csbi.wAttributes);
	return 0;
}

int OS::SetConsoleBackgroundColor(lua_State* L) {
	WORD wRGBI = (WORD)lua_tointeger(L, 1);
	CONSOLE_SCREEN_BUFFER_INFO csbi = CConsoleGetInfo();
	csbi.wAttributes &= FOREGROUND_BLUE | FOREGROUND_GREEN | FOREGROUND_RED | FOREGROUND_INTENSITY;
	csbi.wAttributes |= wRGBI; 
	SetConsoleTextAttribute(m_hConsole, csbi.wAttributes);
	return 0;
}

bool OS::PlatformInit() {
	SetConsoleOutputCP(CP_UTF8);
	return true;
}

}  // namespace LuaNode