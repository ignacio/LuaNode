#ifndef SRC_LUANODE_H_
#define SRC_LUANODE_H_

//#include <boost/asio.hpp>
#include <boost/asio/io_service.hpp>
#include "EvaluadorLua.h"


namespace LuaNode {
	boost::asio::io_service& GetIoService();
	CEvaluadorLua& GetLuaEval();
	int BoostErrorCodeToLua(lua_State* L, const boost::system::error_code& ec);
	
	
	
}

#endif