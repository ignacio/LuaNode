#pragma once

#include "../deps/LuaCppBridge51/lcbHybridObjectWithProperties.h"
#include "../deps/LuaCppBridge51/lcbRawObject.h"

#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/streambuf.hpp>

#include <openssl/hmac.h>
#include <boost/asio/ssl.hpp>

namespace LuaNode {

namespace Crypto {

void Register(lua_State* L);

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
	const unsigned int m_socketId;
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



class Hash : public LuaCppBridge::RawObject<Hash> {
public:
	Hash(lua_State* L);
	virtual ~Hash();

public:
	LCB_RO_DECLARE_EXPORTABLE(Hash);

	int Update(lua_State* L);
	int Final(lua_State* L);

private:
	EVP_MD_CTX m_context;
};


class Hmac : public LuaCppBridge::RawObject<Hmac> {
public:
	Hmac(lua_State* L);
	virtual ~Hmac();

public:
	LCB_RO_DECLARE_EXPORTABLE(Hmac);

	int Update(lua_State* L);
	int Final(lua_State* L);

private:
	HMAC_CTX m_context;
};


class Signer : public LuaCppBridge::RawObject<Signer> {
public:
	Signer(lua_State* L);
	virtual ~Signer();

public:
	LCB_RO_DECLARE_EXPORTABLE(Signer);
	
	int Update(lua_State* L);
	int Sign(lua_State* L);

private:
	EVP_MD_CTX m_context;
};


class Verifier : public LuaCppBridge::RawObject<Verifier> {
public:
	Verifier(lua_State* L);
	virtual ~Verifier();

public:
	LCB_RO_DECLARE_EXPORTABLE(Verifier);

	int Update(lua_State* L);
	int Verify(lua_State* L);

private:
	EVP_MD_CTX m_context;
};



class Cipher : public LuaCppBridge::RawObject<Cipher> {
public:
	Cipher(lua_State* L);
	virtual ~Cipher();

public:
	LCB_RO_DECLARE_EXPORTABLE(Cipher);

	int Update(lua_State* L);
	int Final(lua_State* L);

private:
	EVP_CIPHER_CTX m_context;
	unsigned char m_outputMode;	/* 0 = binary, 1 = hexadecimal */
};


class Decipher : public LuaCppBridge::RawObject<Decipher> {
public:
	Decipher(lua_State* L);
	virtual ~Decipher();

public:
	LCB_RO_DECLARE_EXPORTABLE(Decipher);

	int Update(lua_State* L);
	int Final(lua_State* L);

private:
	EVP_CIPHER_CTX m_context;
	unsigned char m_outputMode;	/* 0 = binary, 1 = hexadecimal */
};


}

}
