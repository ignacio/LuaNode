#include "StdAfx.h"
#include "luanode.h"
#include "luanode_timer.h"
#include "blogger.h"

#include <boost/bind.hpp>

using namespace LuaNode;

const char* Timer::className = "Timer";
const Timer::RegType Timer::methods[] = {
	{"start", &Timer::Start},
	{"stop", &Timer::Stop},
	{"again", &Timer::Again},
	{0}
};

const Timer::RegType Timer::setters[] = {
	LCB_ADD_SET(Timer, repeat),
	{0}
};

const Timer::RegType Timer::getters[] = {
	LCB_ADD_GET(Timer, timeout),
	LCB_ADD_GET(Timer, repeat),
	{0}
};

// ojo acá que si el código está ejecutando en una corutina, L no es mi main state, sino la propia Corutina
Timer::Timer(lua_State* L) : 
	m_L( LuaNode::GetLuaEval() ),
	m_repeats(false),
	m_after(0)
{
	LogDebug("Constructing Timer (%p)", this);
}

Timer::~Timer(void)
{
	LogDebug("Destructing Timer (%p)", this);
}

LCB_IMPL_GET(Timer, timeout) {
	return 1;
}

LCB_IMPL_SET(Timer, repeat) {
	return 0;
}
LCB_IMPL_GET(Timer, repeat) {
	return 1;
}


//////////////////////////////////////////////////////////////////////////
/// 
int Timer::Start(lua_State* L) {
	LogDebug("Timer::Start (%p)", this);
	m_after = luaL_checkinteger(L, 2);
	int repeat = luaL_checkinteger(L, 3);

	if(repeat != 0) {
		m_repeats = true;
	}
	
	//lua_getfield(L, 1, "callback");

	if(m_timer != NULL) {
		// TODO: fix me
		luaL_error(L, "double Start not implemented yet in timers");
	}
	m_timer.reset( new boost::asio::deadline_timer(GetIoService(), boost::posix_time::milliseconds(m_after)) );

	lua_pushvalue(L, 1);
	int reference = luaL_ref(L, LUA_REGISTRYINDEX);
	m_timer->async_wait( boost::bind(&Timer::OnTimeout, this, reference, boost::asio::placeholders::error) );
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Timer::Stop(lua_State* L) {
	LogDebug("Timer::Stop (%p)", this);
	if(m_timer != NULL) {
		m_timer->cancel();
	}
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Timer::Again(lua_State* L) {
	LogDebug("Timer::Again (%p)", this);

	// if no timer, start it (non repeating)
	if(!m_timer) {
		lua_pushinteger(L, 0);
		return Start(L);
	}
	else {
		// if started but non repeating, stop it and start it again
		if(!m_repeats) {
			m_timer->cancel();
		}

		if(lua_isnumber(L, 2)) {
			m_after = lua_tonumber(L, 2);
		}

		lua_pushvalue(L, 1);
		int reference = luaL_ref(L, LUA_REGISTRYINDEX);
		m_timer->expires_from_now( boost::posix_time::milliseconds(m_after) );
		m_timer->async_wait( boost::bind(&Timer::OnTimeout, this, reference, boost::asio::placeholders::error) );
	}
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
void Timer::OnTimeout(int reference, const boost::system::error_code& ec) {
	lua_State* L = m_L;
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	if(boost::asio::error::operation_aborted != ec) {
		bool repeats = m_repeats;	// might change during the callback
		
		lua_getfield(L, 1, "callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			LuaNode::GetLuaEval().call(0, LUA_MULTRET);

			if(m_repeats) {
				// since a new timer could be setup in the callback, grab a new reference and pass that
				// so I can always clean up the old one
				// maybe optimize this some time
				int newReference = luaL_ref(L, LUA_REGISTRYINDEX);
				m_timer->expires_from_now( boost::posix_time::milliseconds(m_after) );
				m_timer->async_wait( boost::bind(&Timer::OnTimeout, this, newReference, boost::asio::placeholders::error) );
			}
		}
		else {
			// no callback, stop the timer
			m_timer->cancel();
		}
	}
	lua_settop(L, 0);
}