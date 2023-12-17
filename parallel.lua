#!/usr/bin/env luajit
local ffi = require 'ffi'
local table = require 'ext.table'
local path = require 'ext.path'

local cmd = assert(..., "you forgot to specify a command")
local srcdir = path:cwd()

-- don't get stuck in recursion
local checkedCWDs = {}
local doneLookingForFiles
local doneProcessingFiles
local maxConcurrent = 4
local tocheck = table()	-- mitigate these, only allow 4 checking at a time
local checking = table()
xpcall(function()
	local function handleGitDir(reqdir)
		-- prevent symlinks piling up
		path(reqdir):cd()
		local cwd = path:cwd()
		if checkedCWDs[cwd] then return end
		checkedCWDs[cwd] = true

		
		local r = {}
		r.dir = cwd
		r.output = os.tmpname()
		r.done = os.tmpname()
		checking:insert(r)
		print(require 'ext.tolua'(r))

		if ffi.os == 'Linux' then
			-- horrible parallelism ...
			-- I should really find a package that does ipc / parallelism for me
			-- hmmmmm why isn't the > working.
			local cmd = '{ luajit "'..os.getenv'LUA_PROJECT_PATH'..'/git/parallel_url.lua" "'..cmd..'" > "'..r.output..'" 2>&1; echo "done" > "'..r.done..'"; }  &'
			print('>'..cmd)
			print(os.execute(cmd))
		else
			error("can't handle this OS yet ... running in sequence")
		end

		srcdir:cd()
	end

	local th = coroutine.create(function()
		while
		not doneLookingForFiles
		or #checking > 0
		do
			-- see if we can add 
			if #tocheck > 0 and #checking < maxConcurrent then
				local checkdir = tocheck:remove()
				-- this'll add to 'checking'
				print('checking '..checkdir)
				handleGitDir(checkdir)
			end
			
			if #checking > 0 then
				-- see if it's done
				for i=#checking,1,-1 do
					local r = checking[i]
					if path(r.done):exists() then	-- done
						print('got results for '..r.dir)
						print('out:', path(r.output):read())
						print('removing...')
						--path(r.done):remove()
						--path(r.output):remove()
						checking:remove(i)
					end
				end
			end
			
			coroutine.yield()
		end
	end)

	path'.':rdir(function(f, isdir)
		local dir, name = path(f):getdir()
		if name.path == '.git' and isdir then
			print('adding '..dir..' to list to check')
			tocheck:insert(dir:fixpathsep())
			coroutine.resume(th)
			return false	-- don't continue
		end
		return true
	end)
	print('done looking for files, now waiting for them to finish...')
	doneLookingForFiles = true
	
	while coroutine.status(th) ~= 'dead' do
		assert(coroutine.resume(th))
	end
	print('done waiting for them to finish...')

end, function(err)
	io.stderr:write(err,'\n',debug.traceback(),'\n')
end)

for _,r in pairs(checking) do
	path(r.done):remove()
	path(r.output):remove()
end
