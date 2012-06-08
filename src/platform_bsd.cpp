#include "stdafx.h"

#include "luanode.h"

#include <kvm.h>
#include <sys/user.h>
#include <sys/param.h>
#include <sys/sysctl.h>

#include "platform.h"

static char s_process_title[16];

using namespace LuaNode;

void Platform::SetProcessTitle(const char* title) {
	strncpy(s_process_title, title, 16);
	s_process_title[15] = 0;
	setproctitle(s_process_title);
}

int Platform::SetProcessTitle(lua_State* L) {
	const char* title = luaL_checkstring(L, 1);
	SetProcessTitle(title);
	return 0;
}

const char* Platform::GetProcessTitle(int *len) {
	static char title[16];

	title[0] = '\0';
	kvm_t *kd;
	struct kinfo_proc *kp;
	kd = kvm_openfiles(NULL, "/dev/null", NULL, O_RDONLY, NULL);
	if(kd != NULL)
	{
		int cnt = -1;
		kp = kvm_getprocs(kd, KERN_PROC_PID, getpid(), &cnt);
		if(cnt == 1)
		{
			char **args;
			args = kvm_getargv(kd, kp, MAXCOMLEN);
			strlcpy(title, args[0], sizeof(title));
			*len = strlen(title);
		}
	}
	return title;
}

int Platform::GetProcessTitle(lua_State* L) {
	int len;
	const char* title = GetProcessTitle(&len);
	lua_pushlstring(L, title, len);
	return 1;
}

int Platform::GetExecutablePath(char* buffer, size_t* size) {
	*size = readlink("/proc/curproc/file", buffer, *size - 1);
	if (*size <= 0) return -1;
	buffer[*size] = '\0';
	return 0;
}

const char* Platform::GetPlatform() {
	return "BSD";
}

bool Platform::Initialize() {
	return true;
}

//////////////////////////////////////////////////////////////////////////
/// Retrieves the current working directory
int Platform::Cwd(lua_State* L) {
	char getbuf[MAXPATHLEN + 1];
	char *r = getcwd(getbuf, sizeof(getbuf) - 1);
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
	struct stat s;
	int file = luaL_checkinteger(L, 1);

	if (file < 0) {
		lua_pushnil(L);
		lua_pushstring(L, "Unknown handle");
		return 2;
	}

	if (isatty(file)) {
		lua_pushstring(L, "TTY");
		return 1;
	}

	if (fstat(file, &s)) {
		lua_pushnil(L);
		lua_pushstring(L, "Unknown handle");
		return 2;
	}

	if (!S_ISSOCK(s.st_mode) && !S_ISFIFO(s.st_mode)) {
		lua_pushstring(L, "FILE");
		return 1;
	}
	lua_pushstring(L, "PIPE");
	return 1;
}
