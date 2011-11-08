#pragma once

#include "../deps/LuaCppBridge51/lcbHybridObjectWithProperties.h"

#include <boost/asio/ip/tcp.hpp>

namespace LuaNode {

namespace Net {

class Acceptor : public LuaCppBridge::HybridObjectWithProperties<Acceptor>
{
public:
	Acceptor(lua_State* L);
	virtual ~Acceptor(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(Acceptor);

	static int tostring_T(lua_State* L);

	int Open(lua_State* L);
	int Close(lua_State* L);

	int SetOption(lua_State* L);
	int GetLocalAddress(lua_State* L);

	int Bind(lua_State* L);
	int Listen(lua_State* L);
	int Accept(lua_State* L);


public:
	void HandleAccept(int reference, boost::shared_ptr<boost::asio::ip::tcp::socket> socket, const boost::system::error_code& error);


	static void RegisterFunctions(lua_State* L);

private:

private:
	lua_State* m_L;
	unsigned int m_acceptorId;
	// Our socket acceptor
	boost::asio::ip::tcp::acceptor m_acceptor;
};

}

}
