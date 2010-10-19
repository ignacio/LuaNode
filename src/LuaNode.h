#ifndef SRC_LUANODE_H_
#define SRC_LUANODE_H_

#include <boost/asio.hpp>
#include "EvaluadorLua.h"


namespace LuaNode {
	boost::asio::io_service& GetIoService();
	CEvaluadorLua& GetLuaEval();
	
	
	
}

#endif