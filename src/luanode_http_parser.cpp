#include "stdafx.h"
#include "luanode.h"
#include "luanode_http_parser.h"
#include "blogger.h"

using namespace LuaNode::Http;


/*static*/ struct http_parser_settings LuaNode::Http::Parser::s_settings;

void LuaNode::Http::RegisterFunctions(lua_State* L) {
	luaL_Reg methods[] = {
		{ 0, 0 }
	};
	luaL_register(L, "Http", methods);
	lua_pop(L, 1);

	Parser::s_settings.on_message_begin    = Parser::on_message_begin;
	Parser::s_settings.on_url              = Parser::on_url;
	Parser::s_settings.on_header_field     = Parser::on_header_field;
	Parser::s_settings.on_header_value     = Parser::on_header_value;
	Parser::s_settings.on_headers_complete = Parser::on_headers_complete;
	Parser::s_settings.on_body             = Parser::on_body;
	Parser::s_settings.on_message_complete = Parser::on_message_complete;
}

//////////////////////////////////////////////////////////////////////////
/// 
static inline const char* method_to_str(unsigned short m) {
	switch (m) {
		case HTTP_DELETE:     return "DELETE";
		case HTTP_GET:        return "GET";
		case HTTP_HEAD:       return "HEAD";
		case HTTP_POST:       return "POST";
		case HTTP_PUT:        return "PUT";
		// pathological
		case HTTP_CONNECT:    return "CONNECT";
		case HTTP_OPTIONS:    return "OPTIONS";
		case HTTP_TRACE:      return "TRACE";
		// webdav
		case HTTP_COPY:       return "COPY";
		case HTTP_LOCK:       return "LOCK";
		case HTTP_MKCOL:      return "MKCOL";
		case HTTP_MOVE:       return "MOVE";
		case HTTP_PROPFIND:   return "PROPFIND";
		case HTTP_PROPPATCH:  return "PROPPATCH";
		case HTTP_UNLOCK:     return "UNLOCK";
		// subversion
		case HTTP_REPORT:     return "REPORT";
		case HTTP_MKACTIVITY: return "MKACTIVITY";
		case HTTP_CHECKOUT:   return "CHECKOUT";
		case HTTP_MERGE:      return "MERGE";
		// upnp
		case HTTP_MSEARCH:    return "M-SEARCH";
		case HTTP_NOTIFY:     return "NOTIFY";
		case HTTP_SUBSCRIBE:  return "SUBSCRIBE";
		case HTTP_UNSUBSCRIBE:return "UNSUSCRIBE";
		case HTTP_PATCH:      return "PATCH";
		case HTTP_PURGE:      return "PURGE";
		// RFC-5789
		default:              return "UNKNOWN";
	}
}


const char* Parser::className = "HTTPParser";
const Parser::RegType Parser::methods[] = {
	{"execute", &Parser::Execute},
	{"finish", &Parser::Finish},
	{"reinitialize", &Parser::Reinitialize},
	{0}
};

const Parser::RegType Parser::setters[] = {
	{0}
};

const Parser::RegType Parser::getters[] = {
	{0}
};

Parser::Parser(lua_State* L) : 
	m_L( LuaNode::GetLuaVM() )
{
	LogDebug("Constructing HTTP Parser (%p)", this);

	const char* options[] = {
		"request",
		"response",
		NULL
	};

	int chosen_option = luaL_checkoption(L, 1, NULL, options);
	switch(chosen_option) {
		case 0:	// request
			Init(HTTP_REQUEST);
		break;
		case 1:	// response
			Init(HTTP_RESPONSE);
		break;
		
		default:
			luaL_error(L, "Constructor argument must be 'request' or 'response'");
		break;
	}
}

Parser::~Parser(void)
{
	LogDebug("Destructing HTTP Parser (%p)", this);
}

void Parser::Init(enum http_parser_type type) {
	http_parser_init(&m_parser, type);
	m_parser.data = this;
}

