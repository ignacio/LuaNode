#include "stdafx.h"
#include "luanode.h"
#include "luanode_constants.h"
#include <errno.h>

#define SET_BOOST_ERR_FIELD(e, v)  lua_pushinteger(L, boost::asio::error::e); lua_setfield(L, t, #v);

#if defined (_WIN32)
# define SET_ERR_FIELD(e) lua_pushinteger(L, WSA ## e); lua_setfield(L, t, #e);
#else
# define SET_ERR_FIELD(e) lua_pushinteger(L, e); lua_setfield(L, t, #e);
#endif

void LuaNode::DefineConstants(lua_State* L)
{
	lua_newtable(L);
	int t = lua_gettop(L);

	lua_pushinteger(L, boost::asio::error::eof); lua_setfield(L, t, "EOF");

	SET_BOOST_ERR_FIELD(access_denied, EACCES);
	SET_BOOST_ERR_FIELD(address_family_not_supported, EAFNOSUPPORT);
	SET_BOOST_ERR_FIELD(address_in_use, EADDRINUSE);
	SET_BOOST_ERR_FIELD(already_connected, EISCONN);
	SET_BOOST_ERR_FIELD(already_started, EALREADY);
	SET_BOOST_ERR_FIELD(broken_pipe, EPIPE);
	SET_BOOST_ERR_FIELD(connection_aborted, ECONNABORTED);
	SET_BOOST_ERR_FIELD(connection_refused, ECONNREFUSED);
	SET_BOOST_ERR_FIELD(connection_reset, ECONNRESET);
	SET_BOOST_ERR_FIELD(bad_descriptor, EBADF);
	SET_BOOST_ERR_FIELD(fault, EFAULT);
	SET_BOOST_ERR_FIELD(host_unreachable, EHOSTUNREACH);
	SET_BOOST_ERR_FIELD(in_progress, EINPROGRESS);
	SET_BOOST_ERR_FIELD(interrupted, EINTR);
	SET_BOOST_ERR_FIELD(invalid_argument, EINVAL);
	SET_BOOST_ERR_FIELD(message_size, EMSGSIZE);
	SET_BOOST_ERR_FIELD(name_too_long, ENAMETOOLONG);
	SET_BOOST_ERR_FIELD(network_down, ENETDOWN);
	SET_BOOST_ERR_FIELD(network_reset, ENETRESET);
	SET_BOOST_ERR_FIELD(network_unreachable, ENETUNREACH);
	SET_BOOST_ERR_FIELD(no_descriptors, EMFILE);
	SET_BOOST_ERR_FIELD(no_buffer_space, ENOBUFS);
	SET_BOOST_ERR_FIELD(no_memory, ENOMEM);
	SET_BOOST_ERR_FIELD(no_permission, EPERM);
	SET_BOOST_ERR_FIELD(no_protocol_option, ENOPROTOOPT);
	SET_BOOST_ERR_FIELD(not_connected, ENOTCONN);
	SET_BOOST_ERR_FIELD(not_socket, ENOTSOCK);
	SET_BOOST_ERR_FIELD(operation_aborted, ECANCELED);
	SET_BOOST_ERR_FIELD(operation_not_supported, EOPNOTSUPP);
	SET_BOOST_ERR_FIELD(shut_down, ESHUTDOWN);
	SET_BOOST_ERR_FIELD(timed_out, ETIMEDOUT);
	SET_BOOST_ERR_FIELD(try_again, EAGAIN);
	SET_BOOST_ERR_FIELD(would_block, EWOULDBLOCK);

	SET_BOOST_ERR_FIELD(host_not_found, HOST_NOT_FOUND);
	SET_BOOST_ERR_FIELD(host_not_found_try_again, TRY_AGAIN);
	SET_BOOST_ERR_FIELD(no_data, NO_DATA);
	SET_BOOST_ERR_FIELD(no_recovery, NO_RECOVERY);

#ifdef EPROCLIM
	SET_ERR_FIELD(EPROCLIM);
#endif

#ifdef WSAEPROCLIM
	SET_ERR_FIELD(EPROCLIM);
#endif

#ifdef EDESTADDRREQ
	SET_ERR_FIELD(EDESTADDRREQ);
#endif

#ifdef EPROTOTYPE
	SET_ERR_FIELD(EPROTOTYPE);
#endif

#ifdef EPROTONOSUPPORT
	SET_ERR_FIELD(EPROTONOSUPPORT);
#endif

#if defined(ESOCKTNOSUPPORT) || defined(WSAESOCKTNOSUPPORT)
	SET_ERR_FIELD(ESOCKTNOSUPPORT);
#endif

#if defined(EPFNOSUPPORT) || defined(WSAEPFNOSUPPORT)
	SET_ERR_FIELD(EPFNOSUPPORT);
#endif

#ifdef EADDRNOTAVAIL
	SET_ERR_FIELD(EADDRNOTAVAIL);
#endif

#if defined(EHOSTDOWN) || defined(WSAEHOSTDOWN)
	SET_ERR_FIELD(EHOSTDOWN);
#endif

#if defined(EDISCON) || defined(WSAEDISCON)
	SET_ERR_FIELD(EDISCON);
#endif
}

#undef SET_ERR_FIELD
