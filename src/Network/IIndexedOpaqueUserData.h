#pragma once

namespace inConcert {
namespace Util {	// nombre de mierda, cambiar

///////////////////////////////////////////////////////////////////////////////
// IIndexedOpaqueUserData
///////////////////////////////////////////////////////////////////////////////

/// Provides an interface that allows access to 'opaque user data' that is data
/// that is stored as either a void * or an unsigned long and that is basically
/// anything that the user wants to store. The data is stored by index and an 
/// implementation of this class is free to store the data in any way that it 
/// sees fit. An index represents a single storage location so a call to 
/// GetUserPointer() and GetUserData() on the same index will return the same
/// data, just viewed in different ways.

class IIndexedOpaqueUserData {
public:
	typedef unsigned short UserDataIndex;

	/// Access the data stored at the specified index as a void pointer.

	virtual void* GetUserPointer(const UserDataIndex index) const = 0;

	/// Update the data stored at the specified index as a void pointer.

	virtual void SetUserPointer(const UserDataIndex index, void* pData) = 0;

	/// Access the data stored at the specified index as an unsigned long.

	//virtual ULONG_PTR GetUserData(const UserDataIndex index) const = 0;

	/// Update the data stored at the specified index as an unsigned long.

	//virtual void SetUserData(const UserDataIndex index, const ULONG_PTR data) = 0;
};

}

}