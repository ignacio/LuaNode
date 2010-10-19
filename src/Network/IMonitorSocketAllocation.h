#if defined (_MSC_VER) && (_MSC_VER >= 1020)
#pragma once
#endif

#ifndef JETBYTE_TOOLS_SOCKET_I_MONITOR_SOCKET_ALLOCATION_INCLUDED__
#define JETBYTE_TOOLS_SOCKET_I_MONITOR_SOCKET_ALLOCATION_INCLUDED__
///////////////////////////////////////////////////////////////////////////////
// File: IMonitorSocketAllocation.h
///////////////////////////////////////////////////////////////////////////////
//
// Copyright 2004 JetByte Limited.
//
// This software is provided "as is" without a warranty of any kind. All 
// express or implied conditions, representations and warranties, including
// any implied warranty of merchantability, fitness for a particular purpose
// or non-infringement, are hereby excluded. JetByte Limited and its licensors 
// shall not be liable for any damages suffered by licensee as a result of 
// using the software. In no event will JetByte Limited be liable for any 
// lost revenue, profit or data, or for direct, indirect, special, 
// consequential, incidental or punitive damages, however caused and regardless 
// of the theory of liability, arising out of the use of or inability to use 
// software, even if JetByte Limited has been advised of the possibility of 
// such damages.
//
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// Classes defined in other files...
///////////////////////////////////////////////////////////////////////////////
namespace inConcert

{
   namespace Util
   {
      class IIndexedOpaqueUserData;
   }
}

///////////////////////////////////////////////////////////////////////////////
// Namespace: inConcert::Network
///////////////////////////////////////////////////////////////////////////////

namespace inConcert {
namespace Network {

///////////////////////////////////////////////////////////////////////////////
// IMonitorSocketAllocation
///////////////////////////////////////////////////////////////////////////////

/// An interface to allow a class to monitor the operation of a class that 
/// allocates sockets. The design of the interface assumes that sockets go 
/// through the following life-cycle: created, allocated, released, destroyed. 
/// Allocators that pool sockets can allow a socket to be created once and then 
/// allocated and released several times before being deleted. Incrementing a 
/// counter when OnSocketCreated() is called and decrementing it when 
/// OnSocketDestroyed() is called will give you a count of the number of sockets
/// that are in existence at any one time. A corresponding counter that is 
/// incremented in OnSocketAttached() and decremented in OnSocketReleased()
/// is called will give a count of the sockets that are currently in use.
/// \ingroup Interfaces
/// \ingroup Monitoring
/// \ingroup SocketAllocators
/// \ingroup ProtectedDestructors

class IMonitorSocketAllocation
{
   public :

      /// Called when a socket is created; a socket can be created only once.

      virtual void OnSocketCreated() = 0;
      
      /// Called when a socket is allocated, that is when a connection is
      /// initiated. A socket can be allocated multiple times, if, for 
      /// example, the allocator pools sockets for reuse. Before a given 
      /// socket can be allocated again it must have been released.

      virtual void OnSocketAttached(
         inConcert::Util::IIndexedOpaqueUserData &userData) = 0;

      /// Called when a socket is released, that is when a connection no 
      /// longer requires it and it returns to the allocator. A socket should 
      /// be released as many times as it is allocated.
 
      virtual void OnSocketReleased(
         inConcert::Util::IIndexedOpaqueUserData &userData) = 0;

      /// Called when a socket is destroyed; a socket can be destroyed only 
      /// once.

      virtual void OnSocketDestroyed() = 0;
     
   protected :

      /// We never delete instances of this interface; you must manage the 
      /// lifetime of the class that implements it.

      ~IMonitorSocketAllocation() {}
};

///////////////////////////////////////////////////////////////////////////////
// Namespace: inConcert::Network
///////////////////////////////////////////////////////////////////////////////

} // End of namespace Network
} // End of namespace inConcert

#endif // JETBYTE_TOOLS_SOCKET_I_MONITOR_SOCKET_ALLOCATION_INCLUDED__

///////////////////////////////////////////////////////////////////////////////
// End of file: IMonitorSocketAllocation.h
///////////////////////////////////////////////////////////////////////////////

