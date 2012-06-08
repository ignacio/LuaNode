#pragma once

#include <lua.hpp>
#include "../../../deps/LuaCppBridge51/lcbHybridObjectWithProperties.h"

#include <termios.h>
#include <boost/asio.hpp>

namespace LuaNode {

namespace detail {

namespace posix {

class TtyStream : 
	public LuaCppBridge::HybridObjectWithProperties<TtyStream>
{
public:
	// Normal constructor
	TtyStream(lua_State* L);
	virtual ~TtyStream();

public:
	LCB_HOWP_DECLARE_EXPORTABLE(TtyStream);

	int SetRawMode(lua_State* L);
	int Read(lua_State* L);
	int Pause(lua_State* L);
	int Write(lua_State* L);
	int Close (lua_State* L);
	int GetWindowSize (lua_State* L);

	static void Reset();

private:
	void HandleReadSome(int reference, const boost::system::error_code& error, size_t bytes_transferred);

private:
	int m_fd;
	struct termios m_orig_termios;
	int m_flags;
	int m_mode;
	lua_State* m_L;
	unsigned long m_pending_reads;

	boost::asio::posix::stream_descriptor* m_stream;
	boost::array<char, 128> m_inputArray;

	friend int uv_tty_set_mode(TtyStream* tty, int mode);
};

int uv_tty_set_mode(TtyStream* tty, int mode);	// gcc complains if not declared

}

}

}