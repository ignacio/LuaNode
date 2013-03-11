#if !defined(AFX_LASEHIBRIDACONPROPS_H__028A4A49_FC22_4CA5_B86C_DCFA5DD54F11__INCLUDED_)
#define AFX_LASEHIBRIDACONPROPS_H__028A4A49_FC22_4CA5_B86C_DCFA5DD54F11__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include <string>
#include "..\lcbHybridObjectWithProperties.h"

class ClaseHibridaConProps :
	public LuaCppBridge::HybridObjectWithProperties<ClaseHibridaConProps>
{
public:
	ClaseHibridaConProps(lua_State* L);
	virtual ~ClaseHibridaConProps();

	LCB_HOWP_DECLARE_EXPORTABLE(ClaseHibridaConProps);

public:
	static int new_T(lua_State* L);
	static int tostring_T(lua_State* L);

	int RetornaString(lua_State* L);
	int Test_test(lua_State* L);
	int Test_check(lua_State* L);
	int Test_PushNewCollectable(lua_State* L);
	int Test_PushNewNonCollectable(lua_State* L);

	LCB_DECL_GET(readonly_property);
	LCB_DECL_SET(writeonly_property);
	LCB_DECL_SETGET(builtin_property)

private:
	std::string m_builtin_property;
	std::string m_readonly_property;
	std::string m_writeonly_property;
};

#endif // !defined(AFX_LASEHIBRIDACONPROPS_H__028A4A49_FC22_4CA5_B86C_DCFA5DD54F11__INCLUDED_)
