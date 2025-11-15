#!/usr/bin/env luajit
-- really this is just a process wrapper around git/rundir.lua
-- but that means you have to check for duplicates up front

local cmd = ...
assert(cmd, "expected cmd")

local rundir = require 'git.rundir'
rundir(cmd)
