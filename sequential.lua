#!/usr/bin/env luajit
local path = require 'ext.path'
local rundir = require 'git.rundir'

local cmd = assert(..., "you forgot to specify a command")

local srcdir = path:cwd()
local checkedSoFar = {}
for f in path'.':rdir(function(f, isdir)
	local dir, name = path(f):getdir()
	if name.path == '.git'
	--and isdir	-- submodule .git folders are coming back in `stat` as regular files ...
	then
		xpcall(function()
			dir:cd()

			-- use cd+cwd to resolve symlinks
			-- TODO how to resolve cwd wrt symlinks?
			local cwd = path:cwd().path
			if not checkedSoFar[cwd] then
				checkedSoFar[cwd] = true

				rundir(cmd)
			end
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
