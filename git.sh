#!/bin/sh

# TODO batch in the same file?

# TODO resolve path with lua?
# or have bash get its execution path dir?

# sequential. boring.
#luajit $LUA_PROJECT_PATH/git/sequential.lua "$@"

# parallelism using shell background processes. proly doesn't work on Windows
#luajit $LUA_PROJECT_PATH/git/parallel-shell.lua "$@"

# parallelism using luajit-thread library
luajit $LUA_PROJECT_PATH/git/parallel-threads.lua "$@"
