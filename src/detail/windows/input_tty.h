#pragma once

#include <windows.h>
#include "windows_tty.h"
#include <vector>
#include <boost/thread.hpp>
#include <lua.hpp>
#include "../../../deps/LuaCppBridge51/lcbHybridObjectWithProperties.h"

namespace LuaNode {

namespace detail {

namespace windows {

/**
InputServer: Handles reading from console.
*/
class InputTtyStream : 
	public LuaCppBridge::HybridObjectWithProperties<InputTtyStream>
{
public:
	InputTtyStream(lua_State* L);
	virtual ~InputTtyStream();
	void Run();

	void PostConstruct(lua_State* L);

public:
	void Start();
	void Stop();

	int SetRawMode (lua_State* L);
	int Read(lua_State* L);
	int Pause(lua_State* L);
	int Close (lua_State* L);

	volatile bool m_run;	// hack!
	tty_context_t m_tty_context;

public:
	LCB_HOWP_DECLARE_EXPORTABLE(InputTtyStream);

private:
	boost::shared_ptr<boost::thread> m_tty_reader_thread;
	boost::shared_ptr<boost::asio::io_service::work> m_input_asio_work;
	int m_self_reference;
	HANDLE m_handle;

private:
	void ReadConsoleHandler (tty_context_t& tty_context, std::vector<INPUT_RECORD> records, DWORD numRecords);
};

}

}

}