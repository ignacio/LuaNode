@echo off

rem Set counters
set /A noProcessed = 0

for %%f in (simple\*.lua) do (
	echo %%f
	call luanode run.lua %%f
	if errorlevel 1 goto :eof
	if not errorlevel -1 goto :eof
	set /A noProcessed += 1
)

echo Ran %noProcessed% tests. Ended without errors.
