@echo off
Setlocal EnableDelayedExpansion EnableExtensions

if not defined APPVEYOR_BUILD_FOLDER set APPVEYOR_BUILD_FOLDER=%CD%

cd %APPVEYOR_BUILD_FOLDER%

:: =========================================================
:: Set some defaults. Infer some variables.
::
if not defined LUA_VER (
	set LUA_VER=5.1.5
)
set LUA=lua
set LUA_SHORTV=%LUA_VER:~0,3%
set LUA_SHORTVND=%LUA_SHORTV:.=%

if not defined LUAROCKS_VER set LUAROCKS_VER=2.2.1
set LUAROCKS_SHORTV=%LUAROCKS_VER:~0,3%

if not defined LUAROCKS_URL set LUAROCKS_URL=http://keplerproject.github.io/luarocks/releases
if not defined LUAROCKS_REPO set LUAROCKS_REPO=http://rocks.moonscript.org
if not defined LUA_URL set LUA_URL=http://www.lua.org/ftp

if not defined LR_EXTERNAL set LR_EXTERNAL=c:\external
if not defined LUAROCKS_INSTALL set LUAROCKS_INSTALL=%ProgramFiles(x86)%\LuaRocks
if not defined LR_ROOT set LR_ROOT=%LUAROCKS_INSTALL%\%LUAROCKS_SHORTV%
if not defined LR_SYSTREE set LR_SYSTREE=%LUAROCKS_INSTALL%\systree
if /I "%platform%"=="x64" set LR_SYSTREE=%ProgramFiles%\LuaRocks\systree

if not defined SEVENZIP set SEVENZIP=7z

if not defined OPENSSL_VER set OPENSSL_VER=1.0.2a

:: Determine if arch is 32/64 bits
if /I "%platform%"=="x86" ( set arch=32) else ( set arch=64)

::
:: =========================================================

:: first create some necessary directories:
mkdir build\downloads 2>NUL


:: defines LUA_DIR so Cmake can find this Lua install
set LUA_DIR=c:\lua%LUA_VER%_%platform%

if not exist !LUA_DIR! (
	:: Download and compile Lua
	if not exist build\downloads\lua-%LUA_VER% (
		echo Downloading Lua %LUA_VER% sources...
		curl --silent --fail --max-time 120 --connect-timeout 30 %LUA_URL%/lua-%LUA_VER%.tar.gz | %SEVENZIP% x -si -so -tgzip | %SEVENZIP% x -si -ttar -aoa -obuild\downloads
		echo Done downloading.
	)
	
	mkdir build\downloads\lua-%LUA_VER%\etc 2> NUL
	if not exist build\downloads\lua-%LUA_VER%\etc\winmake.bat (
		echo Downloading luawinmake...
		curl --silent --location --insecure --fail --max-time 120 --connect-timeout 30 https://github.com/Tieske/luawinmake/archive/master.tar.gz | %SEVENZIP% x -si -so -tgzip | %SEVENZIP% e -si -ttar -aoa -obuild\downloads\lua-%LUA_VER%\etc luawinmake-master\etc\winmake.bat
		echo Done downloading.
	)

	cd build\downloads\lua-%LUA_VER%
	call etc\winmake
	call etc\winmake install %LUA_DIR%
) else (
	echo Lua %LUA_VER% already installed at !LUA_DIR!
)

if not exist !LUA_DIR!\bin\%LUA%.exe (
	echo Missing Lua interpreter
	exit /B 1
)

set PATH=%LUA_DIR%\bin;%PATH%
call !LUA! -v


:: Download and install OpenSSL
cd %APPVEYOR_BUILD_FOLDER%
set _openssl_underscores=%OPENSSL_VER:.=_%
set _openssl_filename=Win%arch%OpenSSL-%_openssl_underscores%.exe
if not exist "build\downloads\%_openssl_filename%" (
	echo Downloading OpenSSL %OPENSSL_VER% %arch% bits...
	curl --silent --fail --max-time 120 --connect-timeout 30 --output "build\downloads\%_openssl_filename%" "http://slproweb.com/download/%_openssl_filename%"
	echo Done downloading.
) else (
	echo OpenSSL %arch% bits already downloaded
)

set OPENSSL_ROOT_DIR=C:\OpenSSL-Win%arch%
if not exist "%OPENSSL_ROOT_DIR%" (
	echo Installing OpenSSL %OPENSSL_VER% %arch% bits...
	build\downloads\%_openssl_filename% /silent /verysilent /sp- /suppressmsgboxes
	echo Done installing.
) else (
	echo OpenSSL %arch% bits already installed
)

set PATH=%OPENSSL_ROOT_DIR%\bin;%PATH%

:: Download and install Boost
cd %APPVEYOR_BUILD_FOLDER%
if not defined BOOST_VERSION set BOOST_VERSION=1.58.0
:: replace dots with underscores
set BOOST_VER_USC=%BOOST_VERSION:.=_%

if not exist build\downloads\boost_%BOOST_VER_USC%-msvc-12.0-%arch%.exe (
	echo Downloading Boost %BOOST_VERSION% %arch% bits...
	curl --silent --fail --location --max-time 1600 --connect-timeout 30 --output build\downloads\boost_%BOOST_VER_USC%-msvc-12.0-%arch%.exe http://sourceforge.net/projects/boost/files/boost-binaries/%BOOST_VERSION%/boost_%BOOST_VER_USC%-msvc-12.0-%arch%.exe/download
	echo Done downloading.
) else (
	echo Boost %BOOST_VERSION% %arch% bits already downloaded
)

if not exist "C:\local\boost_%BOOST_VER_USC%\lib%arch%-msvc-12.0" (
	echo Installing Boost %BOOST_VERSION% %arch% bits...
	build\downloads\boost_%BOOST_VER_USC%-msvc-12.0-%arch%.exe /silent /verysilent /sp- /suppressmsgboxes
	echo Done installing.
) else (
	echo Boost %BOOST_VERSION% %arch% bits already installed
)

echo.
echo ======================================================
echo Installation of Lua %LUA_VER%, OpenSSL and Boost done.
echo Platform - %platform%
echo LUA_PATH  - %LUA_PATH%
echo LUA_CPATH - %LUA_CPATH%
echo ======================================================
echo.

endlocal & set PATH=%PATH%& ^
set LUA_DIR=%LUA_DIR%& ^
set LR_SYSTREE=%LR_SYSTREE%& ^
set LUA_PATH=%LUA_PATH%& ^
set LUA_CPATH=%LUA_CPATH%& ^
set OPENSSL_ROOT_DIR=%OPENSSL_ROOT_DIR%& ^
set LUA_SHORTVND=%LUA_SHORTVND%


goto :eof
