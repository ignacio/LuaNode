#! /bin/bash

set -efo pipefail

mkdir -p "$LUAROCKS_DIR"

pushd "$HOME/build_deps"
	#   Install a recent luarocks release (in the same place as our Lua install)
	curl --location http://luarocks.org/releases/luarocks-$LUAROCKS_VER.tar.gz | tar xz
	pushd luarocks-$LUAROCKS_VER
		if [ "$COMPILE_LUA" == "yes" ]; then
			#./configure --with-lua="$LUA_DIR" --prefix="$LUA_DIR" --lua-version=$LUA_SHORTV
			./configure --with-lua="$LUA_DIR" --prefix="$LUAROCKS_DIR" --lua-version=$LUA_SHORTV
		else
			./configure --prefix="$LUAROCKS_DIR" --lua-version=$LUA_SHORTV
		fi
		make build && make install
	popd
popd
