#! /bin/bash

set -eufo pipefail

export LUAROCKS_DIR="$HOME/luarocks/$LUA_SHORTV"

mkdir -p "$LUAROCKS_DIR"

pushd "$HOME/build_deps"
	#   Install a recent luarocks release (in the same place as our Lua install)
	curl --location http://luarocks.org/releases/luarocks-$LUAROCKS_VER.tar.gz | tar xz
	pushd luarocks-$LUAROCKS_VER
		./configure --with-lua="$LUA_DIR" --prefix="$LUA_DIR" --lua-version=$LUA_SHORTV
		make build && make install
	popd
popd

export PATH=$PATH:$LUAROCKS_DIR/bin
