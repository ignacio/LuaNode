#ifndef SRC_LUANODE_H_
#define SRC_LUANODE_H_

#include <boost/asio/io_service.hpp>
#include "lua_vm.h"
#include "blogger.h"

/*#include <sys/types.h>

#ifndef _WIN32
	#include "../deps/libeio/eio_patch.h"
	#include "../deps/libeio/eio.h"
#endif*/


namespace LuaNode {
	boost::asio::io_service& GetIoService();
	CLuaVM& GetLuaVM();
	int BoostErrorCodeToLua(lua_State* L, const boost::system::error_code& ec);
	int BoostErrorToCallback (lua_State* L, const boost::system::error_code& ec);
	bool FatalError(lua_State* L, const char* message);
	void ReportError(lua_State* L, const char* message);
	
	const char* signo_string(int errorno);

	CLogger& Logger();
}

#endif