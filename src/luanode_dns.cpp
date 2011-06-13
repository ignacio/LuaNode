#include "stdafx.h"
#include "luanode.h"
#include "luanode_dns.h"
#include "blogger.h"

#include <boost/asio/placeholders.hpp>

#include <boost/bind.hpp>



using namespace LuaNode::Dns;

const char* Resolver::className = "Resolver";
const Resolver::RegType Resolver::methods[] = {
	{ "Lookup", &Resolver::Lookup },
	{0}
};

const Resolver::RegType Resolver::setters[] = {
	{0}
};

const Resolver::RegType Resolver::getters[] = {
	{0}
};

static unsigned long s_resolverCount = 0;

Resolver::Resolver(lua_State* L) : 
	m_L(L),
	m_resolver( LuaNode::GetIoService() )
{
	s_resolverCount++;
	LogDebug("Constructing Resolver (%p). Current resolver count = %d", this, s_resolverCount);
}

Resolver::~Resolver(void)
{
	s_resolverCount--;
	LogDebug("Destructing Resolver (%p). Current resolver count = %d", this, s_resolverCount);
}

//////////////////////////////////////////////////////////////////////////
/// 
int Resolver::Lookup(lua_State* L) {
	int callback;

	std::string domain = luaL_checkstring(L, 2);
	std::string service = luaL_checkstring(L, 3);
	luaL_checktype(L, 4, LUA_TFUNCTION);
	lua_pushvalue(L, 4);
	callback = luaL_ref(L, LUA_REGISTRYINDEX);
	bool enumerateAll = lua_toboolean(L, 5);

	/*if(lua_type(L, 3) == LUA_TSTRING) {
		service = lua_tostring(L, 3);
		
	}
	else if(lua_type(L, 3) == LUA_TFUNCTION) {
		lua_pushvalue(L, 3);
		callback = luaL_ref(L, LUA_REGISTRYINDEX);
	}
	else {
		luaL_error(L, "A callback must be supplied");
	}*/

	boost::asio::ip::tcp::resolver::query query(domain, service);

	// TODO: No hacer que esto sea una clase, sino un par de funciones estáticas
	// No pasar el this en el handler (el resolver podría ser gc'ed mientras hay un async_resolve flying...
	// o sino, guardo una ref en la registry mientras tanto...
	m_resolver.async_resolve(query, 
		boost::bind(&Resolver::HandleResolve, this, callback, domain, enumerateAll, boost::asio::placeholders::error, boost::asio::placeholders::iterator)
	);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Resolver::HandleResolve(int callback, std::string domain, bool enumerateAll, const boost::system::error_code& error, boost::asio::ip::tcp::resolver::iterator iter)
{
	lua_State* L = m_L;
	
	lua_rawgeti(L, LUA_REGISTRYINDEX, callback);
	luaL_unref(L, LUA_REGISTRYINDEX, callback);

	if(error) {
		lua_pushstring(L, error.message().c_str());
		lua_call(L, 1, LUA_MULTRET);
		lua_settop(L, 0);
		return;
	}
	
	boost::asio::ip::tcp::resolver::iterator end;
	if(iter == end) {
		lua_pushstring(L, "did not resolve to anything?");	// TODO: proper error message :D
		lua_call(L, 1, LUA_MULTRET);
		lua_settop(L, 0);
		return;
	}

	lua_pushnil(L);
	
	// enumerateAll will push an array of endpoints instead of just the first one
	if(enumerateAll) {
		lua_newtable(L);
		int table = lua_gettop(L);
		int i = 0;
		while(iter != end) {
			boost::asio::ip::tcp::endpoint endpoint = *iter++;
			EndpointToLua(L, endpoint);
			lua_rawseti(L, table, ++i);
		}
	}
	else {
		boost::asio::ip::tcp::endpoint endpoint = *iter++;
		EndpointToLua(L, endpoint);
	}
	lua_pushlstring(L, domain.c_str(), domain.size());
	lua_call(L, 3, LUA_MULTRET);
	lua_settop(L, 0);
}

//////////////////////////////////////////////////////////////////////////
/// Pushes to Lua the data of the endpoint
void Resolver::EndpointToLua(lua_State* L, const boost::asio::ip::tcp::endpoint& endpoint) {
	const boost::asio::ip::address& address = endpoint.address();
	std::string s = endpoint.address().to_string();
	lua_newtable(L);
	lua_pushstring(L, address.to_string().c_str());
	lua_setfield(L, -2, "address");

	lua_pushnumber(L, endpoint.port());
	lua_setfield(L, -2, "port");

	if(endpoint.address().is_v6()) {
		lua_pushnumber(L, 6);
	}
	else if(endpoint.address().is_v4()) {
		lua_pushnumber(L, 4);
	}
	else {
		lua_pushliteral(L, "unknown");
	}
	lua_setfield(L, -2, "family");
}
