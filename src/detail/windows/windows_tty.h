#pragma once

#include <windows.h>

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

#define UNICODE_REPLACEMENT_CHARACTER (0xfffd)

#define ANSI_NORMAL           0x00
#define ANSI_ESCAPE_SEEN      0x02
#define ANSI_CSI              0x04
#define ANSI_ST_CONTROL       0x08
#define ANSI_IGNORE           0x10
#define ANSI_IN_ARG           0x20
#define ANSI_IN_STRING        0x40
#define ANSI_BACKSLASH_SEEN   0x80

#define UV_HANDLE_TTY_SAVED_POSITION            0x00400000
#define UV_HANDLE_TTY_SAVED_ATTRIBUTES          0x00800000

#define UV_HANDLE_TTY_RAW                       0x00080000


int uv_tty_set_mode(tty_context_t* tty, HANDLE handle, int mode);

