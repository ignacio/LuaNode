#include "../../luanode.h"
#include "tty_stream.h"

#include <boost/bind.hpp>
#include <boost/make_shared.hpp>


using namespace LuaNode::detail::posix;


static int orig_termios_fd = -1;
static struct termios orig_termios; /* in order to restore at exit */


//////////////////////////////////////////////////////////////////////////
/// 
int LuaNode::detail::posix::uv_tty_set_mode(TtyStream* tty, int mode) {
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

static void uv_tty_reset_mode() {
	if (orig_termios_fd >= 0) {
		//fprintf(stderr, "uv_tty_reset_mode(fd=%d)\n", orig_termios_fd);
		int res = tcsetattr(orig_termios_fd, TCSANOW, &orig_termios);
		if(res != 0) {
			perror(strerror(errno));
		}
	}
}


const char* TtyStream::className = "TtyStream";
const TtyStream::RegType TtyStream::methods[] = {
	{"setRawMode", &TtyStream::SetRawMode},
	{"write", &TtyStream::Write},
	{"read", &TtyStream::Read},
	{"pause", &TtyStream::Pause},
	{"close", &TtyStream::Close},
	{"getWindowSize", &TtyStream::GetWindowSize},
	{0}
};

const TtyStream::RegType TtyStream::setters[] = {
	{0}
};

const TtyStream::RegType TtyStream::getters[] = {
	{0}
};


TtyStream::TtyStream(lua_State* L) :
	m_fd(-1),
	m_flags(0),
	m_mode(0),
	m_L(NULL),
	m_pending_reads(0),
	m_stream(NULL)
{
	int fd = (int)luaL_checkinteger(L, 1);
	m_fd = fd;	//m_fd = ::dup(fd);
	//fprintf(stderr, "Construyendo TtyStream (%p) (%d -> %d)\n", this, fd, m_fd);
	bool readable = lua_toboolean(L, 2);

	if(readable) {
		m_flags = fcntl(m_fd, F_GETFL, 0);
		if (m_flags == -1) {
			luaL_error(L, "fcntl error!");
		}

		int r = fcntl(m_fd, F_SETFL, m_flags | O_NONBLOCK);
		if (r == -1) {
			luaL_error(L, "fcntl error!");
		}
	}
	else {
		m_fd = ::dup(fd);
	}
	m_stream = new boost::asio::posix::stream_descriptor(LuaNode::GetIoService(), m_fd);
}

TtyStream::~TtyStream() {
	/*fprintf(stderr, "TtyStream::~TtyStream\n");*/
	uv_tty_reset_mode();
	if(m_stream) {
		delete m_stream;
		m_stream = NULL;
	}
}

/*static*/
void TtyStream::Reset() {
	uv_tty_reset_mode();
}

/////////////////////////////////////////////////////////////////////////
/// 
int TtyStream::SetRawMode(lua_State* L)
{
	int res = 0;
	if(lua_toboolean(L, 2) == false) {
		res = uv_tty_set_mode(this, 0);
		/* we don care if it fails when disabling */
	}
	else {
		if(uv_tty_set_mode(this, 1)) {
			return luaL_error(L, "SetRawMode failed with error %s", strerror(errno));
		}
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
		/*fprintf(stderr, "TtyStream::Read (%p) (id:%u) - ReadSome\n", this, m_streamId);*/
		m_pending_reads++;
		m_stream->async_read_some(
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
int TtyStream::Pause (lua_State* L) {
	return 0;
}

/////////////////////////////////////////////////////////////////////////
/// This method is deliberately blocking. Both stdout and stderr writes are blocking when 
/// backed by a tty.
int TtyStream::Write (lua_State* L) {
	//fprintf(stderr, "PosixStream::Write-----\n");
	size_t length;
	const char* data = luaL_checklstring(L, 2, &length);

	try {
		boost::asio::write(*m_stream, boost::asio::buffer(data, length));
	}
	catch(boost::system::system_error& e) {
		return luaL_error(L, "TtyStream::Write - Error writing - %e", e.what());
	}
	lua_pushboolean(L, true);
	return 1;
}

/////////////////////////////////////////////////////////////////////////
/// 
int TtyStream::Close (lua_State* L) {
	m_stream->close();
	return 0;
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
}

/////////////////////////////////////////////////////////////////////////
/// ()from uv_tty_get_winsize)
int TtyStream::GetWindowSize (lua_State* L) {
	//int uv_tty_get_winsize(uv_tty_t* tty, int* width, int* height) {
	struct winsize ws;

	if (ioctl(m_fd, TIOCGWINSZ, &ws) < 0) {
		return luaL_error(L, "fcntl error!");
		//uv__set_sys_error(tty->loop, errno);
		//return -1;
	}

	lua_pushinteger(L, ws.ws_col);
	lua_pushinteger(L, ws.ws_row);

	return 2;
}
