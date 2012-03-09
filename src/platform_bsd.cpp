#include "stdafx.h"

#include "luanode.h"

#include <kvm.h>
#include <sys/user.h>
#include <sys/param.h>
#include <sys/sysctl.h>

#include "platform.h"

static char s_process_title[16];

using namespace LuaNode;

static const char* console_output_options[] = {
	"stdout",
	"stderr",
	NULL
};

void Platform::SetProcessTitle(const char* title) {
	strncpy(s_process_title, title, 16);
	s_process_title[15] = 0;
  setproctitle(s_process_title);
}

int Platform::SetProcessTitle(lua_State* L) {
	const char* title  = luaL_checkstring(L, 1);
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
  char getbuf[MAXPATHLEN + 1];
  char *r = getcwd(getbuf, sizeof(getbuf) - 1);
  if (r == NULL) {
    luaL_error(L, strerror(errno));
  }

  getbuf[sizeof(getbuf) - 1] = '\0';
  lua_pushstring(L, getbuf);
  return 1;
}
