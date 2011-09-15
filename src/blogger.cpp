#include "stdafx.h"
#include "blogger.h"
#include <stdio.h>
#include "luanode.h"


#ifdef ENABLE_LIBBLOGGER

static bool first_run = true;
static CLogger* logger;

static void Initialize() {
	logger = &LuaNode::Logger();
}

#define CHECK_LOG if(first_run) { Initialize(); first_run = false; }

//////////////////////////////////////////////////////////////////////////
///
void LogDebug(const char* format, ...) {
	CHECK_LOG;

	va_list argptr;
	va_start(argptr, format);
	LuaNode::Logger().Debug(format, argptr);
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogInfo(const char* format, ...) {
	CHECK_LOG;

	va_list argptr;
	va_start(argptr, format);
	LuaNode::Logger().Info(format, argptr);
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogProfile(const char* format, ...) {
	CHECK_LOG;

	va_list argptr;
	va_start(argptr, format);
	LuaNode::Logger().Profile(format, argptr);
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogWarning(const char* format, ...) {
	CHECK_LOG;

	va_list argptr;
	va_start(argptr, format);
	LuaNode::Logger().Warning(format, argptr);
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogError(const char* format, ...) {
	CHECK_LOG;

	va_list argptr;
	va_start(argptr, format);
	LuaNode::Logger().Error(format, argptr);
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogFatal(const char* format, ...) {
	CHECK_LOG;

	va_list argptr;
	va_start(argptr, format);
	LuaNode::Logger().Fatal(format, argptr);
	va_end(argptr);
}


CLogger::CLogger(const char* application_name)
	: m_log(liblogger_CreateLogger(application_name))
{
}

CLogger::~CLogger() {
	liblogger_DeleteLogger(m_log);
}

void CLogger::Fatal(const char* format, va_list vargs)
{
	liblogger_FatalV(m_log, format, vargs);
}

void CLogger::Error(const char* format, va_list vargs) {
	liblogger_ErrorV(m_log, format, vargs);
}

void CLogger::Warning(const char* format, va_list vargs) {
	liblogger_WarningV(m_log, format, vargs);
}

void CLogger::Info(const char* format, va_list vargs) {
	liblogger_InfoV(m_log, format, vargs);
}

void CLogger::Debug(const char* format, va_list vargs) {
	liblogger_DebugV(m_log, format, vargs);
}

void CLogger::Profile(const char* format, va_list vargs) {
	liblogger_ProfileV(m_log, format, vargs);
}



#else

CLogger::CLogger(const char* application_name)
{
}

CLogger::~CLogger() {
}

void CLogger::Fatal(const char* format, va_list vargs)
{
}

void CLogger::Error(const char* format, va_list vargs) {
}

void CLogger::Warning(const char* format, va_list vargs) {
}

void CLogger::Info(const char* format, va_list vargs) {
}

void CLogger::Debug(const char* format, va_list vargs) {
}

void CLogger::Profile(const char* format, va_list vargs) {
}


static bool first_run = true;
static CLogger* logger;

static void Initialize() {
	logger = &LuaNode::Logger();
}

#define CHECK_LOG if(first_run) { Initialize(); first_run = false; }

//////////////////////////////////////////////////////////////////////////
///
void LogDebug(const char* strFormat, ...) {
	CHECK_LOG;

	va_list argptr;
	va_start(argptr, strFormat);
	//vfprintf(stderr, strFormat, argptr);
	//fprintf(stderr, "\r\n");
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogInfo(const char* strFormat, ...) {
	CHECK_LOG;

	va_list argptr;
	va_start(argptr, strFormat);
	//vfprintf(stderr, strFormat, argptr);
	//fprintf(stderr, "\r\n");
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogProfile(const char* strFormat, ...) {
	CHECK_LOG;

	va_list argptr;
	va_start(argptr, strFormat);
	vfprintf(stderr, strFormat, argptr);
	fprintf(stderr, "\r\n");
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogWarning(const char* strFormat, ...) {
	CHECK_LOG;

	va_list argptr;
	va_start(argptr, strFormat);
	vfprintf(stderr, strFormat, argptr);
	fprintf(stderr, "\r\n");
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogError(const char* strFormat, ...) {
	CHECK_LOG;

	va_list argptr;
	va_start(argptr, strFormat);
	vfprintf(stderr, strFormat, argptr);
	fprintf(stderr, "\r\n");
	va_end(argptr);
}

//////////////////////////////////////////////////////////////////////////
///
void LogFatal(const char* strFormat, ...) {
	CHECK_LOG;

	va_list argptr;
	va_start(argptr, strFormat);
	vfprintf(stderr, strFormat, argptr);
	fprintf(stderr, "\r\n");
	va_end(argptr);
}
#endif

