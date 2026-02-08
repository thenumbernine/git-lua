#!/usr/bin/env luajit
-- really this is just a process wrapper around git/oneline.lua
-- but that means you have to check for duplicate dirs up front
local reqdir, gitcmd = ...
assert(reqdir and gitcmd, "expected reqdir gitcmd")
print(require 'git.oneline'(reqdir, gitcmd))
