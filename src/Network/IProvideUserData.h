#pragma once

#include "IIndexedOpaqueUserData.h"

//#include "tstring.h"

namespace inConcert {
namespace Util {	// nombre de mierda, cambiar

///////////////////////////////////////////////////////////////////////////////
// IProvideUserData
///////////////////////////////////////////////////////////////////////////////

/// An interface that works with IIndexedOpaqueUserData to allow users of a 
/// class that provides \ref OpaqueUserData "opaque user data" to request a 
/// named 'slot' for their data. Generally what happens is that an allocator
/// will expose this interface and the allocated items will expose the interface
/// to access the user data. Users of the allocator can request named slots of
/// user data before allocating the first item and then all items are created
/// with the required amount of user data space.


class IProvideUserData {
public:
	/// Request a named user data slot and get an index to use in calls to 
	/// methods on IIndexedOpaqueUserData

	virtual IIndexedOpaqueUserData::UserDataIndex RequestUserDataSlot(const std::string& name) = 0;

	/// Prevent more user data slots from being allocated. Returns the number
	/// of user data slots that have been allocated.

	virtual IIndexedOpaqueUserData::UserDataIndex LockUserDataSlots() = 0;

protected :

	/// We never delete instances of this interface; you must manage the 
	/// lifetime of the class that implements it.

	~IProvideUserData() {}
};

}
}
