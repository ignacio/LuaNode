#pragma once

#include <boost/asio.hpp>

#include "blogger.h"

#include "Network/StreamSocketServer.h"
#include "Network/IProvideUserData.h"

class CClientConnection;
class CUser;

class CSocketServer : 
	public inConcert::Network::CStreamSocketServer
{
public:
	CSocketServer(unsigned short port, inConcert::Util::IProvideUserData& userdataProvider, long keepAliveTime, long keepAliveInterval, inConcert::Network::CSocketAllocator& allocator);
	virtual ~CSocketServer();

public:
	void Start();
	void Stop();

private:
	void OnConnectionEstablished(inConcert::Network::IStreamSocket::Ptr socket, const boost::asio::ip::address& address);

	void OnReadCompleted(inConcert::Network::IStreamSocket::Ptr socket, boost::asio::streambuf& buffer, size_t bytesTransferred);

	void OnConnectionClientClose(inConcert::Network::IStreamSocket::Ptr socket);
	void OnConnectionReset(inConcert::Network::IStreamSocket::Ptr socket);
	void OnConnectionClosed(inConcert::Network::IStreamSocket::Ptr socket);

	void OnSocketReleased(inConcert::Util::IIndexedOpaqueUserData& userData);

private:
	void SetPerConnectionData(inConcert::Util::IIndexedOpaqueUserData& userData, CClientConnection* pData) const;
	CClientConnection& GetPerConnectionData(const inConcert::Util::IIndexedOpaqueUserData& userData) const;

private:
	const inConcert::Util::IIndexedOpaqueUserData::UserDataIndex m_userDataIndex;

	long m_keepAliveTime;
	long m_keepAliveInterval;
};


