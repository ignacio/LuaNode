#if !defined(AFX_RAWWITHPROPS_H__E58E56DC_2D79_4041_8535_ACE2A7BB083A__INCLUDED_)
#define AFX_RAWWITHPROPS_H__E58E56DC_2D79_4041_8535_ACE2A7BB083A__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include "..\lcbRawObjectWithProperties.h"

class RawWithProps : 
	public LuaCppBridge::RawObjectWithProperties<RawWithProps>
{
public:
	RawWithProps(lua_State* L);
	virtual ~RawWithProps();

	LCB_ROWP_DECLARE_EXPORTABLE(RawWithProps);

	int TestMethod1(lua_State* L);
};

#endif // !defined(AFX_RAWWITHPROPS_H__E58E56DC_2D79_4041_8535_ACE2A7BB083A__INCLUDED_)
