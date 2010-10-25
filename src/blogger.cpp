#include "stdafx.h"
#include "blogger.h"
extern "C" {
#include <libBlogger2/libblogger2.h>
}
#include <stdarg.h>

static bool bFirstRun = true;
static logger_instance objLog = NULL;

//////////////////////////////////////////////////////////////////////////
/// 
//extern BOOL WINAPI ConsoleControlHandler(DWORD ctrlType);

//////////////////////////////////////////////////////////////////////////
/// 
static void Initialize() {
	// Create a log file using the service's name
	//if(lstrlen(_Module.m_szServiceName) == 0) {
		objLog = liblogger_CreateLogger("LuaNode");
	/*}
	else {
		objLog = CreateLog2(_Module.m_szServiceName);
	}*/
}

//////////////////////////////////////////////////////////////////////////
///
void LogFree() {
	if(objLog) {
		liblogger_DeleteLogger(objLog);
		objLog = NULL;
		bFirstRun = true;
	}
}

//////////////////////////////////////////////////////////////////////////
///
void LogDebug(const char* strFormat, ...) {
	if(bFirstRun) {
		Initialize();
		bFirstRun = false;
	}
	va_list argptr;
	va_start(argptr, strFormat);
	liblogger_DebugV(objLog, strFormat, argptr);
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogInfo(const char* strFormat, ...) {
	if(bFirstRun) {
		Initialize();
		bFirstRun = false;
	}
	va_list argptr;
	va_start(argptr, strFormat);
	liblogger_InfoV(objLog, strFormat, argptr);
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogProfile(const char* strFormat, ...) {
	if(bFirstRun) {
		Initialize();
		bFirstRun = false;
	}
	va_list argptr;
	va_start(argptr, strFormat);
	liblogger_ProfileV(objLog, strFormat, argptr);
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogWarning(const char* strFormat, ...) {
	if(bFirstRun) {
		Initialize();
		bFirstRun = false;
	}
	va_list argptr;
	va_start(argptr, strFormat);
	liblogger_WarningV(objLog, strFormat, argptr);
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogError(const char* strFormat, ...) {
	if(bFirstRun) {
		Initialize();
		bFirstRun = false;
	}
	va_list argptr;
	va_start(argptr, strFormat);
	liblogger_ErrorV(objLog, strFormat, argptr);
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogFatal(const char* strFormat, ...) {
	if(bFirstRun) {
		Initialize();
		bFirstRun = false;
	}
	va_list argptr;
	va_start(argptr, strFormat);
	liblogger_FatalV(objLog, strFormat, argptr);
	va_end(argptr);
}
