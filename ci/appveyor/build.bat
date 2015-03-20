echo LUA_DIR: %LUA_DIR%
echo PATH: %PATH%

cd %APPVEYOR_BUILD_FOLDER%\build
cmake -DBOOST_ROOT="c:\Libraries\boost" -DBOOST_LIBRARYDIR="c:\Libraries\boost\stage\lib" -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --config Release
cd ..\test
copy %APPVEYOR_BUILD_FOLDER%\build\Release\luanode.exe luanode.exe
:: Build artifacts
copy %APPVEYOR_BUILD_FOLDER%\build\Release\luanode.exe %ARTIFACTS%\luanode.exe
copy C:\lua%LUA_VER%\bin\lua%LUA_SHORTVND%.dll %ARTIFACTS%\lua%LUA_SHORTVND%.dll
if %platform%==x86 (
  copy C:\OpenSSL-Win32\bin\ssleay32.dll %ARTIFACTS%\ssleay32.dll
  copy C:\OpenSSL-Win32\bin\libeay32.dll %ARTIFACTS%\libeay32.dll
) else (
  copy C:\OpenSSL-Win64\bin\ssleay32.dll %ARTIFACTS%\ssleay32.dll
  copy C:\OpenSSL-Win64\bin\libeay32.dll %ARTIFACTS%\libeay32.dll
)
7z a luanode-%APPVEYOR_REPO_COMMIT%-%platform%.7z %ARTIFACTS%\*
appveyor PushArtifact luanode-%APPVEYOR_REPO_COMMIT%-%platform%.7z
del luanode-%APPVEYOR_REPO_COMMIT%-%platform%.7z
