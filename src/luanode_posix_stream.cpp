#include "stdafx.h"
#include "luanode.h"
#include "luanode_posix_stream.h"

#include <boost/make_shared.hpp>
#include <boost/bind.hpp>
#include <boost/asio/write.hpp>
#include <boost/asio/placeholders.hpp>

using namespace LuaNode::Posix;

const char* Stream::className = "PosixStream";
const char* Stream::get_full_class_name_T() { return "LuaNode.core.Posix.Stream"; };
const Stream::RegType Stream::methods[] = {
	{"close", &Stream::Close},
	{"write", &Stream::Write},
	{"read", &Stream::Read},
	{0}
};

const Stream::RegType Stream::setters[] = {
	{0}
};

const Stream::RegType Stream::getters[] = {
	{0}
};

Stream::Stream(lua_State* L) :
	m_fd(-1),
	m_L( L ),
	m_streamId(-1),
	m_write_shutdown_pending(false),
	m_pending_writes(0),
	m_pending_reads(0)
{
	m_fd = ::dup((int)luaL_checkinteger(L, 1));
	//fprintf(stderr, "Construyendo Stream (%d)\n", m_fd);
	m_stream = boost::make_shared<boost::asio::posix::stream_descriptor>(boost::ref(LuaNode::GetIoService()), m_fd);
}

Stream::~Stream(void) {};

//////////////////////////////////////////////////////////////////////////
/// 
int Stream::Write(lua_State* L) {
	/*fprintf(stderr, "Stream::Write\n");*/
	if(m_pending_writes > 0) {
		lua_pushboolean(L, false);
		return 1;
	}
	lua_pushvalue(L, 1);
	int reference = luaL_ref(L, LUA_REGISTRYINDEX);

	//fprintf(stderr, "Stream::Write-----\n");
	size_t length;
	const char* data = luaL_checklstring(L, 2, &length);
	
	//fprintf(stderr, "length = %d\n", l);
	m_pending_writes++;
	boost::asio::async_write(*m_stream,
		boost::asio::buffer(data, length),
		boost::bind(&Stream::HandleWrite, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
	);
	lua_pushboolean(L, true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Stream::HandleWrite(int reference, const boost::system::error_code& error, size_t bytes_transferred) {
	/*fprintf(stderr, "Stream::HandleWrite\n");*/
	lua_State* L = LuaNode::GetLuaVM();
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	m_pending_writes--;

	if(!error) {
		//fprintf(stderr, "Stream::HandleWrite - OK\n");
		LogInfo("Stream::HandleWrite (%p) (id:%u) - Bytes Transferred (%lu)", this, m_streamId, 
			(unsigned long)bytes_transferred);
		lua_getfield(L, 1, "write_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushboolean(L, 1);
			LuaNode::GetLuaVM().call(2, LUA_MULTRET);
		}
		else {
			// do nothing?
			//fprintf(stderr, "Stream::HandleWrite - No hay callback de write\n");
		}
	}
	else {
		fprintf(stderr, "Stream::HandleWrite with error (%p) (id:%u) - %s", this, m_streamId, error.message().c_str());	
	}

	lua_settop(L, 0);
};

//////////////////////////////////////////////////////////////////////////
/// 
int Stream::Read(lua_State* L) {
	/*printf("Stream::Read\n");*/
	// store a reference in the registry
	lua_pushvalue(L, 1);
	int reference = luaL_ref(L, LUA_REGISTRYINDEX);
	if(lua_isnoneornil(L, 2)) {
		/*fprintf(stderr, "Socket::Read (%p) (id:%u) - ReadSome\n", this, m_streamId);*/

		m_pending_reads++;
		m_stream->async_read_some(
			boost::asio::buffer(m_inputArray), 
			boost::bind(&Stream::HandleReadSome, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);
	}
	else {
		luaL_error(L, "for the moment the read must be done with nil or a number");
	}
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Stream::Close(lua_State* L) {
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Stream::HandleReadSome(int reference, const boost::system::error_code& error, size_t bytes_transferred)
{
	lua_State* L = LuaNode::GetLuaVM();
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	/*fprintf(stderr, "Stream::HandleReadSome\n");*/
	m_pending_reads--;
	if(!error) {
		LogDebug("Stream::HandleReadSome (%p) (id:%u) - Bytes Transferred (%lu)\n", this, m_streamId, (unsigned long)bytes_transferred);
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			const char* data = m_inputArray.c_array();
			lua_pushlstring(L, data, bytes_transferred);
			LuaNode::GetLuaVM().call(2, LUA_MULTRET);
		}
		else {
			// do nothing?
			if(lua_type(L, 1) == LUA_TUSERDATA) {
				userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
				LogWarning("Stream::HandleReadSome (%p) (id:%u) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_streamId, luaL_typename(L, 1), ud, ud->pT);
			}
			else {
				LogWarning("Stream::HandleReadSome (%p) (id:%u) - No read_callback set on %s", this, m_streamId, luaL_typename(L, 1));
			}
		}
	}
	else {
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			LuaNode::BoostErrorCodeToLua(L, error);	// -> nil, error code, error message

			if(error.value() != boost::asio::error::eof && error.value() != boost::asio::error::operation_aborted) {
				LogError("Stream::HandleReadSome with error (%p) (id:%u) - %s", this, m_streamId, error.message().c_str());
			}

			LuaNode::GetLuaVM().call(4, LUA_MULTRET);
		}
		else {
			LogError("Stream::HandleReadSome with error (%p) (id:%u) - %s", this, m_streamId, error.message().c_str());
			if(lua_type(L, 1) == LUA_TUSERDATA) {
				userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
				LogWarning("Stream::HandleReadSome (%p) (id:%u) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_streamId, luaL_typename(L, 1), ud, ud->pT);
			}
			else {
				LogWarning("Stream::HandleReadSome (%p) (id:%u) - No read_callback set on %s", this, m_streamId, luaL_typename(L, 1));
			}
		}
	}
	lua_settop(L, 0);

	if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
		boost::system::error_code ec;
		m_stream->close(ec);
		if(ec) {
			LogError("Stream::HandleReadSome - Error closing socket (%p) (id:%u) - %s", this, m_streamId, ec.message().c_str());
		}
	}
}
