#pragma once

#include "../deps/luacppbridge51/lcbHybridObjectWithProperties.h"
#include "../deps/http-parser/http_parser.h"

namespace LuaNode {

namespace Http {

void RegisterFunctions(lua_State* L);

class Parser : public LuaCppBridge::HybridObjectWithProperties<Parser>
{
public:
	Parser(lua_State* L);
	virtual ~Parser(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(Parser);

	int Execute(lua_State* L);
	int Finish(lua_State* L);
	int Reinitialize(lua_State* L);

	static int on_message_begin(http_parser* parser);
	static int on_url(http_parser* parser, const char* at, size_t length);
	static int on_header_field(http_parser* parser, const char* at, size_t length);
	static int on_header_value(http_parser* parser, const char* at, size_t length);
	static int on_headers_complete(http_parser* parser);
	static int on_body(http_parser* parser, const char* at, size_t length);
	static int on_message_complete(http_parser* parser);

private:
	void Init(enum http_parser_type type);

private:
	lua_State* m_L;
	bool m_got_exception;
	http_parser m_parser;

public:
	static struct http_parser_settings s_settings;
};


}

}
