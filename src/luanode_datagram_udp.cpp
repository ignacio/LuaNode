#include "stdafx.h"
#include "luanode.h"
#include "luanode_datagram_udp.h"
#include "blogger.h"

#include <boost/asio/read_until.hpp>
#include <boost/asio/write.hpp>
#include <boost/asio/placeholders.hpp>
#include <boost/make_shared.hpp>

#include <boost/bind.hpp>
#include "shared_const_buffer.h"


using namespace LuaNode::Datagram;

static unsigned long s_nextSocketId = 0;
static unsigned long s_socketCount = 0;


//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Datagram::RegisterFunctions(lua_State* L) {
	/*luaL_Reg methods[] = {
		//{ "isIP", LuaNode::Net::IsIP },
		{ 0, 0 }
	};*/
	//luaL_register(L, "Datagram", methods);
	//lua_pop(L, 1);
}


//////////////////////////////////////////////////////////////////////////
/// 
const char* Socket::className = "UdpSocket";
const Socket::RegType Socket::methods[] = {
	{"setoption", &Socket::SetOption},
	{"bind", &Socket::Bind},
	{"close", &Socket::Close},
	{"shutdown", &Socket::Shutdown},
	{"sendto", &Socket::SendTo},
	{"read", &Socket::Read},
	{"connect", &Socket::Connect},
	{"getsockname", &Socket::GetLocalAddress},
	{"getpeername", &Socket::GetRemoteAddress},
	{0}
};

const Socket::RegType Socket::setters[] = {
	{0}
};

const Socket::RegType Socket::getters[] = {
	{0}
};

//////////////////////////////////////////////////////////////////////////
/// 
Socket::Socket(lua_State* L) : 
	m_L( LuaNode::GetLuaVM() ),
	m_socketId(++s_nextSocketId),
	m_close_pending(false),
	//m_read_shutdown_pending(false),
	m_write_shutdown_pending(false),
	m_pending_writes(0),
	m_pending_reads(0)
{
	s_socketCount++;
	LogDebug("Constructing Socket (%p) (id:%lu). Current socket count = %lu", this, m_socketId, s_socketCount);

	const char* kind = luaL_checkstring(L, 1);
	LogDebug("Socket::Socket(%s)", kind);
	if(strcmp(kind, "udp4") == 0) {
		m_socket = boost::make_shared<boost::asio::ip::udp::socket>(boost::ref(GetIoService()), boost::asio::ip::udp::v4());
	}
	else if(strcmp(kind, "udp6") == 0) {
		m_socket = boost::make_shared<boost::asio::ip::udp::socket>(boost::ref(GetIoService()), boost::asio::ip::udp::v6());
	}
}

//////////////////////////////////////////////////////////////////////////
/// This gets called when we accept a connection
Socket::Socket(lua_State* L, boost::asio::ip::udp::socket* socket) :
	m_L( LuaNode::GetLuaVM() ),
	m_socketId(++s_nextSocketId),
	m_close_pending(false),	
	//m_read_shutdown_pending(false),
	m_write_shutdown_pending(false),
	m_pending_writes(0),
	m_pending_reads(0),
	m_socket(socket)
{
	s_socketCount++;
	LogDebug("Constructing Socket (%p) (id:%lu). Current socket count = %lu", this, m_socketId, s_socketCount);
}

