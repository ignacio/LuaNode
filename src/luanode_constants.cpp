#include "stdafx.h"
#include "luanode.h"
#include "luanode_constants.h"

#define SET_ERR_FIELD(e, v)  lua_pushinteger(L, boost::asio::error::e); lua_setfield(L, t, #v);

void LuaNode::DefineConstants(lua_State* L)
{
	lua_newtable(L);
	int t = lua_gettop(L);

	SET_ERR_FIELD(access_denied, EACCES);
	SET_ERR_FIELD(address_family_not_supported, EAFNOSUPPORT);
	SET_ERR_FIELD(address_in_use, EADDRINUSE);
	SET_ERR_FIELD(already_connected, EISCONN);
	SET_ERR_FIELD(already_started, EALREADY);
	SET_ERR_FIELD(broken_pipe, EPIPE);
	SET_ERR_FIELD(connection_aborted, ECONNABORTED);
	SET_ERR_FIELD(connection_refused, ECONNREFUSED);
	SET_ERR_FIELD(connection_reset, ECONNRESET);
	SET_ERR_FIELD(bad_descriptor, EBADF);
	SET_ERR_FIELD(fault, EFAULT);
	SET_ERR_FIELD(host_unreachable, EHOSTUNREACH);
	SET_ERR_FIELD(in_progress, EINPROGRESS);
	SET_ERR_FIELD(interrupted, EINTR);
	SET_ERR_FIELD(invalid_argument, EINVAL);
	SET_ERR_FIELD(message_size, EMSGSIZE);
	SET_ERR_FIELD(name_too_long, ENAMETOOLONG);
	SET_ERR_FIELD(network_down, ENETDOWN);
	SET_ERR_FIELD(network_reset, ENETRESET);
	SET_ERR_FIELD(network_unreachable, ENETUNREACH);
	SET_ERR_FIELD(no_descriptors, EMFILE);
	SET_ERR_FIELD(no_buffer_space, ENOBUFS);
	SET_ERR_FIELD(no_memory, ENOMEM);
	SET_ERR_FIELD(no_permission, EPERM);
	SET_ERR_FIELD(no_protocol_option, ENOPROTOOPT);
	SET_ERR_FIELD(not_connected, ENOTCONN);
	SET_ERR_FIELD(not_socket, ENOTSOCK);
	SET_ERR_FIELD(operation_aborted, ECANCELED);
	SET_ERR_FIELD(operation_not_supported, EOPNOTSUPP);
	SET_ERR_FIELD(shut_down, ESHUTDOWN);
	SET_ERR_FIELD(timed_out, ETIMEDOUT);
	SET_ERR_FIELD(try_again, EAGAIN);
	SET_ERR_FIELD(would_block, EWOULDBLOCK);

	SET_ERR_FIELD(host_not_found, HOST_NOT_FOUND);
	SET_ERR_FIELD(host_not_found_try_again, TRY_AGAIN);
	SET_ERR_FIELD(no_data, NO_DATA);
	SET_ERR_FIELD(no_recovery, NO_RECOVERY);
}

#undef SET_ERR_FIELD
