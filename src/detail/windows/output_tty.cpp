#include "stdafx.h"

#include "output_tty.h"

#include <boost/cstdint.hpp>
#include "../../blogger.h"
#include <io.h>	/* needed for _isatty, _close, _get_osfhandle */

using namespace LuaNode::detail::windows;


// Good info:
// http://www.benryves.com/tutorials/winconsole/all



static int uv_tty_virtual_offset = -1;
static int uv_tty_virtual_height = -1;
static int uv_tty_virtual_width = -1;


#define ARRAY_SIZE(a) (sizeof((a)) / sizeof((a)[0]))

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


const char* OutputTtyStream::className = "OutputTtyStream";
const char* OutputTtyStream::get_full_class_name_T() { return "LuaNode.core.OutputTtyStream"; };
const OutputTtyStream::RegType OutputTtyStream::methods[] = {
	//{"setRawMode", &OutputTtyStream::SetRawMode},
	{"write", &OutputTtyStream::Write},
	{"getWindowSize", &OutputTtyStream::GetWindowSize},
	//{"read", &InputTtyStream::Read},
	//{"pause", &InputTtyStream::Pause},
	{0}
};

const OutputTtyStream::RegType OutputTtyStream::setters[] = {
	{0}
};

const OutputTtyStream::RegType OutputTtyStream::getters[] = {
	{0}
};


//////////////////////////////////////////////////////////////////////////
/// 
OutputTtyStream::OutputTtyStream(lua_State* L)
{
	int fd = luaL_checkinteger(L, 1);
	if(fd == _fileno(stdout)) {
		m_handle = GetStdHandle(STD_OUTPUT_HANDLE);
	}
	else if(fd == _fileno(stderr)) {
		m_handle = GetStdHandle(STD_ERROR_HANDLE);
	}
	else {
		luaL_error(L, "invalid fd");
	}

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
}

//////////////////////////////////////////////////////////////////////////
/// 
int OutputTtyStream::Write (lua_State* L) {
	const char* message = luaL_checkstring(L, 2);
	size_t size = lua_objlen(L, 2);

	ProcessMessage(message, size);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
int OutputTtyStream::tty_SetStyle(DWORD* error) {
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
int OutputTtyStream::uv_tty_clear(int dir, char entire_screen, DWORD* error) {
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
int OutputTtyStream::uv_tty_save_state(unsigned char save_attributes, DWORD* error) {
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
int OutputTtyStream::uv_tty_restore_state(unsigned char restore_attributes, DWORD* error) {
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
/*static*/
void OutputTtyStream::uv_tty_update_virtual_window(CONSOLE_SCREEN_BUFFER_INFO* info)
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
COORD OutputTtyStream::uv_tty_make_real_coord(CONSOLE_SCREEN_BUFFER_INFO* info, int x, unsigned char x_relative, int y, unsigned char y_relative) {
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
int OutputTtyStream::uv_tty_move_caret(int x, unsigned char x_relative, int y, unsigned char y_relative, DWORD* error) {
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
int OutputTtyStream::tty_Reset(DWORD* error) {
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
int OutputTtyStream::ProcessMessage(const char* message, size_t length) {
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
			LogFatal("OutputTtyStream::ProcessMessage - Inconsistent state when processing output");
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

//////////////////////////////////////////////////////////////////////////
/// returns [row, col]
int OutputTtyStream::GetWindowSize (lua_State* L) {

	CONSOLE_SCREEN_BUFFER_INFO info;
	if (!::GetConsoleScreenBufferInfo(m_handle, &info)) {
		return luaL_error(L, "Error in GetConsoleScreenBufferInfo - %d", GetLastError());
	}

	uv_tty_update_virtual_window(&info);

	lua_pushinteger(L, info.dwSize.X);
	lua_pushinteger(L, info.dwSize.Y);
	return 2;
}
