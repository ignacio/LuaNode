#include "stdafx.h"

#include "../../luanode.h"
#include "input_tty.h"
#include <boost/bind.hpp>
#include <boost/make_shared.hpp>


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


using namespace LuaNode::detail::windows;

const char* InputTtyStream::className = "InputTtyStream";
const char* InputTtyStream::get_full_class_name_T() { return "LuaNode.core.InputTtyStream"; };
const InputTtyStream::RegType InputTtyStream::methods[] = {
	{"setRawMode", &InputTtyStream::SetRawMode},
	//{"write", &TtyStream::Write},
	{"read", &InputTtyStream::Read},
	{"pause", &InputTtyStream::Pause},
	{"close", &InputTtyStream::Close},
	{0}
};

const InputTtyStream::RegType InputTtyStream::setters[] = {
	{0}
};

const InputTtyStream::RegType InputTtyStream::getters[] = {
	{0}
};

//////////////////////////////////////////////////////////////////////////
/// 
InputTtyStream::InputTtyStream(lua_State* L) : 
	m_handle(::GetStdHandle(STD_INPUT_HANDLE))
{
	m_tty_context.flags = 0;

	if (!::GetConsoleMode(m_handle, &m_tty_context.original_console_mode)) {
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

void InputTtyStream::PostConstruct(lua_State* L) {
	lua_pushvalue(L, -1);
	m_self_reference = luaL_ref(L, LUA_REGISTRYINDEX);
}

InputTtyStream::~InputTtyStream() {
	// disable raw mode
	uv_tty_set_mode(&m_tty_context, m_handle, FALSE);
	Stop();
}

//////////////////////////////////////////////////////////////////////////
/// 
void InputTtyStream::Run() {
	while(m_run) {
		// Read pending events
		DWORD dwRead = 0;
		std::vector<INPUT_RECORD> inRecords(128);
		if(::ReadConsoleInput(m_handle, &inRecords[0], 128, &dwRead)) {
			if(dwRead == 1 && (inRecords[0].EventType == FOCUS_EVENT)) {
				continue;
			}

			if(dwRead > 0) {
				LuaNode::GetIoService().post( boost::bind(&InputTtyStream::ReadConsoleHandler, this, m_tty_context, inRecords, dwRead) );
			}
		}
		else {
			if(GetLastError() == ERROR_INVALID_HANDLE) {
				m_input_asio_work.reset();
				break;
			}
			fprintf(stderr, "Error in ReadConsoleInput - %d\n", GetLastError());
			break;
		}
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
void InputTtyStream::Start() {
	if(m_tty_reader_thread == NULL) {
		m_run = true;
		m_tty_reader_thread = boost::make_shared<boost::thread>(&InputTtyStream::Run, this);
		if(m_input_asio_work == NULL) {
			m_input_asio_work = boost::make_shared<boost::asio::io_service::work>(boost::ref(LuaNode::GetIoService()));
		}
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
void InputTtyStream::Stop() {
	// hacky way of stopping the thread
	if(!m_run) {
		return;
	}
	m_run = false;
	
	DWORD dwWritten;
	INPUT_RECORD record;
	record.EventType = FOCUS_EVENT;
	record.Event.FocusEvent.bSetFocus = false;	// sera inocuo mandar esto?
	::WriteConsoleInput(m_handle, &record, 1, &dwWritten);

	// don't join it, just let it go away
	m_tty_reader_thread.reset();
	m_input_asio_work.reset();
}

//////////////////////////////////////////////////////////////////////////
/// 
int InputTtyStream::Read (lua_State* L) {
	Start();
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int InputTtyStream::Pause (lua_State* L) {

	m_run = false;
	DWORD dwWritten;
	INPUT_RECORD record;
	record.EventType = FOCUS_EVENT;
	record.Event.FocusEvent.bSetFocus = false;	// sera inocuo mandar esto?
	::WriteConsoleInput(m_handle, &record, 1, &dwWritten);
	
	m_tty_reader_thread->join();
	m_tty_reader_thread.reset();
	
	m_input_asio_work.reset();
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int InputTtyStream::Close (lua_State* L) {
	Stop();
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int InputTtyStream::SetRawMode (lua_State* L) {
	if(lua_toboolean(L, 2) == false) {
		uv_tty_set_mode(&m_tty_context, m_handle, FALSE);
	}
	else {
		if(0 != uv_tty_set_mode(&m_tty_context, m_handle, TRUE)) {
			return luaL_error(L, "SetRawMode failed");
		}
	}
	//lua_pushboolean(L, rawmode);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static */
void InputTtyStream::ReadConsoleHandler (tty_context_t& tty_context, std::vector<INPUT_RECORD> records, DWORD numRecords)
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
					/*if(!tty_resize_callback) {
						continue;
					}*/
					/*CLuaVM& vm = LuaNode::GetLuaVM();
					//lua_rawgeti(vm, LUA_REGISTRYINDEX, tty_resize_callback);
					COORD size = record.Event.WindowBufferSizeEvent.dwSize;
					lua_pushinteger(vm, size.X);
					lua_pushinteger(vm, size.Y);
					vm.call(2, LUA_MULTRET);
					lua_settop(vm, 0);*/

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
		//fprintf(stderr, "function key pressed: '%s'\n", lua_tostring(vm, -1));
		lua_rawgeti(vm, LUA_REGISTRYINDEX, m_self_reference);
		lua_getfield(vm, 1, "read_callback");
		if(lua_type(vm, 2) == LUA_TFUNCTION) {
			lua_pushvalue(vm, 1);
			luaL_pushresult(&buffer);
			LuaNode::GetLuaVM().call(2, LUA_MULTRET);
		}
		else {
			// do nothing?
			if(lua_type(vm, 1) == LUA_TUSERDATA) {
				userdataType* ud = static_cast<userdataType*>(lua_touserdata(vm, 1));
				//LogWarning("TtyStream::HandleReadSome (%p) (id:%u) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_fd, luaL_typename(vm, 1), ud, ud->pT);
			}
			else {
				//LogWarning("TtyStream::HandleReadSome (%p) (id:%u) - No read_callback set on %s", this, m_fd, luaL_typename(vm, 1));
			}
		}

		//lua_insert(vm, -2);

		//vm.call(1, LUA_MULTRET);
		lua_settop(vm, 0);
	}
}
