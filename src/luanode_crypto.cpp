#include "StdAfx.h"
#include "luanode.h"
#include "luanode_crypto.h"
#include "luanode_net.h"
#include "blogger.h"

#include <boost/asio/read_until.hpp>

#include <boost/bind.hpp>
#include "shared_const_buffer.h"


using namespace LuaNode::Crypto;

static unsigned long s_nextSocketId = 0;
static unsigned long s_socketCount = 0;

const char* Socket::className = "SecureSocket";
const Socket::RegType Socket::methods[] = {
	{"setoption", &Socket::SetOption},
	{"verifyPeer", &Socket::VerifyPeer},
	{"getPeerCertificate", &Socket::GetPeerCertificate},
	
	{"close", &Socket::Close},
	{"shutdown", &Socket::Shutdown},
	{"write", &Socket::Write},
	{"read", &Socket::Read},

	{"doHandShake", &Socket::DoHandShake},
	
	{0}
};

const Socket::RegType Socket::setters[] = {
	{0}
};

const Socket::RegType Socket::getters[] = {
	{0}
};


static int verify_callback(int ok, X509_STORE_CTX *ctx) {
	assert(ok);
	return(1); // Ignore errors by now. VerifyPeer will catch them by using SSL_get_verify_result.
}

Socket::Socket(lua_State* L) : 
	m_L(L),
	m_socketId(++s_nextSocketId),
	m_shutdown_pending(false),
	m_close_pending(false),
	m_pending_writes(0),
	m_pending_reads(0)
{
	s_socketCount++;
	LogDebug("Constructing Crypto::Socket (%p) (id:%d). Current socket count = %d", this, m_socketId, s_socketCount);

	LuaNode::Net::Socket* pSocket = LuaNode::Net::Socket::check(L, 1);
	SecureContext* ctx = Crypto::SecureContext::check(L, 2);

	if(lua_toboolean(L, 3)) {
		m_handshake_type = boost::asio::ssl::stream_base::server;
	}
	else {
		m_handshake_type = boost::asio::ssl::stream_base::client;
	}

	if(lua_toboolean(L, 4)) {
		m_should_verify = true;
	}
	else {
		m_should_verify = false;
	}

	m_ssl_socket = new boost::asio::ssl::stream<boost::asio::ip::tcp::socket&>(pSocket->GetSocketRef(), ctx->GetContextRef());

	if(m_should_verify) {
		SSL_set_verify(m_ssl_socket->impl()->ssl, SSL_VERIFY_PEER, verify_callback);
	}
}

