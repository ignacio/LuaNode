#ifndef _BLOGGER_FILE
#define _BLOGGER_FILE

#pragma once

void Log(const char *fmt, ...);


void LogDebug(const char* strFormat, ...);
void LogInfo(const char* strFormat, ...);
void LogProfile(const char* strFormat, ...);
void LogWarning(const char* strFormat, ...);
void LogError(const char* strFormat, ...); 
void LogFatal(const char* strFormat, ...);

void LogFree();

#endif