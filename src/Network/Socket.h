#if defined (_MSC_VER) && (_MSC_VER >= 1020)
#pragma once
#endif

#include "ISocket.h"
#include "IStreamSocketServerCallback.h"
#include "IndexedOpaqueUserData.h"
#include "SocketAllocator.h"

#include <boost/asio.hpp>
#include <boost/thread/mutex.hpp>

namespace inConcert {
namespace Network {

class CStreamSocketServer;

class CStreamSocket :
	public IStreamSocket,
	public boost::enable_shared_from_this<CStreamSocket>
{
public:
	typedef boost::shared_ptr<CStreamSocket> Ptr;
	
	virtual ~CStreamSocket(void);

	static Ptr Create(inConcert::Util::IIndexedOpaqueUserData::UserDataIndex numUserDataSlots, boost::asio::io_service& ioService, IStreamSocketConnectionManagerCallback& socketServer, CSocketAllocator& allocator);

	// Implement IStreamSocket
	void ReadSome();
	void ReadUntil(char delimiter);
	void ReadUntil(const std::string& delimiter);
	void Write(shared_const_buffer buffer);

	// Implement IIndexedOpaqueUserData
	virtual void* GetUserPointer(const UserDataIndex index) const;
	virtual void SetUserPointer(const UserDataIndex index, void* pData);

	// este vendría de IPoolableSocket
	void AbortConnectionIfManagedBy(const CStreamSocketServer& manager);

	virtual void SetKeepAlive(unsigned long time, unsigned long interval);

private:
//public:
	CStreamSocket(inConcert::Util::IIndexedOpaqueUserData::UserDataIndex numUserDataSlots, boost::asio::io_service& ioService, IStreamSocketConnectionManagerCallback& server, CSocketAllocator& allocator);
	

	void HandleRead(const boost::system::error_code& error, size_t bytes_transferred);
	void HandleWrite(const boost::system::error_code& error, size_t bytes_transferred);

private:
	CSocketAllocator& m_allocator;
	IStreamSocketConnectionManagerCallback& m_callback;
	//boost::array<unsigned char, 8192> m_readBuffer;

	boost::asio::streambuf m_inputBuffer;

	boost::mutex m_mutex;
	long m_pendingOperations;
	//unsigned int m_pendingWrites;
	inConcert::Util::CIndexedOpaqueUserData m_userData;
};

}
}