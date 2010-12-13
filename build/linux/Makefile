
INCONCERT_DEVEL_DEFAULT=../../../..
INCONCERT_DEVEL ?= $(INCONCERT_DEVEL_DEFAULT)
INCONCERT_SOURCES_DEFAULT=$(INCONCERT_DEVEL)/sources
INCONCERT_BIN_DEFAULT=$(INCONCERT_DEVEL)/bin
INCONCERT_LIB_DEFAULT=$(INCONCERT_DEVEL)/lib
INCONCERT_SOURCES ?= $(INCONCERT_SOURCES_DEFAULT)
INCONCERT_BIN ?= $(INCONCERT_BIN_DEFAULT)
INCONCERT_LIB ?= $(INCONCERT_LIB_DEFAULT)

PACKAGES = $(INCONCERT_DEVEL)/packages
#BOOST_DIR_DEFAULT = $(PACKAGES)/boost_1_44_0
BOOST_DIR_DEFAULT = /usr/local/include/boost-1_44
BOOST_DIR ?= $(BOOST_DIR_DEFAULT)
#BOOST_LIBS_DEFAULT = $(BOOST_DIR)/lib
BOOST_LIBS_DEFAULT = /usr/local/lib
BOOST_LIBS ?= $(BOOST_LIBS_DEFAULT)

OPENSSL_DIR_DEFAULT = $(PACKAGES)/OpenSSL-1.0.0a
#OPENSSL_DIR ?= $(OPENSSL_DIR_DEFAULT)
OPENSSL_DIR ?= /usr/local/openssl
OPENSSL_INC ?= $(OPENSSL_DIR)/include

GCC_VERSION ?= $(shell expr substr "`g++ -dumpversion | tr -dc '[0-9]'`" 1 2)

BASE_SRC_DIR = ../../

Target ?= Release

# All includes:
INCLUDES = 	-I../											\
			-I$(INCONCERT_SOURCES) 							\
			-I$(BOOST_DIR)									\
			-I$(PACKAGES)/lua5.1/include					\
			-I$(OPENSSL_INC)								\
			-I.


# All libs:
LIBS = -L$(INCONCERT_LIB) -L$(BOOST_LIBS) -L$(INCONCERT_BIN) -L$(PACKAGES)/lua5.1/src

OUTPUT_DIR = $(INCONCERT_BIN)
COMPILER = g++
COMPILER_C = gcc
LINKER = g++
LUA = lua
BIN2C = $(BASE_SRC_DIR)/tools/bin2c.lua

ifeq ($(Target), Debug)
	OUTPUT = luanode_d
	CFLAGS = -Wall -c -g -D_DEBUG
	LFLAGS = -Wall -g -Wl
	SPECIFIC_LIBS = -lboost_system-gcc$(GCC_VERSION)-mt-d \
			-lboost_thread-gcc$(GCC_VERSION)-mt-d \
			-lblogger2_d \
			-llua
else
	OUTPUT = luanode
	CFLAGS = -Wall -c -O2 -D_NDEBUG 
	LFLAGS = -Wall -Wl
	SPECIFIC_LIBS = -lboost_system-gcc$(GCC_VERSION)-mt \
			-lboost_thread-gcc$(GCC_VERSION)-mt \
			-lblogger2 \
			/usr/local/lib/liblua.a \
			-ldl \
			-lssl
endif

OUTPUT_FILE = $(OUTPUT_DIR)/$(OUTPUT)

#dir de jsonobject, para que no me quede tan largo en la linea de compilacion
JSONOBJECT_DIR=$(INCONCERT_SOURCES)/jsonobject

COMPILE = $(COMPILER) $(CFLAGS) "$<" -o "$(Target)/$(*F).o" $(INCLUDES)
LINK = $(LINKER) $(LFLAGS) -o "$(OUTPUT_FILE)" $(INCLUDES) $(LIBS) $(OBJS) $(SPECIFIC_LIBS)
COMPILE_LUA = $(LUA) $(BIN2C) "$<" extension_status > "$(BASE_SRC_DIR)/build/temp/$(*F).precomp"

OBJS = $(PACKAGES)/lua5.1/src/liblua.a \
		$(Target)/blogger.o \
		$(Target)/LuaNode.o \
		$(Target)/luanode_child_process.o \
		$(Target)/luanode_crypto.o \
		$(Target)/luanode_dns.o \
		$(Target)/luanode_file_linux.o \
		$(Target)/luanode_http_parser.o \
		$(Target)/luanode_module_api.o \
		$(Target)/luanode_net.o \
		$(Target)/luanode_net_acceptor.o \
		$(Target)/luanode_timer.o \
		$(Target)/LuaVM.o \
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
		$(Target)/LuaNode/Net.precomp \
		$(Target)/LuaNode/Path.precomp \
		$(Target)/LuaNode/Querystring.precomp \
		$(Target)/LuaNode/Stream.precomp \
		$(Target)/LuaNode/Timers.precomp \
		$(Target)/LuaNode/Url.precomp \
		$(Target)/LuaNode/Url.precomp \
		$(Target)/src/node.precomp \
		$(Target)/StackTracePlus/StackTracePlus.precomp

all : $(OUTPUT_FILE)

#La mayoria de los casos, son Cpp y entran por aca:
$(Target) :
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

#Explicito para json
$(Target)/jsonobject.o: $(JSONOBJECT_DIR)/src/jsonobject.cpp
	$(COMPILER) $(CFLAGS) $(JSONOBJECT_DIR)/src/jsonobject.cpp -o $(Target)/jsonobject.o $(INCLUDES)


$(Target)/libBlogger2Cpp.o: $(INCONCERT_SOURCES)/libblogger2/src/libBlogger2Cpp.cpp
	$(COMPILER) $(CFLAGS) $(INCONCERT_SOURCES)/libblogger2/src/libBlogger2Cpp.cpp -o $(Target)/libBlogger2Cpp.o $(INCLUDES)

$(Target)/preloader.o: $(BASE_SRC_DIR)/lib/preloader.cpp
	$(COMPILER) $(CFLAGS) $(BASE_SRC_DIR)/lib/preloader.cpp -o $(Target)/preloader.o

$(Target)/http_parser.o: $(BASE_SRC_DIR)/deps/http-parser/http_parser.c
	$(COMPILER) $(CFLAGS) $(BASE_SRC_DIR)/deps/http-parser/http_parser.c -o $(Target)/http_parser.o

$(PACKAGES)/Lua5.1/src/liblua.a:
	cd $(PACKAGES)/Lua5.1/src/
	make linux
	cd ../../../sources/LuaNode/build/linux

$(OUTPUT_FILE): $(Target) $(LUAS) $(OBJS)
	$(LINK)
	rm -f $(Target)/preloader.o

.PHONY: clean

clean:
	rm -f $(BASE_SRC_DIR)/build/temp/*
	rm -f $(Target)/*
	rm -f $(BASE_SRC_DIR)/lib/LuaNode/*.precomp
	rm -f "$(OUTPUT_FILE)"
