#include "stdafx.h"
#include "luanode.h"
#include "luanode_stdio.h"
#include "blogger.h"

//////////////////////////////////////////////////////////////////////////
/// Most of the following code was taken from Node.js

#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>
#if defined(__APPLE__) || defined(__OpenBSD__)
# include <util.h>
#elif __FreeBSD__
# include <libutil.h>
#elif defined(__sun)
# include <stropts.h> // for openpty ioctls
#else
# include <pty.h>
#endif

#include <termios.h>
#include <sys/ioctl.h>
#include <stdlib.h>

#include <boost/asio.hpp>
#include <boost/bind.hpp>
#include <boost/make_shared.hpp>

#include <signal.h>

static int stdout_flags = -1;
static int stdin_flags = -1;

static struct termios orig_termios; /* in order to restore at exit */
static int rawmode = 0; /* for atexit() function to check if restore is needed*/

//////////////////////////////////////////////////////////////////////////
/// 
static int EnableRawMode(int fd) {
	struct termios raw;

	if (rawmode) return 0;

	//if (!isatty(fd)) goto fatal;
	if (tcgetattr(fd, &orig_termios) == -1) goto fatal;

	raw = orig_termios;  /* modify the original mode */
	/* input modes: no break, no CR to NL, no parity check, no strip char,
	* no start/stop output control. */
	raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
	/* output modes */
	raw.c_oflag |= (ONLCR);
	/* control modes - set 8 bit chars */
	raw.c_cflag |= (CS8);
	/* local modes - choing off, canonical off, no extended functions,
	* no signal chars (^Z,^C) */
	raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
	/* control chars - set return condition: min number of bytes and timer.
	* We want read to return every single byte, without timeout. */
	raw.c_cc[VMIN] = 1; raw.c_cc[VTIME] = 0; /* 1 byte, no timer */

	/* put terminal in raw mode after flushing */
	if (tcsetattr(fd, TCSAFLUSH, &raw) < 0) goto fatal;
	rawmode = 1;
	return 0;

fatal:
	errno = ENOTTY;
	return -1;
}

void LuaNode::Stdio::DisableRawMode(int fd) {
	/* Don't even check the return value as it's too late. */
	if (rawmode && tcsetattr(fd, TCSAFLUSH, &orig_termios) != -1) {
		rawmode = 0;
	}
}

// process.binding('stdio').setRawMode(true);
static int SetRawMode (lua_State* L) {
	if(lua_toboolean(L, 1) == false) {
		LuaNode::Stdio::DisableRawMode(STDIN_FILENO);
	}
	else {
		if (0 != EnableRawMode(STDIN_FILENO)) {
			return luaL_error(L, "EnableRawMode");	//return ThrowException(ErrnoException(errno, "EnableRawMode"));
		}
	}
	lua_pushboolean(L, rawmode);
	return 1;
}


class PosixStream : public LuaCppBridge::HybridObjectWithProperties<PosixStream>
{
public:
	// Normal constructor
	PosixStream(lua_State* L) :
		m_L( LuaNode::GetLuaVM() ),
		m_socketId(0)
	{
		printf("Construyendo PosixStream (%d)\n", luaL_checkinteger(L, 1));
		int fd = ::dup(STDIN_FILENO);
		//EnableRawMode(fd);

		m_socket = boost::make_shared<boost::asio::posix::stream_descriptor>(boost::ref(LuaNode::GetIoService()), fd);
	}
	// Constructor used when we accept a connection
	//PosixStream(lua_State* L, boost::asio::ip::tcp::socket*);
	virtual ~PosixStream(void) {};

public:
	LCB_HOWP_DECLARE_EXPORTABLE(PosixStream);

	//static int tostring_T(lua_State* L);

	int SetOption(lua_State* L) {
		return 0;
	}

	int Bind(lua_State* L) {
		return 0;
	}
	int Listen(lua_State* L) {
		return 0;
	}
	int Connect(lua_State* L) {
		return 0;
	}

