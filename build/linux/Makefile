
INCONCERT_DEVEL   ?=../../../..
INCONCERT_SOURCES ?=$(INCONCERT_DEVEL)/sources
INCONCERT_BIN     ?=$(INCONCERT_DEVEL)/bin
INCONCERT_LIB     ?=$(INCONCERT_DEVEL)/lib

PACKAGES = $(INCONCERT_DEVEL)/packages

INCLUDE_DIR ?= /usr/local/include
LIB_DIR ?= /usr/local/lib

PREFIX ?= /usr/local

BOOST_VERSION ?= 1_44
BOOST_DIR     ?= $(INCLUDE_DIR)/boost-$(BOOST_VERSION)
BOOST_LIBS    ?= $(LIB_DIR)

# Lua includes directory
#LUA_INC = -I$(PACKAGES)/lua5.1/include
LUA_INC ?= $(INCLUDE_DIR)
LUA_LIB ?= $(LIB_DIR)/liblua.a


OPENSSL_INC ?= /usr/include/openssl

INCONCERT_COMPILER ?= g++
INCONCERT_COMPILER_C ?= gcc

GCC_VERSION ?= $(shell expr substr "`$(INCONCERT_COMPILER) -dumpversion | tr -dc '[0-9]'`" 1 2)

BASE_SRC_DIR = $(realpath $(dir $(realpath $(lastword $(MAKEFILE_LIST))))../..)

Target ?= Release

BUILD_TEMP_DIR = $(BASE_SRC_DIR)/build/temp/$(Target)

# All includes:
INCLUDES =	-I$(INCONCERT_SOURCES)	\
			-I$(LUA_INC)			\
			-I$(BOOST_DIR)			\
			-I$(OPENSSL_INC)		\
			-I$(BUILD_TEMP_DIR)

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
	CFLAGS = -Wall -c -g -D_DEBUG -DENABLE_LIBBLOGGER -Werror
	LFLAGS = -Wall -g -Wl,-E
	SPECIFIC_LIBS = -l$(BOOST_SYSTEM_LIBD) \
			$(LUA_LIB) \
			-ldl \
			-lssl \
			-lpthread \
			-lcrypto \
			-lblogger2_d
else
	OUTPUT = $(OUTPUT_BASE)
	CFLAGS = -Wall -c -O2 -D_NDEBUG -D_SOURCE_PATH=$(BASE_SRC_DIR) -Wno-strict-aliasing -Werror
	LFLAGS = -Wall -Wl,-E
	SPECIFIC_LIBS = -l$(BOOST_SYSTEM_LIB) \
			$(LUA_LIB) \
			-ldl \
			-lssl \
			-lpthread \
			-lcrypto
endif

OUTPUT_FILE = $(OUTPUT_DIR)/$(OUTPUT)


COMPILE = $(COMPILER) $(CFLAGS) "$<" -o "$(BUILD_TEMP_DIR)/$(*F).o" $(INCLUDES)
LINK = $(LINKER) $(LFLAGS) -o "$(OUTPUT_FILE)" $(INCLUDES) $(LIBS) $(OBJS) $(SPECIFIC_LIBS)
COMPILE_LUA = $(LUA) $(BIN2C) "$<" extension_status > "$(BUILD_TEMP_DIR)/$(*F).precomp"

OBJS = $(PACKAGES)/Lua5.1/src/liblua.a \
		$(BUILD_TEMP_DIR)/blogger.o \
		$(BUILD_TEMP_DIR)/luanode.o \
		$(BUILD_TEMP_DIR)/luanode_child_process.o \
		$(BUILD_TEMP_DIR)/luanode_constants.o \
		$(BUILD_TEMP_DIR)/luanode_crypto.o \
		$(BUILD_TEMP_DIR)/luanode_dns.o \
		$(BUILD_TEMP_DIR)/luanode_file_linux.o \
		$(BUILD_TEMP_DIR)/luanode_http_parser.o \
		$(BUILD_TEMP_DIR)/luanode_module_api.o \
		$(BUILD_TEMP_DIR)/luanode_net.o \
		$(BUILD_TEMP_DIR)/luanode_datagram_udp.o \
		$(BUILD_TEMP_DIR)/luanode_net_acceptor.o \
		$(BUILD_TEMP_DIR)/luanode_timer.o \
		$(BUILD_TEMP_DIR)/luanode_os.o \
		$(BUILD_TEMP_DIR)/luanode_stdio_linux.o \
		$(BUILD_TEMP_DIR)/lua_vm.o \
		$(BUILD_TEMP_DIR)/platform_linux.o \
		$(BUILD_TEMP_DIR)/preloader.o \
		$(BUILD_TEMP_DIR)/http_parser.o

