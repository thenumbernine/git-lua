#!/usr/bin/env luajit
local ffi = require 'ffi'
local table = require 'ext.table'
local string = require 'ext.string'
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
		r.shell = os.tmpname()
		r.output = os.tmpname()
		r.done = os.tmpname()
		path(r.done):remove()	-- don't let it exist until we want it to exist

		checking:insert(r)

		if ffi.os == 'Linux' then
			path(r.shell):write(table{
				'luajit "'..luagitdir..'/parallel_url.lua" "'..cmd..'" > "'..r.output..'"',
				'echo "done" >> "'..r.done..'"',
			}:concat'\n'..'\n')

			-- horrible parallelism ...
			-- I should really find a package that does ipc / parallelism for me
			-- hmmmmm why isn't the > working.
			local status, msg, errcode = os.execute('bash "'..r.shell..'" >/dev/null 2>/dev/null &')
			if not status then
				print(r.dir, 'failed with error', msg, errcode)
			end
		else
			error("can't handle this OS yet ... running in sequence")
		end

		srcdir:cd()
	end

	local threads = require 'threadmanager'()
	threads:add(function()
		coroutine.yield()

		while #checking > 0 or #tocheck > 0 do
			-- see if we can add
			if #tocheck > 0 and #checking < maxConcurrent then
				local checkdir = tocheck:remove()
				-- this'll add to 'checking'
				handleGitDir(checkdir)
			end

			if #checking > 0 then
				-- see if it's done
				for i=#checking,1,-1 do
					local r = checking[i]
					if path(r.done):exists() then	-- done
						print(r.dir..' ... '..string.trim(path(r.output):read()))
						path(r.done):remove()
						path(r.output):remove()
						path(r.shell):remove()
						checking:remove(i)
					end
				end
			end

			coroutine.yield()
		end
	end)

	for f in path'.':rdir(function(f, isdir)
		local dir, name = path(f):getdir()
		if name.path == '.git' and isdir then
			tocheck:insert(dir:fixpathsep())
			return false	-- don't continue
		end
		return true
	end) do end

	while #threads.threads > 0 do
		threads:update()
	end

end, function(err)
	io.stderr:write(err,'\n',debug.traceback(),'\n')
end)

for _,r in pairs(checking) do
	path(r.done):remove()
	path(r.output):remove()
end
