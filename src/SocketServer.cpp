#include "stdafx.h"
#include "SocketServer.h"
#include <boost/format.hpp>
#include "ClientConnection.h"




CSocketServer::CSocketServer(unsigned short port, 
							 inConcert::Util::IProvideUserData& userdataProvider, 
							 long keepAliveTime, long keepAliveInterval,
							 inConcert::Network::CSocketAllocator& allocator) : 
	CStreamSocketServer(port, allocator),
	m_userDataIndex(userdataProvider.RequestUserDataSlot("CSocketServer - m_userDataIndex")),
	m_keepAliveTime(keepAliveTime),
	m_keepAliveInterval(keepAliveInterval)
{

}

CSocketServer::~CSocketServer() {

}

//////////////////////////////////////////////////////////////////////////
/// 
void CSocketServer::Start() {
	LogInfo("CSocketServer::Start");
	StartServer();
}

//////////////////////////////////////////////////////////////////////////
/// 
void CSocketServer::Stop() {
	LogInfo("CSocketServer::StopServer");
	StopServer();
}

//////////////////////////////////////////////////////////////////////////
/// 
void CSocketServer::OnConnectionEstablished(inConcert::Network::IStreamSocket::Ptr socket, const boost::asio::ip::address& address) {
	LogDebug("CSocketServer::OnConnectionEstablished (%p)", socket.get());

	// A new client has connected. Create a new Client object, bind the socket to it and start reading commands
	CClientConnection* pClient = new CClientConnection(socket, address.to_string().c_str());
	
	socket->SetKeepAlive(m_keepAliveTime, m_keepAliveInterval);

	SetPerConnectionData(*socket, pClient);

	socket->ReadSome();
	//socket->ReadUntil("\r\n");
}

//////////////////////////////////////////////////////////////////////////
/// 
void CSocketServer::OnReadCompleted(inConcert::Network::IStreamSocket::Ptr socket, boost::asio::streambuf& buffer, size_t bytesTransferred) {
	LogDebug("CSocketServer::OnReadCompleted (%p) - Buffer size (%d) - Bytes Transferred (%d)", socket.get(), buffer.size(), bytesTransferred);

	std::istream inputStream(&buffer);
	std::string line;

	std::getline(inputStream, line);

	CClientConnection& client = GetPerConnectionData(*socket);
	client.ProcessCommand(line);

	LogInfo("CSocketServer::OnReadCompleted - Got data (%s)", line.c_str());

	socket->ReadUntil("\n\r");
}

//////////////////////////////////////////////////////////////////////////
/// 
void CSocketServer::OnConnectionClientClose(inConcert::Network::IStreamSocket::Ptr socket) {
	LogDebug("CSocketServer::OnConnectionClientClose (%p)", socket.get());
}

//////////////////////////////////////////////////////////////////////////
/// 
void CSocketServer::OnConnectionReset(inConcert::Network::IStreamSocket::Ptr socket) {
	LogDebug("CSocketServer::OnConnectionReset (%p)", socket.get());
	CClientConnection& client = GetPerConnectionData(*socket);
	client.Detach();
}

//////////////////////////////////////////////////////////////////////////
/// 
void CSocketServer::OnConnectionClosed(inConcert::Network::IStreamSocket::Ptr socket) {
	LogDebug("CSocketServer::OnConnectionClosed (%p)", socket.get());
	CClientConnection& client = GetPerConnectionData(*socket);
	client.Detach();
}

//////////////////////////////////////////////////////////////////////////
/// 
void CSocketServer::OnSocketReleased(inConcert::Util::IIndexedOpaqueUserData& userData) {
	LogInfo("CSocketServer::OnSocketReleased (%p)", &userData);
	
	CClientConnection& client = GetPerConnectionData(userData);
	SetPerConnectionData(userData, 0);
	delete &client;
}



//////////////////////////////////////////////////////////////////////////
/// 
void CSocketServer::SetPerConnectionData(inConcert::Util::IIndexedOpaqueUserData& userData, CClientConnection* pData) const {
	userData.SetUserPointer(m_userDataIndex, pData);
}

//////////////////////////////////////////////////////////////////////////
/// 
CClientConnection& CSocketServer::GetPerConnectionData(const inConcert::Util::IIndexedOpaqueUserData& userData) const {
	return *reinterpret_cast<CClientConnection*>(userData.GetUserPointer(m_userDataIndex));
}