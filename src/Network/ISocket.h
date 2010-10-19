#pragma once

#include <boost/shared_ptr.hpp>
#include <boost/asio.hpp>
#include "shared_const_buffer.h"

#include "IIndexedOpaqueUserData.h"

/*namespace inConcert {
namespace Network {

//class ISocket {
class ISocket : 
	public boost::asio::ip::tcp::socket
{
public:
	typedef boost::shared_ptr<ISocket> Ptr;

	virtual void Read() = 0;
	virtual void Write(shared_const_buffer buffer) = 0;
};

}

}*/

namespace inConcert {
namespace Network {

class CStreamSocketServer;

class IStreamSocket : 
	public inConcert::Util::IIndexedOpaqueUserData,
	public boost::asio::ip::tcp::socket
{
public:
	typedef boost::shared_ptr<IStreamSocket> Ptr;

	virtual void ReadSome() = 0;
	virtual void ReadUntil(char delimiter) = 0;
	virtual void ReadUntil(const std::string& delimiter) = 0;
	virtual void Write(shared_const_buffer buffer) = 0;

	virtual void AbortConnectionIfManagedBy(const CStreamSocketServer& manager) = 0;	// esto quedó medio injerto acá

	virtual void SetKeepAlive(unsigned long time, unsigned long interval) = 0;

public:
	IStreamSocket(boost::asio::io_service& ioService) : boost::asio::ip::tcp::socket(ioService) {};
};

}

}