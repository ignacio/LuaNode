
INCONCERT_DEVEL_DEFAULT=../../../..
INCONCERT_DEVEL ?= $(INCONCERT_DEVEL_DEFAULT)
INCONCERT_SOURCES_DEFAULT=$(INCONCERT_DEVEL)/sources
INCONCERT_BIN_DEFAULT=$(INCONCERT_DEVEL)/bin
INCONCERT_LIB_DEFAULT=$(INCONCERT_DEVEL)/lib
INCONCERT_SOURCES ?= $(INCONCERT_SOURCES_DEFAULT)
INCONCERT_BIN ?= $(INCONCERT_BIN_DEFAULT)
INCONCERT_LIB ?= $(INCONCERT_LIB_DEFAULT)

PACKAGES = $(INCONCERT_DEVEL)/packages

INCLUDE_DIR ?= /usr/local/include
LIB_DIR ?= /usr/local/lib

PREFIX ?= /usr/local

BOOST_VERSION ?= 1_44
BOOST_DIR_DEFAULT = $(INCLUDE_DIR)/boost-$(BOOST_VERSION)
BOOST_DIR ?= $(BOOST_DIR_DEFAULT)
BOOST_LIBS ?= $(LIB_DIR)

# Lua includes directory
#LUA_INC = -I$(PACKAGES)/lua5.1/include
LUA_INC ?= $(INCLUDE_DIR)
LUA_LIB ?= $(LIB_DIR)/liblua.a


OPENSSL_INC ?= /usr/include/openssl

INCONCERT_COMPILER ?= g++
INCONCERT_COMPILER_C ?= gcc

GCC_VERSION ?= $(shell expr substr "`$(INCONCERT_COMPILER) -dumpversion | tr -dc '[0-9]'`" 1 2)

BASE_SRC_DIR = ../..

Target ?= Release

# All includes:
INCLUDES =	-I$(INCONCERT_SOURCES)	\
			-I$(LUA_INC)			\
			-I$(BOOST_DIR)			\
			-I$(OPENSSL_INC)


# All libs:
LIBS = -L$(INCONCERT_LIB) -L$(BOOST_LIBS) -L$(INCONCERT_BIN)

OUTPUT_BASE = luanode

OUTPUT_DIR = $(INCONCERT_BIN)
COMPILER = $(INCONCERT_COMPILER)
COMPILER_C = $(INCONCERT_COMPILER_C)
LINKER = $(INCONCERT_COMPILER)
LUA ?= $(shell which lua)
BIN2C = $(BASE_SRC_DIR)/tools/bin2c.lua

# if Lua is not on the path, either set it explicitly
ifeq ($(strip $(LUA)),)
	LUA = /usr/local/bin/lua
endif

BOOST_SYSTEM_LIB ?=boost_system-gcc$(GCC_VERSION)-mt-$(BOOST_VERSION)
BOOST_SYSTEM_LIBD ?=boost_system-gcc$(GCC_VERSION)-mt-d-$(BOOST_VERSION)

ifeq ($(Target), Debug)
	OUTPUT = $(OUTPUT_BASE)_d
	CFLAGS = -Wall -c -g -D_DEBUG
	LFLAGS = -Wall -g -Wl,-E
	SPECIFIC_LIBS = -l$(BOOST_SYSTEM_LIBD) \
			$(LUA_LIB) \
			-ldl \
			-lssl \
			-lpthread \
			-lcrypto
else
	OUTPUT = $(OUTPUT_BASE)
	CFLAGS = -Wall -c -O2 -D_NDEBUG -Wno-strict-aliasing
	LFLAGS = -Wall -Wl,-E
	SPECIFIC_LIBS = -l$(BOOST_SYSTEM_LIB) \
			$(LUA_LIB) \
			-ldl \
			-lssl \
			-lpthread \
			-lcrypto
endif

OUTPUT_FILE = $(OUTPUT_DIR)/$(OUTPUT)

COMPILE = $(COMPILER) $(CFLAGS) "$<" -o "$(Target)/$(*F).o" $(INCLUDES)
LINK = $(LINKER) $(LFLAGS) -o "$(OUTPUT_FILE)" $(INCLUDES) $(LIBS) $(OBJS) $(SPECIFIC_LIBS)
COMPILE_LUA = $(LUA) $(BIN2C) "$<" extension_status > "$(BASE_SRC_DIR)/build/temp/$(*F).precomp"

