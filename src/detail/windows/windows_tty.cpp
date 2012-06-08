#include "stdafx.h"
#include "windows_tty.h"
#include "../../blogger.h"

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