//////////////////////////////////////////////////////////////////////////
/// // var bytesParsed = parser->execute(buffer, off, len);
int Parser::Execute(lua_State* L) {
	const char* buffer = luaL_checkstring(L, 2);
	size_t offset = luaL_checkinteger(L, 3);
	size_t len = luaL_checkinteger(L, 4);

	m_got_exception = false;

	size_t nparsed = http_parser_execute(&m_parser, &Parser::s_settings, buffer + offset, len);

	if(m_got_exception) {
		// TODO: signal error
		return 0;
	}

	if(!m_parser.upgrade && nparsed != len) {
		lua_pushnil(L);
		lua_pushfstring(L, "Parse error. %d bytes parsed", (int)nparsed);
		return 2;
	}

	lua_pushinteger(L, nparsed);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Parser::Finish(lua_State* L) {
	m_got_exception = false;

	int rv = http_parser_execute(&m_parser, &Parser::s_settings, NULL, 0);
	if(rv != 0) {
		enum http_errno err = HTTP_PARSER_ERRNO(&m_parser);
		lua_pushstring(L, http_errno_name(err));
		return 1;
	}

	if(m_got_exception) {
		// TODO: y??
		lua_pushstring(L, "Parse error (finish).");
		return 1;
	}
	lua_pushnil(L);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
int Parser::Reinitialize(lua_State* L) {
	const char* options[] = {
		"request",
		"response",
		NULL
	};

	int chosen_option = luaL_checkoption(L, 2, NULL, options);
	switch(chosen_option) {
		case 0:	// request
			Init(HTTP_REQUEST);
		break;
		case 1:	// response
			Init(HTTP_RESPONSE);
		break;
		default:
			luaL_error(L, "Constructor argument must be 'request' or 'response'");
		break;
	}
	return 0;
}


// Callback prototype for http_cb
/*#define DEFINE_HTTP_CB(name)							\
int Parser::name(http_parser* p) {			\
	Parser* parser = static_cast<Parser*>(p->data);		\
	lua_State* L = m_L;									\
	parser->GetSelf(L);									\
														\
	lua_getfield(L, 1, name);						\
	if(lua_type(L, 2) == LUA_TFUNCTION) {				\
		lua_pushvalue(L, 1);							\
		LuaNode::GetLuaVM().call(1, LUA_MULTRET);		\
		if(lua_type(L, -1) == LUA_TNIL) {				\
			parser->got_exception_ = true;				\
		}												\
	}													\
	else {												\
		*//* do nothing? *//*							\
	}													\
	lua_settop(L, 0);									\
};	\*/

//DEFINE_HTTP_CB(on_message_begin)
/*static*/ int Parser::on_message_begin(http_parser* p) {
	Parser* parser = static_cast<Parser*>(p->data);
	lua_State* L = LuaNode::GetLuaVM();
	parser->GetSelf(L);
	int self = lua_gettop(L);

	lua_getfield(L, self, "onMessageBegin");
	if(lua_type(L, -1) == LUA_TFUNCTION) {
		lua_pushvalue(L, self);
		LuaNode::GetLuaVM().call(1, LUA_MULTRET);
		if(lua_type(L, -1) == LUA_TNIL) {
			parser->m_got_exception = true;
			lua_settop(L, 0);
			return -1;
		}
	}
	else {
		/* do nothing? */
	}
	lua_settop(L, 0);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ int Parser::on_url(http_parser* p, const char* at, size_t length) {
	if(length == 0) {
		// shortcut
		return 0; 
	}
	Parser* parser = static_cast<Parser*>(p->data);
	lua_State* L = LuaNode::GetLuaVM();
	parser->GetSelf(L);
	int self = lua_gettop(L);

	lua_getfield(L, self, "onURL");
	if(lua_type(L, -1) == LUA_TFUNCTION) {
		lua_pushvalue(L, self);
		lua_pushlstring(L, at, length);
		lua_pushinteger(L, 0);	// always 0
		lua_pushinteger(L, length);
		LuaNode::GetLuaVM().call(4, LUA_MULTRET);

		if(lua_type(L, -1) == LUA_TNIL) {
			parser->m_got_exception = true;
			lua_settop(L, 0);
			return -1;
		}
	}
	else {
		/* do nothing? */
	}
	lua_settop(L, 0);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ int Parser::on_header_field(http_parser* p, const char* at, size_t length) {
	if(length == 0) {
		// shortcut
		return 0; 
	}
	Parser* parser = static_cast<Parser*>(p->data);
	lua_State* L = LuaNode::GetLuaVM();
	parser->GetSelf(L);
	int self = lua_gettop(L);

	lua_getfield(L, self, "onHeaderField");
	if(lua_type(L, -1) == LUA_TFUNCTION) {
		lua_pushvalue(L, self);
		lua_pushlstring(L, at, length);
		lua_pushinteger(L, 0);	// always 0
		lua_pushinteger(L, length);
		LuaNode::GetLuaVM().call(4, LUA_MULTRET);
		if(lua_type(L, -1) == LUA_TNIL) {
			parser->m_got_exception = true;
			lua_settop(L, 0);
			return -1;
		}
	}
	else {
		/* do nothing? */
	}
	lua_settop(L, 0);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ int Parser::on_header_value(http_parser* p, const char* at, size_t length) {
	Parser* parser = static_cast<Parser*>(p->data);
	lua_State* L = LuaNode::GetLuaVM();
	parser->GetSelf(L);
	int self = lua_gettop(L);

	lua_getfield(L, self, "onHeaderValue");
	if(lua_type(L, -1) == LUA_TFUNCTION) {
		lua_pushvalue(L, self);
		lua_pushlstring(L, at, length);
		lua_pushinteger(L, 0);	// always 0
		lua_pushinteger(L, length);
		LuaNode::GetLuaVM().call(4, LUA_MULTRET);
		if(lua_type(L, -1) == LUA_TNIL) {
			parser->m_got_exception = true;
			lua_settop(L, 0);
			return -1;
		}
	}
	else {
		/* do nothing? */
	}
	lua_settop(L, 0);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ int Parser::on_headers_complete(http_parser* p) {
	Parser* parser = static_cast<Parser*>(p->data);
	lua_State* L = LuaNode::GetLuaVM();
	parser->GetSelf(L);
	int self = lua_gettop(L);

	lua_getfield(L, self, "onHeadersComplete");
	if(lua_type(L, -1) == LUA_TFUNCTION) {
		lua_pushvalue(L, self);
		lua_createtable(L, 0, 0);
		int table = lua_gettop(L);

		if(p->type == HTTP_REQUEST) {	// METHOD
			lua_pushstring(L, method_to_str(p->method));
			lua_setfield(L, table, "method");
		}
		else if(p->type == HTTP_RESPONSE) {	// STATUS
			lua_pushinteger(L, p->status_code);
			lua_setfield(L, table, "statusCode");
		}

		// VERSION
		lua_pushinteger(L, p->http_major);
		lua_setfield(L, table, "versionMajor");

		lua_pushinteger(L, p->http_minor);
		lua_setfield(L, table, "versionMinor");

		lua_pushboolean(L, http_should_keep_alive(p));
		lua_setfield(L, table, "shouldKeepAlive");

		lua_pushboolean(L, p->upgrade);
		lua_setfield(L, table, "upgrade");

		LuaNode::GetLuaVM().call(2, LUA_MULTRET);
		if(lua_isnoneornil(L, -1)) {
			parser->m_got_exception = true;
			lua_settop(L, 0);
			return -1;
		}
		else {
			int res = lua_toboolean(L, -1);
			lua_settop(L, 0);
			return res ? 1 : 0;
		}
	}
	else {
		/* do nothing? */
	}
	lua_settop(L, 0);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ int Parser::on_body(http_parser* p, const char* at, size_t length) {
	Parser* parser = static_cast<Parser*>(p->data);
	lua_State* L = LuaNode::GetLuaVM();
	parser->GetSelf(L);
	int self = lua_gettop(L);

	lua_getfield(L, self, "onBody");
	if(lua_type(L, -1) == LUA_TFUNCTION) {
		lua_pushvalue(L, self);
		lua_pushlstring(L, at, length);
		lua_pushinteger(L, 0);	// always 0
		lua_pushinteger(L, length);
		LuaNode::GetLuaVM().call(4, LUA_MULTRET);
		if(lua_type(L, -1) == LUA_TNIL) {
			parser->m_got_exception = true;
			lua_settop(L, 0);
			return -1;
		}
	}
	else {
		/* do nothing? */
	}
	lua_settop(L, 0);
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ int Parser::on_message_complete(http_parser* p) {
	Parser* parser = static_cast<Parser*>(p->data);
	lua_State* L = LuaNode::GetLuaVM();
	parser->GetSelf(L);
	int self = lua_gettop(L);

	lua_getfield(L, self, "onMessageComplete");
	if(lua_type(L, -1) == LUA_TFUNCTION) {
		lua_pushvalue(L, self);
		LuaNode::GetLuaVM().call(1, LUA_MULTRET);
		if(lua_type(L, -1) == LUA_TNIL) {
			parser->m_got_exception = true;
			lua_settop(L, 0);
			return -1;
		}
	}
	else {
		/* do nothing? */
	}
	lua_settop(L, 0);
	return 0;
}
