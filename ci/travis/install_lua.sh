#! /bin/bash

set -eufo pipefail

pushd "$HOME/build_deps"

if [ "$COMPILE_LUA" == "yes" ]; then
	# defines LUA_DIR so CMake can find this Lua install
	export LUA_DIR="$HOME/lua/$LUA_SHORTV"
	mkdir -p "$LUA_DIR"

	curl http://www.lua.org/ftp/lua-$LUA_VER.tar.gz | tar xz
	pushd lua-$LUA_VER
		make linux
		make INSTALL_TOP="$LUA_DIR" install
		export PATH=$PATH:$LUA_DIR/bin
	popd
fi

popd
