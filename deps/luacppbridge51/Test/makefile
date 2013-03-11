# Proyect path:
LOCAL_INCLUDES = ../../../../../includes/
#BOOST_INCLUDES = ../../../../../packages/boost_1_43_0/
#JSONOBJECT_INCLUDES = ../../../../../sources/dev/Shared/JSONObject/

# change these to reflect your Lua installation
#LUA = ../../../../../packages/Lua5.1
LUA = /usr/local
LUAINC = $(LUA)/include
LUALIB = $(LUA)/lib
LUABIN = $(LUA)/bin

# All includes:
SUPPORT_INCLUDES = ../../../../../includes/
INCLUDES = -I. -I.. -I$(SUPPORT_INCLUDES) -I$(SUPPORT_INCLUDES)/supportLib -I$(BOOST_INCLUDES) -I$(JSONOBJECT_INCLUDES) -I$(LUAINC)

#LIBS = -L. $(SUPPORT_LIB) -llua -ldl -lm
LIBS = -L. $(SUPPORT_LIB) -llua -lm

LIB_NAME = Test
VERSION = 1.0.0.0

# Static lib:
OUTPUT_LIB = $(LIB_NAME)
OUTPUT_DIR = .
OUTPUT_FILE = $(OUTPUT_DIR)/$(OUTPUT_LIB)

# probably no need to change anything below here
COMPILER = g++
ARCHIVER = ar

CFLAGS = $(INCLUDES) $(WARN) -O2 -c
AFLAGS = rcs
WARN = -Wall
DEFS = 

LFLAGS = -Wall -fPIC $(DEBUG)
LINK = $(COMPILER) $(LFLAGS) -o "$(OUTPUT_FILE)" $(LIBS) $(OBJS) -L /usr/local/lib -llua
#LINK = $(ARCHIVER) $(AFLAGS) "$(OUTPUT_FILE)" $(OBJS)

COMPILE = echo "COMPILE"; $(COMPILER) $(CFLAGS) "$<" -o "$(*F).o"

OBJS =	Boton.o \
		ClaseHibrida.o \
		ClaseHibridaConProps.o \
		RawWithProps.o \
		Test.o \
		Ventana.o

#JSONObject.o : ../../../../../sources/dev/Shared/JSONObject/JSONObject.cpp
#	$(COMPILE)

# Pattern rules:
%.o : %.cpp
	$(COMPILE)

# Linking supportLib:
all : $(OUTPUT_FILE)

$(OUTPUT_FILE): $(OUTPUT_DIR) $(OBJS)
	$(LINK)
#	$(POST_BUILD_EVENTS)

# Default directories creation in case they don't exist:

$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

clean:
	rm -f $(OBJS) $(OUTPUT_FILE)

tar: clean
	git archive --format=tar --prefix=$(LIB_NAME)-$(VERSION)/ $(VERSION) | gzip > $(LIB_NAME)-$(VERSION).tar.gz
