PROJECT(LuaNode C CXX)
CMAKE_MINIMUM_REQUIRED(VERSION 2.6)

FIND_PACKAGE(Lua51 REQUIRED)
FIND_PACKAGE(OpenSSL REQUIRED)
FIND_PACKAGE(Threads REQUIRED)

SET( Boost_USE_STATIC_LIBS ON )
SET( Boost_USE_MULTITHREADED ON )
SET( Boost_USE_STATIC_RUNTIME OFF )
ADD_DEFINITIONS( -DBOOST_ALL_NO_LIB )

FIND_PACKAGE(Boost COMPONENTS system date_time thread REQUIRED)

FIND_PROGRAM(LUA NAMES lua-5.1 lua5.1 lua)

IF(WIN32)
    ADD_DEFINITIONS( -D_CRT_SECURE_NO_WARNINGS )
    ADD_DEFINITIONS( -D_WIN32_WINNT=0x0501 )
    SET(OS
        src/luanode_file_win32.cpp
        src/platform_windows.cpp
        src/luanode_stdio_win32.cpp
        src/detail/windows/input_tty.cpp
        src/detail/windows/output_tty.cpp
        src/detail/windows/windows_tty.cpp
    )
ELSEIF(${CMAKE_SYSTEM_NAME} MATCHES "BSD")
    FIND_LIBRARY(KVM_LIBRARIES NAMES kvm)
    SET(OS
        src/luanode_file_linux.cpp
        src/platform_bsd.cpp
        src/luanode_stdio_linux.cpp
        src/detail/tty_stream.cpp
    )
ELSE()
    SET(OS
        src/luanode_file_linux.cpp
        src/platform_linux.cpp
        src/luanode_stdio_linux.cpp
        src/detail/tty_stream.cpp
    )
ENDIF()

SET(LUAS
    lib/luanode/child_process
    lib/luanode/class
    lib/luanode/console
    lib/luanode/crypto
    lib/luanode/datagram
    lib/luanode/dns
    lib/luanode/event_emitter
    lib/luanode/free_list
    lib/luanode/fs
    lib/luanode/http
    lib/luanode/net
    lib/luanode/path
    lib/luanode/querystring
    lib/luanode/readline
    lib/luanode/repl
    lib/luanode/script
    lib/luanode/stream
    lib/luanode/timers
    lib/luanode/tty
    lib/luanode/url
    lib/luanode/utils
    ${LUA_OS}
    src/node
    deps/StackTracePlus/src/StackTracePlus
)

SET(DST ${CMAKE_SOURCE_DIR}/build/temp)
SET(SRC ${CMAKE_SOURCE_DIR})
FILE(MAKE_DIRECTORY ${DST})

FILE(WRITE ${DST}/${target}/build_path.precomp \"${SRC}\")

FOREACH(filename ${LUAS})
    GET_FILENAME_COMPONENT(base ${filename} NAME)
    SET(target "${DST}/${base}.precomp")
    MESSAGE(STATUS "Precompiling ${filename} into ${target}")
    EXECUTE_PROCESS(COMMAND ${LUA} ${SRC}/tools/bin2c.lua ${SRC}/${filename}.lua extension_status OUTPUT_FILE ${target})
ENDFOREACH(filename)

SET(SOURCES
    src/blogger.cpp
    src/luanode.cpp
    src/luanode_child_process.cpp
    src/luanode_constants.cpp
    src/luanode_crypto.cpp
    src/luanode_dns.cpp
    src/luanode_datagram_udp.cpp
    src/luanode_hrtime.cpp
    src/luanode_http_parser.cpp
    src/luanode_module_api.cpp
    src/luanode_net.cpp
    src/luanode_net_acceptor.cpp
    src/luanode_timer.cpp
    src/luanode_os.cpp
    src/lua_vm.cpp
    ${OS}
    lib/preloader.cpp
    deps/http-parser/http_parser.c
)

INCLUDE_DIRECTORIES(src ${LUA_INCLUDE_DIR} ${OPENSSL_INCLUDE_DIR} ${Boost_INCLUDE_DIR} ${DST})
ADD_EXECUTABLE(luanode ${SOURCES})
TARGET_LINK_LIBRARIES(luanode ${LUA_LIBRARIES} ${OPENSSL_LIBRARIES} ${Boost_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT})
IF(${CMAKE_SYSTEM_NAME} MATCHES "BSD")
TARGET_LINK_LIBRARIES(luanode ${KVM_LIBRARIES})
ENDIF()
