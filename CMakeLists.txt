PROJECT(LuaNode C CXX)
CMAKE_MINIMUM_REQUIRED(VERSION 2.6)

FIND_PACKAGE(Lua51 REQUIRED)
FIND_PACKAGE(OpenSSL REQUIRED)
FIND_PACKAGE(Boost COMPONENTS system REQUIRED)

FIND_PROGRAM(LUA NAMES lua-5.1 lua5.1 lua)

IF(WIN32)
    SET(OS src/luanode_file_win32.cpp src/platform_windows.cpp)
ELSE()
    SET(OS src/luanode_file_linux.cpp src/platform_linux.cpp)
ENDIF()

SET(LUAS
    LuaNode/child_process
    LuaNode/Class
    LuaNode/console
    LuaNode/Crypto
    LuaNode/Dns
    LuaNode/event_emitter
    LuaNode/free_list
    LuaNode/Fs
    LuaNode/Http
    LuaNode/Net
    LuaNode/Path
    LuaNode/Querystring
    LuaNode/Stream
    LuaNode/Timers
    LuaNode/Url
    LuaNode/Utils
    src/node
    StackTracePlus/StackTracePlus
)

FOREACH(filename ${LUAS})
    GET_FILENAME_COMPONENT(base ${filename} NAME)
    SET(target "build/temp/${base}.precomp")
    MESSAGE(STATUS "Precompiling ${filename} into ${target}")
    EXECUTE_PROCESS(COMMAND ${LUA} tools/bin2c.lua ${filename} extension_status OUTPUT_FILE ${target})
ENDFOREACH(filename)

SET(SOURCES
    deps/http-parser/http_parser.c
    src/blogger.cpp
    src/LuaNode.cpp
    src/luanode_child_process.cpp
    src/luanode_crypto.cpp
    src/luanode_dns.cpp
    src/luanode_http_parser.cpp
    src/luanode_module_api.cpp
    src/luanode_net.cpp
    src/luanode_net_acceptor.cpp
    src/luanode_timer.cpp
    src/luanode_os.cpp
    ${OS}
    src/LuaVM.cpp
    lib/preloader.cpp
)

INCLUDE_DIRECTORIES(src ${LUA_INCLUDE_DIR} ${OPENSSL_INCLUDE_DIR} ${Boost_INCLUDE_DIR})
ADD_EXECUTABLE(luanode ${SOURCES})
TARGET_LINK_LIBRARIES(luanode ${LUA_LIBRARIES} ${OPENSSL_LIBRARIES} ${Boost_LIBRARIES})
