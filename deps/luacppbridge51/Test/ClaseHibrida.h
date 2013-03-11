#if !defined(AFX_LASEHIBRIDA_H__9D4F8DE1_F126_4A24_B0B5_6C539BD88C73__INCLUDED_)
#define AFX_LASEHIBRIDA_H__9D4F8DE1_F126_4A24_B0B5_6C539BD88C73__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include "..\lcbHybridObject.h"

class ClaseHibrida :
	public LuaCppBridge::HybridObject<ClaseHibrida>
{
public:
	ClaseHibrida(lua_State* L);
	virtual ~ClaseHibrida();

	LCB_HO_DECLARE_EXPORTABLE(ClaseHibrida);

	int RetornaString(lua_State* L);
	int RetornaNuevaInstanciaConGC(lua_State* L);
	int RetornaNuevaInstanciaSinGC(lua_State* L);
	int RetornaThisSinGC(lua_State* L);


private:
	ClaseHibrida* m_newInstance;
};

#endif // !defined(AFX_LASEHIBRIDA_H__9D4F8DE1_F126_4A24_B0B5_6C539BD88C73__INCLUDED_)
