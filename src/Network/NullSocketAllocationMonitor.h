#if defined (_MSC_VER) && (_MSC_VER >= 1020)
#pragma once
#endif

#ifndef JETBYTE_TOOLS_SOCKET_NULL_SOCKET_ALLOCATION_MONITOR_INCLUDED__
#define JETBYTE_TOOLS_SOCKET_NULL_SOCKET_ALLOCATION_MONITOR_INCLUDED__
///////////////////////////////////////////////////////////////////////////////
// File: NullSocketAllocationMonitor.h
///////////////////////////////////////////////////////////////////////////////
//
// Copyright 2005 JetByte Limited.
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

#include "IMonitorSocketAllocation.h"

///////////////////////////////////////////////////////////////////////////////
// Namespace: inConcert::Network
///////////////////////////////////////////////////////////////////////////////

namespace inConcert {
namespace Network {

///////////////////////////////////////////////////////////////////////////////
// CNullSocketAllocationMonitor
///////////////////////////////////////////////////////////////////////////////

/// An object that implements IMonitorSocketAllocation and does nothing.
/// \ingroup NullObj
/// \ingroup Monitoring
/// \ingroup SocketUtils

class CNullSocketAllocationMonitor : public IMonitorSocketAllocation
{
   public :

      virtual void OnSocketCreated() {}
      
      virtual void OnSocketAttached(
         inConcert::Util::IIndexedOpaqueUserData & /*userData*/) {}
      
      virtual void OnSocketReleased(
         inConcert::Util::IIndexedOpaqueUserData & /*userData*/) {}

      virtual void OnSocketDestroyed() {}
};

///////////////////////////////////////////////////////////////////////////////
// Namespace: inConcert::Network
///////////////////////////////////////////////////////////////////////////////

} // End of namespace Network
} // End of namespace inConcert 

#endif // JETBYTE_TOOLS_SOCKET_NULL_SOCKET_ALLOCATION_MONITOR_INCLUDED__

///////////////////////////////////////////////////////////////////////////////
// End of file: NullSocketAllocationMonitor.h
///////////////////////////////////////////////////////////////////////////////

