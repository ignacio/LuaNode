#include "stdafx.h"
#include "LuaNode.h"
#include "luanode_file_win32.h"
#include <sys/types.h>

#include <boost/asio.hpp>
#include <boost/asio/windows/stream_handle.hpp>



using namespace LuaNode::Fs;

//////////////////////////////////////////////////////////////////////////
/// 
void LuaNode::Fs::RegisterFunctions(lua_State* L) {
	luaL_Reg methods[] = {
		//{ "isIP", LuaNode::Net::IsIP },
		//{ "read", LuaNode::Fs::Read },
		{ 0, 0 }
	};
	luaL_register(L, "Fs", methods);
	lua_pop(L, 1);
}

/*
static int After(eio_req* req) {
	return 0;
}

#define ASYNC_CALL(func, callback, ...)                           \
	eio_req *req = eio_##func(__VA_ARGS__, EIO_PRI_DEFAULT, After, (void*)&callback);
*/



/*
 * Wrapper for read(2).
 *
 * bytesRead = fs.read(fd, buffer, offset, length, position)
 *
 * 0 fd        integer. file descriptor
 * 1 buffer    instance of Buffer
 * 2 offset    integer. offset to start reading into inside buffer
 * 3 length    integer. length to read
 * 4 position  file position - null for current position
 *
 */
/*
char buffer[8124];
static int LuaNode::Fs::Read(lua_State* L) {
	int fd = luaL_checkinteger(L, 1);

	
	size_t buf_length = sizeof(buffer);

	off_t offset = 0;
	
	int callback = 1;

	boost::asio::windows::stream_handle in(LuaNode::GetIoService(), CreateFile("D:\\utils\\TaskSwitchXP\\lang\\_Translation.txt", GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL) );

	boost::asio::streambuf m_inputBuff;
	boost::asio::async_read(
		in, 
		m_inputBuff,
		//boost::bind(&Socket::HandleRead, this, reference, boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred)
	)
	in.async_read_some()
	//boost::asio::windows::random_access_handle file_( LuaNode::GetIoService() );
	
	//file_.assign();

	ASYNC_CALL(read, callback, fd, buffer, buf_length, offset);


	lua_pushboolean(L, true);
	return 1;
}*/

/*
 * Wrapper for read(2).
 *
 * bytesRead = fs.read(fd, buffer, offset, length, position)
 *
 * 0 fd        integer. file descriptor
 * 1 buffer    instance of Buffer
 * 2 offset    integer. offset to start reading into inside buffer
 * 3 length    integer. length to read
 * 4 position  file position - null for current position
 *
 */
/*static Handle<Value> Read(const Arguments& args) {
	HandleScope scope;

	if (args.Length() < 2 || !args[0]->IsInt32()) {
		return THROW_BAD_ARGS;
	}

	int fd = args[0]->Int32Value();

	Local<Value> cb;

	size_t len;
	off_t pos;

	char * buf = NULL;

	if (!Buffer::HasInstance(args[1])) {
		return ThrowException(Exception::Error(
			String::New("Second argument needs to be a buffer")));
	}

	Local<Object> buffer_obj = args[1]->ToObject();
	char *buffer_data = Buffer::Data(buffer_obj);
	size_t buffer_length = Buffer::Length(buffer_obj);

	size_t off = args[2]->Int32Value();
	if (off >= buffer_length) {
		return ThrowException(Exception::Error(
			String::New("Offset is out of bounds")));
	}

	len = args[3]->Int32Value();
	if (off + len > buffer_length) {
		return ThrowException(Exception::Error(
			String::New("Length is extends beyond buffer")));
	}

	pos = GET_OFFSET(args[4]);

	buf = buffer_data + off;

	cb = args[5];

	if (cb->IsFunction()) {
		ASYNC_CALL(read, cb, fd, buf, len, pos);
	} else {
		// SYNC
		ssize_t ret;

		ret = pos < 0 ? read(fd, buf, len) : pread(fd, buf, len, pos);
		if (ret < 0) return ThrowException(ErrnoException(errno));
		Local<Integer> bytesRead = Integer::New(ret);
		return scope.Close(bytesRead);
	}
}*/