LUAS = 	$(BUILD_TEMP_DIR)/child_process.precomp \
		$(BUILD_TEMP_DIR)/class.precomp \
		$(BUILD_TEMP_DIR)/console.precomp \
		$(BUILD_TEMP_DIR)/crypto.precomp \
		$(BUILD_TEMP_DIR)/datagram.precomp \
		$(BUILD_TEMP_DIR)/dns.precomp \
		$(BUILD_TEMP_DIR)/event_emitter.precomp \
		$(BUILD_TEMP_DIR)/free_list.precomp \
		$(BUILD_TEMP_DIR)/fs.precomp \
		$(BUILD_TEMP_DIR)/http.precomp \
		$(BUILD_TEMP_DIR)/net.precomp \
		$(BUILD_TEMP_DIR)/path.precomp \
		$(BUILD_TEMP_DIR)/querystring.precomp \
		$(BUILD_TEMP_DIR)/readline.precomp \
		$(BUILD_TEMP_DIR)/repl.precomp \
		$(BUILD_TEMP_DIR)/script.precomp \
		$(BUILD_TEMP_DIR)/stream.precomp \
		$(BUILD_TEMP_DIR)/timers.precomp \
		$(BUILD_TEMP_DIR)/tty.precomp \
		$(BUILD_TEMP_DIR)/tty_posix.precomp \
		$(BUILD_TEMP_DIR)/url.precomp \
		$(BUILD_TEMP_DIR)/utils.precomp \
		$(BUILD_TEMP_DIR)/node.precomp \
		$(BUILD_TEMP_DIR)/StackTracePlus/StackTracePlus.precomp

all : $(OUTPUT_FILE)


$(BUILD_TEMP_DIR) :
	mkdir -p $(BUILD_TEMP_DIR)

$(BUILD_TEMP_DIR)/%.o : $(BASE_SRC_DIR)/src/%.cpp
	@echo ""
	$(COMPILE)

$(BUILD_TEMP_DIR)/%.precomp : $(BASE_SRC_DIR)/lib/luanode/%.lua
	@echo ""
	$(COMPILE_LUA)

$(BUILD_TEMP_DIR)/%.precomp : $(BASE_SRC_DIR)/src/%.lua
	@echo ""
	$(COMPILE_LUA)

$(BUILD_TEMP_DIR)/StackTracePlus/%.precomp : $(BASE_SRC_DIR)/deps/StackTracePlus/src/%.lua
	@echo ""
	$(COMPILE_LUA)



$(BUILD_TEMP_DIR)/preloader.o: $(BASE_SRC_DIR)/lib/preloader.cpp
	$(COMPILER) $(CFLAGS) $(BASE_SRC_DIR)/lib/preloader.cpp -o $(BUILD_TEMP_DIR)/preloader.o -I $(INCLUDES)

$(BUILD_TEMP_DIR)/http_parser.o: $(BASE_SRC_DIR)/deps/http-parser/http_parser.c
	$(COMPILER) $(CFLAGS) -Wno-error $(BASE_SRC_DIR)/deps/http-parser/http_parser.c -o $(BUILD_TEMP_DIR)/http_parser.o

#$(PACKAGES)/Lua5.1/src/liblua.a:
#	cd $(PACKAGES)/Lua5.1/src/
#	make linux
#	cd ../../../sources/LuaNode/build/linux

$(OUTPUT_FILE): $(BUILD_TEMP_DIR) $(LUAS) $(OBJS)
	$(LINK)
	rm -f $(BUILD_TEMP_DIR)/preloader.o

.PHONY: clean

clean:
	rm -rf $(BUILD_TEMP_DIR)
	rm -f $(BASE_SRC_DIR)/lib/luanode/*.precomp
	rm -f "$(OUTPUT_FILE)"
