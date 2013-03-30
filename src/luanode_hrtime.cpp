/* Contains code taken from libuv and node.js */

/* Copyright Joyent, Inc. and other Node contributors. All rights reserved.
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#include "stdafx.h"

#include "luanode.h"
#include "luanode_hrtime.h"

#undef NANOSEC
#define NANOSEC ((boost::uint64_t) 1e9)

static const char HRTIME_MT[] = "luanode_hrtime_mt";

#if defined (_WIN32)
/* The resolution of the high-resolution clock. */
static boost::uint64_t uv_hrtime_frequency_ = 0;

class hrtime_init {
public:
	hrtime_init() { 
		LARGE_INTEGER frequency;

		if (!::QueryPerformanceFrequency(&frequency)) {
			uv_hrtime_frequency_ = 0;
			return;
		}

		uv_hrtime_frequency_ = frequency.QuadPart;
	}
};

hrtime_init init;

#elif defined (__APPLE__)
#  include <mach/mach.h>
#  include <mach/mach_time.h>
#  define __STDC_FORMAT_MACROS
#  include <inttypes.h>
#else
#  include <time.h>
#  define __STDC_FORMAT_MACROS
#  include <inttypes.h>
#endif


// used in GetHighresTime () below
#define NANOS_PER_SEC 1000000000


#if defined (_WIN32)
boost::uint64_t LuaNode::HighresTime::Get () {
	LARGE_INTEGER counter;

	/* If the performance frequency is zero, there's no support. */
	if (!uv_hrtime_frequency_) {
	    /* uv__set_sys_error(loop, ERROR_NOT_SUPPORTED); */
	    return 0;
	}

	if (!::QueryPerformanceCounter(&counter)) {
		/* uv__set_sys_error(loop, GetLastError()); */
		return 0;
	}

	/* Because we have no guarantee about the order of magnitude of the */
	/* performance counter frequency, and there may not be much headroom to */
	/* multiply by NANOSEC without overflowing, we use 128-bit math instead. */
	return ((boost::uint64_t) counter.LowPart * NANOSEC / uv_hrtime_frequency_) +
			(((boost::uint64_t) counter.HighPart * NANOSEC / uv_hrtime_frequency_)
			<< 32);
}
#elif defined (__APPLE__)
boost::uint64_t LuaNode::HighresTime::Get () {
	mach_timebase_info_data_t info;
	
	if (mach_timebase_info(&info) != KERN_SUCCESS) {
		abort();
	}

	return mach_absolute_time() * info.numer / info.denom;
}
#else
boost::uint64_t LuaNode::HighresTime::Get () {
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ((boost::uint64_t) ts.tv_sec * NANOSEC + ts.tv_nsec);
}
#endif


//////////////////////////////////////////////////////////////////////////
/// Metamethods for some arithmetic operations
static int substract (lua_State* L) {
	boost::uint64_t t1 = *(boost::uint64_t*)luaL_checkudata(L, 1, HRTIME_MT);
	boost::uint64_t t2 = *(boost::uint64_t*)luaL_checkudata(L, 2, HRTIME_MT);

	boost::uint64_t* result = (boost::uint64_t*)lua_newuserdata(L, sizeof(boost::uint64_t));
	*result = t1 - t2;
	luaL_newmetatable(L, HRTIME_MT);
	lua_setmetatable(L, -2);
	return 1;
}

static int less_than (lua_State* L) {
	boost::uint64_t t1 = *(boost::uint64_t*)luaL_checkudata(L, 1, HRTIME_MT);
	boost::uint64_t t2 = *(boost::uint64_t*)luaL_checkudata(L, 2, HRTIME_MT);

	lua_pushboolean(L, (t1 < t2));
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// Converts the time to a string representation (value in nanoseconds).
static int tostring (lua_State* L) {
	boost::uint64_t time = *(boost::uint64_t*)luaL_checkudata(L, 1, HRTIME_MT);
	char buffer[32];
#if defined (_WIN32)
	sprintf(buffer, "%I64u", time);
#else
	sprintf(buffer, "%"PRId64, time);
#endif
	lua_pushstring(L, buffer);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// Takes a time and returns its seconds part and its nanoseconds part.
int split (lua_State* L) {
	boost::uint64_t time = *(boost::uint64_t*)luaL_checkudata(L, 1, HRTIME_MT);

	lua_pushnumber(L, (lua_Number)(time / NANOS_PER_SEC));
	lua_pushnumber(L, (lua_Number)(time % NANOS_PER_SEC));
	return 2;
}

//////////////////////////////////////////////////////////////////////////
/// Takes a time and returns the number of microseconds in it.
/// It is safe to return the value as a Lua number since we have enough precision now.
/// (2^52) microseconds = 142.713509 years
int as_microseconds (lua_State* L) {
	boost::uint64_t time = *(boost::uint64_t*)luaL_checkudata(L, 1, HRTIME_MT);

	lua_pushnumber(L, (lua_Number)(time / 1000));
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// Takes a time and returns the number of milliseconds in it.
/// It is safe to return the value as a Lua number since we have enough precision now.
/// (2^52) milliseconds = 142 713.509 years
int as_milliseconds (lua_State* L) {
	boost::uint64_t time = *(boost::uint64_t*)luaL_checkudata(L, 1, HRTIME_MT);

	lua_pushnumber(L, (lua_Number)(time / 1000000));
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// The value returned by uv_hrtime() is a 64-bit int representing nanoseconds,
/// so this function instead returns a userdata large enought to hold a 64 bit number in it.
/// Pass in a userdata from a previous hrtime() call to instead get a time diff.
///
int LuaNode::HighresTime::Get (lua_State* L) {
	boost::uint64_t time = Get();

	if(lua_isuserdata(L, 1)) {
		// Return a timediff userdata
		boost::uint64_t* start = (boost::uint64_t*)lua_touserdata(L, 1);
		time -= *start;
	}

	boost::uint64_t* result = (boost::uint64_t*)lua_newuserdata(L, sizeof(boost::uint64_t));
	*result = time;

	int pos = lua_gettop(L);
	if(luaL_newmetatable(L, HRTIME_MT) == 1) {
		// If the metatable has been created, fill it with our metamethods.
		int mt = lua_gettop(L);
		lua_pushcfunction(L, substract);
		lua_setfield(L, mt, "__sub");

		lua_pushcfunction(L, less_than);
		lua_setfield(L, mt, "__lt");

		lua_pushcfunction(L, tostring);
		lua_setfield(L, mt, "__tostring");

		lua_pushcfunction(L, split);
		lua_setfield(L, mt, "split");

		lua_pushcfunction(L, as_microseconds);
		lua_setfield(L, mt, "us");

		lua_pushcfunction(L, as_milliseconds);
		lua_setfield(L, mt, "ms");

		lua_pushvalue(L, mt);
		lua_setfield(L, mt, "__index");
	}
	lua_setmetatable(L, pos);
	return 1;
}
