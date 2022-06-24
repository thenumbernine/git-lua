#!/usr/bin/env lua

local cmd = assert(..., "you forgot to specify a command")

local lfs = require 'lfs'
local getattr = lfs.symlinkattributes
-- in Windows in lfs 1.8.0 there's an error inside of 'symlinkattributes'
if not pcall(function() getattr'.' end) then
	getattr = lfs.attributes
end

local function recurse()
	local cwd = lfs.currentdir()
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
							assert(os.execute('git '..cmd))
						else
							lfs.chdir(f)
							recurse()
							lfs.chdir('..')
						end
					end
				end
			end
		end
	end, function(err)
		io.stderr:write(cwd..'\n'..err..'\n'..debug.traceback())
	end)
end

recurse()
