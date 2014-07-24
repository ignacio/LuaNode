#pragma once

#include "../deps/luacppbridge51/lcbHybridObjectWithProperties.h"

#include <boost/asio/deadline_timer.hpp>

#include <boost/shared_ptr.hpp>

namespace LuaNode {

	class Timer : public LuaCppBridge::HybridObjectWithProperties<Timer>
{
public:
	Timer(lua_State* L);
	virtual ~Timer(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(Timer);
	static const char* get_full_class_name_T();

	int Start(lua_State* L);
	int Stop(lua_State* L);
	int Again(lua_State* L);

private:
	void OnTimeout(int reference, const boost::system::error_code& ec);

private:
	boost::shared_ptr< boost::asio::deadline_timer > m_timer;
	const unsigned int m_timerId;
	bool m_repeats;
	int m_after;
};

}
