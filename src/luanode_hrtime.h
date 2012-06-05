#ifndef LUANODE_HRTIME_H_
#define LUANODE_HRTIME_H_

#include <boost/cstdint.hpp>

namespace LuaNode { namespace HighresTime {

boost::uint64_t Get ();
int Get (lua_State* L);

} }

#endif