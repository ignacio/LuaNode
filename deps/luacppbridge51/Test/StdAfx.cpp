// stdafx.cpp : source file that includes just the standard includes
//	Test.pch will be the pre-compiled header
//	stdafx.obj will contain the pre-compiled type information

#include "stdafx.h"

// TODO: reference any additional headers you need in STDAFX.H
// and not in this file

#ifdef _DEBUG
	#pragma message("***** Debug linking *****")
	#pragma comment(lib, "../../../../../Packages/Lua5.1/lib/Lua5.1_d.lib")
#else
	#pragma message("***** Release linking *****")
	#pragma comment(lib, "../../../../../Packages/Lua5.1/lib/Lua5.1.lib")
#endif