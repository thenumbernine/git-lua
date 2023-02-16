#!/usr/bin/env lua

local cmd = assert(..., "you forgot to specify a command")
local io = require 'ext.io'

local lfs = require 'lfs'
local getattr = lfs.symlinkattributes
-- in Windows in lfs 1.8.0 there's an error inside of 'symlinkattributes'
if not pcall(function() getattr'.' end) then
	getattr = lfs.attributes
end

local function recurse()
	local cwd = lfs.currentdir()
	local err
	xpcall(function()
		for f in lfs.dir('.') do
			if f ~= '.' and f ~= '..' then
				local attr = getattr(f)
				if attr == nil then
					io.stderr:write('failed to get attributes for '..cwd..'/'..f..'\n')
				else
					if attr.mode == 'directory'
					and not attr.target	-- and it's not a symlink
					then
						if f == '.git' then
							io.stderr:write(cwd, ' ... ')
							local msg, err = io.readproc('git '..cmd..' 2>&1')
							if msg then
								-- if it is a known / simple message
								-- sometimes it's "Already up to date"
								-- sometimes it's "Already up-to-date"
								if msg:match'^Already up.to.date'
								or msg:match'^There is no tracking information for the current branch'
								then
									--print first line only
									print(msg:match'^([^\r\n]*)')
								elseif msg:match"^On branch (.*)%s+Your branch is up to date with 'origin/(.*)'%.%s+nothing to commit, working tree clean" then
									-- only for this one, go ahead and merge the first \n
									print((msg:gsub('[\r\n]', ' ')))
								else
									-- print all output for things like pulls and conflicts and merges
									print(msg)
								end
							else
								error('ERROR '..err)
							end
						else
							lfs.chdir(f)
							local err
							xpcall(function()
								recurse()
							end, function(msg)
								err = msg..'\n'..debug.traceback()
							end)
							lfs.chdir('..')
							-- TODO what about growing call stacks with directory depth?
							if err then error(err) end
						end
					end
				end
			end
		end
	end, function(msg)
		err = msg..'\n'..debug.traceback()
	end)
	if err then
		io.stderr:write(cwd..'\n'..err)
	end
end

recurse()
