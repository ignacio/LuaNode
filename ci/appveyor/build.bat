@echo off
Setlocal EnableDelayedExpansion EnableExtensions

if not defined SEVENZIP set SEVENZIP=7z
if not defined APPVEYOR_BUILD_FOLDER set APPVEYOR_BUILD_FOLDER=%CD%

:: =========================================================
:: Determine if arch is 32/64 bits
if /I "%platform%"=="x86" (
	set arch=32
	set _cmake_per_Arch_Args=""
) else (
	set arch=64
	set _cmake_per_Arch_Args=-DCMAKE_GENERATOR_PLATFORM=%platform%
)
:: =========================================================
echo LUA_DIR: %LUA_DIR%
echo PATH: %PATH%

set build_dir=%APPVEYOR_BUILD_FOLDER%\build_%platform%
mkdir %build_dir% 2>NUL
cd %build_dir%

:: Where to put the resulting artifacts
if not defined ARTIFACTS set ARTIFACTS=%build_dir%\artifacts

if not defined BOOST_VERSION set BOOST_VERSION=1.58.0
:: replace dots with underscores
set BOOST_VER_USC=%BOOST_VERSION:.=_%

cmake --version
cmake -G "Visual Studio 12 2013" -DBOOST_ROOT="c:\local\boost_%BOOST_VER_USC%" -DBOOST_LIBRARYDIR="c:\local\boost_%BOOST_VER_USC%\lib%arch%-msvc-12.0" -DCMAKE_BUILD_TYPE=Release %_cmake_per_Arch_Args% ..
cmake --build . --config Release

copy %build_dir%\Release\luanode.exe luanode.exe

:: Build artifacts
mkdir %ARTIFACTS% 2>NUL
copy %build_dir%\Release\luanode.exe %ARTIFACTS%\luanode.exe
copy %build_dir%\Release\luanode.exe %APPVEYOR_BUILD_FOLDER%\test\luanode.exe
copy %LUA_DIR%\bin\lua%LUA_SHORTVND%.dll %ARTIFACTS%\lua%LUA_SHORTVND%.dll
copy C:\OpenSSL-Win%arch%\bin\ssleay32.dll %ARTIFACTS%\ssleay32.dll
copy C:\OpenSSL-Win%arch%\bin\libeay32.dll %ARTIFACTS%\libeay32.dll

if "%APPVEYOR%"=="True" (
	%SEVENZIP% a luanode-%APPVEYOR_REPO_COMMIT%-%platform%.7z %ARTIFACTS%\*
	appveyor PushArtifact luanode-%APPVEYOR_REPO_COMMIT%-%platform%.7z
	luanode-%APPVEYOR_REPO_COMMIT%-%platform%.7z
)

endlocal
