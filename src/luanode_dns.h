#pragma once

#include <luacppbridge51/lcbHybridObjectWithProperties.h>

#include <boost/asio/ip/tcp.hpp>

namespace LuaNode {

namespace Dns {

class Resolver : public LuaCppBridge::HybridObjectWithProperties<Resolver>
{
public:
	Resolver(lua_State* L);
	virtual ~Resolver(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(Resolver);

	int Lookup(lua_State* L);

	void HandleResolve(int callback, std::string domain, const boost::system::error_code& error, boost::asio::ip::tcp::resolver::iterator iterator);


private:
	lua_State* m_L;
	boost::asio::ip::tcp::resolver m_resolver;
};

}

}