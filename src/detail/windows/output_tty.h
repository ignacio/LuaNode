#pragma once

#include <windows.h>
#include "windows_tty.h"
#include <lua.hpp>
#include "../../../deps/LuaCppBridge51/lcbHybridObjectWithProperties.h"

namespace LuaNode {

namespace detail {

namespace windows {

/**
OutputTtyStream: Handles writing to console (used for stdout and stderr)
*/
class OutputTtyStream :
	public LuaCppBridge::HybridObjectWithProperties<OutputTtyStream>
{
public:
	OutputTtyStream(lua_State* L);

public:
	int Write (lua_State* L);
	int GetWindowSize (lua_State* L);

	int tty_SetStyle(DWORD* error);
	int uv_tty_clear(int dir, char entire_screen, DWORD* error);
	int uv_tty_save_state(unsigned char save_attributes, DWORD* error);
	int uv_tty_restore_state(unsigned char restore_attributes, DWORD* error);

	COORD uv_tty_make_real_coord(CONSOLE_SCREEN_BUFFER_INFO* info, int x, unsigned char x_relative, int y, unsigned char y_relative);
	int uv_tty_move_caret(int x, unsigned char x_relative, int y, unsigned char y_relative, DWORD* error);
	int tty_Reset(DWORD* error);
	int ProcessMessage(const char* message, size_t length);

	static void uv_tty_update_virtual_window(CONSOLE_SCREEN_BUFFER_INFO* info);

	tty_context_t m_tty_context;
	HANDLE m_handle;

public:
	LCB_HOWP_DECLARE_EXPORTABLE(OutputTtyStream);
};

}

}

}