#ifndef _BLOGGER_FILE
#define _BLOGGER_FILE

#pragma once

#include <stdarg.h>

#ifdef ENABLE_LIBBLOGGER
extern "C" {
	#include <libBlogger2/libblogger2.h>
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