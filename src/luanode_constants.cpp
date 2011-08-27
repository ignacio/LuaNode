#include "stdafx.h"
#include "luanode.h"
#include "luanode_constants.h"

#define ERRNO_CASE(e, v)  lua_pushinteger(L, boost::asio::error::e); lua_setfield(L, t, #v);

void LuaNode::DefineConstants(lua_State* L)
{
	lua_newtable(L);
	int t = lua_gettop(L);

	ERRNO_CASE(access_denied, EACCES);
	ERRNO_CASE(address_family_not_supported, EAFNOSUPPORT);
	ERRNO_CASE(address_in_use, EADDRINUSE);
	ERRNO_CASE(already_connected, EISCONN);
	ERRNO_CASE(already_started, EALREADY);
	ERRNO_CASE(broken_pipe, EPIPE);
	ERRNO_CASE(connection_aborted, ECONNABORTED);
	ERRNO_CASE(connection_refused, ECONNREFUSED);
	ERRNO_CASE(connection_reset, ECONNRESET);
	ERRNO_CASE(bad_descriptor, EBADF);
	ERRNO_CASE(fault, EFAULT);
	ERRNO_CASE(host_unreachable, EHOSTUNREACH);
	ERRNO_CASE(in_progress, EINPROGRESS);
	ERRNO_CASE(interrupted, EINTR);
	ERRNO_CASE(invalid_argument, EINVAL);
	ERRNO_CASE(message_size, EMSGSIZE);
	ERRNO_CASE(name_too_long, ENAMETOOLONG);
	ERRNO_CASE(network_down, ENETDOWN);
	ERRNO_CASE(network_reset, ENETRESET);
	ERRNO_CASE(network_unreachable, ENETUNREACH);
	ERRNO_CASE(no_descriptors, EMFILE);
	ERRNO_CASE(no_buffer_space, ENOBUFS);
	ERRNO_CASE(no_memory, ENOMEM);
	ERRNO_CASE(no_permission, EPERM);
	ERRNO_CASE(no_protocol_option, ENOPROTOOPT);
	ERRNO_CASE(not_connected, ENOTCONN);
	ERRNO_CASE(not_socket, ENOTSOCK);
	ERRNO_CASE(operation_aborted, ECANCELED);
	ERRNO_CASE(operation_not_supported, EOPNOTSUPP);
	ERRNO_CASE(shut_down, ESHUTDOWN);
	ERRNO_CASE(timed_out, ETIMEDOUT);
	ERRNO_CASE(try_again, EAGAIN);
	ERRNO_CASE(would_block, EWOULDBLOCK);

	ERRNO_CASE(host_not_found, HOST_NOT_FOUND);
	ERRNO_CASE(host_not_found_try_again, TRY_AGAIN);
	ERRNO_CASE(no_data, NO_DATA);
	ERRNO_CASE(no_recovery, NO_RECOVERY);
}