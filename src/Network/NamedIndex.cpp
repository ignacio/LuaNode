///////////////////////////////////////////////////////////////////////////////
// File: NamedIndex.cpp
///////////////////////////////////////////////////////////////////////////////
//
// Copyright 1997 - 2003 JetByte Limited.
//
// JetByte Limited grants you ("Licensee") a non-exclusive, royalty free, 
// licence to use, modify and redistribute this software in source and binary 
// code form, provided that i) this copyright notice and licence appear on all 
// copies of the software; and ii) Licensee does not utilize the software in a 
// manner which is disparaging to JetByte Limited.
//
// This software is provided "as is" without a warranty of any kind. All 
// express or implied conditions, representations and warranties, including
// any implied warranty of merchantability, fitness for a particular purpose
// or non-infringement, are hereby excluded. JetByte Limited and its licensors 
// shall not be liable for any damages suffered by licensee as a result of 
// using, modifying or distributing the software or its derivatives. In no
// event will JetByte Limited be liable for any lost revenue, profit or data,
// or for direct, indirect, special, consequential, incidental or punitive
// damages, however caused and regardless of the theory of liability, arising 
// out of the use of or inability to use software, even if JetByte Limited 
// has been advised of the possibility of such damages.
//
// This software is not designed or intended for use in on-line control of 
// aircraft, air traffic, aircraft navigation or aircraft communications; or in 
// the design, construction, operation or maintenance of any nuclear 
// facility. Licensee represents and warrants that it will not use or 
// redistribute the Software for such purposes. 
//
///////////////////////////////////////////////////////////////////////////////

#pragma warning(disable: 4786)   // identifier was truncated to '255' characters in the debug information
#include "NamedIndex.h"
//#include "Exception.h"
#include <stdexcept>

#include <limits>

///////////////////////////////////////////////////////////////////////////////
// Lint options
//
//lint -save
//
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// Namespace: InconcertTools::Win32
///////////////////////////////////////////////////////////////////////////////

namespace inConcert {
namespace Util {

///////////////////////////////////////////////////////////////////////////////
// CNamedIndex
///////////////////////////////////////////////////////////////////////////////

CNamedIndex::CNamedIndex()
   : m_locked(false)
{
}

CNamedIndex::Index CNamedIndex::Add(const std::string& name)
{
   if (m_locked)
   {
	   std::string message = "CNamedIndex::Add() - Can not add new named index. Indices are locked";
	   throw std::runtime_error(message);
   }

   for (size_t i = 0 ; i < m_names.size(); ++i)
   {
      if (m_names[i] == name)
      {
		  std::string message = "CNamedIndex::Add() - Named index " + name + " already exists";
		  throw std::runtime_error(message);
      }
   }
	const size_t size = m_names.size();

	if (size > std::numeric_limits<Index>::max())
	{
		std::string message = "CNamedIndex::Add() - Too many named indices...";
		throw std::runtime_error(message);
	}

	m_names.push_back(name);

	return static_cast<Index>(size);
}

CNamedIndex::Index CNamedIndex::Find(const std::string& name) const
{
   for (size_t i = 0 ; i < m_names.size(); ++i)
   {
      if (m_names[i] == name)
      {
         return i;
      }
   }
   std::string message = "CNamedIndex::Find() - Named index " + name + " does not exist";
   throw std::runtime_error(message);
}

CNamedIndex::Index CNamedIndex::FindOrAdd(const std::string& name)
{
   if (m_locked)
   {
	   std::string message = "CNamedIndex::Add() - Can not add new named index. Indices are locked";
	   throw std::runtime_error(message);
   }

   for (size_t i = 0 ; i < m_names.size(); ++i)
   {
      if (m_names[i] == name)
      {
         return i;
      }
   }

   const size_t size = m_names.size();

   if (size > std::numeric_limits<Index>::max())
   {
	   std::string message = "CNamedIndex::Add() - Too many named indices...";
	   throw std::runtime_error(message);
   }

   m_names.push_back(name);

   return static_cast<Index>(size);
}

CNamedIndex::Index CNamedIndex::GetMaxIndexValue() const
{
   return static_cast<Index>(m_names.size());
}

CNamedIndex::Index CNamedIndex::Lock()
{
   m_locked = true;

   return static_cast<Index>(m_names.size());
}

bool CNamedIndex::Locked() const
{
	return m_locked;
}

///////////////////////////////////////////////////////////////////////////////
// Namespace: InconcertTools::Win32
///////////////////////////////////////////////////////////////////////////////

} // End of namespace Win32
} // End of namespace InconcertTools 

///////////////////////////////////////////////////////////////////////////////
// Lint options
//
//lint -restore
//
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// End of file: NamedIndex.cpp
///////////////////////////////////////////////////////////////////////////////
