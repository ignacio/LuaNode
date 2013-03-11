#pragma once

#include <lua.hpp>
#include "../../../deps/luacppbridge51/lcbHybridObjectWithProperties.h"

#include <boost/asio/posix/stream_descriptor.hpp>
#include <boost/shared_ptr.hpp>
#include <boost/array.hpp>

namespace LuaNode {

namespace Posix {

class Stream : public LuaCppBridge::HybridObjectWithProperties<Stream>
{
public:
	Stream(lua_State* L);
	virtual ~Stream(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(Stream);

	int Write(lua_State* L);
	int Read(lua_State* L);
	int Close(lua_State* L);

private:
	void HandleWrite(int reference, const boost::system::error_code& error, size_t bytes_transferred);
	void HandleReadSome(int reference, const boost::system::error_code& error, size_t bytes_transferred);

public:
	int m_fd;

private:
	lua_State* m_L;
	const unsigned int m_streamId;
	bool m_close_pending;
	//bool m_read_shutdown_pending;
	bool m_write_shutdown_pending;
	unsigned long m_pending_writes;
	unsigned long m_pending_reads;

	boost::shared_ptr< boost::asio::posix::stream_descriptor > m_stream;
	boost::array<char, 8192> m_inputArray;	// agrandar esto y poolearlo (el test simple\test-http-upgrade-server necesita un buffer grande sino falla)
};

}

}