#include "stdafx.h"

/* Contains code taken from libuv.

 * Copyright Joyent, Inc. and other Node contributors. All rights reserved.
 *
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

#include "luanode.h"
#include "luanode_stdio.h"

#include <stdio.h>

#include <windows.h>
#include <io.h>
#include <stdlib.h>
#include <fcntl.h>
#include <boost/thread.hpp>
#include <boost/make_shared.hpp>
#include <iostream>
#include <string>
#include <queue>
#include <boost/cstdint.hpp>

// Warning: the following is a mess. I should split this.

#define ARRAY_SIZE(a) (sizeof((a)) / sizeof((a)[0]))


// Good info:
// http://www.benryves.com/tutorials/winconsole/all

#define UNICODE_REPLACEMENT_CHARACTER (0xfffd)

#define ANSI_NORMAL           0x00
#define ANSI_ESCAPE_SEEN      0x02
#define ANSI_CSI              0x04
#define ANSI_ST_CONTROL       0x08
#define ANSI_IGNORE           0x10
#define ANSI_IN_ARG           0x20
#define ANSI_IN_STRING        0x40
#define ANSI_BACKSLASH_SEEN   0x80

static void uv_tty_update_virtual_window(CONSOLE_SCREEN_BUFFER_INFO* info);

#define UV_HANDLE_TTY_SAVED_POSITION            0x00400000
#define UV_HANDLE_TTY_SAVED_ATTRIBUTES          0x00800000

#define UV_HANDLE_TTY_RAW                       0x00080000


/* TTY watcher data */
static bool tty_watcher_initialized = false;
static HANDLE tty_handle;
static HANDLE tty_wait_handle;
static int tty_error_callback = LUA_NOREF;
static int tty_keypress_callback = LUA_NOREF;
static int tty_resize_callback = LUA_NOREF;

static int uv_tty_virtual_offset = -1;
static int uv_tty_virtual_height = -1;
static int uv_tty_virtual_width = -1;

typedef struct tty_context_t {
	DWORD original_console_mode;
	/* Fields used for translating win */
	/* keystrokes into vt100 characters */
	char last_key[8];
	unsigned char last_key_offset;
	unsigned char last_key_len;
	INPUT_RECORD last_input_record;
	WCHAR last_utf16_high_surrogate;
	/* utf8-to-utf16 conversion state */
	unsigned char utf8_bytes_left;
	unsigned int utf8_codepoint;
	/* eol conversion state */
	unsigned char previous_eol;
	/* ansi parser state */
	unsigned char ansi_parser_state;
	unsigned char ansi_csi_argc;
	unsigned short ansi_csi_argv[4];
	COORD saved_position;
	WORD saved_attributes;

	unsigned int flags;
} tty_context_t;


static const char* get_vt100_fn_key(DWORD code, char shift, char ctrl, size_t* len) {
#define VK_CASE(vk, normal_str, shift_str, ctrl_str, shift_ctrl_str)          \
	case (vk):                                                                \
		if (shift && ctrl) {                                                  \
			*len = sizeof shift_ctrl_str;                                     \
			return "\033" shift_ctrl_str;                                     \
		} else if (shift) {                                                   \
			*len = sizeof shift_str ;                                         \
			return "\033" shift_str;                                          \
		} else if (ctrl) {                                                    \
			*len = sizeof ctrl_str;                                           \
			return "\033" ctrl_str;                                           \
		} else {                                                              \
			*len = sizeof normal_str;                                         \
			return "\033" normal_str;                                         \
		}

	switch (code) {
		/* These mappings are the same as Cygwin's. Unmodified and alt-modified */
		/* keypad keys comply with linux console, modifiers comply with xterm */
		/* modifier usage. F1..f12 and shift-f1..f10 comply with linux console, */
		/* f6..f12 with and without modifiers comply with rxvt. */
		VK_CASE(VK_INSERT,  "[2~",  "[2;2~", "[2;5~", "[2;6~")
		VK_CASE(VK_END,     "[4~",  "[4;2~", "[4;5~", "[4;6~")
		VK_CASE(VK_DOWN,    "[B",   "[1;2B", "[1;5B", "[1;6B")
		VK_CASE(VK_NEXT,    "[6~",  "[6;2~", "[6;5~", "[6;6~")
		VK_CASE(VK_LEFT,    "[D",   "[1;2D", "[1;5D", "[1;6D")
		VK_CASE(VK_CLEAR,   "[G",   "[1;2G", "[1;5G", "[1;6G")
		VK_CASE(VK_RIGHT,   "[C",   "[1;2C", "[1;5C", "[1;6C")
		VK_CASE(VK_UP,      "[A",   "[1;2A", "[1;5A", "[1;6A")
		VK_CASE(VK_HOME,    "[1~",  "[1;2~", "[1;5~", "[1;6~")
		VK_CASE(VK_PRIOR,   "[5~",  "[5;2~", "[5;5~", "[5;6~")
		VK_CASE(VK_DELETE,  "[3~",  "[3;2~", "[3;5~", "[3;6~")
		VK_CASE(VK_NUMPAD0, "[2~",  "[2;2~", "[2;5~", "[2;6~")
		VK_CASE(VK_NUMPAD1, "[4~",  "[4;2~", "[4;5~", "[4;6~")
		VK_CASE(VK_NUMPAD2, "[B",   "[1;2B", "[1;5B", "[1;6B")
		VK_CASE(VK_NUMPAD3, "[6~",  "[6;2~", "[6;5~", "[6;6~")
		VK_CASE(VK_NUMPAD4, "[D",   "[1;2D", "[1;5D", "[1;6D")
		VK_CASE(VK_NUMPAD5, "[G",   "[1;2G", "[1;5G", "[1;6G")
		VK_CASE(VK_NUMPAD6, "[C",   "[1;2C", "[1;5C", "[1;6C")
		VK_CASE(VK_NUMPAD7, "[A",   "[1;2A", "[1;5A", "[1;6A")
		VK_CASE(VK_NUMPAD8, "[1~",  "[1;2~", "[1;5~", "[1;6~")
		VK_CASE(VK_NUMPAD9, "[5~",  "[5;2~", "[5;5~", "[5;6~")
		VK_CASE(VK_DECIMAL, "[3~",  "[3;2~", "[3;5~", "[3;6~")
		VK_CASE(VK_F1,      "[[A",  "[23~",  "[11^",  "[23^" )
		VK_CASE(VK_F2,      "[[B",  "[24~",  "[12^",  "[24^" )
		VK_CASE(VK_F3,      "[[C",  "[25~",  "[13^",  "[25^" )
		VK_CASE(VK_F4,      "[[D",  "[26~",  "[14^",  "[26^" )
		VK_CASE(VK_F5,      "[[E",  "[28~",  "[15^",  "[28^" )
		VK_CASE(VK_F6,      "[17~", "[29~",  "[17^",  "[29^" )
		VK_CASE(VK_F7,      "[18~", "[31~",  "[18^",  "[31^" )
		VK_CASE(VK_F8,      "[19~", "[32~",  "[19^",  "[32^" )
		VK_CASE(VK_F9,      "[20~", "[33~",  "[20^",  "[33^" )
		VK_CASE(VK_F10,     "[21~", "[34~",  "[21^",  "[34^" )
		VK_CASE(VK_F11,     "[23~", "[23$",  "[23^",  "[23@" )
		VK_CASE(VK_F12,     "[24~", "[24$",  "[24^",  "[24@" )

		default:
			*len = 0;
			return NULL;
	}
	#undef VK_CASE
}

