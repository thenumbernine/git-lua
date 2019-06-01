#!/usr/bin/env lua

local cmd = assert(..., "you forgot to specify a command")

require 'lfs'

local function recurse()
	local cwd = lfs.currentdir()
	xpcall(function()
		for f in lfs.dir('.') do
			if f ~= '.' and f ~= '..' then
				local attr = lfs.attributes(f)
				if attr == nil then
					io.stderr:write('failed to get attributes for '..cwd..'/'..f..'\n')
				else
					if attr.mode == 'directory' then
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
