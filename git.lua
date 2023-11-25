#!/usr/bin/env lua
local table = require 'ext.table'
local path = require 'ext.path'

local cmd = assert(..., "you forgot to specify a command")
local io = require 'ext.io'	-- io.readproc

-- don't get stuck in recursion
local checkedSoFar = {}

local srcdir = path:cwd()
local function handleGitDir(reqdir)
	local err
	xpcall(function()
		path(reqdir):cd()
		local cwd = path:cwd()
		-- TODO how to resolve cwd wrt symlinks?
		if checkedSoFar[cwd] then return end
		checkedSoFar[cwd] = true

		-- TODO here launch a process and somehow wait for it to finish ...
		-- how to monitor other than busy wait or temp files?
-- start /b git cmd 2^>^&1 ... but that still waits to exit right?

		io.stderr:write(cwd, ' ... ')
		local msg
		msg, err = io.readproc('git '..cmd..' 2>&1')
		if msg then
			-- if it is a known / simple message
			-- sometimes it's "Already up to date"
			-- sometimes it's "Already up-to-date"
			if msg:match'^Already up.to.date'
			or msg:match'^There is no tracking information for the current branch'
			then
				--print first line only
				print(msg:match'^([^\r\n]*)')
			elseif msg:match"^On branch(.*)%s+Your branch is up.to.date with 'origin/(.*)'%.%s+nothing to commit, working tree clean" then
				-- only for this one, go ahead and merge the first \n
				print((msg:gsub('[\r\n]', ' ')))
			else
				-- print all output for things like pulls and conflicts and merges
				print(msg)
			end
		else
			error('ERROR '..err)
		end
	end, function(msg)
		err = msg..'\n'..debug.traceback()
	end)
	if err then
		io.stderr:write(reqdir..'\n'..err)
	end
	path(srcdir):cd()
end

path'.':rdir(function(f, isdir)
	local dir, name = path(f):getdir()
	if name == '.git' and isdir then
		handleGitDir(dir:fixpathsep())
		return true	-- don't continue
	end
	return true
end)