//////////////////////////////////////////////////////////////////////////
/// 
static void ReadConsoleHandler (tty_context_t& tty_context, std::vector<INPUT_RECORD> records, DWORD numRecords)
{
	// Process the events
	unsigned int i = 0;
	DWORD records_left = numRecords;
	off_t buf_used = 0;
	luaL_Buffer buffer;

	CLuaVM& vm = LuaNode::GetLuaVM();

	while( (records_left > 0 || tty_context.last_key_len > 0)  ) {
		if(tty_context.last_key_len == 0) {
			INPUT_RECORD& record = records[i];
			records_left--;
			i++;
			tty_context.last_input_record = record;
			switch(record.EventType) {
				case KEY_EVENT: {
					if(!tty_keypress_callback) {
						continue;
					}
					KEY_EVENT_RECORD& keyRecord = record.Event.KeyEvent; 
					/* Ignore keyup events, unless the left alt key was held and a valid */
					/* unicode character was emitted. */
					if (!keyRecord.bKeyDown && !(((keyRecord.dwControlKeyState & LEFT_ALT_PRESSED) ||
						keyRecord.wVirtualKeyCode == VK_MENU) && keyRecord.uChar.UnicodeChar != 0))
					{
						continue;
					}

					/* Ignore keypresses to numpad number keys if the left alt is held */
					/* because the user is composing a character, or windows simulating */
					/* this. */
					if ((keyRecord.dwControlKeyState & LEFT_ALT_PRESSED) &&
						!(keyRecord.dwControlKeyState & ENHANCED_KEY) &&
						(keyRecord.wVirtualKeyCode == VK_INSERT ||
						keyRecord.wVirtualKeyCode == VK_END ||
						keyRecord.wVirtualKeyCode == VK_DOWN ||
						keyRecord.wVirtualKeyCode == VK_NEXT ||
						keyRecord.wVirtualKeyCode == VK_LEFT ||
						keyRecord.wVirtualKeyCode == VK_CLEAR ||
						keyRecord.wVirtualKeyCode == VK_RIGHT ||
						keyRecord.wVirtualKeyCode == VK_HOME ||
						keyRecord.wVirtualKeyCode == VK_UP ||
						keyRecord.wVirtualKeyCode == VK_PRIOR ||
						keyRecord.wVirtualKeyCode == VK_NUMPAD0 ||
						keyRecord.wVirtualKeyCode == VK_NUMPAD1 ||
						keyRecord.wVirtualKeyCode == VK_NUMPAD2 ||
						keyRecord.wVirtualKeyCode == VK_NUMPAD3 ||
						keyRecord.wVirtualKeyCode == VK_NUMPAD4 ||
						keyRecord.wVirtualKeyCode == VK_NUMPAD5 ||
						keyRecord.wVirtualKeyCode == VK_NUMPAD6 ||
						keyRecord.wVirtualKeyCode == VK_NUMPAD7 ||
						keyRecord.wVirtualKeyCode == VK_NUMPAD8 ||
						keyRecord.wVirtualKeyCode == VK_NUMPAD9)) {
							continue;
					}

					if(keyRecord.uChar.UnicodeChar != 0) {
						int prefix_len, char_len;
						/* Character key pressed */
						if(keyRecord.uChar.UnicodeChar >= 0xD800 && keyRecord.uChar.UnicodeChar < 0xDC00) {
							/* UTF-16 high surrogate */
							tty_context.last_utf16_high_surrogate = keyRecord.uChar.UnicodeChar;
							continue;
						}
					
						/* Prefix with \u033 if alt was held, but alt was not used as part of a compose sequence. */
						if ((keyRecord.dwControlKeyState & (LEFT_ALT_PRESSED | RIGHT_ALT_PRESSED))
							&& !(keyRecord.dwControlKeyState & (LEFT_CTRL_PRESSED |
							RIGHT_CTRL_PRESSED)) && keyRecord.bKeyDown)
						{
							tty_context.last_key[0] = '\033';
							prefix_len = 1;
						}
						else {
							prefix_len = 0;
						}

						if (keyRecord.uChar.UnicodeChar >= 0xDC00 && keyRecord.uChar.UnicodeChar < 0xE000) {
							/* UTF-16 surrogate pair */
							WCHAR utf16_buffer[2] = { tty_context.last_utf16_high_surrogate, keyRecord.uChar.UnicodeChar};
							char_len = WideCharToMultiByte(CP_UTF8,
								0,
								utf16_buffer,
								2,
								&tty_context.last_key[prefix_len],
								sizeof tty_context.last_key,
								NULL,
								NULL);
						} else {
							/* Single UTF-16 character */
							char_len = WideCharToMultiByte(CP_UTF8,
								0,
								&keyRecord.uChar.UnicodeChar,
								1,
								&tty_context.last_key[prefix_len],
								sizeof tty_context.last_key,
								NULL,
								NULL);
						}
						/* Whatever happened, the last character wasn't a high surrogate. */
						tty_context.last_utf16_high_surrogate = 0;

						/* If the utf16 character(s) couldn't be converted something must */
						/* be wrong. */
						if (!char_len) {
							////Puv__set_sys_error(loop, GetLastError());
							////Pm_tty_context.flags &= ~UV_HANDLE_READING;
							////Pm_tty_context.read_cb((uv_stream_t*) handle, -1, buf);
							////Pgoto out;
						}

						tty_context.last_key_len = (unsigned char) (prefix_len + char_len);
						tty_context.last_key_offset = 0;
						continue;
					}
					else {
						/* Function key pressed */
						const char* vt100;
						size_t prefix_len, vt100_len;

						vt100 = get_vt100_fn_key(keyRecord.wVirtualKeyCode,
							!!(keyRecord.dwControlKeyState & SHIFT_PRESSED),
							!!(keyRecord.dwControlKeyState & (
							LEFT_CTRL_PRESSED |
							RIGHT_CTRL_PRESSED)),
							&vt100_len);

						/* If we were unable to map to a vt100 sequence, just ignore. */
						if (!vt100) {
							continue;
						}

						//fprintf(stderr, "function key pressed: %s\n", vt100);

						/* Prefix with \x033 when the alt key was held. */
						if (keyRecord.dwControlKeyState & (LEFT_ALT_PRESSED | RIGHT_ALT_PRESSED)) {
							tty_context.last_key[0] = '\033';
							prefix_len = 1;
						}
						else {
							prefix_len = 0;
						}

						/* Copy the vt100 sequence to the handle buffer. */
						assert(prefix_len + vt100_len < sizeof tty_context.last_key);
						memcpy(&tty_context.last_key[prefix_len], vt100, vt100_len);
	
						tty_context.last_key_len = (unsigned char) (prefix_len + vt100_len);
						tty_context.last_key_offset = 0;
						continue;
					}
				break; }
				
				case WINDOW_BUFFER_SIZE_EVENT: {
					if(!tty_resize_callback) {
						continue;
					}
					CLuaVM& vm = LuaNode::GetLuaVM();
					lua_rawgeti(vm, LUA_REGISTRYINDEX, tty_resize_callback);
					COORD size = record.Event.WindowBufferSizeEvent.dwSize;
					lua_pushinteger(vm, size.X);
					lua_pushinteger(vm, size.Y);
					vm.call(2, LUA_MULTRET);
					lua_settop(vm, 0);

				break; }
			}
		}
		else {
			/* Copy any bytes left from the last keypress to the user buffer. */
			if (tty_context.last_key_offset < tty_context.last_key_len) {
				/* Allocate a buffer if needed */
				if(buf_used == 0) {
					luaL_buffinit(vm, &buffer);
				}
				buf_used++;
				luaL_addchar(&buffer, tty_context.last_key[tty_context.last_key_offset++]);

				/* If the buffer is full, emit it */
				/*if (buf_used == buf.len) {
					m_tty_context.read_cb((uv_stream_t*) handle, buf_used, buf);
					buf = uv_null_buf_;
					buf_used = 0;
				}*/
				continue;
			}

			/* Apply dwRepeat from the last input record. */
			if (--tty_context.last_input_record.Event.KeyEvent.wRepeatCount > 0) {
				tty_context.last_key_offset = 0;
				continue;
			}

			tty_context.last_key_len = 0;
			continue;
		}
	}

	if(buf_used > 0) {
		luaL_pushresult(&buffer);
		//fprintf(stderr, "function key pressed: '%s'\n", lua_tostring(vm, -1));
		lua_rawgeti(vm, LUA_REGISTRYINDEX, tty_keypress_callback);
		lua_insert(vm, -2);

		vm.call(1, LUA_MULTRET);
		lua_settop(vm, 0);
	}
}


