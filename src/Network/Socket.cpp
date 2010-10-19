// this is needed for tcp_keepalive definition
#ifdef _WIN32
#include <winsock2.h>
#endif

#ifdef _WIN32
  #if defined(_MSC_VER)
    #include "MSTCPiP.h"
  #elif defined(__MINGW32__)
// afanado de mstcpip.h
/* Argument structure for SIO_KEEPALIVE_VALS */

struct tcp_keepalive {
    u_long  onoff;
    u_long  keepalivetime;
    u_long  keepaliveinterval;
};

// New WSAIoctl Options

#define SIO_RCVALL            _WSAIOW(IOC_VENDOR,1)
#define SIO_RCVALL_MCAST      _WSAIOW(IOC_VENDOR,2)
#define SIO_RCVALL_IGMPMCAST  _WSAIOW(IOC_VENDOR,3)
#define SIO_KEEPALIVE_VALS    _WSAIOW(IOC_VENDOR,4)
#define SIO_ABSORB_RTRALERT   _WSAIOW(IOC_VENDOR,5)
#define SIO_UCAST_IF          _WSAIOW(IOC_VENDOR,6)
#define SIO_LIMIT_BROADCASTS  _WSAIOW(IOC_VENDOR,7)
#define SIO_INDEX_BIND        _WSAIOW(IOC_VENDOR,8)
#define SIO_INDEX_MCASTIF     _WSAIOW(IOC_VENDOR,9)
#define SIO_INDEX_ADD_MCAST   _WSAIOW(IOC_VENDOR,10)
#define SIO_INDEX_DEL_MCAST   _WSAIOW(IOC_VENDOR,11)

// Values for use with SIO_RCVALL* options
#define RCVALL_OFF             0
#define RCVALL_ON              1
#define RCVALL_SOCKETLEVELONLY 2

  #else
    #error Unknown compiler.
  #endif
#elif defined(__GNUC__)
#include <sys/socket.h>
#include <arpa/inet.h>
#endif

#include "Socket.h"
#include <boost/bind.hpp>
#include <boost/format.hpp>
#include "../blogger.h"

using namespace inConcert::Network;

/*static*/ CStreamSocket::Ptr CStreamSocket::Create(inConcert::Util::IIndexedOpaqueUserData::UserDataIndex numUserDataSlots, 
													boost::asio::io_service& ioService, 
													IStreamSocketConnectionManagerCallback& callbacks,
													CSocketAllocator& allocator)
{
	return Ptr(new CStreamSocket(numUserDataSlots, ioService, callbacks, allocator));
}

CStreamSocket::CStreamSocket(inConcert::Util::IIndexedOpaqueUserData::UserDataIndex numUserDataSlots, 
							 boost::asio::io_service& ioService,
							 IStreamSocketConnectionManagerCallback& callbacks,
							 CSocketAllocator& allocator
							 )
:	inConcert::Network::IStreamSocket(ioService), 
		m_callback(callbacks),
		m_userData(numUserDataSlots),
		m_allocator(allocator),
		m_pendingOperations(0)
{
	LogInfo("CStreamSocket::CStreamSocket - Constructed socket (%p)", this);
}

