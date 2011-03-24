#include "stdafx.h"
#include "LuaNode.h"
#include "luanode_net.h"
#include "blogger.h"

#include <boost/asio/read_until.hpp>
#include <boost/asio/write.hpp>
#include <boost/asio/placeholders.hpp>

#include <boost/bind.hpp>
#include <boost/make_shared.hpp>
#include "shared_const_buffer.h"


// this is needed for tcp_keepalive definition
#ifdef _WIN32
#include <winsock2.h>
#endif

#ifdef _WIN32
#if defined(_MSC_VER)
#include "MSTCPiP.h"
#elif defined(__MINGW32__)
// afanado de mstcpip.h
/* Argument structure for SIO_KEEPALIVE_VALS */

struct tcp_keepalive {
	u_long  onoff;
	u_long  keepalivetime;
	u_long  keepaliveinterval;
};

// New WSAIoctl Options

#define SIO_RCVALL            _WSAIOW(IOC_VENDOR,1)
#define SIO_RCVALL_MCAST      _WSAIOW(IOC_VENDOR,2)
#define SIO_RCVALL_IGMPMCAST  _WSAIOW(IOC_VENDOR,3)
#define SIO_KEEPALIVE_VALS    _WSAIOW(IOC_VENDOR,4)
#define SIO_ABSORB_RTRALERT   _WSAIOW(IOC_VENDOR,5)
#define SIO_UCAST_IF          _WSAIOW(IOC_VENDOR,6)
#define SIO_LIMIT_BROADCASTS  _WSAIOW(IOC_VENDOR,7)
#define SIO_INDEX_BIND        _WSAIOW(IOC_VENDOR,8)
#define SIO_INDEX_MCASTIF     _WSAIOW(IOC_VENDOR,9)
#define SIO_INDEX_ADD_MCAST   _WSAIOW(IOC_VENDOR,10)
#define SIO_INDEX_DEL_MCAST   _WSAIOW(IOC_VENDOR,11)

// Values for use with SIO_RCVALL* options
#define RCVALL_OFF             0
#define RCVALL_ON              1
#define RCVALL_SOCKETLEVELONLY 2

#else
#error Unknown compiler.
#endif
#elif defined(__linux__)
#include <sys/socket.h>
#include <arpa/inet.h>
#endif



using namespace LuaNode::Net;

static unsigned long s_nextSocketId = 0;
static unsigned long s_socketCount = 0;


//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Net::RegisterFunctions(lua_State* L) {
	luaL_Reg methods[] = {
		{ "isIP", LuaNode::Net::IsIP },
		{ 0, 0 }
	};
	luaL_register(L, "Net", methods);
	lua_pop(L, 1);
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ int LuaNode::Net::IsIP(lua_State* L) {
	std::string address = luaL_checkstring(L, 1);

	boost::system::error_code ec;
	
	boost::asio::ip::address_v4::from_string(address, ec);
	if(!ec) {
		lua_pushboolean(L, true);
		lua_pushinteger(L, 4);
	}
	else {
		boost::asio::ip::address_v6::from_string(address, ec);
		if(!ec) {
			lua_pushboolean(L, true);
			lua_pushinteger(L, 6);
		}
		else {
			lua_pushboolean(L, false);
			lua_pushstring(L, ec.message().c_str());
		}
	}
	return 2;
}



