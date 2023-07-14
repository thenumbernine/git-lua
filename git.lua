#!/usr/bin/env lua
local table = require 'ext.table'
local file = require 'ext.file'

local cmd = assert(..., "you forgot to specify a command")
local io = require 'ext.io'	-- io.readproc

-- don't get stuck in recursion
local checkedSoFar = {}

local srcdir = file:cwd()
local function handleGitDir(reqdir)
	local err
	xpcall(function()
		file(reqdir):cd()
		local cwd = file:cwd()
		-- TODO how to resolve cwd wrt symlinks?
		if checkedSoFar[cwd] then return end
		checkedSoFar[cwd] = true

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
		io.stderr:write(cwd..'\n'..err)
	end
	file(srcdir):cd()
end

file'.':rdir(function(f, isdir)
	local dir, name = file(f):getdir()
	if name == '.git' and isdir then
		handleGitDir(dir)
		return true	-- don't continue
	end
	return true
end)