CStreamSocket::~CStreamSocket(void)
{
	LogInfo("CStreamSocket::~CStreamSocket - Destructed socket (%p)", this);
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocket::Write(shared_const_buffer buffer) {
	//int a = boost::bind(&CSocket::handle_write, shared_from_this(), boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred);
	/*boost::_bi::bind_t<void, boost::_mfi::mf2<void,CSocket,const boost::system::error_code &,size_t>, boost::_bi::list3<boost::_bi::value<boost::shared_ptr<CSocket> >,boost::arg<1>,boost::arg<2> > > a =
		boost::bind(&CSocket::handle_write, shared_from_this(), boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred);*/
	//boost::asio::async_write(m_socket, buffer,

	boost::mutex::scoped_lock lock( m_mutex );
	m_pendingOperations++;
	boost::asio::async_write(*this, buffer,
		boost::bind(&CStreamSocket::HandleWrite, shared_from_this(), boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
	);

	//boost::function< void(IStreamSocketServerCallback*, CSocket&, shared_const_buffer& buffer) > f = &IStreamSocketServerCallback::OnWriteCompleted;
	//f(&m_callback, *this, buffer);
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocket::HandleWrite(const boost::system::error_code& error, size_t bytes_transferred) {
	if(!error) {
		m_callback.OnWriteCompleted(shared_from_this(), bytes_transferred);
	}
	else {
		m_callback.OnWriteCompletionError(shared_from_this(), bytes_transferred, error);
	}

	boost::mutex::scoped_lock lock( m_mutex );
	if(--m_pendingOperations == 0) {
		m_allocator.ReleaseSocket( shared_from_this() );
		m_callback.OnSocketReleased(*this);
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocket::ReadSome() {
	boost::mutex::scoped_lock lock(m_mutex);

	m_pendingOperations++;

	boost::asio::async_read(*this, m_inputBuffer, 
		boost::bind(&CStreamSocket::HandleRead, shared_from_this(), boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
	);
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocket::ReadUntil(char delimiter) {
	/*m_socket.async_read_some(boost::asio::buffer(m_readBuffer), 
		boost::bind(&CStreamSocket::HandleRead, shared_from_this(), boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
	);*/

	/*boost::asio::async_read(m_socket, boost::asio::buffer(m_readBuffer), 
		boost::bind(&CStreamSocket::HandleRead, shared_from_this(), boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
	);*/

	//boost::asio::streambuf buffer;

	//boost::asio::streambuf::mutable_buffers_type buffers = buffer.prepare(512);
	//char delimiter = '\n';
	//boost::asio::async_read_until(m_socket, m_inputBuffer, delimiter, 

	boost::mutex::scoped_lock lock( m_mutex );

	m_pendingOperations++;
	
	boost::asio::async_read_until(*this, m_inputBuffer, delimiter, 
		boost::bind(&CStreamSocket::HandleRead, shared_from_this(), boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
	);
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocket::ReadUntil(const std::string& delimiter) {
	boost::mutex::scoped_lock lock( m_mutex );

	m_pendingOperations++;
	boost::asio::async_read_until(*this, m_inputBuffer, delimiter,
		boost::bind(&CStreamSocket::HandleRead, shared_from_this(), boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		//boost::bind(&IStreamSocketConnectionManagerCallback::HandleRead, shared_from_this(), boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
	);
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocket::HandleRead(const boost::system::error_code& error, size_t bytes_read) {
	if(!error) {
		m_callback.OnReadCompleted(shared_from_this(), m_inputBuffer, bytes_read);
	}
	else {
		//std::string s = error.message();
		switch(error.value()) {
			case boost::asio::error::eof:
				m_callback.OnConnectionClosed(shared_from_this());
			break;

#ifdef _WIN32
			case ERROR_CONNECTION_ABORTED:
#endif
			case boost::asio::error::connection_aborted:
				m_callback.OnConnectionClosed(shared_from_this());
			break;

			case boost::asio::error::operation_aborted:
				m_callback.OnConnectionClosed(shared_from_this());
			break;

			case boost::asio::error::connection_reset:
				m_callback.OnConnectionReset(shared_from_this());
			break;

			default:
				m_callback.OnReadCompletionError(shared_from_this(), bytes_read, error);
			break;
		}
	}

	boost::mutex::scoped_lock lock( m_mutex );
	if(--m_pendingOperations == 0) {
		m_allocator.ReleaseSocket( shared_from_this() );
		m_callback.OnSocketReleased(*this);
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
void* CStreamSocket::GetUserPointer(const UserDataIndex index) const
{
	return m_userData.GetUserPointer(index);
}

//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocket::SetUserPointer(const UserDataIndex index, void* pData)
{
	return m_userData.SetUserPointer(index, pData);
}


//////////////////////////////////////////////////////////////////////////
/// 
void CStreamSocket::AbortConnectionIfManagedBy(const CStreamSocketServer& manager) {
	// por ahora no doy bola, no tengo la interface necesaria
	//if(manager == m_manager) {
		// por ahora 
	//}
	//AbortConnection();
	if (is_open())
	{
		// Force a non lingering close.
		boost::system::error_code ec;
		boost::asio::socket_base::linger option(false, 0);
		set_option(option, ec);
		std::string s = ec.message();

		/*LINGER lingerStruct;

		lingerStruct.l_onoff = 1;
		lingerStruct.l_linger = 0;*/

		/*if (SOCKET_ERROR == ::setsockopt(m_socket, SOL_SOCKET, SO_LINGER, (char *)&lingerStruct, sizeof(lingerStruct)))
		{
			m_pCallback->OnError(_T("CStreamSocket::AbortConnection() - setsockopt(SO_LINGER) - ")  + GetLastErrorMessage(::WSAGetLastError()));
		}*/

		close();

		//if (CloseSocket())
		//{
			// Route this via the manager so that it is dispatched and passed to the client
			// without a lock being held.

			//m_callback.OnConnectionClosed( shared_from_this() );
			//m_pManager->OnConnectionClosed(*this);
		//}
	}
}

//////////////////////////////////////////////////////////////////////////
/// time = Keep Alive in n sec., 
/// interval = Resend if No-Reply
void CStreamSocket::SetKeepAlive(unsigned long time, unsigned long interval) {
	boost::asio::socket_base::keep_alive option(true);
	
	set_option(option);

#ifdef _WIN32
	DWORD dwBytes = 0;
	tcp_keepalive kaSettings = {0}, sReturned = {0};
	kaSettings.onoff = 1;
	kaSettings.keepalivetime = time; 
	kaSettings.keepaliveinterval = interval;
	if (::WSAIoctl(native(), SIO_KEEPALIVE_VALS, &kaSettings, sizeof(kaSettings), &sReturned, sizeof(sReturned), &dwBytes, NULL, NULL) != 0)
	{
		std::string message = str(boost::format("CStreamSocket::SetKeepAlive (%p) - Failed to set keepalive on win32 native socket - %d") % this % WSAGetLastError() );
		throw std::runtime_error(message);
	}
#endif
}