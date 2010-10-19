#pragma once

#include "IStreamSocketServerCallback.h"
#include "SocketAllocator.h"

#include <boost/asio.hpp>
#include <boost/thread.hpp>

#include <list>

namespace inConcert {
namespace Network {

class CStreamSocketServer :
	//public IStreamSocketServerCallback
	//public CStreamSocketConnectionManager,
	//public IServerControl
	public boost::asio::io_service,
	public IStreamSocketConnectionManagerCallback
{
public:
	CStreamSocketServer(unsigned short listenPort, CSocketAllocator& allocator);
	virtual ~CStreamSocketServer(void);

public:
	void StartServer();
	void StopServer();

//private:
public:
	void StartAccept();

	// From ISocketCallback
	virtual void OnError(const std::string& message);
	// end ISocketCallback

	// From IStreamSocketConnectionManagerCallback
	virtual void OnConnectionEstablished(IStreamSocket::Ptr socket, const boost::asio::ip::address& address);
	//virtual void OnSocketReleased(void* userdata);
	virtual void OnReadCompleted(IStreamSocket::Ptr socket, boost::asio::streambuf& buffer, size_t bytesRead);
	virtual void OnReadCompletionError(IStreamSocket::Ptr socket, size_t bytesRead, const boost::system::error_code& error);
	virtual void OnWriteCompleted(IStreamSocket::Ptr socket, size_t bytesTransferred);
	virtual void OnWriteCompletionError(IStreamSocket::Ptr socket, size_t bytesTransferred, const boost::system::error_code& error);
	virtual void OnMaximumConnections();
	// end IStreamSocketConnectionManagerCallback

	// From IStreamSocketCallback
	void OnConnectionClientClose(IStreamSocket::Ptr socket);
	void OnConnectionReset(IStreamSocket::Ptr socket);
	void OnConnectionClosed(IStreamSocket::Ptr socket);
	// end IStreamSocketCallback
	
private:
	void HandleAccept(IStreamSocket::Ptr socket, const boost::system::error_code& error);
	void HandleRead(const boost::system::error_code& error, size_t bytes_transferred);
	void HandleWrite(const boost::system::error_code& error, size_t bytes_transferred);

	void Run(boost::barrier& signalWhenReady);

private:
	// Our socket acceptor
	boost::asio::ip::tcp::acceptor m_acceptor;

	//
	boost::thread m_thread;
	boost::mutex m_lock;
	volatile bool m_hasToStop;

	CSocketAllocator& m_allocator;
};

}
}