#pragma once

#include <lua.hpp>
#include "../deps/LuaCppBridge51/lcbHybridObjectWithProperties.h"
#include <boost/array.hpp>


namespace LuaNode {

namespace Fs {

	void RegisterFunctions(lua_State* L);

	int Open(lua_State* L);

	int Read(lua_State* L);


class File : public LuaCppBridge::HybridObjectWithProperties<File>
{
public:
	// Normal constructor
	File(lua_State* L);
	virtual ~File(void);

public:
	LCB_HOWP_DECLARE_EXPORTABLE(File);

	static int tostring_T(lua_State* L);

	int Write(lua_State* L);
	int Read(lua_State* L);
	int Seek(lua_State* L);
	int Close(lua_State* L);

private:

private:
	lua_State* m_L;
	const unsigned int m_fileId;
	boost::array<char, 8192> m_inputArray;	// agrandar esto y poolearlo (el test simple\test-http-upgrade-server necesita un buffer grande sino falla)
};

}

}