int uv_tty_set_mode(tty_context_t* tty, HANDLE handle, int mode) {
	DWORD flags = 0;

	if (!!mode == !!(tty->flags & UV_HANDLE_TTY_RAW)) {
		return 0;
	}

	if (tty->original_console_mode & ENABLE_QUICK_EDIT_MODE) {
		flags = ENABLE_QUICK_EDIT_MODE | ENABLE_EXTENDED_FLAGS;
	}

	if (mode) {
		/* Raw input */
		flags |= ENABLE_WINDOW_INPUT;
	}
	else {
		/* Line-buffered mode. */
		flags |= ENABLE_ECHO_INPUT | ENABLE_INSERT_MODE | ENABLE_LINE_INPUT |ENABLE_EXTENDED_FLAGS | ENABLE_PROCESSED_INPUT;
	}

	if (!SetConsoleMode(handle, flags)) {
		LogError("uv_tty_set_mode failed with code %d", GetLastError());
		return -1;
	}

	/* Update flag. */
	tty->flags &= ~UV_HANDLE_TTY_RAW;
	tty->flags |= mode ? UV_HANDLE_TTY_RAW : 0;

	return 0;
}


/**
InputServer: Handles reading from console.
*/
class InputServer {
public:
	InputServer();
	void Run();

	volatile bool m_run;	// hack!
	tty_context_t m_tty_context;
};

//////////////////////////////////////////////////////////////////////////
/// 
InputServer::InputServer() {

	if (!GetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), &m_tty_context.original_console_mode)) {
		//uv__set_sys_error(loop, GetLastError());
		//return -1;
		//fprintf(stderr, "%d\n", GetLastError());
		//abort();
		return;
		// TODO: Loguear el error
	}

	/* Init keycode-to-vt100 mapper state. */
	m_tty_context.last_key_offset = 0;
	m_tty_context.last_key_len = 0;
	
	m_tty_context.last_utf16_high_surrogate = 0;
	memset(&m_tty_context.last_input_record, 0, sizeof m_tty_context.last_input_record);
	
	/* Init utf8-to-utf16 conversion state. */
	m_tty_context.utf8_bytes_left = 0;
	m_tty_context.utf8_codepoint = 0;

	/* Initialize eol conversion state */
	m_tty_context.previous_eol = 0;

	/* Init ANSI parser state. */
	m_tty_context.ansi_parser_state = ANSI_NORMAL;
}


//////////////////////////////////////////////////////////////////////////
/// 
void InputServer::Run() {
	while(m_run) {
		// Read pending events
		DWORD dwRead = 0;
		std::vector<INPUT_RECORD> inRecords(128);
		if(::ReadConsoleInput(GetStdHandle(STD_INPUT_HANDLE), &inRecords[0], 128, &dwRead)) {
			if(dwRead == 1 && (inRecords[0].EventType == FOCUS_EVENT)) {
				continue;
			}

			if(dwRead > 0) {
				LuaNode::GetIoService().post( boost::bind(ReadConsoleHandler, m_tty_context, inRecords, dwRead) );
			}
		}
		else {
			fprintf(stderr, "Error in ReadConsoleInput - %d", GetLastError());
			break;
		}
	}
}

// ugh! remove this globals...
boost::shared_ptr<InputServer> tty_input;
static boost::shared_ptr<boost::thread> tty_reader_thread;
static boost::shared_ptr<boost::asio::io_service::work> input_asio_work; 

