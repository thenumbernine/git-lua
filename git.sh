#!/bin/sh

# TODO resolve path with lua?
# or have bash get its execution path dir?
luajit $LUA_PROJECT_PATH/git/sequential.lua "$@"

# TODO batch in the same file?
