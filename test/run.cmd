@echo off

for %%f in (simple\*.lua) do (
	echo %%f
	call luanode run.lua %%f
	if errorlevel 1 goto :eof
)


