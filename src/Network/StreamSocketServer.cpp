#include "StreamSocketServer.h"
#include "Socket.h"
#include <boost/bind.hpp>
#include "../blogger.h"

using namespace inConcert::Network;

CStreamSocketServer::CStreamSocketServer(unsigned short listenPort, CSocketAllocator& allocator) :
	m_acceptor(*this, boost::asio::ip::tcp::endpoint(boost::asio::ip::tcp::v4(), listenPort)),
	m_hasToStop(false),
	m_allocator(allocator)
{
}

CStreamSocketServer::~CStreamSocketServer(void)
{

}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::StartServer() {
	StartAccept();

	boost::barrier barrier(2);
	m_thread = boost::thread( &CStreamSocketServer::Run, this, boost::ref(barrier) );
	// esperar a que el thread esté pronto
	barrier.wait();
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::StopServer() {
	m_acceptor.cancel();

	m_allocator.AbortMyConnections(*this);
	m_thread.join();
	m_allocator.ReleaseSockets();
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::Run(boost::barrier& signalWhenReady) {
	// Aviso que estoy pronto
	signalWhenReady.wait();

	run();
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::StartAccept() {
	IStreamSocket::Ptr pSocket = m_allocator.AllocateSocket(*this, *this);

	m_acceptor.async_accept(
		*pSocket,
		boost::bind(&CStreamSocketServer::HandleAccept, this, pSocket, boost::asio::placeholders::error)
	);
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::HandleAccept(IStreamSocket::Ptr socket, const boost::system::error_code& error) {
	LogDebug("CStreamSocketServer::HandleAccept (%p)", socket.get());
	if(!error) {
		// Get ready for another connection
		StartAccept();
		boost::asio::ip::address address = socket->remote_endpoint().address();
		OnConnectionEstablished(socket, address);
	}
	else {
		if(error != boost::asio::error::operation_aborted) {
			LogError("CStreamSocketServer::HandleAccept (%p) - %s", socket.get(), error.message().c_str());
		}
		m_allocator.ReleaseSocket(socket);
		// we don't call OnSocketReleased, because a connection had not been established
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::OnConnectionEstablished(IStreamSocket::Ptr socket, const boost::asio::ip::address& address) {
	LogError("CStreamSocketServer::OnConnectionEstablished (%p) - %s", socket.get(), address.to_string().c_str());
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::OnReadCompleted(IStreamSocket::Ptr socket, boost::asio::streambuf& buffer, size_t bytesTransferred) {
	LogInfo("CStreamSocketServer::OnReadCompleted (%p) - Buffer size (%d) - Bytes Transferred (%d)", socket.get(), buffer.size(), bytesTransferred);
}


//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::OnReadCompletionError(IStreamSocket::Ptr socket, size_t bytesRead, const boost::system::error_code& error) {
	LogError("CStreamSocketServer::OnReadCompletionError (%p) - %s", socket.get(), error.message().c_str());
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::OnWriteCompleted(IStreamSocket::Ptr socket, size_t bytesTransferred) {
	LogInfo("CStreamSocketServer::OnWriteCompleted (%p) - Bytes Transferred (%d)", socket.get(), bytesTransferred);
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::OnWriteCompletionError(IStreamSocket::Ptr socket, size_t bytesTransferred, const boost::system::error_code& error) {
	LogError("CStreamSocketServer::OnWriteCompletionError (%p) - %s", socket.get(), error.message().c_str());
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::OnMaximumConnections() {

}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::OnError(const std::string& message) {
	LogInfo("CStreamSocketServer::OnError - %s", message.c_str());
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::OnConnectionClientClose(IStreamSocket::Ptr socket)
{
	LogInfo("CStreamSocketServer::OnConnectionClientClose (%p)", socket.get());
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::OnConnectionReset(IStreamSocket::Ptr socket)
{
	LogInfo("CStreamSocketServer::OnConnectionReset (%p)", socket.get());
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocketServer::OnConnectionClosed(IStreamSocket::Ptr socket)
{
	LogInfo("CStreamSocketServer::OnConnectionClosed (%p)", socket.get());
}
