#include "stdafx.h"

#include "LuaNode.h"
#include "platform.h"

namespace LuaNode {


int OS::GetExecutablePath(char* buffer, size_t* size) {
	*size = GetModuleFileName(NULL, buffer, *size - 1);
	if(*size <= 0) {
		return -1;
	}
	buffer[*size] = '\0';
	return 0;
}

}  // namespace LuaNode