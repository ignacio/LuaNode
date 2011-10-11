#include "stdafx.h"

#include "luanode.h"
#include "platform.h"

/* SetProcessTitle */
#include <sys/prctl.h>
#include <linux/prctl.h>

static char s_process_title[16];

using namespace LuaNode;

static const char* console_output_options[] = {
	"stdout",
	"stderr",
	NULL
};

void Platform::SetProcessTitle(const char* title) {
	// see: http://manpages.courier-mta.org/htmlman2/prctl.2.html
	strncpy(s_process_title, title, 16);
	s_process_title[15] = 0;
	prctl(PR_SET_NAME, s_process_title);
}

int Platform::SetProcessTitle(lua_State* L) {
	const char* title  = luaL_checkstring(L, 1);
	SetProcessTitle(title);
	return 0;
}

const char* Platform::GetProcessTitle(int *len) {
	static char title[16];
	prctl(PR_GET_NAME, title);
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
	if(luaL_checkoption(L, 2, "stdout", console_output_options) == 0) {
		printf("%s", color);
	}
	else {
		fprintf(stderr, "%s", color);
	}
	return 0;
}

int Platform::SetConsoleBackgroundColor(lua_State* L) {
	const char* color = luaL_checkstring(L, 1);
	if(luaL_checkoption(L, 2, "stdout", console_output_options) == 0) {
		printf("%s", color);
	}
	else {
		fprintf(stderr, "%s", color);
	}
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