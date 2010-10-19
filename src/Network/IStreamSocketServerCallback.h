#pragma once

#include <boost/system/error_code.hpp>
#include <boost/asio/streambuf.hpp>

#include "ISocket.h"	// deberia ser IStreamSocket

namespace inConcert {

namespace Network {
	
class ISocketCallback {
public:
	virtual void OnError(const std::string& message) = 0;

protected:
	~ISocketCallback() {};
};

}

}


namespace inConcert {

	namespace Network {

		class IStreamSocketCallback : public ISocketCallback {
		public:
			virtual void OnConnectionClientClose(IStreamSocket::Ptr socket) = 0;

			virtual void OnConnectionReset(IStreamSocket::Ptr socket) = 0;

			virtual void OnConnectionClosed(IStreamSocket::Ptr socket) = 0;

		protected:
			~IStreamSocketCallback() {};
		};
	}
}


namespace inConcert {
namespace Network {
class IStreamSocketConnectionManagerCallback : public IStreamSocketCallback {
public:
	virtual void OnConnectionEstablished(IStreamSocket::Ptr socket, const boost::asio::ip::address& address) = 0;

	virtual void OnSocketReleased(inConcert::Util::IIndexedOpaqueUserData& userData) = 0;

	virtual void OnReadCompleted(IStreamSocket::Ptr socket, boost::asio::streambuf& buffer, size_t bytesRead) = 0;

	virtual void OnReadCompletionError(IStreamSocket::Ptr socket, size_t bytesRead, const boost::system::error_code& error) = 0;

	virtual void OnWriteCompleted(IStreamSocket::Ptr socket, size_t bytesTransferred) = 0;

	virtual void OnWriteCompletionError(IStreamSocket::Ptr socket, size_t bytesTransferred, const boost::system::error_code& error) = 0;

	virtual void OnMaximumConnections() = 0;
};

}
}


/*namespace inConcert {
	namespace Network {

		class IASIO
		
	}
}*/