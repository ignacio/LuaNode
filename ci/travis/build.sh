#! /bin/bash

set -eufo pipefail

cd $TRAVIS_BUILD_DIR/build
if [ "$COMPILE_LUA" == "yes" ]; then
	ls -lahr ${LUA_DIR}
	cmake -DBOOST_ROOT=/usr/lib -DLUA_INCLUDE_DIR=${LUA_DIR}/include -DLUA_LIBRARY=${LUA_DIR}/lib/liblua.a ..
else
	cmake -DBOOST_ROOT=/usr/lib ..
fi
cmake --build .
cp luanode luanode_d
