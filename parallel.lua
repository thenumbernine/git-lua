#!/usr/bin/env luajit
local ffi = require 'ffi'
local table = require 'ext.table'
local path = require 'ext.path'
local os = require 'ext.os'

local srcdir = path:cwd()

-- chdir to source dir
--local luagitdir = path(package.searchpath('git.parallel', package.path):gsub('\\', '/')):getdir()
path(arg[0]):getdir():cd()
local luagitdir = path:cwd()
srcdir:cd()


local cmd = assert(..., "you forgot to specify a command")

-- don't get stuck in recursion
local checkedCWDs = {}
local doneLookingForFiles
local doneProcessingFiles
local maxConcurrent = 4	-- = require 'thread'.numThreads()
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
print('handleGitDir checking', r)
		checking:insert(r)
		print(require 'ext.tolua'(r))

		if ffi.os == 'Linux' then
			-- horrible parallelism ...
			-- I should really find a package that does ipc / parallelism for me
			-- hmmmmm why isn't the > working.
			local cmd = '(luajit "'..luagitdir..'/parallel_url.lua" "'..cmd..'" &> "'..r.output..'"; echo "done" >> "'..r.done..'")  &'
			os.exec(cmd)
		else
			error("can't handle this OS yet ... running in sequence")
		end

		srcdir:cd()
	end

	local threads = require 'threadmanager'()
	threads:add(function()
		coroutine.yield()

		while
--		not doneLookingForFiles or
		--#checking > 0
		true
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
-- ...... but it's not done.
-- why is it writing 'done' before the output file even exists?
						print('got results for '..r.dir)
						print('out:', path(r.output):read())
						print('removing...')
						path(r.output):remove()
						path(r.done):remove()
						checking:remove(i)
					end
				end
			end

			coroutine.yield()
		end
	end)

	for f in path'.':rdir(function(f, isdir)
		local dir, name = path(f):getdir()
--print('searching', dir, name)
		if name.path == '.git' and isdir then
--print('adding '..dir..' to list to check')
			tocheck:insert(dir:fixpathsep())
			return false	-- don't continue
		end
		return true
	end) do end

	threads:update()

	print('done looking for files, now waiting for them to finish...')
	doneLookingForFiles = true

	threads:update()

	print('done waiting for them to finish...')

end, function(err)
	io.stderr:write(err,'\n',debug.traceback(),'\n')
end)

for _,r in pairs(checking) do
	path(r.done):remove()
	path(r.output):remove()
end
