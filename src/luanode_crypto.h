#pragma once

#include "../deps/luacppbridge51/lcbHybridObjectWithProperties.h"

#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/streambuf.hpp>

#include <boost/asio/ssl.hpp>

namespace LuaNode {

namespace Crypto {

class Socket : public LuaCppBridge::HybridObjectWithProperties<Socket>
{
public:
	Socket(lua_State* L);
	Socket(lua_State* L, boost::asio::ip::tcp::socket*);
	virtual ~Socket(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(Socket);

	static int tostring_T(lua_State* L);

	int SetOption(lua_State* L);

	int VerifyPeer(lua_State* L);
	int GetPeerCertificate(lua_State* L);
	int Connect(lua_State* L);

	int Write(lua_State* L);
	int Read(lua_State* L);

	int Close(lua_State* L);
	int Shutdown(lua_State* L);

	//int GetLocalAddress(lua_State* L);
	//int GetRemoteAddress(lua_State* L);

	int DoHandShake(lua_State* L);

private:
	void HandleWrite(int reference, const boost::system::error_code& error, size_t bytes_transferred);
	void HandleRead(int reference, const boost::system::error_code& error, size_t bytes_transferred);
	void HandleReadSome(int reference, const boost::system::error_code& error, size_t bytes_transferred);
	void HandleConnect(int reference, const boost::system::error_code& error);
	void HandleHandshake(int reference, const boost::system::error_code& error);
	void HandleShutdown(int reference, const boost::system::error_code& error);

private:
	lua_State* m_L;
	const unsigned long m_socketId;
	bool m_shutdown_pending;
	bool m_close_pending;
	unsigned long m_pending_writes;
	unsigned long m_pending_reads;
	
	boost::asio::ssl::stream<boost::asio::ip::tcp::socket&>* m_ssl_socket;
	
	boost::asio::streambuf m_inputBuffer;
	//boost::array<char, 4> m_inputArray;	// agrandar esto y poolearlo
	//boost::array<char, 32> m_inputArray;	// agrandar esto y poolearlo
	//boost::array<char, 64> m_inputArray;	// agrandar esto y poolearlo
	boost::array<char, 128> m_inputArray;	// agrandar esto y poolearlo (el test simple\test-http-upgrade-server necesita un buffer grande sino falla)
	
	boost::asio::ssl::stream_base::handshake_type m_handshake_type;
	bool m_should_verify;
	bool m_shutdown_send;
};


class SecureContext : public LuaCppBridge::HybridObjectWithProperties<SecureContext> {
public:
	SecureContext(lua_State* L);
	virtual ~SecureContext(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(SecureContext);

	int SetKey(lua_State* L);
	int SetCert(lua_State* L);
	int AddCACert(lua_State* L);


public:
	boost::asio::ssl::context& GetContextRef() { return *m_context; };

private:
	lua_State* m_L;
	boost::shared_ptr< boost::asio::ssl::context > m_context;
	X509_STORE* m_ca_store;
};

}

}