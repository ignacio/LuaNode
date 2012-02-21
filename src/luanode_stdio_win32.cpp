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


/* TTY watcher data */
static bool tty_watcher_initialized = false;
static HANDLE tty_handle;
static HANDLE tty_wait_handle;
static int tty_error_callback = LUA_NOREF;
static int tty_keypress_callback = LUA_NOREF;
static int tty_resize_callback = LUA_NOREF;

typedef struct tty_context_t {
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
} tty_context_t;


static const char* get_vt100_fn_key(DWORD code, char shift, char ctrl,
									size_t* len) {
#define VK_CASE(vk, normal_str, shift_str, ctrl_str, shift_ctrl_str)          \
	case (vk):                                                                \
	if (shift && ctrl) {                                                    \
	*len = sizeof shift_ctrl_str;                                         \
	return "\033" shift_ctrl_str;                                         \
	} else if (shift) {                                                     \
	*len = sizeof shift_str ;                                             \
	return "\033" shift_str;                                              \
	} else if (ctrl) {                                                      \
	*len = sizeof ctrl_str;                                               \
	return "\033" ctrl_str;                                               \
} else {                                                                \
	*len = sizeof normal_str;                                             \
	return "\033" normal_str;                                             \
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

static void ReadConsoleHandler (tty_context_t& tty_context, std::vector<INPUT_RECORD> records, DWORD numRecords) {
	// Process the events
	unsigned int i = 0;
	DWORD records_left = numRecords;
	off_t buf_used = 0;
	luaL_Buffer buffer;

	CLuaVM& vm = LuaNode::GetLuaVM();

	while( (records_left > 0 || tty_context.last_key_len > 0)  ) {
	//for(unsigned int i = 0; i < numRecords; i++) {
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
					/*if(!keyRecord.bKeyDown) {
						// Ignore keyup
						continue;
					}*/
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
					
						/* Prefix with \u033 if alt was held, but alt was not used as part */
						/* a compose sequence. */
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
							////Phandle->flags &= ~UV_HANDLE_READING;
							////Phandle->read_cb((uv_stream_t*) handle, -1, buf);
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

						/* Prefix with \x033 when the alt key was held. */
						if (keyRecord.dwControlKeyState & (LEFT_ALT_PRESSED | RIGHT_ALT_PRESSED)) {
							tty_context.last_key[0] = '\033';
							prefix_len = 1;
						}
						else {
							prefix_len = 0;
						}

						/* Copy the vt100 sequence to the handle buffer. */
						assert(prefix_len + vt100_len < sizeof handle->last_key);
						memcpy(&tty_context.last_key[prefix_len], vt100, vt100_len);
	
						tty_context.last_key_len = (unsigned char) (prefix_len + vt100_len);
						tty_context.last_key_offset = 0;
						continue;
					}
				/*{
					CLuaVM& vm = LuaNode::GetLuaVM();
					lua_rawgeti(vm, LUA_REGISTRYINDEX, tty_keypress_callback);

					lua_pushinteger(vm, keyRecord.uChar.AsciiChar);
					
					lua_newtable(vm);
					int table = lua_gettop(vm);

					lua_pushinteger(vm, keyRecord.wVirtualKeyCode);
					lua_setfield(vm, table, "virtualKeyCode");

					lua_pushinteger(vm, keyRecord.wVirtualScanCode);
					lua_setfield(vm, table, "virtualScanCode");

					lua_pushstring(vm, "nombre tecla");
					lua_setfield(vm, table, "name");

					lua_pushboolean(vm, (keyRecord.dwControlKeyState & SHIFT_PRESSED));
					lua_setfield(vm, table, "shift");

					lua_pushboolean(vm, (keyRecord.dwControlKeyState & LEFT_CTRL_PRESSED) || (keyRecord.dwControlKeyState & RIGHT_CTRL_PRESSED));
					lua_setfield(vm, table, "ctrl");

					lua_pushboolean(vm, (keyRecord.dwControlKeyState & LEFT_ALT_PRESSED) || (keyRecord.dwControlKeyState & RIGHT_ALT_PRESSED));
					lua_setfield(vm, table, "meta");

					vm.call(2, LUA_MULTRET);
					lua_settop(vm, 0);
				}*/
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

				/*case MENU_EVENT:
					printf("MENU_EVENT\n");
				break;

				case MOUSE_EVENT:
					printf("MOUSE_EVENT\n");
				break;
		
				case FOCUS_EVENT:
					printf("FOCUS_EVENT\n");
				break;*/
			}
		}
		else {
			/* Copy any bytes left from the last keypress to the user buffer. */
			if (tty_context.last_key_offset < tty_context.last_key_len) {
				/* Allocate a buffer if needed */
				if(buf_used == 0) {
					luaL_buffinit(vm, &buffer);
				}
				/*if (buf_used == 0) {
					buf = handle->alloc_cb((uv_handle_t*) handle, 1024);
				}*/

				//buf.base[buf_used++] = tty_context.last_key[tty_context.last_key_offset++];
				buf_used++;
				luaL_addchar(&buffer, tty_context.last_key[tty_context.last_key_offset++]);

				/* If the buffer is full, emit it */
				/*if (buf_used == buf.len) {
					handle->read_cb((uv_stream_t*) handle, buf_used, buf);
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
		//}
	}

	if(buf_used > 0) {
		luaL_pushresult(&buffer);
		lua_rawgeti(vm, LUA_REGISTRYINDEX, tty_keypress_callback);
		lua_insert(vm, -2);

		/*lua_pushinteger(vm, keyRecord.uChar.AsciiChar);

		lua_newtable(vm);
		int table = lua_gettop(vm);

		lua_pushinteger(vm, keyRecord.wVirtualKeyCode);
		lua_setfield(vm, table, "virtualKeyCode");

		lua_pushinteger(vm, keyRecord.wVirtualScanCode);
		lua_setfield(vm, table, "virtualScanCode");

		lua_pushstring(vm, "nombre tecla");
		lua_setfield(vm, table, "name");

		lua_pushboolean(vm, (keyRecord.dwControlKeyState & SHIFT_PRESSED));
		lua_setfield(vm, table, "shift");

		lua_pushboolean(vm, (keyRecord.dwControlKeyState & LEFT_CTRL_PRESSED) || (keyRecord.dwControlKeyState & RIGHT_CTRL_PRESSED));
		lua_setfield(vm, table, "ctrl");

		lua_pushboolean(vm, (keyRecord.dwControlKeyState & LEFT_ALT_PRESSED) || (keyRecord.dwControlKeyState & RIGHT_ALT_PRESSED));
		lua_setfield(vm, table, "meta");*/

		vm.call(1, LUA_MULTRET);
		lua_settop(vm, 0);
	}
}

class InputServer {
public:
	InputServer() {
	//char last_key[8];

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
	//unsigned char ansi_csi_argc;
	//unsigned short ansi_csi_argv[4];
	//COORD saved_position;
	//WORD saved_attributes;
};

volatile bool m_run;	// hack!

tty_context_t m_tty_context;

void Run() {
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

};

// ugh! remove this globals...
InputServer input;
static boost::shared_ptr<boost::thread> tty_reader_thread;
static boost::shared_ptr<boost::asio::io_service::work> asio_work; 

//////////////////////////////////////////////////////////////////////////
/// TODO: this is the same on luanode_stdio_linux.cpp
static int IsATTY (lua_State* L) {
	int fd = luaL_checkinteger(L, 1);

	lua_pushboolean(L, _isatty(fd));

	return 1;
}

static int WriteError (lua_State* L) {
	if(lua_gettop(L) == 0) {
		// do nothing
		return 0;
	}
	const char* message = luaL_checkstring(L, 1);
	fprintf(stderr, "%s", message);
	return 0;
}

static int OpenStdin (lua_State* L) {
	//setRawMode(0); // init into nonraw mode
	lua_pushinteger(L, _fileno(stdin));
	return 1;
}


static int IsStdinBlocking (lua_State* L) {
	// On windows stdin always blocks
	lua_pushboolean(L, true);
	return 1;
}


static int IsStdoutBlocking (lua_State* L) {
	// On windows stdout always blocks
	lua_pushboolean(L, true);
	return 1;
}


boost::mutex m_lock;
boost::condition_variable m_haveEvent;
std::queue<std::string> commands;

struct OutputServer {	

void operator () () {
	while (1) {
		std::string message;
		{
			boost::unique_lock<boost::mutex> lock(m_lock);
			m_haveEvent.wait(lock);
			while(!commands.empty()) {
				message = commands.front();
				commands.pop();
				fprintf(stdout, "%s", message.c_str());
			}
		}
		//fprintf(stdout, "%s", message.c_str());
		///while (!commands.push(command))				;
		// spin till the main thread consumes a queue entry		
	}	
}

};


OutputServer output;
boost::thread outputThread(output);



static int WriteTTY (lua_State* L) {
	int fd = luaL_checkinteger(L, 1);
	const char* message = luaL_checkstring(L, 2);
	size_t size = lua_objlen(L, 2);

	boost::mutex::scoped_lock lock(m_lock);
	commands.push(message);
	m_haveEvent.notify_one();

	/*commands.push()

	HANDLE h = (HANDLE)_get_osfhandle(fd);
	DWORD dwWritten;
	OVERLAPPED over = {0};
	//over.
	//WriteFile(h, message, size, &dwWritten, NULL);
	BOOL res = WriteFileEx(h, message, size, &over, FileIOCompletionRoutine);
	printf("%d", GetLastError() );*/
	return 0;
}

static int CloseTTY (lua_State* L) {
	int fd = luaL_checkinteger(L, 1);
	lua_pushinteger(L, _close(fd));
	return 1;
}


// process.binding('stdio').setRawMode(true);
/*static Handle<Value> SetRawMode (const Arguments& args) {
	HandleScope scope;

	if (args[0]->IsFalse()) {
		Stdio::DisableRawMode(STDIN_FILENO);
	} else {
		if (0 != EnableRawMode(STDIN_FILENO)) {
			return ThrowException(ErrnoException(errno, "EnableRawMode"));
		}
	}

	return rawmode ? True() : False();
}-*

/*static void LuaNode::Stdio::DisableRawMode(int fd) {
	setRawMode
}*/

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


/* moveCursor(fd, dx, dy) */
/* cursorTo(fd, x, y) */
template<bool relative>
static int SetCursor (lua_State* L) {
	int fd = luaL_checkinteger(L, 1);

	HANDLE handle = (HANDLE)_get_osfhandle(fd);

	CONSOLE_SCREEN_BUFFER_INFO info;
	if (!GetConsoleScreenBufferInfo(handle, &info)) {
		return luaL_error(L, "Error in GetConsoleScreenBufferInfo - %d", GetLastError());
	}

	COORD pos = info.dwCursorPosition;
	if(relative) {
		if(lua_isnumber(L, 2)) {
			pos.X += static_cast<short>(lua_tointeger(L, 2));
		}
		if(lua_isnumber(L, 3)) {
			pos.Y += static_cast<short>(lua_tointeger(L, 3));
		}
	}
	else {
		if(lua_isnumber(L, 2)) {
			pos.X = static_cast<short>(lua_tointeger(L, 2));
		}
		if(lua_isnumber(L, 3)) {
			pos.Y = static_cast<short>(lua_tointeger(L, 3));
		}
	}

	COORD size = info.dwSize;
	if(pos.X >= size.X) {
		pos.X = size.X - 1;
	}
	if(pos.X < 0) {
		pos.X = 0;
	}
	if(pos.Y >= size.Y) {
		pos.Y = size.Y - 1;
	}
	if(pos.Y < 0) {
		pos.Y = 0;
	}

	if(!::SetConsoleCursorPosition(handle, pos)) {
		return luaL_error(L, "Error in SetConsoleCursorPosition - %d", GetLastError());
	}
	return 0;
}


/*
 * ClearLine(fd, direction)
 * direction:
 *   -1: from cursor leftward
 *    0: entire line
 *    1: from cursor to right
 */
static int ClearLine (lua_State* L) {
	int fd = luaL_checkinteger(L, 1);
	HANDLE handle = (HANDLE)_get_osfhandle(fd);

	int dir = (int)luaL_optnumber(L, 2, 0);

	CONSOLE_SCREEN_BUFFER_INFO info;
	if(!::GetConsoleScreenBufferInfo(handle, &info)) {
	    return luaL_error(L, "Error in GetConsoleScreenBufferInfo - %d", GetLastError());
	}

	short x1 = dir <= 0 ? 0 : info.dwCursorPosition.X;
	short x2 = dir >= 0 ? info.dwSize.X - 1: info.dwCursorPosition.X;
	short count = x2 - x1 + 1;

	if (x1 != info.dwCursorPosition.X) {
		COORD pos;
		pos.Y = info.dwCursorPosition.Y;
		pos.X = x1;
		if(!::SetConsoleCursorPosition(handle, pos)) {
			return luaL_error(L, "Error in SetConsoleCursorPosition - %d", GetLastError());
		}
	}

	DWORD oldMode;
	if(!::GetConsoleMode(handle, &oldMode)) {
		return luaL_error(L, "Error in GetConsoleMode - %d", GetLastError());
	}

	// Disable wrapping at eol because otherwise windows scrolls the console
	// when clearing the last line of the console
	DWORD mode = oldMode & ~ENABLE_WRAP_AT_EOL_OUTPUT;
	if(!::SetConsoleMode(handle, mode)) {
		return luaL_error(L, "Error in SetConsoleMode - %d", GetLastError());
	}

	std::vector<WCHAR> buf(count);

	for (short i = 0; i < count; i++) {
	    buf[i] = L' ';
	}

	DWORD written;
	if(!::WriteConsoleW(handle, &buf[0], count, &written, NULL)) {
		return luaL_error(L, "Error in WriteConsole - %d", GetLastError());
	}

	if(!::SetConsoleCursorPosition(handle, info.dwCursorPosition)) {
		return luaL_error(L, "Error in SetConsoleCursorPosition - %d", GetLastError());
	}

	if(!::SetConsoleMode(handle, oldMode)) {
		return luaL_error(L, "Error in SetConsoleMode - %d", GetLastError());
	}
	return 0;
}


static int InitTTYWatcher (lua_State* L) {
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

	tty_watcher_initialized = true;
	tty_wait_handle = NULL;

	return 0;
}


static int StartTTYWatcher (lua_State* L) {
	if(!tty_watcher_initialized) {
		return luaL_error(L, "TTY watcher not initialized");
	}

	if(tty_reader_thread == NULL) {
		input.m_run = true;
		tty_reader_thread = boost::make_shared<boost::thread>(&InputServer::Run, &input);
		if(asio_work == NULL) {
			asio_work = boost::make_shared<boost::asio::io_service::work>(boost::ref(LuaNode::GetIoService()));
		}
	}
	return 0;
}

static int StopTTYWatcher (/*lua_State* L*/) {
	// hacky way of stopping the thread
	input.m_run = false;
	DWORD dwWritten;
	INPUT_RECORD record;
	record.EventType = FOCUS_EVENT;
	record.Event.FocusEvent.bSetFocus = false;	// sera inocuo mandar esto?
	::WriteConsoleInput(GetStdHandle(STD_INPUT_HANDLE), &record, 1, &dwWritten);
	tty_reader_thread.reset();
	asio_work.reset();
	// don't join it, just let it go away
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
		{ "moveCursor", SetCursor<true> },
		{ "cursorTo", SetCursor<false> },
		{ "clearLine", ClearLine },
		{ "getWindowSize", GetWindowSize },
		{ "initTTYWatcher", InitTTYWatcher },
		{ "destroyTTYWatcher", DestroyTTYWatcher },
		{ "startTTYWatcher", StartTTYWatcher },
		{ "stopTTYWatcher", StopTTYWatcher_ },
		//{ "setRawMode", SetRawMode },
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
}