//////////////////////////////////////////////////////////////////////////
/// TODO: this is the same on luanode_stdio_linux.cpp
static int IsATTY (lua_State* L) {
	int fd = luaL_checkinteger(L, 1);

	lua_pushboolean(L, _isatty(fd));

	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
static int WriteError (lua_State* L) {
	if(lua_gettop(L) == 0) {
		// do nothing
		return 0;
	}
	const char* message = luaL_checkstring(L, 1);
	fprintf(stderr, "%s", message);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// Returna the file descriptor mapped to stdin
static int OpenStdin (lua_State* L) {
	//setRawMode(0); // init into nonraw mode
	lua_pushinteger(L, _fileno(stdin));
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
static int IsStdinBlocking (lua_State* L) {
	// On windows stdin always blocks
	lua_pushboolean(L, true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
static int IsStdoutBlocking (lua_State* L) {
	// On windows stdout always blocks
	lua_pushboolean(L, true);
	return 1;
}



//////////////////////////////////////////////////////////////////////////
/// 
static int tty_WriteTextW(HANDLE handle, const WCHAR buffer[], DWORD length, DWORD* error) {
	DWORD written;

	if(*error != ERROR_SUCCESS) {
		return -1;
	}
	if(!WriteConsoleW(handle, (void*) buffer, length, &written, NULL)) {
		*error = GetLastError();
		return -1;
	}
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
static int tty_WriteTextA(HANDLE handle, const CHAR buffer[], DWORD length, DWORD* error) {
	DWORD written;

	if(*error != ERROR_SUCCESS) {
		return -1;
	}
	if(!WriteConsoleA(handle, (void*) buffer, length, &written, NULL)) {
		*error = GetLastError();
		return -1;
	}
	return 0;
}

/**
OutputServer: Handles writing to console.
*/
class OutputServer {
public:
	OutputServer();

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
	/*boost::mutex m_lock;
	boost::condition_variable m_haveEvent;
	std::queue<std::string> commands;*/
};

//////////////////////////////////////////////////////////////////////////
/// 
OutputServer::OutputServer() {
	/* Init keycode-to-vt100 mapper state. */
	m_tty_context.last_key_offset = 0;
	m_tty_context.last_key_len = 0;
	//INPUT_RECORD last_input_record;
	m_tty_context.last_utf16_high_surrogate = 0;
	memset(&m_tty_context.last_input_record, 0, sizeof m_tty_context.last_input_record);

	/* Init utf8-to-utf16 conversion state. */
	m_tty_context.utf8_bytes_left = 0;
	m_tty_context.utf8_codepoint = 0;

	/* Initialize eol conversion state */
	m_tty_context.previous_eol = 0;

	/* Init ANSI parser state. */
	m_tty_context.ansi_parser_state = ANSI_NORMAL;

	m_handle = GetStdHandle(STD_OUTPUT_HANDLE);
}

/*void operator () () {
	while (1) {
		std::string message;
		DWORD error = 0;
		{
			boost::unique_lock<boost::mutex> lock(m_lock);
			m_haveEvent.wait(lock);
			while(!commands.empty()) {
				message = commands.front();
				commands.pop();

				const char* msg = message.c_str();
				ProcessMessage(msg, message.size());
			}
		}
	}
}*/

//////////////////////////////////////////////////////////////////////////
/// 
int OutputServer::tty_SetStyle(DWORD* error) {
	unsigned short argc = m_tty_context.ansi_csi_argc;
	unsigned short* argv = m_tty_context.ansi_csi_argv;
	int i;
	CONSOLE_SCREEN_BUFFER_INFO info;

	char fg_color = -1, bg_color = -1;
	char fg_bright = -1, bg_bright = -1;

	if (argc == 0) {
		/* Reset mode */
		fg_color = 7;
		bg_color = 0;
		fg_bright = 0;
		bg_bright = 0;
	}

	for (i = 0; i < argc; i++) {
		short arg = argv[i];

		if (arg == 0) {
			/* Reset mode */
			fg_color = 7;
			bg_color = 0;
			fg_bright = 0;
			bg_bright = 0;

		} else if (arg == 1) {
			/* Foreground bright on */
			fg_bright = 1;

		} else if (arg == 2) {
			/* Both bright off */
			fg_bright = 0;
			bg_bright = 0;

		} else if (arg == 5) {
			/* Background bright on */
			bg_bright = 1;

		} else if (arg == 21 || arg == 22) {
			/* Foreground bright off */
			fg_bright = 0;

		} else if (arg == 25) {
			/* Background bright off */
			bg_bright = 0;

		} else if (arg >= 30 && arg <= 37) {
			/* Set foreground color */
			fg_color = arg - 30;

		} else if (arg == 39) {
			/* Default text color */
			fg_color = 7;
			fg_bright = 0;

		} else if (arg >= 40 && arg <= 47) {
			/* Set background color */
			bg_color = arg - 40;

		} else if (arg ==  49) {
			/* Default background color */
			bg_color = 0;

		} else if (arg >= 90 && arg <= 97) {
			/* Set bold foreground color */
			fg_bright = 1;
			fg_color = arg - 90;

		} else if (arg >= 100 && arg <= 107) {
			/* Set bold background color */
			bg_bright = 1;
			bg_color = arg - 100;

		}
	}

	if (fg_color == -1 && bg_color == -1 && fg_bright == -1 &&
		bg_bright == -1) {
			/* Nothing changed */
			return 0;
	}

	if (!GetConsoleScreenBufferInfo(m_handle, &info)) {
		*error = GetLastError();
		return -1;
	}

	if (fg_color != -1) {
		info.wAttributes &= ~(FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE);
		if (fg_color & 1) info.wAttributes |= FOREGROUND_RED;
		if (fg_color & 2) info.wAttributes |= FOREGROUND_GREEN;
		if (fg_color & 4) info.wAttributes |= FOREGROUND_BLUE;
	}

	if (fg_bright != -1) {
		if (fg_bright) {
			info.wAttributes |= FOREGROUND_INTENSITY;
		} else {
			info.wAttributes &= ~FOREGROUND_INTENSITY;
		}
	}

	if (bg_color != -1) {
		info.wAttributes &= ~(BACKGROUND_RED | BACKGROUND_GREEN | BACKGROUND_BLUE);
		if (bg_color & 1) info.wAttributes |= BACKGROUND_RED;
		if (bg_color & 2) info.wAttributes |= BACKGROUND_GREEN;
		if (bg_color & 4) info.wAttributes |= BACKGROUND_BLUE;
	}

	if (bg_bright != -1) {
		if (bg_bright) {
			info.wAttributes |= BACKGROUND_INTENSITY;
		} else {
			info.wAttributes &= ~BACKGROUND_INTENSITY;
		}
	}

	if (!SetConsoleTextAttribute(m_handle, info.wAttributes)) {
		*error = GetLastError();
		return -1;
	}

	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int OutputServer::uv_tty_clear(int dir, char entire_screen, DWORD* error) {
	unsigned short argc = m_tty_context.ansi_csi_argc;
	unsigned short* argv = m_tty_context.ansi_csi_argv;

	CONSOLE_SCREEN_BUFFER_INFO info;
	COORD start, end;
	DWORD count, written;

	int x1, x2, y1, y2;
	int x1r, x2r, y1r, y2r;

	if (*error != ERROR_SUCCESS) {
		return -1;
	}

	if (dir == 0) {
		/* Clear from current position */
		x1 = 0;
		x1r = 1;
	}
	else {
		/* Clear from column 0 */
		x1 = 0;
		x1r = 0;
	}

	if (dir == 1) {
		/* Clear to current position */
		x2 = 0;
		x2r = 1;
	}
	else {
		/* Clear to end of row. We pretend the console is 65536 characters wide, */
		/* uv_tty_make_real_coord will clip it to the actual console width. */
		x2 = 0xffff;
		x2r = 0;
	}

	if (!entire_screen) {
		/* Stay on our own row */
		y1 = y2 = 0;
		y1r = y2r = 1;
	}
	else {
		/* Apply columns direction to row */
		y1 = x1;
		y1r = x1r;
		y2 = x2;
		y2r = x2r;
	}

retry:
	if (!GetConsoleScreenBufferInfo(m_handle, &info)) {
		*error = GetLastError();
		return -1;
	}

	start = uv_tty_make_real_coord(&info, x1, x1r, y1, y1r);
	end = uv_tty_make_real_coord(&info, x2, x2r, y2, y2r);
	count = (end.Y * info.dwSize.X + end.X) - (start.Y * info.dwSize.X + start.X) + 1;

	if (!(FillConsoleOutputCharacterW(m_handle, L'\x20', count, start, &written) &&
		FillConsoleOutputAttribute(m_handle, info.wAttributes, written, start, &written)))
	{
		if (GetLastError() == ERROR_INVALID_PARAMETER) {
			/* The console may be resized - retry */
			goto retry;
		}
		else {
			*error = GetLastError();
			return -1;
		}
	}

	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int OutputServer::uv_tty_save_state(unsigned char save_attributes, DWORD* error) {
	CONSOLE_SCREEN_BUFFER_INFO info;

	if (*error != ERROR_SUCCESS) {
		return -1;
	}

	if (!GetConsoleScreenBufferInfo(m_handle, &info)) {
		*error = GetLastError();
		return -1;
	}

	uv_tty_update_virtual_window(&info);

	m_tty_context.saved_position.X = info.dwCursorPosition.X;
	m_tty_context.saved_position.Y = info.dwCursorPosition.Y - uv_tty_virtual_offset;
	m_tty_context.flags |= UV_HANDLE_TTY_SAVED_POSITION;

	if (save_attributes) {
		m_tty_context.saved_attributes = info.wAttributes & (FOREGROUND_INTENSITY | BACKGROUND_INTENSITY);
		m_tty_context.flags |= UV_HANDLE_TTY_SAVED_ATTRIBUTES;
	}

	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int OutputServer::uv_tty_restore_state(unsigned char restore_attributes, DWORD* error) {
	CONSOLE_SCREEN_BUFFER_INFO info;
	WORD new_attributes;

	if (*error != ERROR_SUCCESS) {
		return -1;
	}

	if (m_tty_context.flags & UV_HANDLE_TTY_SAVED_POSITION) {
		if (uv_tty_move_caret(
							m_tty_context.saved_position.X,
							0,
							m_tty_context.saved_position.Y,
							0,
							error) != 0)
		{
			return -1;
		}
	}

	if (restore_attributes && (m_tty_context.flags & UV_HANDLE_TTY_SAVED_ATTRIBUTES)) {
		if (!GetConsoleScreenBufferInfo(m_handle, &info)) {
			*error = GetLastError();
			return -1;
		}

		new_attributes = info.wAttributes;
		new_attributes &= ~(FOREGROUND_INTENSITY | BACKGROUND_INTENSITY);
		new_attributes |= m_tty_context.saved_attributes;

		if (!SetConsoleTextAttribute(m_handle, new_attributes)) {
			*error = GetLastError();
			return -1;
		}
	}

	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ void OutputServer::uv_tty_update_virtual_window(CONSOLE_SCREEN_BUFFER_INFO* info)
{
	uv_tty_virtual_height = info->srWindow.Bottom - info->srWindow.Top + 1;
	uv_tty_virtual_width = info->dwSize.X;

	/* Recompute virtual window offset row. */
	if (uv_tty_virtual_offset == -1) {
		uv_tty_virtual_offset = info->dwCursorPosition.Y;
	}
	else if (uv_tty_virtual_offset < info->dwCursorPosition.Y - uv_tty_virtual_height + 1) {
		/* If suddenly find the cursor outside of the virtual window, it must */
		/* have somehow scrolled. Update the virtual window offset. */
		uv_tty_virtual_offset = info->dwCursorPosition.Y - uv_tty_virtual_height + 1;
	}
	if (uv_tty_virtual_offset + uv_tty_virtual_height > info->dwSize.Y) {
		uv_tty_virtual_offset = info->dwSize.Y - uv_tty_virtual_height;
	}
	if (uv_tty_virtual_offset < 0) {
		uv_tty_virtual_offset = 0;
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
COORD OutputServer::uv_tty_make_real_coord(CONSOLE_SCREEN_BUFFER_INFO* info, int x, unsigned char x_relative, int y, unsigned char y_relative) {
	COORD result;

	uv_tty_update_virtual_window(info);

	/* Adjust y position */
	if (y_relative) {
		y = info->dwCursorPosition.Y + y;
	}
	else {
		y = uv_tty_virtual_offset + y;
	}
	/* Clip y to virtual client rectangle */
	if (y < uv_tty_virtual_offset) {
		y = uv_tty_virtual_offset;
	}
	else if (y >= uv_tty_virtual_offset + uv_tty_virtual_height) {
		y = uv_tty_virtual_offset + uv_tty_virtual_height - 1;
	}

	/* Adjust x */
	if (x_relative) {
		x = info->dwCursorPosition.X + x;
	}
	/* Clip x */
	if (x < 0) {
		x = 0;
	}
	else if (x >= uv_tty_virtual_width) {
		x = uv_tty_virtual_width - 1;
	}

	result.X = (unsigned short) x;
	result.Y = (unsigned short) y;
	return result;
}

//////////////////////////////////////////////////////////////////////////
/// 
int OutputServer::uv_tty_move_caret(int x, unsigned char x_relative, int y, unsigned char y_relative, DWORD* error) {
	CONSOLE_SCREEN_BUFFER_INFO info;
	COORD pos;

	if (*error != ERROR_SUCCESS) {
		return -1;
	}

retry:
	if (!GetConsoleScreenBufferInfo(m_handle, &info)) {
		*error = GetLastError();
	}

	pos = uv_tty_make_real_coord(&info, x, x_relative, y, y_relative);

	if (!SetConsoleCursorPosition(m_handle, pos)) {
		if (GetLastError() == ERROR_INVALID_PARAMETER) {
			/* The console may be resized - retry */
			goto retry;
		}
		else {
			*error = GetLastError();
			return -1;
		}
	}

	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int OutputServer::tty_Reset(DWORD* error) {
	const COORD origin = {0, 0};
	const WORD char_attrs = FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_RED;
	CONSOLE_SCREEN_BUFFER_INFO info;
	DWORD count, written;

	if (*error != ERROR_SUCCESS) {
		return -1;
	}

	/* Reset original text attributes. */
	if (!SetConsoleTextAttribute(m_handle, char_attrs)) {
		*error = GetLastError();
		return -1;
	}

	/* Move the cursor position to (0, 0). */
	if (!SetConsoleCursorPosition(m_handle, origin)) {
		*error = GetLastError();
		return -1;
	}

	/* Clear the screen buffer. */
	retry:
	if (!GetConsoleScreenBufferInfo(m_handle, &info)) {
		*error = GetLastError();
		return -1;
	}

	count = info.dwSize.X * info.dwSize.Y;

	if (!(FillConsoleOutputCharacterW(m_handle,
								L'\x20',
								count,
								origin,
								&written) &&
			FillConsoleOutputAttribute(m_handle,
									char_attrs,
									written,
									origin,
									&written))) {
		if (GetLastError() == ERROR_INVALID_PARAMETER) {
		/* The console may be resized - retry */
		goto retry;
		}
		else {
			*error = GetLastError();
			return -1;
		}
	}

	/* Move the virtual window up to the top. */
	uv_tty_virtual_offset = 0;
	uv_tty_update_virtual_window(&info);

	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int OutputServer::ProcessMessage(const char* message, size_t length) {
	DWORD error = 0;

	/* We can only write 8k characters at a time. Windows can't handle */
	/* much more characters in a single console write anyway. */
	WCHAR utf16_buf[8192];
	DWORD utf16_buf_used = 0;

#define FLUSH_TEXT()                                                     \
	do {                                                                 \
		if (utf16_buf_used > 0) {                                        \
			tty_WriteTextW(m_handle, utf16_buf, utf16_buf_used, &error); \
			utf16_buf_used = 0;                                          \
		}                                                                \
	} while (0)

	/* Cache for fast access */
	unsigned char utf8_bytes_left = m_tty_context.utf8_bytes_left;
	unsigned int utf8_codepoint = m_tty_context.utf8_codepoint;
	unsigned char previous_eol = m_tty_context.previous_eol;
	unsigned char ansi_parser_state = m_tty_context.ansi_parser_state;

	/* Store the error here. If we encounter an error, stop trying to do i/o */
	/* but keep parsing the buffer so we leave the parser in a consistent */
	/* state. */
	error = ERROR_SUCCESS;

	for(unsigned int j = 0; j < length; j++) {
		unsigned char c = message[j];
		
		/* Run the character through the utf8 decoder We happily accept non */
		/* shortest form encodings and invalid code points - there's no real */
		/* harm that can be done. */
		if (utf8_bytes_left == 0) {
			/* Read utf-8 start byte */
			DWORD first_zero_bit;
			unsigned char not_c = ~c;
#ifdef _MSC_VER /* msvc */
			if (_BitScanReverse(&first_zero_bit, not_c)) {
#else /* assume gcc */
			if (c != 0) {
				first_zero_bit = (sizeof(int) * 8) - 1 - __builtin_clz(not_c);
#endif
				if (first_zero_bit == 7) {
					/* Ascii - pass right through */
					utf8_codepoint = (unsigned int) c;
				} 
				else if (first_zero_bit <= 5) {
					/* Multibyte sequence */
					utf8_codepoint = (0xff >> (8 - first_zero_bit)) & c;
					utf8_bytes_left = (char) (6 - first_zero_bit);
				}
				else {
					/* Invalid continuation */
					utf8_codepoint = UNICODE_REPLACEMENT_CHARACTER;
				}
			}
			else {
				/* 0xff -- invalid */
				utf8_codepoint = UNICODE_REPLACEMENT_CHARACTER;
			}
		}
		else if ((c & 0xc0) == 0x80) {
			/* Valid continuation of utf-8 multibyte sequence */
			utf8_bytes_left--;
			utf8_codepoint <<= 6;
			utf8_codepoint |= ((unsigned int) c & 0x3f);
		}
		else {
			/* Start byte where continuation was expected. */
			utf8_bytes_left = 0;
			utf8_codepoint = UNICODE_REPLACEMENT_CHARACTER;
			/* Patch buf offset so this character will be parsed again as a */
			/* start byte. */
			j--;
		}

		/* Maybe we need to parse more bytes to find a character. */
		if (utf8_bytes_left != 0) {
			continue;
		}

		/* Parse vt100/ansi escape codes */
		if (ansi_parser_state == ANSI_NORMAL) {
			switch (utf8_codepoint) {
			case '\033':
				ansi_parser_state = ANSI_ESCAPE_SEEN;
				continue;

			case 0233:
				ansi_parser_state = ANSI_CSI;
				m_tty_context.ansi_csi_argc = 0;
				continue;
			}
		}
		else if (ansi_parser_state == ANSI_ESCAPE_SEEN) {
			switch (utf8_codepoint) {
			case '[':
				ansi_parser_state = ANSI_CSI;
				m_tty_context.ansi_csi_argc = 0;
				continue;

			case '^':
			case '_':
			case 'P':
			case ']':
				/* Not supported, but we'll have to parse until we see a stop */
				/* code, e.g. ESC \ or BEL. */
				ansi_parser_state = ANSI_ST_CONTROL;
				continue;

			case '\033':
				/* Ignore double escape. */
				continue;

			case 'c':
				/* Full console reset. */
				FLUSH_TEXT();
				tty_Reset(&error);
				ansi_parser_state = ANSI_NORMAL;
				continue;

			case '7':
				/* Save the cursor position and text attributes. */
				FLUSH_TEXT();
				uv_tty_save_state(1, &error);
				ansi_parser_state = ANSI_NORMAL;
				continue;

			case '8':
				/* Restore the cursor position and text attributes */
				FLUSH_TEXT();
				uv_tty_restore_state(1, &error);
				ansi_parser_state = ANSI_NORMAL;
				continue;

			default:
				if (utf8_codepoint >= '@' && utf8_codepoint <= '_') {
					/* Single-char control. */
					ansi_parser_state = ANSI_NORMAL;
					continue;
				}
				else {
					/* Invalid - proceed as normal, */
					ansi_parser_state = ANSI_NORMAL;
				}
			}

		}
		else if (ansi_parser_state & ANSI_CSI) {
			if (!(ansi_parser_state & ANSI_IGNORE)) {
				if (utf8_codepoint >= '0' && utf8_codepoint <= '9') {
					/* Parsing a numerical argument */

					if (!(ansi_parser_state & ANSI_IN_ARG)) {
						/* We were not currently parsing a number */

						/* Check for too many arguments */
						if (m_tty_context.ansi_csi_argc >= ARRAY_SIZE(m_tty_context.ansi_csi_argv)) {
							ansi_parser_state |= ANSI_IGNORE;
							continue;
						}
						ansi_parser_state |= ANSI_IN_ARG;
						m_tty_context.ansi_csi_argc++;
						m_tty_context.ansi_csi_argv[m_tty_context.ansi_csi_argc - 1] = (unsigned short) utf8_codepoint - '0';
						continue;
					}
					else {
						/* We were already parsing a number. Parse next digit. */
						boost::uint32_t value = 10 * m_tty_context.ansi_csi_argv[m_tty_context.ansi_csi_argc - 1];

						/* Check for overflow. */
						if (value > USHRT_MAX) {//if (value > UINT16_MAX) {
							ansi_parser_state |= ANSI_IGNORE;
							continue;
						}
						m_tty_context.ansi_csi_argv[m_tty_context.ansi_csi_argc - 1] = (unsigned short) value + (utf8_codepoint - '0');
						continue;
					}

				}
				else if (utf8_codepoint == ';') {
					/* Denotes the end of an argument. */
					if (ansi_parser_state & ANSI_IN_ARG) {
						ansi_parser_state &= ~ANSI_IN_ARG;
						continue;
					}
					else {
						/* If ANSI_IN_ARG is not set, add another argument and */
						/* default it to 0. */
						/* Check for too many arguments */
						if (m_tty_context.ansi_csi_argc >= ARRAY_SIZE(m_tty_context.ansi_csi_argv)) {
							ansi_parser_state |= ANSI_IGNORE;
							continue;
						}
						m_tty_context.ansi_csi_argc++;
						m_tty_context.ansi_csi_argv[m_tty_context.ansi_csi_argc - 1] = 0;
						continue;
					}
				}
				else if (utf8_codepoint >= '@' && utf8_codepoint <= '~' && (m_tty_context.ansi_csi_argc > 0 || utf8_codepoint != '[')) {
					int x, y, d;

					/* Command byte */
					switch (utf8_codepoint) {
					case 'A':
						/* cursor up */
						FLUSH_TEXT();
						y = -(m_tty_context.ansi_csi_argc ? m_tty_context.ansi_csi_argv[0] : 1);
						uv_tty_move_caret(0, 1, y, 1, &error);
						break;

					case 'B':
						/* cursor down */
						FLUSH_TEXT();
						y = m_tty_context.ansi_csi_argc ? m_tty_context.ansi_csi_argv[0] : 1;
						uv_tty_move_caret(0, 1, y, 1, &error);
						break;

					case 'C':
						/* cursor forward */
						FLUSH_TEXT();
						x = m_tty_context.ansi_csi_argc ? m_tty_context.ansi_csi_argv[0] : 1;
						uv_tty_move_caret(x, 1, 0, 1, &error);
						break;

					case 'D':
						/* cursor back */
						FLUSH_TEXT();
						x = -(m_tty_context.ansi_csi_argc ? m_tty_context.ansi_csi_argv[0] : 1);
						uv_tty_move_caret(x, 1, 0, 1, &error);
						break;

					case 'E':
						/* cursor next line */
						FLUSH_TEXT();
						y = m_tty_context.ansi_csi_argc ? m_tty_context.ansi_csi_argv[0] : 1;
						uv_tty_move_caret(0, 0, y, 1, &error);
						break;

					case 'F':
						/* cursor previous line */
						FLUSH_TEXT();
						y = -(m_tty_context.ansi_csi_argc ? m_tty_context.ansi_csi_argv[0] : 1);
						uv_tty_move_caret(0, 0, y, 1, &error);
						break;

					case 'G':
						/* cursor horizontal move absolute */
						FLUSH_TEXT();
						x = (m_tty_context.ansi_csi_argc >= 1 && m_tty_context.ansi_csi_argv[0]) ? m_tty_context.ansi_csi_argv[0] - 1 : 0;
						uv_tty_move_caret(x, 0, 0, 1, &error);
						break;

					case 'H':
					case 'f':
						/* cursor move absolute */
						FLUSH_TEXT();
						y = (m_tty_context.ansi_csi_argc >= 1 && m_tty_context.ansi_csi_argv[0]) ? m_tty_context.ansi_csi_argv[0] - 1 : 0;
						x = (m_tty_context.ansi_csi_argc >= 2 && m_tty_context.ansi_csi_argv[1]) ? m_tty_context.ansi_csi_argv[1] - 1 : 0;
						uv_tty_move_caret(x, 0, y, 0, &error);
						break;

					case 'J':
						/* Erase screen */
						FLUSH_TEXT();
						d = m_tty_context.ansi_csi_argc ? m_tty_context.ansi_csi_argv[0] : 0;
						if (d >= 0 && d <= 2) {
							uv_tty_clear(d, 1, &error);
						}
						break;

					case 'K':
						/* Erase line */
						FLUSH_TEXT();
						d = m_tty_context.ansi_csi_argc ? m_tty_context.ansi_csi_argv[0] : 0;
						if (d >= 0 && d <= 2) {
							uv_tty_clear(d, 0, &error);
						}
						break;

					case 'm':
						/* Set style */
						FLUSH_TEXT();
						tty_SetStyle(&error);
						break;

					case 's':
						/* Save the cursor position. */
						FLUSH_TEXT();
						uv_tty_save_state(0, &error);
						break;

					case 'u':
						/* Restore the cursor position */
						FLUSH_TEXT();
						uv_tty_restore_state(0, &error);
						break;
					}

					/* Sequence ended - go back to normal state. */
					ansi_parser_state = ANSI_NORMAL;
					continue;

				}
				else {
					/* We don't support commands that use private mode characters or */
					/* intermediaries. Ignore the rest of the sequence. */
					ansi_parser_state |= ANSI_IGNORE;
					continue;
				}
			}
			else {
				/* We're ignoring this command. Stop only on command character. */
				if (utf8_codepoint >= '@' && utf8_codepoint <= '~') {
					ansi_parser_state = ANSI_NORMAL;
				}
				continue;
			}
		}
		else if (ansi_parser_state & ANSI_ST_CONTROL) {
			/* Unsupported control code */
			/* Ignore everything until we see BEL or ESC \ */
			if (ansi_parser_state & ANSI_IN_STRING) {
				if (!(ansi_parser_state & ANSI_BACKSLASH_SEEN)) {
					if (utf8_codepoint == '"') {
						ansi_parser_state &= ~ANSI_IN_STRING;
					}
					else if (utf8_codepoint == '\\') {
						ansi_parser_state |= ANSI_BACKSLASH_SEEN;
					}
				}
				else {
					ansi_parser_state &= ~ANSI_BACKSLASH_SEEN;
				}
			}
			else {
				if (utf8_codepoint == '\007' || (utf8_codepoint == '\\' && (ansi_parser_state & ANSI_ESCAPE_SEEN))) {
					/* End of sequence */
					ansi_parser_state = ANSI_NORMAL;
				}
				else if (utf8_codepoint == '\033') {
					/* Escape character */
					ansi_parser_state |= ANSI_ESCAPE_SEEN;
				}
				else if (utf8_codepoint == '"') {
					/* String starting */
					ansi_parser_state |= ANSI_IN_STRING;
					ansi_parser_state &= ~ANSI_ESCAPE_SEEN;
					ansi_parser_state &= ~ANSI_BACKSLASH_SEEN;
				}
				else {
					ansi_parser_state &= ~ANSI_ESCAPE_SEEN;
				}
			}
			continue;
		}
		else {
			/* Inconsistent state */
			LogFatal("OutputServer::ProcessMessage - Inconsistent state when processing output");
			abort();
		}

		/* We wouldn't mind emitting utf-16 surrogate pairs. Too bad, the */
		/* windows console doesn't really support UTF-16, so just emit the */
		/* replacement character. */
		if (utf8_codepoint > 0xffff) {
			utf8_codepoint = UNICODE_REPLACEMENT_CHARACTER;
		}

		if (utf8_codepoint == 0x0a || utf8_codepoint == 0x0d) {
			/* EOL conversion - emit \r\n, when we see either \r or \n. */
			/* If a \n immediately follows a \r or vice versa, ignore it. */
			if (previous_eol == 0 || utf8_codepoint == previous_eol) {
				/* If there's no room in the utf16 buf, flush it first. */
				if (2 > ARRAY_SIZE(utf16_buf) - utf16_buf_used) {
					tty_WriteTextW(m_handle, utf16_buf, utf16_buf_used, &error);
					utf16_buf_used = 0;
				}

				utf16_buf[utf16_buf_used++] = L'\r';
				utf16_buf[utf16_buf_used++] = L'\n';
				previous_eol = (char) utf8_codepoint;
			}
			else {
				/* Ignore this newline, but don't ignore later ones. */
				previous_eol = 0;
			}
		}
		else if (utf8_codepoint <= 0xffff) {
			/* Encode character into utf-16 buffer. */

			/* If there's no room in the utf16 buf, flush it first. */
			if (1 > ARRAY_SIZE(utf16_buf) - utf16_buf_used) {
				tty_WriteTextW(m_handle, utf16_buf, utf16_buf_used, &error);
				utf16_buf_used = 0;
			}

			utf16_buf[utf16_buf_used++] = (WCHAR) utf8_codepoint;
			previous_eol = 0;
		}
	}

	/* Flush remaining characters */
	FLUSH_TEXT();

	/* Copy cached values back to struct. */
	m_tty_context.utf8_bytes_left = utf8_bytes_left;
	m_tty_context.utf8_codepoint = utf8_codepoint;
	m_tty_context.previous_eol = previous_eol;
	m_tty_context.ansi_parser_state = ansi_parser_state;
	
	//LeaveCriticalSection(&uv_tty_output_lock);

	//if (error == STATUS_SUCCESS) {
	if (error == 0) {
		return 0;
	} else {
		return -1;
	}

#undef FLUSH_TEXT
};



OutputServer tty_output;
//boost::thread outputThread(output);
//static boost::shared_ptr<boost::asio::io_service::work> output_asio_work; 


static int WriteTTY (lua_State* L) {
	int fd = luaL_checkinteger(L, 1);
	const char* message = luaL_checkstring(L, 2);
	size_t size = lua_objlen(L, 2);

	// this allows to make stdout non-blocking
	/*boost::mutex::scoped_lock lock(m_lock);
	commands.push(message);
	m_haveEvent.notify_one();

	const char* msg = message.c_str();*/
	tty_output.ProcessMessage(message, size);
	return 0;
}

static int CloseTTY (lua_State* L) {
	int fd = luaL_checkinteger(L, 1);
	lua_pushinteger(L, _close(fd));
	return 1;
}

static int SetRawMode(lua_State* L) {
	if(lua_toboolean(L, 1) == false) {
		uv_tty_set_mode(&tty_input->m_tty_context, GetStdHandle(STD_INPUT_HANDLE), FALSE);
	}
	else {
		if(0 != uv_tty_set_mode(&tty_input->m_tty_context, GetStdHandle(STD_INPUT_HANDLE), TRUE)) {
		//if (0 != EnableRawMode(STDIN_FILENO)) {
			return luaL_error(L, "EnableRawMode");	//return ThrowException(ErrnoException(errno, "EnableRawMode"));
		}
	}
	//lua_pushboolean(L, rawmode);
	return 0;
}

// process.binding('stdio').getWindowSize(fd);
// returns [row, col]
static int GetWindowSize (lua_State* L) {
	int fd = luaL_checkinteger(L, 1);

	HANDLE handle = (HANDLE)_get_osfhandle(fd);

	CONSOLE_SCREEN_BUFFER_INFO info;
	if (!GetConsoleScreenBufferInfo(handle, &info)) {
		return luaL_error(L, "Error in GetConsoleScreenBufferInfo - %d", GetLastError());
	}

	lua_pushinteger(L, info.dwSize.X);
	lua_pushinteger(L, info.dwSize.Y);
	return 2;
}

//////////////////////////////////////////////////////////////////////////
/// 
static int InitTTYWatcher (lua_State* L)
{
	if(tty_watcher_initialized) {
		return luaL_error(L, "TTY watcher already initialized");
	}

	int fd = luaL_checkinteger(L, 1);
	tty_handle = (HANDLE)_get_osfhandle(fd);

	luaL_checktype(L, 2, LUA_TFUNCTION);
	lua_pushvalue(L, 2);
	int tty_error_callback = luaL_ref(L, LUA_REGISTRYINDEX);

	if(lua_type(L, 3) == LUA_TFUNCTION) {
		lua_pushvalue(L, 3);
		tty_keypress_callback = luaL_ref(L, LUA_REGISTRYINDEX);
	}

	if(lua_type(L, 4) == LUA_TFUNCTION) {
		lua_pushvalue(L, 4);
		tty_resize_callback = luaL_ref(L, LUA_REGISTRYINDEX);
	}

	tty_input = boost::make_shared<InputServer>();

	tty_watcher_initialized = true;
	tty_wait_handle = NULL;

	return 0;
}


static int StartTTYWatcher (lua_State* L) {
	if(!tty_watcher_initialized) {
		return luaL_error(L, "TTY watcher not initialized");
	}

	if(tty_reader_thread == NULL) {
		tty_input->m_run = true;
		tty_reader_thread = boost::make_shared<boost::thread>(&InputServer::Run, tty_input);
		if(input_asio_work == NULL) {
			input_asio_work = boost::make_shared<boost::asio::io_service::work>(boost::ref(LuaNode::GetIoService()));
		}
	}
	return 0;
}

static int StopTTYWatcher (/*lua_State* L*/) {
	// hacky way of stopping the thread
	if(tty_watcher_initialized) {
		tty_input->m_run = false;
		DWORD dwWritten;
		INPUT_RECORD record;
		record.EventType = FOCUS_EVENT;
		record.Event.FocusEvent.bSetFocus = false;	// sera inocuo mandar esto?
		::WriteConsoleInput(GetStdHandle(STD_INPUT_HANDLE), &record, 1, &dwWritten);

		// don't join it, just let it go away
		tty_reader_thread.reset();
		input_asio_work.reset();
	}
	return 0;
}

static int StopTTYWatcher_ (lua_State* L) {
	StopTTYWatcher();
	return 0;
}

static int DestroyTTYWatcher (lua_State* L) {
	if(!tty_watcher_initialized) {
		return luaL_error(L, "TTY watcher not initialized");
	}

	StopTTYWatcher(/*L*/);

	if(tty_error_callback != LUA_NOREF) {
		luaL_unref(L, LUA_REGISTRYINDEX, tty_error_callback);
	}
	if(tty_keypress_callback != LUA_NOREF) {
		luaL_unref(L, LUA_REGISTRYINDEX, tty_keypress_callback);
	}
	if(tty_resize_callback != LUA_NOREF) {
		luaL_unref(L, LUA_REGISTRYINDEX, tty_resize_callback);
	}

	tty_input.reset();
	tty_watcher_initialized = false;

	return 0;
}


/*
 * Flush stdout and stderr on node exit
 * Not necessary on windows, so a no-op
 */
void LuaNode::Stdio::Flush() {
}

/////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Stdio::RegisterFunctions (lua_State* L) {
	luaL_Reg methods[] = {
		{ "isatty", IsATTY },
		{ "writeError", WriteError },
		{ "openStdin", OpenStdin },
		{ "writeTTY", WriteTTY },	// windows only
		{ "closeTTY", CloseTTY },
		{ "isStdoutBlocking", IsStdoutBlocking },
		{ "isStdinBlocking", IsStdinBlocking },
		{ "getWindowSize", GetWindowSize },
		{ "initTTYWatcher", InitTTYWatcher },
		{ "destroyTTYWatcher", DestroyTTYWatcher },
		{ "startTTYWatcher", StartTTYWatcher },
		{ "stopTTYWatcher", StopTTYWatcher_ },
		{ "setRawMode", SetRawMode },
		{ 0, 0 }
	};
	luaL_register(L, "Stdio", methods);
	int table = lua_gettop(L);

	lua_pushinteger(L, _fileno(stdout));
	lua_setfield(L, table, "stdoutFD");

	lua_pushinteger(L, _fileno(stdin));
	lua_setfield(L, table, "stdinFD");

	lua_pushinteger(L, _fileno(stderr));
	lua_setfield(L, table, "stderrFD");
	lua_pop(L, 1);
}

//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Stdio::OnExit (/*lua_State* L*/) {
	StopTTYWatcher(/*L*/);
	if(tty_input) {
		uv_tty_set_mode(&tty_input->m_tty_context, GetStdHandle(STD_INPUT_HANDLE), FALSE);
	}
}