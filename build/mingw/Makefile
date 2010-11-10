
INCONCERT_DEVEL_DEFAULT=../../..
INCONCERT_DEVEL ?= $(INCONCERT_DEVEL_DEFAULT)
INCONCERT_SOURCES_DEFAULT=$(INCONCERT_DEVEL)/sources
INCONCERT_BIN_DEFAULT=$(INCONCERT_DEVEL)/bin
INCONCERT_LIB_DEFAULT=$(INCONCERT_DEVEL)/lib
INCONCERT_BIN ?= $(INCONCERT_BIN_DEFAULT)
INCONCERT_LIB ?= $(INCONCERT_LIB_DEFAULT)

BOOST_DIR_DEFAULT=$(INCONCERT_DEVEL)/packages/boost_1_44_0/
BOOST_DIR ?= $(BOOST_DIR_DEFAULT)
BOOST_LIB_DEFAULT=$(BOOST_DIR)/lib
BOOST_LIB ?= $(BOOST_LIB_DEFAULT)

LUA_DIR ?= $(INCONCERT_DEVEL)/packages/lua5.1
LUA_INC ?= $(LUA_DIR)/include
LUA_LIB ?= $(LUA_DIR)/lib

OPENSSL_DIR ?= $(INCONCERT_DEVEL)/packages/OpenSSL-1.0.0a
OPENSSL_INC ?= $(OPENSSL_DIR)/include
OPENSSL_LIB ?= $(OPENSSL_DIR)/lib

GCC_VERSION ?= $(shell expr substr "`g++ -dumpversion | tr -dc '[0-9]'`" 1 2)

Target ?= Release
CFLAGS = -fPIC -c

BIN2C = ../../tools/bin2c.lua

OBJS_ROOT ?= .
OBJS_DIR = $(OBJS_ROOT)/$(Target)
OUTPUT_DIR = $(INCONCERT_BIN)

SRC_DIR = ../../src
LIB_DIR = ../../lib

# All includes:
INCLUDES = 	-I../											\
			-I$(BOOST_DIR)									\
			-I$(LUA_INC)									\
			-I$(OPENSSL_INC)

# All libs:
LIBS = -L$(INCONCERT_LIB) -L$(BOOST_LIB) -L$(INCONCERT_BIN) -L$(LUA_LIB) -L$(OPENSSL_LIB)

COMPILER = g++
C_COMPILER = gcc
LINKER = g++

ifeq ($(Target), Debug)
	OUTPUT = luanode_d.exe
	CFLAGS = -c -g -D_DEBUG -D_WIN32 -D_MINGW
	LFLAGS = -Wall -g -Wl
	BOOST_SPECIFIC_LIBS = 	-lboost_system-mgw45-mt-d-1_44	\
							-lwsock32 -lws2_32				\
							-llua5.1 -lssleay32 -llibeay32

else
	OUTPUT = luanode.exe
	CFLAGS = -c -O2 -D_NDEBUG -D_WIN32 -D_MINGW
	LFLAGS = -Wall -Wl
	BOOST_SPECIFIC_LIBS = 	-lboost_system-mgw45-mt-1_44	\
							-lwsock32 -lws2_32				\
							-llua5.1 -lssleay32 -llibeay32
endif

OUTPUT_FILE = $(OUTPUT_DIR)/$(OUTPUT)

#dir de jsonobject, para que no me quede tan largo en la linea de compilacion

COMPILE = $(COMPILER) $(CFLAGS) "$<" -o "$(*F).o" $(INCLUDES)
LINK = $(LINKER) $(LFLAGS) -o "$(OUTPUT_FILE)" $(INCLUDES) $(LIBS) $(OBJS) $(BOOST_SPECIFIC_LIBS)

COMPILE_LUA = lua5.1 $(BIN2C) "$<" > "$(@)"

LUAS_PRECOMP = $(LIB_DIR)/LuaNode/child_process.precomp \
				$(LIB_DIR)/LuaNode/console.precomp \
				$(LIB_DIR)/LuaNode/Crypto.precomp \
				$(LIB_DIR)/LuaNode/Dns.precomp \
				$(LIB_DIR)/LuaNode/event_emitter.precomp \
				$(LIB_DIR)/LuaNode/free_list.precomp \
				$(LIB_DIR)/LuaNode/Fs.precomp \
				$(LIB_DIR)/LuaNode/Http.precomp \
				$(LIB_DIR)/LuaNode/Net.precomp \
				$(LIB_DIR)/LuaNode/Path.precomp \
				$(LIB_DIR)/LuaNode/Querystring.precomp \
				$(LIB_DIR)/LuaNode/Stream.precomp \
				$(LIB_DIR)/LuaNode/Timers.precomp \
				$(LIB_DIR)/LuaNode/Url.precomp \
				$(SRC_DIR)/node.precomp \
				$(SRC_DIR)/../deps/StackTracePlus/src/StackTracePlus.precomp

OBJS = http_parser.o \
		blogger.o \
		LuaNode.o \
		luanode_child_process.o \
		luanode_crypto.o \
		luanode_dns.o \
		luanode_file_win32.o \
		luanode_http_parser.o \
		luanode_module_api.o \
		luanode_net.o \
		luanode_net_acceptor.o \
		luanode_timer.o \
		LuaVM.o \
		platform_windows.o \
		../../lib/preloader.o \
		stdafx.o

all : $(OUTPUT_FILE)

#La mayoria de los casos, son Cpp y entran por aca:
%.o : $(SRC_DIR)/%.cpp
	$(COMPILE)
	
#Explicito para http-parser
http_parser.o: $(SRC_DIR)/../deps/http-parser/http_parser.c
	$(C_COMPILER) $(CFLAGS) $(SRC_DIR)/../deps/http-parser/http_parser.c -o http_parser.o $(INCLUDES)

%.precomp : %.lua
	$(COMPILE_LUA)


$(OUTPUT_FILE): $(LUAS_PRECOMP) $(OBJS)
	$(LINK)

.PHONY: clean

clean:
	rm -f *.o
	rm -f $(LIB_DIR)/LuaNode/*.precomp
	rm -f $(SRC_DIR)/node.precomp
	rm -f $(SRC_DIR)/../deps/StackTracePlus/src/StackTracePlus.precomp
	rm -f "$(OUTPUT_FILE)"
