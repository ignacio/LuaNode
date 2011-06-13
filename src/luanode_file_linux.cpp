#include "stdafx.h"
#include "luanode.h"
#include "luanode_file_linux.h"
#include <sys/types.h>
#include "blogger.h"


static unsigned long s_nextFileId = 0;
static unsigned long s_fileCount = 0;


using namespace LuaNode::Fs;

//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Fs::RegisterFunctions(lua_State* L) {
	luaL_Reg methods[] = {
		//{ "isIP", LuaNode::Net::IsIP },
		//{ "read", LuaNode::Fs::Read },
		{ "open", LuaNode::Fs::Open },
		{ "read", LuaNode::Fs::Read },
		{ 0, 0 }
	};
	luaL_register(L, "Fs", methods);
	lua_pop(L, 1);
}

//////////////////////////////////////////////////////////////////////////
/// 
int LuaNode::Fs::Open(lua_State* L) {
	//const char* filename = luaL_checkstring(L, 1);

	return 0;
}

int LuaNode::Fs::Read(lua_State* L) {
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
const char* File::className = "File";
const File::RegType File::methods[] = {
	{"close", &File::Close},
	{"write", &File::Write},
	{"read", &File::Read},
	{"seek", &File::Seek},
	{0}
};

const File::RegType File::setters[] = {
	{0}
};

const File::RegType File::getters[] = {
	{0}
};

//////////////////////////////////////////////////////////////////////////
/// 
File::File(lua_State* L) : 
	m_L(L),
	m_fileId(++s_nextFileId)
{
	throw "Must not call File constructor directly";
}

File::~File(void)
{
	s_fileCount--;
	LogDebug("Destructing File (%p) (id=%d). Current file count = %d", this, m_fileId, s_fileCount);
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ int File::tostring_T(lua_State* L) {
	lua_pushstring(L, "archivo");
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int File::Write(lua_State* L) {
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int File::Read(lua_State* L) {
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int File::Seek(lua_State* L) {
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int File::Close(lua_State* L) {
	return 0;
}

