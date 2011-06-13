#include "stdafx.h"
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


/* TTY watcher data */
static bool tty_watcher_initialized = false;
static HANDLE tty_handle;
static HANDLE tty_wait_handle;
static int tty_error_callback = LUA_NOREF;
static int tty_keypress_callback = LUA_NOREF;
static int tty_resize_callback = LUA_NOREF;


static void ReadConsoleHandler (std::vector<INPUT_RECORD> records, DWORD numRecords) {
	// Process the events
	for(unsigned int i = 0; i < numRecords; i++) {
		INPUT_RECORD& record = records[i];
		switch(record.EventType) {
			case KEY_EVENT: {
				if(!tty_keypress_callback) {
					continue;
				}
				KEY_EVENT_RECORD& keyRecord = record.Event.KeyEvent; 
				if(!keyRecord.bKeyDown) {
					// Ignore keyup
					continue;
				}

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
}

class InputServer {
public:
InputServer() {};

volatile bool m_run;	// hack!

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
				LuaNode::GetIoService().post( boost::bind(ReadConsoleHandler, inRecords, dwRead) );
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

static int StopTTYWatcher (lua_State* L) {
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

static int DestroyTTYWatcher (lua_State* L) {
	if(!tty_watcher_initialized) {
		return luaL_error(L, "TTY watcher not initialized");
	}

	StopTTYWatcher(L);

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
		{ "stopTTYWatcher", StopTTYWatcher },
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
void LuaNode::Stdio::OnExit (lua_State* L) {
	StopTTYWatcher(L);
}