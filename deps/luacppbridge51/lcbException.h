#ifndef __luaCppBridge_Exception_h__
#define __luaCppBridge_Exception_h__

#include <lua.hpp>
#include <stdexcept>

namespace LuaCppBridge
{

	struct Type_error : public std::runtime_error
	{
		Type_error(lua_State* L)
			: std::runtime_error( lua_tostring(L, -1) )
		{}
		
		Type_error(lua_State* L, bool pop_stack)
			: std::runtime_error( lua_tostring(L, -1) )
		{
			lua_pop(L, 1);
		}
		
		Type_error(std::string const & error_message)
			: std::runtime_error(error_message)
		{}
	};

}

#endif