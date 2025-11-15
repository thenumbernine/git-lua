#!/usr/bin/env luajit
-- really this is just a process wrapper around git/rundir.lua
-- but that means you have to check for duplicate dirs up front
require 'git.rundir'((assert(..., "expected cmd")))
