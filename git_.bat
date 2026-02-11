@echo off

REM fun fact, don't use `git.bat` on windows, or running it will fork-bomb.  use any other name.

REM TODO batch in the same file?

REM TODO resolve path with lua?
REM or have bash get its execution path dir?

REM sequential. boring.
REM luajit "%LUA_PROJECT_PATH%/git/sequential.lua" %*

REM parallelism using shell background processes. proly doesn't work on Windows
REM luajit "%LUA_PROJECT_PATH%/git/parallel-shell.lua" %*

REM parallelism using luajit-thread library
luajit "%LUA_PROJECT_PATH%/git/parallel-threads.lua" %*
