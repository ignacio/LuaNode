#if !defined(AFX_VENTANA_H__E57E3880_7717_4AC9_990D_64BD8E22EC17__INCLUDED_)
#define AFX_VENTANA_H__E57E3880_7717_4AC9_990D_64BD8E22EC17__INCLUDED_

#pragma once

#include "..\lcbHybridObject.h"

class CVentana :
	public LuaCppBridge::HybridObject<CVentana>
{
public:
	CVentana(lua_State* L);
	virtual ~CVentana();

	LCB_HO_DECLARE_EXPORTABLE(CVentana);

public:
	int GetRect(lua_State* L);
};

#endif // !defined(AFX_VENTANA_H__E57E3880_7717_4AC9_990D_64BD8E22EC17__INCLUDED_)
