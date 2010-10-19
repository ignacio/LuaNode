#if defined (_MSC_VER) && (_MSC_VER >= 1020)
#pragma once
#endif

#ifndef JETBYTE_TOOLS_NAMED_INDEX_INCLUDED__
#define JETBYTE_TOOLS_NAMED_INDEX_INCLUDED__
///////////////////////////////////////////////////////////////////////////////
// File NamedIndex.h
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

///////////////////////////////////////////////////////////////////////////////
// Lint options
//
//lint -save
//
///////////////////////////////////////////////////////////////////////////////

#include <vector>

#include <string>

///////////////////////////////////////////////////////////////////////////////
// Namespace: InconcertTools::Util
///////////////////////////////////////////////////////////////////////////////

namespace inConcert {
namespace Util {

///////////////////////////////////////////////////////////////////////////////
// CNamedIndex
///////////////////////////////////////////////////////////////////////////////

class CNamedIndex
{
   public:

	   typedef unsigned short Index;

	   // Construct an empty collection

		CNamedIndex();

		/// Allocates a new index called name and returns the value. Throws an
		/// exception if the name already exists or if the collection has already
		/// had Lock() called on it.
		Index Add(const std::string& name);

		/// Finds an index called name and returns the value. Throws an exception 
		/// if the name does not exist.
		Index Find(const std::string&name) const;

		/// First attempts to Find() an index by name and if the name doesn't 
		/// already exist then creates a new index called name and returns the 
		/// value. Throws an exception if the collection has already had Lock() 
		/// called on it.
		Index FindOrAdd(const std::string& name);

		/// Returns the number of indices allocated.
		Index GetMaxIndexValue() const;

		/// Locks the collection against further additions and returns the 
		/// number of indices allocated.
		Index Lock();

		/// Returns true if the collection is locked.
		bool Locked() const;

	private:

		typedef std::vector<std::string> Names;

		Names m_names;

		bool m_locked;

		// No copies do not implement
		CNamedIndex(const CNamedIndex &rhs);
		CNamedIndex &operator=(const CNamedIndex &rhs);
};

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

#endif // JETBYTE_TOOLS_NAMED_INDEX_INCLUDED__

///////////////////////////////////////////////////////////////////////////////
// End of file NamedIndex.h
///////////////////////////////////////////////////////////////////////////////

