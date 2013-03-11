#if !defined(AFX_BOTON_H__5A028C73_CC88_4D61_A6AA_E5E0771642F1__INCLUDED_)
#define AFX_BOTON_H__5A028C73_CC88_4D61_A6AA_E5E0771642F1__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include "..\lcbHybridObject.h"
#include "Ventana.h"

class CBoton :
	//public CVentana,
	public LuaCppBridge::HybridObject<CBoton>
{
public:
	CBoton(lua_State* L);
	virtual ~CBoton();

	LCB_HO_DECLARE_EXPORTABLE(CBoton);

public:
	int GetLabel(lua_State* L);
};

#endif // !defined(AFX_BOTON_H__5A028C73_CC88_4D61_A6AA_E5E0771642F1__INCLUDED_)
