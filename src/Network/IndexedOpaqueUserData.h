#if defined (_MSC_VER) && (_MSC_VER >= 1020)
#pragma once
#endif

#ifndef JETBYTE_TOOLS_INDEXED_OPAQUE_USER_DATA_INCLUDED__
#define JETBYTE_TOOLS_INDEXED_OPAQUE_USER_DATA_INCLUDED__
///////////////////////////////////////////////////////////////////////////////
// File: IndexedOpaqueUserData.h
///////////////////////////////////////////////////////////////////////////////
//
// Copyright 2002 JetByte Limited.
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

#include "IIndexedOpaqueUserData.h"

#include <vector>

///////////////////////////////////////////////////////////////////////////////
// Namespace: inConcert::Util
///////////////////////////////////////////////////////////////////////////////

namespace inConcert {
namespace Util {

///////////////////////////////////////////////////////////////////////////////
// CIndexedOpaqueUserData
///////////////////////////////////////////////////////////////////////////////

/// Implements IIndexedOpaqueUserData in terms of a std::vector of void *.
/// \ingroup OpaqueUserData

class CIndexedOpaqueUserData : public IIndexedOpaqueUserData
{
   public:

      /// Create some indexed opaque user data of the specified size

      explicit inline CIndexedOpaqueUserData(const UserDataIndex numberOfSlots)
      {
         m_userData.resize(numberOfSlots);

         ClearUserData();
      }

      // Implement IIndexedOpaqueUserData

      virtual inline void* GetUserPointer(
         const UserDataIndex index) const
      {
         return m_userData[index];
      }
       
      virtual inline void SetUserPointer(
         const UserDataIndex index,
         void *pData)
      {
         m_userData[index] = pData;
      }

      /// Sets the values stored in all indices to 0.
      inline void ClearUserData()
      {
         for (size_t i = 0; i < m_userData.size(); ++i)
         {
            m_userData[i] = 0;
         }
      }

   private :

      typedef std::vector<void*> IndexedUserData;

      IndexedUserData m_userData;

      /// No copies do not implement
      CIndexedOpaqueUserData(const CIndexedOpaqueUserData &rhs);
      /// No copies do not implement
      CIndexedOpaqueUserData &operator=(const CIndexedOpaqueUserData &rhs);
};

///////////////////////////////////////////////////////////////////////////////
// Namespace: inConcert::Util
///////////////////////////////////////////////////////////////////////////////

} // End of namespace Util
} // End of namespace inConcert 

#endif // JETBYTE_TOOLS_INDEXED_OPAQUE_USER_DATA_INCLUDED__

///////////////////////////////////////////////////////////////////////////////
// End of File: IndexedOpaqueUserData.h
///////////////////////////////////////////////////////////////////////////////

