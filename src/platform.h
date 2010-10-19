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
};


}  // namespace LuaNode
#endif  // LUANODE_PLATFORM_H_
