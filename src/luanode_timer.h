#pragma once

#include <luacppbridge51/lcbHybridObjectWithProperties.h>
#include <boost/asio.hpp>
#include <boost/shared_ptr.hpp>

namespace LuaNode {

	class Timer : public LuaCppBridge::HybridObjectWithProperties<Timer>
{
public:
	Timer(lua_State* L);
	virtual ~Timer(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(Timer);

	int Start(lua_State* L);
	int Stop(lua_State* L);
	int Again(lua_State* L);

	LCB_DECL_GET(timeout);
	LCB_DECL_SETGET(repeat);

public:
	void OnTimeout(int reference, const boost::system::error_code& ec);

private:
	boost::shared_ptr< boost::asio::deadline_timer > m_timer;
	lua_State* m_L;
	bool m_repeats;
	int m_after;
};

}