Socket::~Socket(void)
{
	s_socketCount--;
	LogDebug("Destructing Socket (%p) (id:%lu). Current socket count = %lu", this, m_socketId, s_socketCount);
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ int Socket::tostring_T(lua_State* L) {
	userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
	Socket* obj = ud->pT;
	lua_pushfstring(L, "%s (%p) (id:%u)", className, obj, obj->m_socketId);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::GetRemoteAddress(lua_State* L) {
	const boost::asio::ip::udp::endpoint& endpoint = m_socket->remote_endpoint();

	lua_pushstring(L, endpoint.address().to_string().c_str());
	lua_pushinteger(L, endpoint.port());
	return 2;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::GetLocalAddress(lua_State* L) {
	const boost::asio::ip::udp::endpoint& endpoint = m_socket->local_endpoint();

	lua_pushstring(L, endpoint.address().to_string().c_str());
	lua_pushinteger(L, endpoint.port());
	return 2;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::SetOption(lua_State* L) {
	const char* options[] = {
		"broadcast",
		"ttl",
		//"keepalive",
		"no_option",
		NULL
	};
	const char* option = luaL_checkstring(L, 2);
	LogDebug("Socket::SetOption (id:%lu) - %s", m_socketId, option);

	int chosen_option = luaL_checkoption(L, 2, "no_option", options);
	switch(chosen_option) {
		case 0: {	// broadcast
			boost::system::error_code ec;
			bool value = lua_toboolean(L, 3) != 0;
			m_socket->set_option( boost::asio::socket_base::broadcast(value), ec );
			return BoostErrorCodeToLua(L, ec);		
		break; }

		case 1: {	// ttl
			int newttl = luaL_checkinteger(L, 4);
			int result = setsockopt(m_socket->native(), IPPROTO_IP, IP_TTL, (const char*)&newttl, sizeof(newttl));
			if(result != 0) {
#ifdef _WIN32
				luaL_error(L, "Socket::SetOption (%p) - Failed to set TTL on native socket - %d", this, WSAGetLastError());
#elif __linux__
				luaL_error(L, "Socket::SetOption (%p) - Failed to set TTL on native socket - %d, s", this, errno, strerror(errno));
#endif
			}
		break; }
	}
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Bind(lua_State* L) {
	boost::asio::ip::udp::endpoint endpoint;
	if(lua_isnoneornil(L, 3) && lua_isnumber(L, 2)) {
		unsigned short port = luaL_checkinteger(L, 2);
		endpoint = boost::asio::ip::udp::endpoint( boost::asio::ip::udp::v4(), port );
	}
	else {
		const char* ip = luaL_checkstring(L, 2);
		unsigned short port = luaL_checkinteger(L, 3);

		endpoint = boost::asio::ip::udp::endpoint( boost::asio::ip::address::from_string(ip), port );
	}
	boost::system::error_code ec;
	m_socket->bind(endpoint, ec);
	return BoostErrorCodeToLua(L, ec);
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Close(lua_State* L) {
	// Q: should I do the same when there are pending reads? probably not. One tends to have always a pending read.
	if(m_pending_writes) {
		LogDebug("Socket::Close - Socket (%p) (id:%lu) marked for closing", this, m_socketId);
		// can't close the socket right away, just flag it and close it when there are no more queued ops
		m_close_pending = true;
		lua_pushboolean(L, true);
		return 1;
	}
	// nothing is waiting, just close the socket right away
	LogDebug("Socket::Close - Socket (%p) (id:%lu) closing now", this, m_socketId);
	boost::system::error_code ec;
	m_socket->shutdown(boost::asio::socket_base::shutdown_both, ec);
	m_socket->close(ec);
	return BoostErrorCodeToLua(L, ec);
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Shutdown(lua_State* L) {
	static const char* options[] = {
		"read",
		"write",
		"both",
		"no_option",
		NULL
	};

	boost::system::error_code ec;

	if(lua_type(L, 2) == LUA_TSTRING) {
		const char* option = luaL_checkstring(L, 2);
		
		int chosen_option = luaL_checkoption(L, 2, "no_option", options);
		switch(chosen_option) {
			case 0:	// read
				/*m_read_shutdown_pending = true;
				if(m_pending_reads > 0) {
					m_write_shutdown_pending = true;
				}
				else {
					m_socket->shutdown(boost::asio::socket_base::shutdown_send, ec);
				}*/
				LogDebug("Socket::Shutdown (%p) (id:%lu) - %s", this, m_socketId, option);
				m_socket->shutdown(boost::asio::socket_base::shutdown_receive, ec);
			break;
	
			case 1:	// write
				if(m_pending_writes > 0) {
					m_write_shutdown_pending = true;
					LogDebug("Socket::Shutdown (%p) (id:%lu) - Marked for shutdown - %s", this, m_socketId, option);
				}
				else {
					m_socket->shutdown(boost::asio::socket_base::shutdown_send, ec);
				}
			break;
	
			case 2:	// both
				if(m_pending_writes > 0) {
					m_write_shutdown_pending = true;
					LogDebug("Socket::Shutdown (%p) (id:%lu) - Marked for shutdown - write", this, m_socketId);
				}
				else {
					m_socket->shutdown(boost::asio::socket_base::shutdown_send, ec);
				}
				//m_write_shutdown_pending = true;
				//m_read_shutdown_pending = true;
				m_socket->shutdown(boost::asio::socket_base::shutdown_receive, ec);
			break;
	
			default:
			break;
		}
	}
	else {
		LogDebug("Socket::Shutdown (%p) (id:%lu) - both", this, m_socketId);
		if(m_pending_writes > 0) {
			m_write_shutdown_pending = true;
			LogDebug("Socket::Shutdown (%p) (id:%lu) - Marked for shutdown - write", this, m_socketId);
		}
		else {
			m_socket->shutdown(boost::asio::socket_base::shutdown_send, ec);
		}
		m_socket->shutdown(boost::asio::socket_base::shutdown_receive, ec);
	}
	return BoostErrorCodeToLua(L, ec);
}

//////////////////////////////////////////////////////////////////////////
/// sendto(self, buf, off, len, flags, destination port, destination address, [callback]);
int Socket::SendTo(lua_State* L) {
	if(m_pending_writes > 0) {
		lua_pushboolean(L, false);
		return 1;
	}

	unsigned short port = luaL_checkinteger(L, 6);
	const char* address = luaL_checkstring(L, 7);

	boost::asio::ip::udp::endpoint endpoint( boost::asio::ip::address::from_string(address), port );

	// store a reference in the registry
	lua_pushvalue(L, 1);
	int reference = luaL_ref(L, LUA_REGISTRYINDEX);

	int callback = LUA_NOREF;
	if(!lua_isnoneornil(L, 8)) {
		lua_pushvalue(L, 8);
		callback = luaL_ref(L, LUA_REGISTRYINDEX);
	}

	if(lua_type(L, 2) == LUA_TSTRING) {
		const char* data = lua_tostring(L, 2);
		size_t length = lua_objlen(L, 2);
		std::string d(data, length);
		shared_const_buffer buffer(d);

		LogDebug("Socket::Write (%p) (id:%lu) - Length=%lu, \r\n'%s'", this, m_socketId, (unsigned long)length, data);
	
		m_pending_writes++;
		////P
		/*
		boost::asio::async_write(*m_socket, buffer,
			boost::bind(&Socket::HandleWrite, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);
		*/
		m_socket->async_send_to(buffer, endpoint,
			boost::bind(&Socket::HandleSendTo, this, reference, callback , boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred));
	}
	else {
		luaL_error(L, "Socket::Write, unhandled type '%s'", luaL_typename(L, 2));
	}
	lua_pushboolean(L, true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Socket::HandleSendTo(int reference, int callback, const boost::system::error_code& error, size_t bytes_transferred) {
	lua_State* L = LuaNode::GetLuaVM();
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	if(callback != LUA_NOREF) {
		lua_rawgeti(L, LUA_REGISTRYINDEX, callback);
		luaL_unref(L, LUA_REGISTRYINDEX, callback);
	}

	// stack: self, [callback]

	m_pending_writes--;
	if(!error) {
		LogInfo("Socket::HandleSendTo (%p) (id:%lu) - Bytes Transferred (%lu)", this, m_socketId, 
			(unsigned long)bytes_transferred);
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			LuaNode::GetLuaVM().call(1, LUA_MULTRET);
		}
		else {
			// do nothing?
		}
	}
	else {
		LogDebug("Socket::HandleSendTo with error (%p) (id:%lu) - %s", this, m_socketId, error.message().c_str());
		//m_callback.OnWriteCompletionError(shared_from_this(), bytes_transferred, error);
		//lua_getfield(L, 1, "write_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			BoostErrorCodeToLua(L, error);	// -> nil, error code, error message
			LuaNode::GetLuaVM().call(4, LUA_MULTRET);
		}
		else {
			LogError("Socket::HandleSendTo with error (%p) (id:%lu) - %s", this, m_socketId, error.message().c_str());
		}
	}
	lua_settop(L, 0);

	if(m_write_shutdown_pending && m_pending_writes == 0) {
		LogDebug("Socket::HandleSendTo - Applying delayed send shutdown (%p) (id:%lu) (send)", this, m_socketId);
		boost::system::error_code ec;
		m_socket->shutdown(boost::asio::socket_base::shutdown_send, ec);
		if(ec) {
			LogError("Socket::HandleSendTo - Error shutting down socket (%p) (id:%lu) (send) - %s", this, m_socketId, ec.message().c_str());
		}
	}

	if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
		boost::system::error_code ec;
		m_socket->close(ec);
		if(ec) {
			LogError("Socket::HandleSendTo - Error closing socket (%p) (id:%lu) - %s", this, m_socketId, ec.message().c_str());
		}
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Read(lua_State* L) {
	// store a reference in the registry
	lua_pushvalue(L, 1);
	int reference = luaL_ref(L, LUA_REGISTRYINDEX);

	if(lua_isnoneornil(L, 2)) {
		LogDebug("Socket::Read (%p) (id:%lu) - ReadSome", this, m_socketId);

		m_pending_reads++;
		m_socket->async_receive(
			boost::asio::buffer(m_inputArray),
			boost::bind(&Socket::HandleReceive, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);
		////P
		/*m_socket->async_read_some(
			boost::asio::buffer(m_inputArray), 
			boost::bind(&Socket::HandleReadSome, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);*/
	}
	else if(!lua_isnumber(L, 2)) {
		//const char* p = luaL_optstring(L, 2, "*l");
		std::string delimiter = "\r\n";

		LogDebug("Socket::Read (%p) (id:%lu) - ReadLine", this, m_socketId);

		m_pending_reads++;
		////P
		/*
		boost::asio::async_read_until(
			*m_socket, 
			m_inputBuffer, 
			delimiter,
			boost::bind(&Socket::HandleRead, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);*/
	}
	else {
		luaL_error(L, "for the moment the read must be done with nil or a number");
	}

	/*boost::asio::async_read(*m_socket, buffer,
		boost::bind(&Socket::HandleSendTo, this, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);*/
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Socket::HandleRead(int reference, const boost::system::error_code& error, size_t bytes_transferred) {
	lua_State* L = LuaNode::GetLuaVM();
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	m_pending_reads--;
	if(!error) {
		LogInfo("Socket::HandleRead (%p) (id:%lu) - Bytes Transferred (%lu)", this, m_socketId, 
			(unsigned long)bytes_transferred);
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			const char* data = (const char*)boost::asio::detail::buffer_cast_helper(m_inputBuffer.data());
			lua_pushlstring(L, data, m_inputBuffer.size());
			m_inputBuffer.consume(m_inputBuffer.size());	// its safe to consume, the string has already been interned
			LuaNode::GetLuaVM().call(2, LUA_MULTRET);
		}
		else {
			// do nothing?
			if(lua_type(L, 1) == LUA_TUSERDATA) {
				userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
				LogWarning("Socket::HandleRead (%p) (id:%lu) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_socketId, luaL_typename(L, 1), ud, ud->pT);
			}
			else {
				LogWarning("Socket::HandleRead (%p) (id:%lu) - No read_callback set on %s", this, m_socketId, luaL_typename(L, 1));
			}
		}
	}
	else {
		LogDebug("Socket::HandleRead with error (%p) (id:%lu) - %s", this, m_socketId, error.message().c_str());
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			BoostErrorCodeToLua(L, error);	// -> nil, error code, error message
			LuaNode::GetLuaVM().call(4, LUA_MULTRET);
			m_inputBuffer.consume(m_inputBuffer.size());
		}
		else {
			LogError("Socket::HandleRead with error (%p) (id:%lu) - %s", this, m_socketId, error.message().c_str());
		}
	}
	lua_settop(L, 0);

	if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
		boost::system::error_code ec;
		m_socket->close(ec);
		if(ec) {
			LogError("Socket::HandleRead - Error closing socket (%p) (id:%lu) - %s", this, m_socketId, ec.message().c_str());
		}
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
void Socket::HandleReceive(int reference, const boost::system::error_code& error, size_t bytes_transferred) {
	lua_State* L = LuaNode::GetLuaVM();
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);
	
	m_pending_reads--;
	if(!error) {
		LogInfo("Socket::HandleReceive (%p) (id:%lu) - Bytes Transferred (%lu)", this, m_socketId, 
			(unsigned long)bytes_transferred);
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
				LogWarning("Socket::HandleReceive (%p) (id:%lu) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_socketId, luaL_typename(L, 1), ud, ud->pT);
			}
			else {
				LogWarning("Socket::HandleReceive (%p) (id:%lu) - No read_callback set on %s", this, m_socketId, luaL_typename(L, 1));
			}
		}
	}
	else {
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			BoostErrorCodeToLua(L, error);	// -> nil, error code, error message

			if(error.value() != boost::asio::error::eof && error.value() != boost::asio::error::operation_aborted) {
				LogError("Socket::HandleReceive with error (%p) (id:%lu) - %s", this, m_socketId, error.message().c_str());
			}

			LuaNode::GetLuaVM().call(4, LUA_MULTRET);
		}
		else {
			LogError("Socket::HandleReceive with error (%p) (id:%lu) - %s", this, m_socketId, error.message().c_str());
			if(lua_type(L, 1) == LUA_TUSERDATA) {
				userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
				LogWarning("Socket::HandleReceive (%p) (id:%lu) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_socketId, luaL_typename(L, 1), ud, ud->pT);
			}
			else {
				LogWarning("Socket::HandleReceive (%p) (id:%lu) - No read_callback set on %s", this, m_socketId, luaL_typename(L, 1));
			}
		}
	}
	lua_settop(L, 0);

	if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
		boost::system::error_code ec;
		m_socket->close(ec);
		if(ec) {
			LogError("Socket::HandleReceive - Error closing socket (%p) (id:%lu) - %s", this, m_socketId, ec.message().c_str());
		}
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Connect(lua_State* L) {
	const char* ip = luaL_checkstring(L, 2);
	unsigned short port = luaL_checkinteger(L, 3);

	LogDebug("Socket::Connect (%p) (id:%lu) (%s:%hu)", this, m_socketId, ip, port);

	boost::asio::ip::udp::endpoint endpoint( boost::asio::ip::address::from_string(ip), port );

	// store a reference in the registry
	lua_pushvalue(L, 1);
	int reference = luaL_ref(L, LUA_REGISTRYINDEX);

	m_socket->async_connect(endpoint, 
		boost::bind(&Socket::HandleConnect, this, reference, boost::asio::placeholders::error)
	);
	lua_pushboolean(L, true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Socket::HandleConnect(int reference, const boost::system::error_code& error) {
	lua_State* L = LuaNode::GetLuaVM();
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	LogInfo("Socket::HandleConnect (%p) (id:%lu)", this, m_socketId);
	lua_getfield(L, 1, "connect_callback");
	if(lua_type(L, 2) == LUA_TFUNCTION) {
		lua_pushvalue(L, 1);
		if(!error) {
			lua_pushboolean(L, true);
			LuaNode::GetLuaVM().call(2, LUA_MULTRET);
		}
		else {
			lua_pushboolean(L, false);
			lua_pushstring(L, error.message().c_str());

			LuaNode::GetLuaVM().call(3, LUA_MULTRET);
		}		
	}
	else {
		LogError("Socket::HandleConnect with error (%p) (id:%lu) - %s", this, m_socketId, error.message().c_str());
	}
	lua_settop(L, 0);
}

