#pragma once

#include <lua.hpp>
#include "../deps/LuaCppBridge51/lcbHybridObjectWithProperties.h"

#include <boost/asio/windows/stream_handle.hpp>
#include <boost/asio/windows/random_access_handle.hpp>

#include <boost/shared_ptr.hpp>
#include <boost/enable_shared_from_this.hpp>
#include <boost/array.hpp>


namespace LuaNode {

namespace Fs {

	void RegisterFunctions(lua_State* L);



	int Open(lua_State* L);

	int Read(lua_State* L);



class File : public LuaCppBridge::HybridObjectWithProperties<File>
{
public:
	// Normal constructor
	File(lua_State* L);
	File(lua_State* L, boost::asio::windows::random_access_handle::native_type& handle);
	virtual ~File(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(File);

	static int tostring_T(lua_State* L);

	int Write(lua_State* L);
	int Read(lua_State* L);
	int Seek(lua_State* L);
	int Close(lua_State* L);

private:
	void HandleRead(int reference, int callback, const boost::system::error_code& error, size_t bytes_transferred);

private:
	boost::asio::windows::random_access_handle m_file;
	lua_State* m_L;
	const unsigned int m_fileId;
	boost::array<char, 8192> m_inputArray;	// agrandar esto y poolearlo (el test simple\test-http-upgrade-server necesita un buffer grande sino falla)
};

}

}