OBJS = $(PACKAGES)/Lua5.1/src/liblua.a \
		$(Target)/blogger.o \
		$(Target)/luanode.o \
		$(Target)/luanode_child_process.o \
		$(Target)/luanode_crypto.o \
		$(Target)/luanode_dns.o \
		$(Target)/luanode_file_linux.o \
		$(Target)/luanode_http_parser.o \
		$(Target)/luanode_module_api.o \
		$(Target)/luanode_net.o \
		$(Target)/luanode_datagram_udp.o \
		$(Target)/luanode_net_acceptor.o \
		$(Target)/luanode_timer.o \
		$(Target)/luanode_os.o \
		$(Target)/luanode_stdio_linux.o \
		$(Target)/lua_vm.o \
		$(Target)/platform_linux.o \
		$(Target)/preloader.o \
		$(Target)/http_parser.o

LUAS = 	$(Target)/LuaNode/child_process.precomp \
		$(Target)/LuaNode/Class.precomp \
		$(Target)/LuaNode/console.precomp \
		$(Target)/LuaNode/Crypto.precomp \
		$(Target)/LuaNode/Dns.precomp \
		$(Target)/LuaNode/event_emitter.precomp \
		$(Target)/LuaNode/free_list.precomp \
		$(Target)/LuaNode/Fs.precomp \
		$(Target)/LuaNode/Http.precomp \
		$(Target)/LuaNode/Datagram.precomp \
		$(Target)/LuaNode/Net.precomp \
		$(Target)/LuaNode/Path.precomp \
		$(Target)/LuaNode/Querystring.precomp \
		$(Target)/LuaNode/Stream.precomp \
		$(Target)/LuaNode/Timers.precomp \
		$(Target)/LuaNode/Url.precomp \
		$(Target)/LuaNode/Utils.precomp \
		$(Target)/LuaNode/Script.precomp \
		$(Target)/LuaNode/Tty.precomp \
		$(Target)/LuaNode/Tty_posix.precomp \
		$(Target)/src/node.precomp \
		$(Target)/StackTracePlus/StackTracePlus.precomp

all : $(OUTPUT_FILE)


$(Target) :
	echo $(LUA)
	mkdir -p $(Target)
	mkdir -p $(BASE_SRC_DIR)/build/temp

$(Target)/%.o : $(BASE_SRC_DIR)/src/%.cpp 
	@echo ""
	$(COMPILE)

$(Target)/LuaNode/%.precomp : $(BASE_SRC_DIR)/lib/LuaNode/%.lua
	@echo ""
	$(COMPILE_LUA)

$(Target)/src/%.precomp : $(BASE_SRC_DIR)/src/%.lua
	@echo ""
	$(COMPILE_LUA)

$(Target)/StackTracePlus/%.precomp : $(BASE_SRC_DIR)/deps/StackTracePlus/src/%.lua
	@echo ""
	$(COMPILE_LUA)



$(Target)/preloader.o: $(BASE_SRC_DIR)/lib/preloader.cpp
	$(COMPILER) $(CFLAGS) $(BASE_SRC_DIR)/lib/preloader.cpp -o $(Target)/preloader.o

$(Target)/http_parser.o: $(BASE_SRC_DIR)/deps/http-parser/http_parser.c
	$(COMPILER) $(CFLAGS) $(BASE_SRC_DIR)/deps/http-parser/http_parser.c -o $(Target)/http_parser.o

#$(PACKAGES)/Lua5.1/src/liblua.a:
#	cd $(PACKAGES)/Lua5.1/src/
#	make linux
#	cd ../../../sources/LuaNode/build/linux

$(OUTPUT_FILE): $(Target) $(LUAS) $(OBJS)
	$(LINK)
	rm -f $(Target)/preloader.o

.PHONY: clean

clean:
	rm -f $(BASE_SRC_DIR)/build/temp/*
	rm -f $(Target)/*
	rm -f $(BASE_SRC_DIR)/lib/LuaNode/*.precomp
	rm -f "$(OUTPUT_FILE)"
