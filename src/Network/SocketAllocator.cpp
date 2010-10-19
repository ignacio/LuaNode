#include "SocketAllocator.h"
#include "NullSocketAllocationMonitor.h"
#include "Socket.h"

using namespace inConcert::Network;

static CNullSocketAllocationMonitor s_nullAllocationMonitor;

CSocketAllocator::CSocketAllocator(const SocketCount maxFreeSockets)
	:	m_maxFreeSockets(maxFreeSockets),
		m_monitor(s_nullAllocationMonitor)
{
}

CSocketAllocator::CSocketAllocator(
	IMonitorSocketAllocation& monitor,
	/*const JetByteTools::Win32::ICriticalSectionFactory *pLockFactory,*/
 	const SocketCount maxFreeSockets/*,
 	const DWORD spinCount*/)
	:	m_monitor(monitor),
		m_maxFreeSockets(maxFreeSockets)
{
}

CSocketAllocator::~CSocketAllocator(void)
{
}

CSocketAllocator::SocketCount CSocketAllocator::EnlargePool(SocketCount socketsToAdd, boost::asio::io_service& ioService, IStreamSocketConnectionManagerCallback& callback)
{
	boost::recursive_mutex::scoped_lock lock(m_connectionsLock);

	for (SocketCount i = 0; i < socketsToAdd; ++i) {
		IStreamSocket::Ptr socket = CreateSocket(ioService, callback);

		m_freeSockets[socket] = socket;
	}

	return static_cast<SocketCount>(m_freeSockets.size());
}

inConcert::Util::IIndexedOpaqueUserData::UserDataIndex CSocketAllocator::RequestUserDataSlot(
	const std::string& name)
{
	if (m_namedUserDataSlots.Locked())
	{
		throw std::runtime_error("CSocketAllocator::RequestUserDataSlot() - Too late, a socket has already been allocated");
	}

	return m_namedUserDataSlots.FindOrAdd(name);
}

inConcert::Util::IIndexedOpaqueUserData::UserDataIndex CSocketAllocator::LockUserDataSlots()
{
	return m_namedUserDataSlots.Lock();
}

//////////////////////////////////////////////////////////////////////////
/// 
IStreamSocket::Ptr CSocketAllocator::AllocateSocket(boost::asio::io_service& ioService, IStreamSocketConnectionManagerCallback& callbacks) {
	boost::recursive_mutex::scoped_lock lock(m_connectionsLock);

	IStreamSocket::Ptr pSocket;

	if(!m_freeSockets.empty()) {
		SocketMap::iterator it = m_freeSockets.begin();
		pSocket = it->second;
		m_freeSockets.erase(it);
		pSocket->close();
	}
	else {
		pSocket = CreateSocket(ioService, callbacks);
	}

	m_activeSockets[pSocket] = pSocket;

	m_monitor.OnSocketAttached(*pSocket);
	return pSocket;
}

//////////////////////////////////////////////////////////////////////////
/// 
IStreamSocket::Ptr CSocketAllocator::CreateSocket(boost::asio::io_service& ioService, IStreamSocketConnectionManagerCallback& callbacks) {
	const inConcert::Util::IIndexedOpaqueUserData::UserDataIndex numberOfUserDataSlots = m_namedUserDataSlots.Lock();

	/*if (m_pLockFactory)
	{
		void *key = reinterpret_cast<void *>(::InterlockedIncrement(&m_key));

		IPoolableSocket &socket = CreateSocket(
			numberOfUserDataSlots, 
			m_pLockFactory->GetCriticalSection(key));

		m_monitor.OnSocketCreated();

		return socket;
	}
	else
	{*/
		//IPoolableSocket &socket = CreateSocket(numberOfUserDataSlots, m_spinCount);
		IStreamSocket::Ptr socket = CStreamSocket::Create(numberOfUserDataSlots, ioService, callbacks, *this);

		m_monitor.OnSocketCreated();

		return socket;
	/*}*/
}

//////////////////////////////////////////////////////////////////////////
/// 
void CSocketAllocator::ReleaseSocket(IStreamSocket::Ptr socket) {
	boost::recursive_mutex::scoped_lock lock(m_connectionsLock);

	m_monitor.OnSocketReleased(*socket);

	m_activeSockets.erase(socket);

	if (m_maxFreeSockets == 0 || m_freeSockets.size() < m_maxFreeSockets) {
		m_freeSockets[socket] = socket;
	}
	else {
		m_monitor.OnSocketDestroyed();
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
void CSocketAllocator::ReleaseSockets() {
	boost::recursive_mutex::scoped_lock lock(m_connectionsLock);

	while (m_activeSockets.size()) {
		IStreamSocket::Ptr socket = m_activeSockets.begin()->second;

		ReleaseSocket(socket);
	}

	m_freeSockets.clear();
}

//////////////////////////////////////////////////////////////////////////
/// 
void CSocketAllocator::AbortMyConnections(const CStreamSocketServer& manager) {
	boost::recursive_mutex::scoped_lock lock(m_connectionsLock);

	for(SocketMap::const_iterator iter = m_activeSockets.begin(), end = m_activeSockets.end(); iter != end; ++iter)
	{
		iter->second->AbortConnectionIfManagedBy(manager);
		//iter->second->close();
	}
}