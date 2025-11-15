#!/usr/bin/env luajit
local path = require 'ext.path'
local rundir = require 'git.rundir'

local cmd = assert(..., "you forgot to specify a command")

-- TODO here launch a process and somehow wait for it to finish ...
-- how to monitor other than busy wait or temp files?
-- start /b git cmd 2^>^&1 ... but that still waits to exit right?

local srcdir = path:cwd()
local checkedSoFar = {}
for f in path'.':rdir(function(f, isdir)
	local dir, name = path(f):getdir()
	if name.path == '.git'
	--and isdir	-- submodule .git folders are coming back in `stat` as regular files ...
	then
		xpcall(function()
			rundir(cmd, dir:fixpathsep(), checkedSoFar)
		end, function(err)
			io.stderr:write(dir..'\n'..err..'\n'..debug.traceback())
		end)
		srcdir:cd()

		--return false -- don't continue
		return true		-- but what if there are subdirs
		-- and if there are subdirs then doing child-first will cause parents' pull to always reset the children ...
	end
	return true
end) do end
