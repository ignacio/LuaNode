#! /bin/bash

set -eufo pipefail

pushd "$HOME/build_deps"

if [ "$COMPILE_LUA" == "yes" ]; then
	mkdir -p "$LUA_DIR"

	curl http://www.lua.org/ftp/lua-$LUA_VER.tar.gz | tar xz
	pushd lua-$LUA_VER
		make linux
		make INSTALL_TOP="$LUA_DIR" install
	popd
fi

popd
