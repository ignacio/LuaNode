#include "stdafx.h"
#include "luanode.h"
#include "luanode_constants.h"
#include <errno.h>

#define BOOST_ERRNO_CASE(e, v)  lua_pushinteger(L, boost::asio::error::e); lua_setfield(L, t, #v);

#if defined (_WIN32)
# define ERRNO_CASE(e) lua_pushinteger(L, WSA ## e); lua_setfield(L, t, #e);
#else
# define ERRNO_CASE(e) lua_pushinteger(L, e); lua_setfield(L, t, #e);
#endif


void LuaNode::DefineConstants(lua_State* L)
{
	lua_newtable(L);
	int t = lua_gettop(L);

	lua_pushinteger(L, boost::asio::error::eof); lua_setfield(L, t, "EOF");

	BOOST_ERRNO_CASE(access_denied, EACCES);
	BOOST_ERRNO_CASE(address_family_not_supported, EAFNOSUPPORT);
	BOOST_ERRNO_CASE(address_in_use, EADDRINUSE);
	BOOST_ERRNO_CASE(already_connected, EISCONN);
	BOOST_ERRNO_CASE(already_started, EALREADY);
	BOOST_ERRNO_CASE(broken_pipe, EPIPE);
	BOOST_ERRNO_CASE(connection_aborted, ECONNABORTED);
	BOOST_ERRNO_CASE(connection_refused, ECONNREFUSED);
	BOOST_ERRNO_CASE(connection_reset, ECONNRESET);
	BOOST_ERRNO_CASE(bad_descriptor, EBADF);
	BOOST_ERRNO_CASE(fault, EFAULT);
	BOOST_ERRNO_CASE(host_unreachable, EHOSTUNREACH);
	BOOST_ERRNO_CASE(in_progress, EINPROGRESS);
	BOOST_ERRNO_CASE(interrupted, EINTR);
	BOOST_ERRNO_CASE(invalid_argument, EINVAL);
	BOOST_ERRNO_CASE(message_size, EMSGSIZE);
	BOOST_ERRNO_CASE(name_too_long, ENAMETOOLONG);
	BOOST_ERRNO_CASE(network_down, ENETDOWN);
	BOOST_ERRNO_CASE(network_reset, ENETRESET);
	BOOST_ERRNO_CASE(network_unreachable, ENETUNREACH);
	BOOST_ERRNO_CASE(no_descriptors, EMFILE);
	BOOST_ERRNO_CASE(no_buffer_space, ENOBUFS);
	BOOST_ERRNO_CASE(no_memory, ENOMEM);
	BOOST_ERRNO_CASE(no_permission, EPERM);
	BOOST_ERRNO_CASE(no_protocol_option, ENOPROTOOPT);
	BOOST_ERRNO_CASE(not_connected, ENOTCONN);
	BOOST_ERRNO_CASE(not_socket, ENOTSOCK);
	BOOST_ERRNO_CASE(operation_aborted, ECANCELED);
	BOOST_ERRNO_CASE(operation_not_supported, EOPNOTSUPP);
	BOOST_ERRNO_CASE(shut_down, ESHUTDOWN);
	BOOST_ERRNO_CASE(timed_out, ETIMEDOUT);
	BOOST_ERRNO_CASE(try_again, EAGAIN);
	BOOST_ERRNO_CASE(would_block, EWOULDBLOCK);

	BOOST_ERRNO_CASE(host_not_found, HOST_NOT_FOUND);
	BOOST_ERRNO_CASE(host_not_found_try_again, TRY_AGAIN);
	BOOST_ERRNO_CASE(no_data, NO_DATA);
	BOOST_ERRNO_CASE(no_recovery, NO_RECOVERY);

#ifdef EPROCLIM
	ERRNO_CASE(EPROCLIM);
#endif

#ifdef WSAEPROCLIM
	ERRNO_CASE(EPROCLIM);
#endif

#ifdef EDESTADDRREQ
	ERRNO_CASE(EDESTADDRREQ);
#endif

#ifdef EPROTOTYPE
	ERRNO_CASE(EPROTOTYPE);
#endif

#ifdef EPROTONOSUPPORT
	ERRNO_CASE(EPROTONOSUPPORT);
#endif

#if defined(ESOCKTNOSUPPORT) || defined(WSAESOCKTNOSUPPORT)
	ERRNO_CASE(ESOCKTNOSUPPORT);
#endif

#if defined(EPFNOSUPPORT) || defined(WSAEPFNOSUPPORT)
	ERRNO_CASE(EPFNOSUPPORT);
#endif

#ifdef EADDRNOTAVAIL
	ERRNO_CASE(EADDRNOTAVAIL);
#endif

#if defined(EHOSTDOWN) || defined(WSAEHOSTDOWN)
	ERRNO_CASE(EHOSTDOWN);
#endif

#if defined(EDISCON) || defined(WSAEDISCON)
	ERRNO_CASE(EDISCON);
#endif
}