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
#include <boost/asio/write.hpp>

#include <signal.h>

static int stdin_flags = -1;

static int orig_termios_fd = -1;
static struct termios orig_termios; /* in order to restore at exit */


class TtyStream;
int uv_tty_set_mode(TtyStream* tty, int mode);
void uv_tty_reset_mode();

class PosixStream : public LuaCppBridge::HybridObjectWithProperties<PosixStream>
{
public:
	// Normal constructor
	PosixStream(lua_State* L) :
		m_fd(-1),
		m_L( LuaNode::GetLuaVM() ),
		m_socketId(-1)
	{
		//m_fd = ::dup((int)luaL_checkinteger(L, 1));
		m_fd = (int)luaL_checkinteger(L, 1);
		//fprintf(stderr, "Construyendo PosixStream (%d)\n", m_fd);
		m_socket = boost::make_shared<boost::asio::posix::stream_descriptor>(boost::ref(LuaNode::GetIoService()), m_fd);
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
		lua_pushvalue(L, 1);
		int reference = luaL_ref(L, LUA_REGISTRYINDEX);

		//fprintf(stderr, "PosixStream::Write-----\n");
		size_t length;
		const char* data = luaL_checklstring(L, 2, &length);
		
		//fprintf(stderr, "length = %d\n", l);
		boost::asio::async_write(*m_socket,
			boost::asio::buffer(data, length),
			boost::bind(&PosixStream::HandleWrite, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);
		return 0;
	}
	int Read(lua_State* L) {
		/*printf("PosixStream::Read\n");*/
		// store a reference in the registry
		lua_pushvalue(L, 1);
		int reference = luaL_ref(L, LUA_REGISTRYINDEX);
		if(lua_isnoneornil(L, 2)) {
			/*fprintf(stderr, "Socket::Read (%p) (id:%u) - ReadSome\n", this, m_socketId);*/

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
	void HandleWrite(int reference, const boost::system::error_code& error, size_t bytes_transferred) {
		//fprintf(stderr, "PosixStream::HandleWrite\n");
		lua_State* L = LuaNode::GetLuaVM();
		lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
		luaL_unref(L, LUA_REGISTRYINDEX, reference);

		if(!error) {
			//fprintf(stderr, "PosixStream::HandleWrite - OK\n");
		}
		else {
			fprintf(stderr, "PosixStream::HandleReadSome with error (%p) (id:%u) - %s", this, m_socketId, error.message().c_str());		
		}

		lua_settop(L, 0);
	};
	void HandleRead(int reference, const boost::system::error_code& error, size_t bytes_transferred);
	void HandleReadSome(int reference, const boost::system::error_code& error, size_t bytes_transferred)
	{
		lua_State* L = LuaNode::GetLuaVM();
		lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
		luaL_unref(L, LUA_REGISTRYINDEX, reference);

		/*fprintf(stderr, "PosixStream::HandleReadSome\n");*/
		m_pending_reads--;
		if(!error) {
			LogDebug("PosixStream::HandleReadSome (%p) (id:%u) - Bytes Transferred (%lu)\n", this, m_socketId, (unsigned long)bytes_transferred);
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
					LogWarning("PosixStream::HandleReadSome (%p) (id:%u) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_socketId, luaL_typename(L, 1), ud, ud->pT);
				}
				else {
					LogWarning("PosixStream::HandleReadSome (%p) (id:%u) - No read_callback set on %s", this, m_socketId, luaL_typename(L, 1));
				}
			}
		}
		else {
			lua_getfield(L, 1, "read_callback");
			if(lua_type(L, 2) == LUA_TFUNCTION) {
				lua_pushvalue(L, 1);
				LuaNode::BoostErrorCodeToLua(L, error);	// -> nil, error code, error message

				if(error.value() != boost::asio::error::eof && error.value() != boost::asio::error::operation_aborted) {
					LogError("PosixStream::HandleReadSome with error (%p) (id:%u) - %s", this, m_socketId, error.message().c_str());
				}

				LuaNode::GetLuaVM().call(4, LUA_MULTRET);
			}
			else {
				LogError("PosixStream::HandleReadSome with error (%p) (id:%u) - %s", this, m_socketId, error.message().c_str());
				if(lua_type(L, 1) == LUA_TUSERDATA) {
					userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
					LogWarning("PosixStream::HandleReadSome (%p) (id:%u) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_socketId, luaL_typename(L, 1), ud, ud->pT);
				}
				else {
					LogWarning("PosixStream::HandleReadSome (%p) (id:%u) - No read_callback set on %s", this, m_socketId, luaL_typename(L, 1));
				}
			}
		}
		lua_settop(L, 0);

		if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
			boost::system::error_code ec;
			m_socket->close(ec);
			if(ec) {
				LogError("PosixStream::HandleReadSome - Error closing socket (%p) (id:%u) - %s", this, m_socketId, ec.message().c_str());
			}
		}
	}
	void HandleConnect(int reference, const boost::system::error_code& error);

public:
	int m_fd;

private:
	lua_State* m_L;
	const unsigned int m_socketId;
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




class TtyStream : 
	public LuaCppBridge::HybridObjectWithProperties<TtyStream>
{
public:
	// Normal constructor
	TtyStream(lua_State* L) :
		m_fd(-1),
		m_flags(0),
		m_mode(0)
	{
		int fd = (int)luaL_checkinteger(L, 1);
		m_fd = fd;	//m_fd = ::dup(fd);
		//fprintf(stderr, "Construyendo TtyStream (%p) (%d -> %d)\n", this, fd, m_fd);
		bool readable = lua_toboolean(L, 2);

		if(readable) {
			stdin_flags = fcntl(m_fd, F_GETFL, 0);
			if (stdin_flags == -1) {
				luaL_error(L, "fcntl error!");
			}

			int r = fcntl(m_fd, F_SETFL, stdin_flags | O_NONBLOCK);
			if (r == -1) {
				luaL_error(L, "fcntl error!");
			}
		}
		m_mode = 0;
		m_socket = boost::make_shared<boost::asio::posix::stream_descriptor>(boost::ref(LuaNode::GetIoService()), m_fd);
	}
	virtual ~TtyStream() {
		// TODO: chequear que el descriptor se cierre
		//uv_tty_reset_mode();
	}

public:
	LCB_HOWP_DECLARE_EXPORTABLE(TtyStream);

	int Write(lua_State* L);
	int Read(lua_State* L);
	int SetRawMode(lua_State* L);

private:
	void HandleWrite(int reference, const boost::system::error_code& error, size_t bytes_transferred);
	void HandleReadSome(int reference, const boost::system::error_code& error, size_t bytes_transferred);

public:
	int m_fd;
	struct termios m_orig_termios;
	unsigned int m_flags;
	int m_mode;
	lua_State* m_L;
	bool m_close_pending;
	bool m_write_shutdown_pending;
	unsigned long m_pending_writes;
	unsigned long m_pending_reads;

	boost::shared_ptr< boost::asio::posix::stream_descriptor > m_socket;
	boost::asio::streambuf m_inputBuffer;
	boost::array<char, 128> m_inputArray;
};


const char* TtyStream::className = "TtyStream";
const TtyStream::RegType TtyStream::methods[] = {
	{"setRawMode", &TtyStream::SetRawMode},
	{"write", &TtyStream::Write},
	{"read", &TtyStream::Read},
	{0}
};

const TtyStream::RegType TtyStream::setters[] = {
	{0}
};

const TtyStream::RegType TtyStream::getters[] = {
	{0}
};

/////////////////////////////////////////////////////////////////////////
/// 
int TtyStream::SetRawMode(lua_State* L)
{
	int res = 0;
	if(lua_toboolean(L, 2) == false) {
		res = uv_tty_set_mode(this, 0);
	}
	else {
		res = uv_tty_set_mode(this, 1);
		if(res) {
			return luaL_error(L, "SetRawMode failed with error %s", strerror(errno));
		}
	}
	return 0;
}

/////////////////////////////////////////////////////////////////////////
/// 
int TtyStream::Write (lua_State* L) {
	//fprintf(stderr, "PosixStream::Write-----\n");
	size_t length;
	const char* data = luaL_checklstring(L, 2, &length);

	try {
		boost::asio::write(*m_socket, boost::asio::buffer(data, length));
	}
	catch(boost::system::system_error& e) {
		return luaL_error(L, "TtyStream::Write - Error writing - %e", e.what());
	}
	return 0;
}

/////////////////////////////////////////////////////////////////////////
/// 
int TtyStream::Read(lua_State* L) {
	/*printf("TtyStream::Read\n");*/
	// store a reference in the registry
	lua_pushvalue(L, 1);
	int reference = luaL_ref(L, LUA_REGISTRYINDEX);
	if(lua_isnoneornil(L, 2)) {
		/*fprintf(stderr, "TtyStream::Read (%p) (id:%u) - ReadSome\n", this, m_socketId);*/

		m_pending_reads++;
		m_socket->async_read_some(
			boost::asio::buffer(m_inputArray), 
			boost::bind(&TtyStream::HandleReadSome, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
		);
	}
	else {
		luaL_error(L, "for the moment the read must be done with nil or a number");
	}
	return 0;
}

/////////////////////////////////////////////////////////////////////////
/// 
void TtyStream::HandleWrite(int reference, const boost::system::error_code& error, size_t bytes_transferred) {
	//fprintf(stderr, "TtyStream::HandleWrite\n");
	lua_State* L = LuaNode::GetLuaVM();
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	if(!error) {
		//fprintf(stderr, "TtyStream::HandleWrite - OK\n");
	}
	else {
		fprintf(stderr, "TtyStream::HandleWrite with error (%p) (id:%u) - %s", this, m_fd, error.message().c_str());		
	}

	lua_settop(L, 0);
}

/////////////////////////////////////////////////////////////////////////
/// 
void TtyStream::HandleReadSome(int reference, const boost::system::error_code& error, size_t bytes_transferred)
{
	lua_State* L = LuaNode::GetLuaVM();
	lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
	luaL_unref(L, LUA_REGISTRYINDEX, reference);

	m_pending_reads--;
	if(!error) {
		LogDebug("TtyStream::HandleReadSome (%p) (id:%u) - Bytes Transferred (%lu)\n", this, m_fd, (unsigned long)bytes_transferred);
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
				LogWarning("TtyStream::HandleReadSome (%p) (id:%u) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_fd, luaL_typename(L, 1), ud, ud->pT);
			}
			else {
				LogWarning("TtyStream::HandleReadSome (%p) (id:%u) - No read_callback set on %s", this, m_fd, luaL_typename(L, 1));
			}
		}
	}
	else {
		lua_getfield(L, 1, "read_callback");
		if(lua_type(L, 2) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			LuaNode::BoostErrorCodeToLua(L, error);	// -> nil, error code, error message

			if(error.value() != boost::asio::error::eof && error.value() != boost::asio::error::operation_aborted) {
				LogError("TtyStream::HandleReadSome with error (%p) (id:%u) - %s", this, m_fd, error.message().c_str());
			}

			LuaNode::GetLuaVM().call(4, LUA_MULTRET);
		}
		else {
			LogError("TtyStream::HandleReadSome with error (%p) (id:%u) - %s", this, m_fd, error.message().c_str());
			if(lua_type(L, 1) == LUA_TUSERDATA) {
				userdataType* ud = static_cast<userdataType*>(lua_touserdata(L, 1));
				LogWarning("TtyStream::HandleReadSome (%p) (id:%u) - No read_callback set on %s (address: %p, possible obj: %p)", this, m_fd, luaL_typename(L, 1), ud, ud->pT);
			}
			else {
				LogWarning("TtyStream::HandleReadSome (%p) (id:%u) - No read_callback set on %s", this, m_fd, luaL_typename(L, 1));
			}
		}
	}
	lua_settop(L, 0);

	if(m_close_pending && m_pending_writes == 0 && m_pending_reads == 0) {
		boost::system::error_code ec;
		m_socket->close(ec);
		if(ec) {
			LogError("TtyStream::HandleReadSome - Error closing socket (%p) (id:%u) - %s", this, m_fd, ec.message().c_str());
		}
	}
}

// ugh! remove this globals...
//boost::shared_ptr<TtyStream> tty_input;

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
	lua_pushinteger(L, STDIN_FILENO);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Stdio::Flush () {
	if (stdin_flags != -1) {
		fcntl(STDIN_FILENO, F_SETFL, stdin_flags & ~O_NONBLOCK);
	}

	fflush(stdout);
	fflush(stderr);
}

//////////////////////////////////////////////////////////////////////////
/// 
static void HandleSIGCONT (int signum) {
	fprintf(stderr, "HandleSIGCONT\n");
	/*if (rawmode) {
		rawmode = 0;
		EnableRawMode(STDIN_FILENO);
	}*/
	uv_tty_reset_mode();
}

/////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Stdio::RegisterFunctions (lua_State* L) {

	luaL_Reg methods[] = {
		{ "isatty", IsATTY },
		/*{ "writeError", WriteError },*/
		{ "openStdin", OpenStdin },
		/*{ "writeTTY", WriteTTY },	// windows only
		{ "closeTTY", CloseTTY },
		{ "isStdoutBlocking", IsStdoutBlocking },
		{ "isStdinBlocking", IsStdinBlocking },
		{ "getWindowSize", GetWindowSize },
		{ "initTTYWatcher", InitTTYWatcher },
		{ "destroyTTYWatcher", DestroyTTYWatcher },
		{ "startTTYWatcher", StartTTYWatcher },
		{ "stopTTYWatcher", StopTTYWatcher },*/
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
	TtyStream::Register(L, NULL, true);
}

//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Stdio::OnExit (/*lua_State* L*/) {
	uv_tty_reset_mode();
}

//////////////////////////////////////////////////////////////////////////
/// 
int uv_tty_set_mode(TtyStream* tty, int mode) {
	//fprintf(stderr, "uv_tty_set_mode %p %d\n", tty, mode);
	int fd = tty->m_fd;
	struct termios raw;
	//fprintf(stderr, "tty_SetMode para fd=%d\n", fd);

	if(mode && tty->m_mode == 0) {
		// on
		//fprintf(stderr, "ON\n");

		if (tcgetattr(fd, &tty->m_orig_termios)) {
			fprintf(stderr, "tcgetattr(fd, &tty->m_orig_termios)\n");
			goto fatal;
		}

		// This is used for uv_tty_reset_mode()
		if(orig_termios_fd == -1) {
			orig_termios = tty->m_orig_termios;
			orig_termios_fd = ::dup(fd); // Hay que hacer dup, sino falla al atexit
		}

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
		raw.c_cc[VMIN] = 1;
		raw.c_cc[VTIME] = 0; /* 1 byte, no timer */

		/* put terminal in raw mode after draining */
		if (tcsetattr(fd, TCSADRAIN, &raw)) {
			fprintf(stderr, "tcsetattr(fd, TCSADRAIN, &raw)\n");
			goto fatal;
		}

		tty->m_mode = 1;

		return 0;
	}
	else if(mode == 0 && tty->m_mode) {
		// off
		//fprintf(stderr, "OFF\n");

		// put terminal in original mode after flushing
		if (tcsetattr(fd, TCSAFLUSH, &tty->m_orig_termios)) {
			fprintf(stderr, "tcsetattr(fd, TCSAFLUSH, &tty->m_orig_termios)\n");
			goto fatal;
		}

		tty->m_mode = 0;
		return 0;
	}

fatal:
	fprintf(stderr, "fatal fd=%d\n", fd);
	errno = ENOTTY;
	return -1;
}

void uv_tty_reset_mode() {
	if (orig_termios_fd >= 0) {
		//fprintf(stderr, "uv_tty_reset_mode(fd=%d)\n", orig_termios_fd);
		int res = tcsetattr(orig_termios_fd, TCSANOW, &orig_termios);
		if(res != 0) {
			perror(strerror(errno));
		}
	}
}