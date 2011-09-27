#ifndef _BLOGGER_FILE
#define _BLOGGER_FILE

#pragma once

#include <stdarg.h>
#include <lua.hpp>

#ifdef ENABLE_LIBBLOGGER
extern "C" {
	#include <libblogger2/libBlogger2.hpp>
}
#endif

#ifdef _MSC_VER
#define CHECK_PRINTF(string_index, first_to_check)
#else
#define CHECK_PRINTF(string_index, first_to_check) __attribute__ ((format (printf, string_index, first_to_check))) 
#endif


void LogDebug(const char* strFormat, ...) CHECK_PRINTF(1,2);
void LogInfo(const char* strFormat, ...) CHECK_PRINTF(1,2);
void LogProfile(const char* strFormat, ...) CHECK_PRINTF(1,2);
void LogWarning(const char* strFormat, ...) CHECK_PRINTF(1,2);
void LogError(const char* strFormat, ...) CHECK_PRINTF(1,2);
void LogFatal(const char* strFormat, ...) CHECK_PRINTF(1,2);

int LogDebug(lua_State* L);
int LogInfo(lua_State* L);
int LogProfile(lua_State* L);
int LogWarning(lua_State* L);
int LogError(lua_State* L);
int LogFatal(lua_State* L);

class CLogger {
public:
	CLogger(const char* application_name);
	~CLogger();

public:
	void Fatal(const char* format, va_list vargs);
	void Error(const char* format, va_list vargs);
	void Warning(const char* format, va_list vargs);
	void Info(const char* format, va_list vargs);
	void Debug(const char* format, va_list vargs);
	void Profile(const char* format, va_list vargs);

private:
#ifdef ENABLE_LIBBLOGGER
	logger_instance m_log;
#endif
};

#undef CHECK_PRINTF

#endif