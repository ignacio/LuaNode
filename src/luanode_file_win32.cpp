#include "stdafx.h"
#include "LuaNode.h"
#include "luanode_file_win32.h"
#include <sys/types.h>
#include "blogger.h"

#include <boost/asio.hpp>
#include <boost/asio/windows/stream_handle.hpp>
#include <boost/asio/windows/random_access_handle.hpp>
#include <boost/asio/read_at.hpp>

#include <boost/bind.hpp>
#include "shared_const_buffer.h"


static unsigned long s_nextFileId = 0;
static unsigned long s_fileCount = 0;


using namespace LuaNode::Fs;

/////////////////////////////////////////////////////////////////////////
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
	const char* filename = luaL_checkstring(L, 1);
	
	boost::asio::windows::random_access_handle::native_type handle(
		::CreateFile(filename, GENERIC_READ, 0, 0,
		OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED, 0));

	File* file = new File(L, handle);
	File::push(L, file, true);
	return 1;
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
	m_fileId(++s_nextFileId),
	m_file( LuaNode::GetIoService() )
{
	throw "Must not call File constructor directly";
}

File::File(lua_State* L, boost::asio::windows::random_access_handle::native_type& handle) : 
	m_L(L),
	m_fileId(++s_nextFileId),
	m_file( LuaNode::GetIoService() )
{
	s_fileCount++;
	LogDebug("Constructing File (%p) (id=%d). Current file count = %d", this, m_fileId, s_fileCount);

	boost::system::error_code ec;
	m_file.assign(handle, ec);
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
	unsigned int length = luaL_checkinteger(L, 2);
	unsigned int position = luaL_checkinteger(L, 3);

	lua_pushvalue(L, 4);
	// store a reference to the callback
	int callback = luaL_ref(L, LUA_REGISTRYINDEX);

	// store a reference to this in the registry
	lua_pushvalue(L, 1);
	int reference = luaL_ref(L, LUA_REGISTRYINDEX);

	boost::asio::async_read_at(m_file, position, boost::asio::buffer(m_inputArray),
		boost::bind(&File::HandleRead, this, reference, callback, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
	);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
void File::HandleRead(int reference, int callback, const boost::system::error_code& error, size_t bytes_transferred) {
	lua_State* L = m_L;
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	if(!error || error == boost::asio::error::eof) {
		LogInfo("File::HandleRead (%p) (id=%d) - Bytes Transferred (%d)", this, m_fileId, bytes_transferred);
		lua_rawgeti(L, LUA_REGISTRYINDEX, callback);
		luaL_unref(L, LUA_REGISTRYINDEX, callback);
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushnil(L);
			const char* data = m_inputArray.c_array();
			lua_pushlstring(L, data, bytes_transferred);
			lua_pushinteger(L, bytes_transferred);
			LuaNode::GetLuaVM().call(4, LUA_MULTRET);
		}
		else {
			// do nothing?
			if(lua_type(L, 1) == LUA_TUSERDATA) {
				userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
				LogWarning("File::HandleRead (%p) (id=%d) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_fileId, luaL_typename(L, 1), ud, ud->pT);
			}
			else {
				LogWarning("File::HandleRead (%p) (id=%d) - No read_callback set on %s", this, m_fileId, luaL_typename(L, 1));
			}
		}
	}
	else {
		LogDebug("File::HandleRead with error (%p) (id=%d) - %s", this, m_fileId, error.message().c_str());
		lua_rawgeti(L, LUA_REGISTRYINDEX, callback);
		luaL_unref(L, LUA_REGISTRYINDEX, callback);
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushinteger(L, error.value());
			lua_pushstring(L, error.message().c_str());
			LuaNode::GetLuaVM().call(3, LUA_MULTRET);
		}
		else {
			LogError("File::HandleRead with error (%p) (id=%d) - %s", this, m_fileId, error.message().c_str());
		}
	}
	lua_settop(L, 0);
}

//////////////////////////////////////////////////////////////////////////
/// 
int File::Seek(lua_State* L) {
	// This does not affect overlapped operations...

	// TODO: check for 2 parameter: set, end, etc

	LARGE_INTEGER pos;
	pos.QuadPart = luaL_checkinteger(L, 3);

	if(SetFilePointerEx(m_file.native(), pos, NULL, FILE_BEGIN)) {
		lua_pushboolean(L, true);
		return 1;
	}
	else {
		lua_pushboolean(L, false);
		lua_pushstring(L, "error seeking file");	// TODO: return the proper error message
	}
	return 2;
}

//////////////////////////////////////////////////////////////////////////
/// 
int File::Close(lua_State* L) {
	return 0;
}