//////////////////////////////////////////////////////////////////////////
/// 
const char* Socket::className = "Socket";
const Socket::RegType Socket::methods[] = {
	{"setoption", &Socket::SetOption},
	{"bind", &Socket::Bind},
	{"close", &Socket::Close},
	{"shutdown", &Socket::Shutdown},
	{"write", &Socket::Write},
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
	m_L(L),
	m_socketId(++s_nextSocketId),
	m_close_pending(false),
	//m_read_shutdown_pending(false),
	m_write_shutdown_pending(false),
	m_pending_writes(0),
	m_pending_reads(0)
{
	s_socketCount++;
	LogDebug("Constructing Socket (%p) (id=%d). Current socket count = %d", this, m_socketId, s_socketCount);

	const char* kind = luaL_checkstring(L, 1);
	LogDebug("Socket::Socket(%s)", kind);
	if(strcmp(kind, "tcp4") == 0) {
		m_socket = boost::make_shared<boost::asio::ip::tcp::socket>( boost::ref(GetIoService()), boost::asio::ip::tcp::v4() );
	}
	else if(strcmp(kind, "tcp6") == 0) {
		m_socket = boost::make_shared<boost::asio::ip::tcp::socket>( boost::ref(GetIoService()), boost::asio::ip::tcp::v6() );
	}
	else {
		luaL_error(L, "unknown socket kind %s", kind);
	}
}

//////////////////////////////////////////////////////////////////////////
/// This gets called when we accept a connection
Socket::Socket(lua_State* L, boost::asio::ip::tcp::socket* socket) :
	m_L(L),
	m_socketId(++s_nextSocketId),
	m_close_pending(false),	
	//m_read_shutdown_pending(false),
	m_write_shutdown_pending(false),
	m_pending_writes(0),
	m_pending_reads(0),
	m_socket(socket)
{
	s_socketCount++;
	LogDebug("Constructing Socket (%p) (id=%d). Current socket count = %d", this, m_socketId, s_socketCount);
}

Socket::~Socket(void)
{
	s_socketCount--;
	LogDebug("Destructing Socket (%p) (id=%d). Current socket count = %d", this, m_socketId, s_socketCount);
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ int Socket::tostring_T(lua_State* L) {
	userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
	Socket* obj = ud->pT;
	lua_pushfstring(L, "%s (%p) (id=%d)", className, obj, obj->m_socketId);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::GetRemoteAddress(lua_State* L) {
	const boost::asio::ip::tcp::endpoint& endpoint = m_socket->remote_endpoint();

	lua_pushstring(L, endpoint.address().to_string().c_str());
	lua_pushinteger(L, endpoint.port());
	return 2;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::GetLocalAddress(lua_State* L) {
	const boost::asio::ip::tcp::endpoint& endpoint = m_socket->local_endpoint();

	lua_pushstring(L, endpoint.address().to_string().c_str());
	lua_pushinteger(L, endpoint.port());
	return 2;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::SetOption(lua_State* L) {
	const char* options[] = {
		"reuseaddr",
		"nodelay",
		"keepalive",
		"no_option",
		NULL
	};
	const char* option = luaL_checkstring(L, 2);
	LogDebug("Socket::SetOption (id=%d) - %s", m_socketId, option);

	int chosen_option = luaL_checkoption(L, 2, "no_option", options);
	switch(chosen_option) {
		case 0: {	// reuseaddr
			bool value = lua_toboolean(L, 3) != 0;
			m_socket->set_option( boost::asio::socket_base::reuse_address(value) );
		break; }

		case 1: {	// nodelay
			bool value = lua_toboolean(L, 3) != 0;
			m_socket->set_option( boost::asio::ip::tcp::no_delay(value) );
		break; }

		case 2: {	// keepalive
			bool value = lua_toboolean(L, 3) != 0;
			m_socket->set_option( boost::asio::socket_base::keep_alive(value) );
			int time = lua_isnumber(L, 4) ? lua_tointeger(L, 4) : 0;
			int interval = lua_isnumber(L, 5) ? lua_tointeger(L, 5) : 0;
			if(value && time) {
#ifdef _WIN32
				DWORD dwBytes = 0;
				tcp_keepalive kaSettings = {0}, sReturned = {0};
				kaSettings.onoff = 1;
				kaSettings.keepalivetime = time;
				kaSettings.keepaliveinterval = interval;
				if (::WSAIoctl(m_socket->native(), SIO_KEEPALIVE_VALS, &kaSettings, sizeof(kaSettings), &sReturned, sizeof(sReturned), &dwBytes, NULL, NULL) != 0)
				{
					luaL_error(L, "Socket::SetOption (%p) - Failed to set keepalive on win32 native socket - %d", this, WSAGetLastError());
				}
#elif defined(__linux__)
				if( setsockopt(m_socket->native(), SOL_TCP, TCP_KEEPIDLE, (void *)&time, sizeof(time)) != 0 ) {
					luaL_error(L, "Socket::SetOption (%p) - Failed to set keepalive (TCP_KEEPIDLE) on native socket - %d", this, errno);
				}
				if(interval != 0) {
					if( setsockopt(m_socket->native(), SOL_TCP, TCP_KEEPINTVL, (void *)&interval, sizeof(interval)) != 0 ) {
						luaL_error(L, "Socket::SetOption (%p) - Failed to set keepalive (TCP_KEEPINTVL=%d) on native socket - %d, %s", this, interval, errno, strerror(errno));
					}
				}
#elif defined(__APPLE__)
				if( setsockopt(fd, IPPROTO_TCP, TCP_KEEPALIVE, (void *)&time, sizeof(time)) != 0 ) {
					luaL_error(L, "Socket::SetOption (%p) - Failed to set keepalive (TCP_KEEPALIVE) on native socket - %d", this, errno);
				}
#endif
			}
		break; }
	}
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Bind(lua_State* L) {
	const char* ip = luaL_checkstring(L, 2);
	unsigned short port = luaL_checkinteger(L, 3);

	boost::asio::ip::tcp::endpoint endpoint( boost::asio::ip::address::from_string(ip), port );
	
	boost::system::error_code ec;
	m_socket->bind(endpoint, ec);
	return BoostErrorCodeToLua(L, ec);
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Close(lua_State* L) {
	// Q: should I do the same when there are pending reads? probably not. One tends to have always a pending read.
	if(m_pending_writes) {
		LogDebug("Socket::Close - Socket (%p) (id=%d) marked for closing", this, m_socketId);
		// can't close the socket right away, just flag it and close it when there are no more queued ops
		m_close_pending = true;
		lua_pushboolean(L, true);
		return 1;
	}
	// nothing is waiting, just close the socket right away
	LogDebug("Socket::Close - Socket (%p) (id=%d) closing now", this, m_socketId);
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
				LogDebug("Socket::Shutdown (%p) (id=%d) - %s", this, m_socketId, option);
				m_socket->shutdown(boost::asio::socket_base::shutdown_receive, ec);
			break;
	
			case 1:	// write
				if(m_pending_writes > 0) {
					m_write_shutdown_pending = true;
					LogDebug("Socket::Shutdown (%p) (id=%d) - Marked for shutdown - %s", this, m_socketId, option);
				}
				else {
					m_socket->shutdown(boost::asio::socket_base::shutdown_send, ec);
				}
			break;
	
			case 2:	// both
				if(m_pending_writes > 0) {
					m_write_shutdown_pending = true;
					LogDebug("Socket::Shutdown (%p) (id=%d) - Marked for shutdown - write", this, m_socketId);
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
		LogDebug("Socket::Shutdown (%p) (id=%d) - both", this, m_socketId);
		if(m_pending_writes > 0) {
			m_write_shutdown_pending = true;
			LogDebug("Socket::Shutdown (%p) (id=%d) - Marked for shutdown - write", this, m_socketId);
		}
		else {
			m_socket->shutdown(boost::asio::socket_base::shutdown_send, ec);
		}
		m_socket->shutdown(boost::asio::socket_base::shutdown_receive, ec);
	}
	return BoostErrorCodeToLua(L, ec);
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Write(lua_State* L) {
	if(m_pending_writes > 0) {
		lua_pushboolean(L, false);
		return 1;
	}
	// store a reference in the registry
	lua_pushvalue(L, 1);
	int reference = luaL_ref(L, LUA_REGISTRYINDEX);

	if(lua_type(L, 2) == LUA_TSTRING) {
		const char* data = lua_tostring(L, 2);
		size_t length = lua_objlen(L, 2);
		std::string d(data, length);
		shared_const_buffer buffer(d);

		LogDebug("Socket::Write (%p) (id=%d) - Length=%d, \r\n'%s'", this, m_socketId, length, data);
	
		m_pending_writes++;
		boost::asio::async_write(*m_socket, buffer,
			boost::bind(&Socket::HandleWrite, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);
	}
	else {
		luaL_error(L, "Socket::Write, unhandled type '%s'", luaL_typename(L, 2));
	}
	lua_pushboolean(L, true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Socket::HandleWrite(int reference, const boost::system::error_code& error, size_t bytes_transferred) {
	lua_State* L = m_L;
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	m_pending_writes--;
	if(!error) {
		LogInfo("Socket::HandleWrite (%p) (id=%d) - Bytes Transferred (%d)", this, m_socketId, bytes_transferred);
		lua_getfield(L, 1, "write_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			LuaNode::GetLuaVM().call(1, LUA_MULTRET);
		}
		else {
			// do nothing?
		}
	}
	else {
		LogDebug("Socket::HandleWrite with error (%p) (id=%d) - %s", this, m_socketId, error.message().c_str());
		//m_callback.OnWriteCompletionError(shared_from_this(), bytes_transferred, error);
		lua_getfield(L, 1, "write_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushnil(L);

			switch(error.value()) {
			case boost::asio::error::eof:
				lua_pushliteral(L, "eof");
				break;
#ifdef _WIN32
			case ERROR_CONNECTION_ABORTED:
#endif
			case boost::asio::error::connection_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::operation_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::connection_reset:
				lua_pushliteral(L, "reset");
				break;

			default:
				lua_pushstring(L, error.message().c_str());
				break;
			}

			LuaNode::GetLuaVM().call(3, LUA_MULTRET);
		}
		else {
			LogError("Socket::HandleWrite with error (%p) (id=%d) - %s", this, m_socketId, error.message().c_str());
		}
	}
	lua_settop(L, 0);

	if(m_write_shutdown_pending && m_pending_writes == 0) {
		LogDebug("Socket::HandleWrite - Applying delayed send shutdown (%p) (id=%d) (send)", this, m_socketId);
		boost::system::error_code ec;
		m_socket->shutdown(boost::asio::socket_base::shutdown_send, ec);
		if(ec) {
			LogError("Socket::HandleWrite - Error shutting down socket (%p) (id=%d) (send) - %s", this, m_socketId, ec.message().c_str());
		}
	}

	if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
		boost::system::error_code ec;
		m_socket->close(ec);
		if(ec) {
			LogError("Socket::HandleWrite - Error closing socket (%p) (id=%d) - %s", this, m_socketId, ec.message().c_str());
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
		LogDebug("Socket::Read (%p) (id=%d) - ReadSome", this, m_socketId);

		m_pending_reads++;
		m_socket->async_read_some(
			boost::asio::buffer(m_inputArray), 
			boost::bind(&Socket::HandleReadSome, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);
	}
	else if(!lua_isnumber(L, 2)) {
		//const char* p = luaL_optstring(L, 2, "*l");
		std::string delimiter = "\r\n";

		LogDebug("Socket::Read (%p) (id=%d) - ReadLine", this, m_socketId);

		m_pending_reads++;
		boost::asio::async_read_until(
			*m_socket, 
			m_inputBuffer, 
			delimiter,
			boost::bind(&Socket::HandleRead, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);
	}
	else {
		luaL_error(L, "for the moment the read must be done with nil or a number");
	}

	/*boost::asio::async_read(*m_socket, buffer,
		boost::bind(&Socket::HandleWrite, this, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);*/
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Socket::HandleRead(int reference, const boost::system::error_code& error, size_t bytes_transferred) {
	lua_State* L = m_L;
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	m_pending_reads--;
	if(!error) {
		LogInfo("Socket::HandleRead (%p) (id=%d) - Bytes Transferred (%d)", this, m_socketId, bytes_transferred);
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
				LogWarning("Socket::HandleRead (%p) (id=%d) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_socketId, luaL_typename(L, 1), ud, ud->pT);
			}
			else {
				LogWarning("Socket::HandleRead (%p) (id=%d) - No read_callback set on %s", this, m_socketId, luaL_typename(L, 1));
			}
		}
	}
	else {
		LogDebug("Socket::HandleRead with error (%p) (id=%d) - %s", this, m_socketId, error.message().c_str());
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushnil(L);

			switch(error.value()) {
			case boost::asio::error::eof:
				lua_pushliteral(L, "eof");
				break;
#ifdef _WIN32
			case ERROR_CONNECTION_ABORTED:
#endif
			case boost::asio::error::connection_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::operation_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::connection_reset:
				lua_pushliteral(L, "reset");
				break;

			default:
				lua_pushstring(L, error.message().c_str());
				break;
			}

			LuaNode::GetLuaVM().call(3, LUA_MULTRET);
			m_inputBuffer.consume(m_inputBuffer.size());
		}
		else {
			LogError("Socket::HandleRead with error (%p) (id=%d) - %s", this, m_socketId, error.message().c_str());
		}
	}
	lua_settop(L, 0);

	if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
		boost::system::error_code ec;
		m_socket->close(ec);
		if(ec) {
			LogError("Socket::HandleRead - Error closing socket (%p) (id=%d) - %s", this, m_socketId, ec.message().c_str());
		}
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
void Socket::HandleReadSome(int reference, const boost::system::error_code& error, size_t bytes_transferred) {
	lua_State* L = m_L;
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);
	
	m_pending_reads--;
	if(!error) {
		LogInfo("Socket::HandleReadSome (%p) (id=%d) - Bytes Transferred (%d)", this, m_socketId, bytes_transferred);
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
				LogWarning("Socket::HandleReadSome (%p) (id=%d) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_socketId, luaL_typename(L, 1), ud, ud->pT);
			}
			else {
				LogWarning("Socket::HandleReadSome (%p) (id=%d) - No read_callback set on %s", this, m_socketId, luaL_typename(L, 1));
			}
		}
	}
	else {
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushnil(L);

			switch(error.value()) {
			case boost::asio::error::eof:
				lua_pushliteral(L, "eof");
				break;
#ifdef _WIN32
			case ERROR_CONNECTION_ABORTED:
#endif
			case boost::asio::error::connection_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::operation_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::connection_reset:
				lua_pushliteral(L, "reset");
				break;

			default:
				lua_pushstring(L, error.message().c_str());
				break;
			}

			if(error.value() != boost::asio::error::eof && error.value() != boost::asio::error::operation_aborted) {
				LogError("Socket::HandleReadSome with error (%p) (id=%d) - %s", this, m_socketId, error.message().c_str());
			}

			LuaNode::GetLuaVM().call(3, LUA_MULTRET);
		}
		else {
			LogError("Socket::HandleReadSome with error (%p) (id=%d) - %s", this, m_socketId, error.message().c_str());
			if(lua_type(L, 1) == LUA_TUSERDATA) {
				userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
				LogWarning("Socket::HandleReadSome (%p) (id=%d) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_socketId, luaL_typename(L, 1), ud, ud->pT);
			}
			else {
				LogWarning("Socket::HandleReadSome (%p) (id=%d) - No read_callback set on %s", this, m_socketId, luaL_typename(L, 1));
			}
		}
	}
	lua_settop(L, 0);

	if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
		boost::system::error_code ec;
		m_socket->close(ec);
		if(ec) {
			LogError("Socket::HandleReadSome - Error closing socket (%p) (id=%d) - %s", this, m_socketId, ec.message().c_str());
		}
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Connect(lua_State* L) {
	const char* ip = luaL_checkstring(L, 2);
	unsigned short port = luaL_checkinteger(L, 3);

	LogDebug("Socket::Connect (%p) (id=%d) (%s:%d)", this, m_socketId, ip, port);

	boost::asio::ip::tcp::endpoint endpoint( boost::asio::ip::address::from_string(ip), port );

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
	lua_State* L = m_L;
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	LogInfo("Socket::HandleConnect (%p) (id=%d)", this, m_socketId);
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
		LogError("Socket::HandleConnect with error (%p) (id=%d) - %s", this, m_socketId, error.message().c_str());
	}
	lua_settop(L, 0);
}

