:: Download and compile Lua
appveyor DownloadFile %LUAURL%/lua-%LUA_VER%.tar.gz
7z x lua-%LUA_VER%.tar.gz
7z x lua-%LUA_VER%.tar
cd lua-%LUA_VER%
appveyor DownloadFile https://github.com/Tieske/luawinmake/archive/master.zip
7z x master.zip
if not exist etc mkdir etc
mv luawinmake-master\etc\winmake.bat %APPVEYOR_BUILD_FOLDER%\lua-%LUA_VER%\etc\winmake.bat
call etc\winmake.bat
call etc\winmake.bat install c:\lua%LUA_VER%
if %LUA_SHORTV%==5.1 (copy "etc\lua.hpp" "c:\lua%LUA_VER%\include")
:: defines LUA_DIR so Cmake can find this Lua install
set LUA_DIR=c:\lua%LUA_VER%
set PATH=%PATH%;c:\lua%LUA_VER%\bin
:: Download and install OpenSSL
cd %APPVEYOR_BUILD_FOLDER%
if %platform%==x86 (
  echo "Downloading OpenSSL 32 bits"
  appveyor DownloadFile http://slproweb.com/download/Win32OpenSSL-1_0_2a.exe
  Win32OpenSSL-1_0_2a.exe /silent /verysilent /sp- /suppressmsgboxes
) else (
  echo "Downloading OpenSSL 64 bits"
  appveyor DownloadFile http://slproweb.com/download/Win64OpenSSL-1_0_2a.exe
  Win64OpenSSL-1_0_2a.exe /silent /verysilent /sp- /suppressmsgboxes
)
