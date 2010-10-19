#pragma once

#include "NamedIndex.h"
#include "IProvideUserData.h"
#include "ISocket.h"

#include <boost/thread/recursive_mutex.hpp>

namespace inConcert
{
	namespace Network
	{
		class IStreamSocketConnectionManagerCallback;
		class IMonitorSocketAllocation;
		class CStreamSocketServer;
	}
}

namespace inConcert {

namespace Network {


class CSocketAllocator : 
	public inConcert::Util::IProvideUserData
{
public:
	typedef unsigned short SocketCount;

public:
	/// Create an allocator which uses the optional lockFactory, if supplied,
	/// to create ICriticalSection instances for its sockets and maintains a 
	/// pool of maxFreeSockets. If the lock factory is not supplied then
	/// sockets with unique critical sections will be created and the spin
	/// count supplied will be used to initialise them.

	CSocketAllocator(/*lock factory*/ const SocketCount maxFreeSockets/*, const DWORD spinCount*/);

	/// Create an allocator which can be monitored via the supplied 
	/// IMonitorSocketAllocation instance and that uses the optional 
	/// lockFactory, if supplied, to create ICriticalSection instances for 
	/// its sockets and maintains a pool of maxFreeSockets. If the lock factory 
	/// is not supplied then sockets with unique critical sections will be 
	/// created and the spin count supplied will be used to initialise them.

	CSocketAllocator(
		IMonitorSocketAllocation& monitor,
		/*const JetByteTools::Win32::ICriticalSectionFactory *pLockFactory,*/
 		const SocketCount maxFreeSockets/*,
 		const DWORD spinCount*/);

	/// Create socketsToAdd sockets and add them to the pool. Returns the
	/// number of sockets now in the pool.

	SocketCount EnlargePool(const SocketCount socketsToAdd, boost::asio::io_service& ioService, IStreamSocketConnectionManagerCallback& callback);

	~CSocketAllocator();


	IStreamSocket::Ptr AllocateSocket(boost::asio::io_service& ioService, IStreamSocketConnectionManagerCallback& callback);
	void ReleaseSocket(IStreamSocket::Ptr socket);

	void AbortMyConnections(const CStreamSocketServer& manager);	// Deberia ser IStreamSocketConnectionManager

	void ReleaseSockets();

	/// Implement IProvideUserData
	virtual inConcert::Util::IIndexedOpaqueUserData::UserDataIndex RequestUserDataSlot(const std::string& name);

	virtual inConcert::Util::IIndexedOpaqueUserData::UserDataIndex LockUserDataSlots();

private:
	IStreamSocket::Ptr CreateSocket(boost::asio::io_service& ioService, IStreamSocketConnectionManagerCallback& callback);

	// Override in derived class to create your socket

	/*virtual IStreamSocket::Ptr CreateSocket(
		const JetByteTools::Win32::IIndexedOpaqueUserData::UserDataIndex numberOfUserDataSlots,
			JetByteTools::Win32::ISharedCriticalSection &criticalSection) = 0;*/

	/*virtual IStreamSocket::Ptr CreateSocket(
		const inConcert::Util::IIndexedOpaqueUserData::UserDataIndex numberOfUserDataSlots,
		const DWORD spinCount) = 0;*/

private:
	inConcert::Util::CNamedIndex m_namedUserDataSlots;

	typedef std::map<IStreamSocket::Ptr, IStreamSocket::Ptr> SocketMap;
	SocketMap m_activeSockets;
	SocketMap m_freeSockets;

	IMonitorSocketAllocation& m_monitor;
	
	const SocketCount m_maxFreeSockets;

	boost::recursive_mutex m_connectionsLock;
};

}

}