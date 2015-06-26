#! /bin/bash

if [ "$COMPILE_LUA" == "yes" ]; then
	# defines LUA_DIR so CMake can find this Lua install
	export LUA_DIR="$HOME/lua/$LUA_SHORTV"
	export PATH=${PATH}:${LUA_DIR}/bin
fi

export LUAROCKS_DIR="$HOME/luarocks/$LUA_SHORTV"
export PATH=${PATH}:${LUAROCKS_DIR}/bin
