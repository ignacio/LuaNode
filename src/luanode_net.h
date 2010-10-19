#pragma once

#include <luacppbridge51/lcbHybridObjectWithProperties.h>
#include <boost/asio.hpp>
#include <boost/shared_ptr.hpp>
#include <boost/enable_shared_from_this.hpp>

namespace LuaNode {

namespace Net {

void RegisterFunctions(lua_State* L);

static int IsIP(lua_State* L);
/*class Net : public LuaCppBridge::HybridObjectWithProperties<Net>
{
public:
	Net(lua_State* L);
	virtual ~Net(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(Net);

	int CreateSocket(lua_State* L);

	int Accept(lua_State* L);
	int Stop(lua_State* L);
	int Again(lua_State* L);

	LCB_DECL_GET(timeout);
	LCB_DECL_SETGET(repeat);
	//LCB_DECL_GET(callback);

public:
	//void OnTimeout(const boost::system::error_code& ec);
	void HandleAccept(boost::shared_ptr< boost::asio::ip::tcp::socket > socket, const boost::system::error_code& error);

private:
	void StartAccept();

private:
	// Our socket acceptor
	boost::asio::ip::tcp::acceptor m_acceptor;

	lua_State* m_L;
};*/





class Socket : public LuaCppBridge::HybridObjectWithProperties<Socket>
{
public:
	Socket(lua_State* L);
	Socket(lua_State* L, boost::asio::ip::tcp::socket*);
	virtual ~Socket(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(Socket);

	int SetOption(lua_State* L);

	int Bind(lua_State* L);
	int Listen(lua_State* L);
	int Connect(lua_State* L);

	int Write(lua_State* L);
	int Read(lua_State* L);

	int Close(lua_State* L);
	int Shutdown(lua_State* L);

	int GetLocalAddress(lua_State* L);
	int GetRemoteAddress(lua_State* L);

private:
	void HandleWrite(const boost::system::error_code& error, size_t bytes_transferred);
	void HandleRead(const boost::system::error_code& error, size_t bytes_transferred);
	void HandleReadSome(const boost::system::error_code& error, size_t bytes_transferred);
	void HandleConnect(const boost::system::error_code& error);

private:
	boost::shared_ptr< boost::asio::ip::tcp::socket > m_socket;
	boost::asio::streambuf m_inputBuffer;
	//boost::array<char, 4> m_inputArray;	// agrandar esto y poolearlo
	//boost::array<char, 32> m_inputArray;	// agrandar esto y poolearlo
	//boost::array<char, 64> m_inputArray;	// agrandar esto y poolearlo
	boost::array<char, 128> m_inputArray;	// agrandar esto y poolearlo (el test simple\test-http-upgrade-server necesita un buffer grande sino falla)
	lua_State* m_L;
};





class Acceptor : public LuaCppBridge::HybridObjectWithProperties<Acceptor>
{
public:
	Acceptor(lua_State* L);
	virtual ~Acceptor(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(Acceptor);

	int Open(lua_State* L);
	int Close(lua_State* L);

	int SetOption(lua_State* L);
	int GetLocalAddress(lua_State* L);

	int Bind(lua_State* L);
	int Listen(lua_State* L);
	int Accept(lua_State* L);


public:
	void HandleAccept(boost::asio::ip::tcp::socket* socket, const boost::system::error_code& error);

private:

private:
	// Our socket acceptor
	boost::asio::ip::tcp::acceptor m_acceptor;
	lua_State* m_L;
};

}

}