Socket::~Socket(void)
{
	s_socketCount--;
	LogDebug("Destructing Crypto::Socket (%p) (id:%d). Current socket count = %d", this, m_socketId, s_socketCount);
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ int Socket::tostring_T(lua_State* L) {
	userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
	Socket* obj = ud->pT;
	lua_pushfstring(L, "%s (%p) (id=%d)", className, obj, obj->m_socketId);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::SetOption(lua_State* L) {
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::VerifyPeer(lua_State* L) {
	//lua_getfield(L, 1, "_ssl_context");
	SecureContext* ctx = Crypto::SecureContext::check(L, 2);

	boost::asio::ssl::context& context = ctx->GetContextRef();

	/*boost::system::error_code ec;
	ctx->GetContextRef().set_verify_mode(boost::asio::ssl::context_base::verify_peer, ec);
	if(ec) {
		return BoostErrorCodeToLua(L, ec);
	}
	lua_pushboolean(L, true);
	return 1;*/

	/*if (ss->ssl_ == NULL) return False();
	if (!ss->should_verify_) return False();*/

	
	X509* peer_cert = SSL_get_peer_certificate( m_ssl_socket->impl()->ssl );
	if(peer_cert == NULL) {
		lua_pushboolean(L, false);
		return 1;
	}
	X509_free(peer_cert);

	long x509_verify_error = SSL_get_verify_result( m_ssl_socket->impl()->ssl );

	// Can also check for:
	// X509_V_ERR_CERT_HAS_EXPIRED
	// X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT
	// X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN
	// X509_V_ERR_INVALID_CA
	// X509_V_ERR_PATH_LENGTH_EXCEEDED
	// X509_V_ERR_INVALID_PURPOSE
	// X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT

	// printf("%s\n", X509_verify_cert_error_string(x509_verify_error));

	if (!x509_verify_error) {
		lua_pushboolean(L, true);
	}
	else {
		lua_pushboolean(L, false);
	}
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::GetPeerCertificate(lua_State* L) {
	const SSL* ssl = m_ssl_socket->impl()->ssl;
	
	X509* peer_cert = SSL_get_peer_certificate(ssl);
	if(peer_cert == NULL) {
		lua_pushnil(L);
		return 1;
	}

	lua_newtable(L);
	int table = lua_gettop(L);
	char* subject = X509_NAME_oneline(X509_get_subject_name(peer_cert), 0, 0);
	if (subject != NULL) {
		lua_pushstring(L, subject);
		lua_setfield(L, table, "subject");
		OPENSSL_free(subject);
	}
	char* issuer = X509_NAME_oneline(X509_get_issuer_name(peer_cert), 0, 0);
	if (issuer != NULL) {
		lua_pushstring(L, subject);
		lua_setfield(L, table, "issuer");
		OPENSSL_free(issuer);
	}

	char buf[256];
	BIO* bio = BIO_new(BIO_s_mem());
	ASN1_TIME_print(bio, X509_get_notBefore(peer_cert));
	memset(buf, 0, sizeof(buf));
	BIO_read(bio, buf, sizeof(buf) - 1);
	lua_pushstring(L, buf);
	lua_setfield(L, table, "valid_from");
	
	ASN1_TIME_print(bio, X509_get_notAfter(peer_cert));
	memset(buf, 0, sizeof(buf));
	BIO_read(bio, buf, sizeof(buf) - 1);
	BIO_free(bio);
	lua_pushstring(L, buf);
	lua_setfield(L, table, "valid_to");

	unsigned int md_size, i;
	unsigned char md[EVP_MAX_MD_SIZE];
	if (X509_digest(peer_cert, EVP_sha1(), md, &md_size)) {
		const char hex[] = "0123456789ABCDEF";
		char fingerprint[EVP_MAX_MD_SIZE * 3];

		for (i=0; i<md_size; i++) {
			fingerprint[3*i] = hex[(md[i] & 0xf0) >> 4];
			fingerprint[(3*i)+1] = hex[(md[i] & 0x0f)];
			fingerprint[(3*i)+2] = ':';
		}

		if (md_size > 0) {
			fingerprint[(3*(md_size-1))+2] = '\0';
		}
		else {
			fingerprint[0] = '\0';
		}

		lua_pushstring(L, fingerprint);
		lua_setfield(L, table, "fingerprint");
	}

	X509_free(peer_cert);

	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::DoHandShake(lua_State* L) {
	LogDebug("SecureSocket::DoHandShake (%p) (id:%d)", this, m_socketId);

	// store a reference in the registry
	lua_pushvalue(L, 1);
	int reference = luaL_ref(L, LUA_REGISTRYINDEX);

	m_ssl_socket->async_handshake(m_handshake_type,
		boost::bind(&Socket::HandleHandshake, this,
		reference, boost::asio::placeholders::error)
	);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Socket::HandleHandshake(int reference, const boost::system::error_code& error) {
	lua_State* L = m_L;
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	if(!error) {
		LogInfo("SecureSocket::HandleHandshake (%p) (id:%d)", this, m_socketId);
		lua_getfield(L, 1, "handshake_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			LuaNode::GetLuaVM().call(1, LUA_MULTRET);
		}
		else {
			// do nothing?
		}
	}
	else {
		LogDebug("SecureSocket::HandleHandshake with error (%p) (id:%d) - %s", this, m_socketId, error.message().c_str());
		lua_getfield(L, 1, "handshake_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushnil(L);

			switch(error.value()) {
			case boost::asio::error::eof:
				lua_pushliteral(L, "eof");
				break;
#ifdef _WIN32
			case ERROR_CONNECTION_ABORTED:
#endif
			case boost::asio::error::connection_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::operation_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::connection_reset:
				lua_pushliteral(L, "reset");
				break;

			default:
				lua_pushstring(L, error.message().c_str());
				break;
			}

			LuaNode::GetLuaVM().call(3, LUA_MULTRET);
			m_inputBuffer.consume(m_inputBuffer.size());
		}
		else {
			LogError("SecureSocket::HandleWrite with error (%p) - %s", this, m_socketId, error.message().c_str());
		}
	}
	lua_settop(L, 0);
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Write(lua_State* L) {
	/*if(m_shutdown_pending) {
		LogDebug("SecureSocket::Write (%p) ignoring because shutdown was signaled", this);
		return 0;
	}*/
	if(m_pending_writes > 0) {
		lua_pushboolean(L, false);
		return 1;
	}
	// store a reference in the registry
	lua_pushvalue(L, 1);
	int reference = luaL_ref(L, LUA_REGISTRYINDEX);

	if(lua_type(L, 2) == LUA_TSTRING) {
		const char* data = lua_tostring(L, 2);
		size_t length = lua_objlen(L, 2);
		std::string d(data, length);
		shared_const_buffer buffer(d);

		LogDebug("SecureSocket::Write (%p) (id:%d) - Length=%d, \r\n'%s'", this, m_socketId, length, data);

		m_pending_writes++;
		boost::asio::async_write(*m_ssl_socket, buffer,
			boost::bind(&Socket::HandleWrite, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
			);
	}
	else {
		luaL_error(L, "SecureSocket::Write (%p) (id:%d), unhandled type '%s'", this, m_socketId, luaL_typename(L, 2));
	}
	lua_pushboolean(L, true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Socket::HandleWrite(int reference, const boost::system::error_code& error, size_t bytes_transferred) {
	lua_State* L = m_L;
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	m_pending_writes--;
	if(!error) {
		LogInfo("SecureSocket::HandleWrite (%p) (id:%d) - Bytes Transferred (%d)", this, m_socketId, bytes_transferred);
		lua_getfield(L, 1, "write_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			LuaNode::GetLuaVM().call(1, LUA_MULTRET);
		}
		else {
			// do nothing?
		}
	}
	else {
		LogDebug("SecureSocket::HandleWrite with error (%p) (id:%d) - %s", this, m_socketId, error.message().c_str());
		lua_getfield(L, 1, "write_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushnil(L);

			switch(error.value()) {
			case boost::asio::error::eof:
				lua_pushliteral(L, "eof");
				break;
#ifdef _WIN32
			case ERROR_CONNECTION_ABORTED:
#endif
			case boost::asio::error::connection_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::operation_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::connection_reset:
				lua_pushliteral(L, "reset");
				break;

			default:
				lua_pushstring(L, error.message().c_str());
				break;
			}

			LuaNode::GetLuaVM().call(3, LUA_MULTRET);
			m_inputBuffer.consume(m_inputBuffer.size());
		}
		else {
			LogError("SecureSocket::HandleWrite with error (%p) (id:%d) - %s", this, m_socketId, error.message().c_str());
		}
	}

	boost::system::error_code ec;
	if(m_pending_writes == 0 && m_shutdown_pending) {
		boost::system::error_code ec;
		/*m_ssl_socket->async_shutdown(
			boost::bind(&Socket::HandleShutdown, this,
			reference, boost::asio::placeholders::error)
			);*/

		if(ec) {
			luaL_error(L, ec.message().c_str());
		}
		//m_ssl_socket->lowest_layer().shutdown(boost::asio::socket_base::shutdown_both, ec);
		if(m_shutdown_send) {
			m_ssl_socket->lowest_layer().shutdown(boost::asio::socket_base::shutdown_send, ec);
		}
		else {
			m_ssl_socket->lowest_layer().shutdown(boost::asio::socket_base::shutdown_receive, ec);
		}
		if(ec) {
			LogWarning("Error en shutdown (%p) (id:%d) '%s'", this, m_socketId, ec.message().c_str());
		}
	}

	/*boost::system::error_code ec;
	if(m_pending_writes == 0 && m_shutdown_pending) {
		LogDebug("Socket::HandleWrite (%p) async_shutdown", this);

		// store a reference in the registry
		lua_pushvalue(L, 1);
		int reference = luaL_ref(L, LUA_REGISTRYINDEX);

		m_ssl_socket->async_shutdown(
			boost::bind(&Socket::HandleShutdown, this,
			reference, boost::asio::placeholders::error)
			);*/

		/*if(m_handshake_type == boost::asio::ssl::stream_base::server) {
			LogDebug("Socket::HandleWrite (%p) async_shutdown (shutdown send)", this);
			m_ssl_socket->lowest_layer().shutdown(boost::asio::socket_base::shutdown_send, ec);
		}*/
		/*else {
			LogWarning("Socket::HandleWrite (%p) async_shutdown (shutdown send)", this);
			m_ssl_socket->lowest_layer().shutdown(boost::asio::socket_base::shutdown_receive, ec);			
		}*/
	//}

	if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
		boost::system::error_code ec;
		m_ssl_socket->lowest_layer().close(ec);
		if(ec) {
			LogError("SecureSocket::HandleWrite - Error closing socket (%p) (id=%d) - %s", this, m_socketId, ec.message().c_str());
		}
	}

	lua_settop(L, 0);
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Read(lua_State* L) {
	/*if(m_shutdown_pending) {
		LogDebug("SecureSocket::Read (%p) ignoring because shutdown was signaled", this);
		return 0;
	}*/

	// store a reference in the registry
	lua_pushvalue(L, 1);
	int reference = luaL_ref(L, LUA_REGISTRYINDEX);

	m_pending_reads++;
	if(lua_isnoneornil(L, 2)) {
		m_ssl_socket->async_read_some(
			boost::asio::buffer(m_inputArray), 
			boost::bind(&Socket::HandleReadSome, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);
	}
	else if(!lua_isnumber(L, 2)) {
		const char* p = luaL_optstring(L, 2, "*l");
		std::string delimiter = "\r\n";

		boost::asio::async_read_until(
			*m_ssl_socket, 
			m_inputBuffer, 
			delimiter,
			boost::bind(&Socket::HandleRead, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);
	}

	/*boost::asio::async_read(*m_socket, buffer,
		boost::bind(&Socket::HandleWrite, this, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);*/
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Socket::HandleRead(int reference, const boost::system::error_code& error, size_t bytes_transferred) {
	lua_State* L = m_L;
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	m_pending_reads--;
	if(!error) {
		LogInfo("SecureSocket::HandleRead (%p) (id:%d) - Bytes Transferred (%d)", this, m_socketId, bytes_transferred);
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			const char* data = (const char*)buffer_cast_helper(m_inputBuffer.data());
			lua_pushlstring(L, data, m_inputBuffer.size());
			m_inputBuffer.consume(m_inputBuffer.size());	// its safe to consume, the string has already been interned
			LuaNode::GetLuaVM().call(2, LUA_MULTRET);
		}
		else {
			// do nothing?
		}
	}
	else {
		if(m_shutdown_pending) {
			// ignore error when we're shutting down (FIXME!)
			return;
		}
		LogDebug("SecureSocket::HandleRead with error (%p) (id:%d) - %s", this, m_socketId, error.message().c_str());
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushnil(L);

			switch(error.value()) {
			case boost::asio::error::eof:
				lua_pushliteral(L, "eof");
				break;
#ifdef _WIN32
			case ERROR_CONNECTION_ABORTED:
#endif
			case boost::asio::error::connection_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::operation_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::connection_reset:
				lua_pushliteral(L, "reset");
				break;

			default:
				lua_pushstring(L, error.message().c_str());
				break;
			}

			LuaNode::GetLuaVM().call(3, LUA_MULTRET);
			m_inputBuffer.consume(m_inputBuffer.size());
		}
		else {
			LogError("SecureSocket::HandleRead with error (%p) (id:%d) - %s", this, m_socketId, error.message().c_str());
		}
	}

	/*boost::system::error_code ec;
	if(m_pending_writes == 0 && m_shutdown_pending) {
		boost::system::error_code ec;
		m_ssl_socket->async_shutdown(
			boost::bind(&Socket::HandleShutdown, this,
			reference, boost::asio::placeholders::error)
			);

		if(ec) {
			luaL_error(L, ec.message().c_str());
		}
	}*/

	if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
		boost::system::error_code ec;
		m_ssl_socket->lowest_layer().close(ec);
		if(ec) {
			LogError("Socket::HandleRead - Error closing socket (%p) (id=%d) - %s", this, m_socketId, ec.message().c_str());
		}
	}

	lua_settop(L, 0);
}

//////////////////////////////////////////////////////////////////////////
/// 
void Socket::HandleReadSome(int reference, const boost::system::error_code& error, size_t bytes_transferred) {
	lua_State* L = m_L;
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	m_pending_reads--;
	const char* data = m_inputArray.c_array();
	if(!error) {
		LogInfo("SecureSocket::HandleReadSome (%p) (id:%d) - Bytes Transferred (%d)", this, m_socketId, bytes_transferred);
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			const char* data = m_inputArray.c_array();
			lua_pushlstring(L, data, bytes_transferred);
			LuaNode::GetLuaVM().call(2, LUA_MULTRET);
		}
		else {
			// do nothing?
		}
	}
	else {
		if(m_shutdown_pending) {
			// ignore error when we're shutting down (FIXME!)
			//return;
		}
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushnil(L);

			switch(error.value()) {
			case boost::asio::error::eof:
				lua_pushliteral(L, "eof");
				break;
#ifdef _WIN32
			case ERROR_CONNECTION_ABORTED:
#endif
			case boost::asio::error::connection_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::operation_aborted:
				lua_pushliteral(L, "aborted");
				break;

			case boost::asio::error::connection_reset:
				lua_pushliteral(L, "reset");
				break;

			default:
				lua_pushstring(L, error.message().c_str());
				break;
			}

			LuaNode::GetLuaVM().call(3, LUA_MULTRET);
			m_inputBuffer.consume(m_inputBuffer.size());
		}
		else {
			LogError("SecureSocket::HandleRead with error (%p) (id:%d) - %s", this, m_socketId, error.message().c_str());
		}
	}

	/*boost::system::error_code ec;
	if(m_pending_reads == 0 && m_shutdown_pending) {
		boost::system::error_code ec;
		m_ssl_socket->async_shutdown(
			boost::bind(&Socket::HandleShutdown, this,
			reference, boost::asio::placeholders::error)
			);

		if(ec) {
			luaL_error(L, ec.message().c_str());
		}
	}*/

	if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
		boost::system::error_code ec;
		m_ssl_socket->lowest_layer().close(ec);
		if(ec) {
			LogError("Socket::HandleReadSome - Error closing socket (%p) (id=%d) - %s", this, m_socketId, ec.message().c_str());
		}
	}

	lua_settop(L, 0);
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Close(lua_State* L) {
	// Q: should I do the same when there are pending reads? probably not. One tends to have always a pending read.
	if(m_pending_writes) {
		LogDebug("SecureSocket::Close - Socket (%p) (id=%d) marked for closing", this, m_socketId);
		// can't close the socket right away, just flag it and close it when there are no more queued ops
		m_close_pending = true;
		lua_pushboolean(L, true);
		return 1;
	}
	// nothing is waiting, just close the socket right away
	LogDebug("SecureSocket::Close - Socket (%p) (id=%d) closing now", this, m_socketId);
	boost::system::error_code ec;
	m_ssl_socket->lowest_layer().close(ec);
	return BoostErrorCodeToLua(L, ec);
}

//////////////////////////////////////////////////////////////////////////
/// 
int Socket::Shutdown(lua_State* L) {
	LogDebug("SecureSocket::Shutdown (%p) (id:%d)", this, m_socketId);

	m_shutdown_pending = true;

	/*m_ssl_socket->async_shutdown(
		boost::bind(&Socket::HandleShutdown, this,
		reference, boost::asio::placeholders::error)
		);

	if(ec) {
		luaL_error(L, ec.message().c_str());
	}*/

	if(strcmp(luaL_checkstring(L, 2), "write") == 0) {
		m_shutdown_send = true;
		//m_ssl_socket->lowest_layer().shutdown(boost::asio::socket_base::shutdown_send, ec);
	}

	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Socket::HandleShutdown(int reference, const boost::system::error_code& error) {
	lua_State* L = m_L;
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	// No encontre mejor forma de hacer esto que llamar al read_handler con un error 'eof'
	if(!error) {
		LogInfo("SecureSocket::HandleShutdown (%p) (id:%d)", this, m_socketId);

		lua_getfield(L, 1, "read_callback");
		//lua_getfield(L, 1, "shutdown_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushnil(L);
			lua_pushliteral(L, "eof");
			LuaNode::GetLuaVM().call(3, LUA_MULTRET);
		}
		else {
			// do nothing?
		}
	}
	else {
		LogDebug("SecureSocket::HandleShutdown with error (%p) (id:%d) - %s", this, m_socketId, error.message().c_str());
		//lua_getfield(L, 1, "shutdown_callback");
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushnil(L);
			lua_pushliteral(L, "eof");

			LuaNode::GetLuaVM().call(3, LUA_MULTRET);
			m_inputBuffer.consume(m_inputBuffer.size());
		}
		else {
			LogError("SecureSocket::HandleShutdown with error (%p) (id:%d) - %s", this, m_socketId, error.message().c_str());
		}
	}

	lua_settop(L, 0);
}










//////////////////////////////////////////////////////////////////////////
/// 
const char* SecureContext::className = "SecureContext";
const SecureContext::RegType SecureContext::methods[] = {
	{"setKey", &SecureContext::SetKey},
	{"setCert", &SecureContext::SetCert},
	{"addCACert", &SecureContext::AddCACert},
	{0}
};

const SecureContext::RegType SecureContext::setters[] = {
	{0}
};

const SecureContext::RegType SecureContext::getters[] = {
	{0}
};

typedef boost::asio::ssl::stream<boost::asio::ip::tcp::socket> ssl_socket;

SecureContext::SecureContext(lua_State* L) : 
	m_L(L)
{
	// TODO: handle other ssl types
	m_context.reset( new boost::asio::ssl::context( GetIoService(), boost::asio::ssl::context::sslv23) );
	m_context->set_options(boost::asio::ssl::context::default_workarounds);

	//boost::system::error_code ec;
	//m_context->set_verify_mode(boost::asio::ssl::context_base::verify_peer, ec);
	
	m_ca_store = X509_STORE_new();
	SSL_CTX_set_cert_store(m_context->impl(), m_ca_store);
}


SecureContext::~SecureContext(void)
{
}

//////////////////////////////////////////////////////////////////////////
/// 
int SecureContext::SetKey(lua_State* L) {
	const char* key_pem = luaL_checkstring(L, 2);
	size_t key_pem_len = lua_objlen(L, 2);

	BIO *bp = BIO_new(BIO_s_mem());
	if (!BIO_write(bp, key_pem, key_pem_len)) {
		BIO_free(bp);
		lua_pushboolean(L, false);
		return 1;
	}

	EVP_PKEY* pkey = PEM_read_bio_PrivateKey(bp, NULL, NULL, NULL);

	if (pkey == NULL) {
		BIO_free(bp);
		lua_pushboolean(L, false);
		return 1;
	}

	SSL_CTX_use_PrivateKey( m_context->impl(), pkey);
	BIO_free(bp);
	// XXX Free pkey? 

	lua_pushboolean(L, true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int SecureContext::SetCert(lua_State* L) {
	const char* cert_pem = luaL_checkstring(L, 2);
	size_t cert_pem_len = lua_objlen(L, 2);

	BIO *bp = BIO_new(BIO_s_mem());

	if (!BIO_write(bp, cert_pem, cert_pem_len)) {
		BIO_free(bp);
		lua_pushboolean(L, false);
		return 1;
	}

	X509* x509 = PEM_read_bio_X509(bp, NULL, NULL, NULL);

	if (x509 == NULL) {
		BIO_free(bp);
		lua_pushboolean(L, false);
		return 1;
	}

	SSL_CTX_use_certificate(m_context->impl(), x509);

	BIO_free(bp);
	X509_free(x509);

	lua_pushboolean(L, true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int SecureContext::AddCACert(lua_State* L) {
	const char* cert_pem = luaL_checkstring(L, 2);
	size_t cert_pem_len = lua_objlen(L, 2);

	BIO *bp = BIO_new(BIO_s_mem());

	if (!BIO_write(bp, cert_pem, cert_pem_len)) {
		BIO_free(bp);
		lua_pushboolean(L, false);
		return 1;
	}

	X509 *x509 = PEM_read_bio_X509(bp, NULL, NULL, NULL);

	if (x509 == NULL) {
		BIO_free(bp);
		lua_pushboolean(L, false);
		return 1;
	}

	X509_STORE_add_cert(m_ca_store, x509);

	BIO_free(bp);
	X509_free(x509);

	lua_pushboolean(L, true);
	return 1;
}