	int Write(lua_State* L) {
		printf("PosixStream::Write\n");
		return 0;
	}
	int Read(lua_State* L) {
		printf("PosixStream::Read\n");
		// store a reference in the registry
		lua_pushvalue(L, 1);
		int reference = luaL_ref(L, LUA_REGISTRYINDEX);
		if(lua_isnoneornil(L, 2)) {
			LogDebug("Socket::Read (%p) (id=%d) - ReadSome", this, m_socketId);

			m_pending_reads++;
			m_socket->async_read_some(
				boost::asio::buffer(m_inputArray), 
				boost::bind(&PosixStream::HandleReadSome, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
				);
		}
		else {
			luaL_error(L, "for the moment the read must be done with nil or a number");
		}
		return 0;
	}

	int Close(lua_State* L) {
		return 0;
	}
	int Shutdown(lua_State* L) {
		return 0;
	}

public:
	//boost::asio::ip::tcp::socket& GetSocketRef() { return *m_socket; };

private:
	void HandleWrite(int reference, const boost::system::error_code& error, size_t bytes_transferred);
	void HandleRead(int reference, const boost::system::error_code& error, size_t bytes_transferred);
	void HandleReadSome(int reference, const boost::system::error_code& error, size_t bytes_transferred)
	{
		lua_State* L = LuaNode::GetLuaVM();
		lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
		luaL_unref(L, LUA_REGISTRYINDEX, reference);

		m_pending_reads--;
		if(!error) {
			printf("PosixStream::HandleReadSome (%p) (id=%d) - Bytes Transferred (%d)\n", this, (int)m_socketId, bytes_transferred);
			lua_getfield(L, 1, "read_callback");
			if(lua_type(L, 2) == LUA_TFUNCTION) {
				lua_pushvalue(L, 1);
				const char* data = m_inputArray.c_array();
				lua_pushlstring(L, data, bytes_transferred);
				LuaNode::GetLuaVM().call(2, LUA_MULTRET);
			}
			else {
				// do nothing?
				if(lua_type(L, 1) == LUA_TUSERDATA) {
					userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
					LogWarning("PosixStream::HandleReadSome (%p) (id=%d) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_socketId, luaL_typename(L, 1), ud, ud->pT);
				}
				else {
					LogWarning("PosixStream::HandleReadSome (%p) (id=%d) - No read_callback set on %s", this, m_socketId, luaL_typename(L, 1));
				}
			}
		}
		else {
			lua_getfield(L, 1, "read_callback");
			if(lua_type(L, 2) == LUA_TFUNCTION) {
				lua_pushvalue(L, 1);
				lua_pushnil(L);

				switch(error.value()) {
case boost::asio::error::eof:
	lua_pushliteral(L, "eof");
	break;
#ifdef _WIN32
case ERROR_CONNECTION_ABORTED:
#endif
case boost::asio::error::connection_aborted:
	lua_pushliteral(L, "aborted");
	break;

case boost::asio::error::operation_aborted:
	lua_pushliteral(L, "aborted");
	break;

case boost::asio::error::connection_reset:
	lua_pushliteral(L, "reset");
	break;

default:
	lua_pushstring(L, error.message().c_str());
	break;
				}

				if(error.value() != boost::asio::error::eof && error.value() != boost::asio::error::operation_aborted) {
					LogError("PosixStream::HandleReadSome with error (%p) (id=%d) - %s", this, m_socketId, error.message().c_str());
				}

				LuaNode::GetLuaVM().call(3, LUA_MULTRET);
			}
			else {
				LogError("PosixStream::HandleReadSome with error (%p) (id=%d) - %s", this, m_socketId, error.message().c_str());
				if(lua_type(L, 1) == LUA_TUSERDATA) {
					userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
					LogWarning("PosixStream::HandleReadSome (%p) (id=%d) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_socketId, luaL_typename(L, 1), ud, ud->pT);
				}
				else {
					LogWarning("PosixStream::HandleReadSome (%p) (id=%d) - No read_callback set on %s", this, m_socketId, luaL_typename(L, 1));
				}
			}
		}
		lua_settop(L, 0);

		if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
			boost::system::error_code ec;
			m_socket->close(ec);
			if(ec) {
				LogError("PosixStream::HandleReadSome - Error closing socket (%p) (id=%d) - %s", this, m_socketId, ec.message().c_str());
			}
		}
	}
	void HandleConnect(int reference, const boost::system::error_code& error);

private:
	lua_State* m_L;
	const unsigned long m_socketId;
	bool m_close_pending;
	//bool m_read_shutdown_pending;
	bool m_write_shutdown_pending;
	unsigned long m_pending_writes;
	unsigned long m_pending_reads;

	//boost::shared_ptr< boost::asio::ip::tcp::socket > m_socket;
	boost::shared_ptr< boost::asio::posix::stream_descriptor > m_socket;
	boost::asio::streambuf m_inputBuffer;
	//boost::array<char, 4> m_inputArray;	// agrandar esto y poolearlo
	//boost::array<char, 32> m_inputArray;	// agrandar esto y poolearlo
	//boost::array<char, 64> m_inputArray;	// agrandar esto y poolearlo
	//boost::array<char, 128> m_inputArray;	// agrandar esto y poolearlo (el test simple\test-http-upgrade-server necesita un buffer grande sino falla)
	boost::array<char, 8192> m_inputArray;	// agrandar esto y poolearlo (el test simple\test-http-upgrade-server necesita un buffer grande sino falla)
	//boost::array<char, 1> m_inputArray;	// agrandar esto y poolearlo (el test simple\test-http-upgrade-server necesita un buffer grande sino falla)
};

const char* PosixStream::className = "PosixStream";
const PosixStream::RegType PosixStream::methods[] = {
	{"setoption", &PosixStream::SetOption},
	{"bind", &PosixStream::Bind},
	{"close", &PosixStream::Close},
	{"shutdown", &PosixStream::Shutdown},
	{"write", &PosixStream::Write},
	{"read", &PosixStream::Read},
	{"connect", &PosixStream::Connect},
	{0}
};

const PosixStream::RegType PosixStream::setters[] = {
	{0}
};

const PosixStream::RegType PosixStream::getters[] = {
	{0}
};


//////////////////////////////////////////////////////////////////////////
/// TODO: this is the same on luanode_stdio_win32.cpp
static int IsATTY (lua_State* L) {
	int fd = luaL_checkinteger(L, 1);

	lua_pushboolean(L, isatty(fd));

	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
static int OpenStdin (lua_State* L) {
	printf("OpenStdin\n");
	if (isatty(STDIN_FILENO)) {
		// XXX selecting on tty fds wont work in windows.
		// Must ALWAYS make a coupling on shitty platforms.
		stdin_flags = fcntl(STDIN_FILENO, F_GETFL, 0);
		if (stdin_flags == -1) {
			return luaL_error(L, "fcntl error!");
		}

		int r = fcntl(STDIN_FILENO, F_SETFL, stdin_flags | O_NONBLOCK);
		if (r == -1) {
			return luaL_error(L, "fcntl error!");
		}
	}

	lua_pushinteger(L, STDIN_FILENO);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Stdio::Flush () {
	if (stdin_flags != -1) {
		fcntl(STDIN_FILENO, F_SETFL, stdin_flags & ~O_NONBLOCK);
	}

	if (stdout_flags != -1) {
		fcntl(STDOUT_FILENO, F_SETFL, stdout_flags & ~O_NONBLOCK);
	}

	fflush(stdout);
	fflush(stderr);
}

//////////////////////////////////////////////////////////////////////////
/// 
static void HandleSIGCONT (int signum) {
	if (rawmode) {
		rawmode = 0;
		EnableRawMode(STDIN_FILENO);
	}
}

/////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Stdio::RegisterFunctions (lua_State* L) {
	
	if (isatty(STDOUT_FILENO)) {
		// XXX selecting on tty fds wont work in windows.
		// Must ALWAYS make a coupling on shitty platforms.
		stdout_flags = fcntl(STDOUT_FILENO, F_GETFL, 0);
		fcntl(STDOUT_FILENO, F_SETFL, stdout_flags | O_NONBLOCK);
	}

	luaL_Reg methods[] = {
		{ "isatty", IsATTY },
		/*{ "writeError", WriteError },*/
		{ "openStdin", OpenStdin },
		/*{ "writeTTY", WriteTTY },	// windows only
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
		{ "stopTTYWatcher", StopTTYWatcher },*/
		{ "setRawMode", SetRawMode },
		{ 0, 0 }
	};
	luaL_register(L, "Stdio", methods);
	int table = lua_gettop(L);

	lua_pushinteger(L, STDOUT_FILENO);
	lua_setfield(L, table, "stdoutFD");

	lua_pushinteger(L, STDIN_FILENO);
	lua_setfield(L, table, "stdinFD");

	lua_pushinteger(L, STDERR_FILENO);
	lua_setfield(L, table, "stderrFD");
	lua_pop(L, 1);

	struct sigaction sa;
	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = HandleSIGCONT;
	sigaction(SIGCONT, &sa, NULL);

	PosixStream::Register(L, NULL, true);
}

//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Stdio::OnExit (/*lua_State* L*/) {
	DisableRawMode(STDIN_FILENO);
}