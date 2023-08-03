#!/usr/bin/env luajit
local ffi = require 'ffi'
local table = require 'ext.table'
local path = require 'ext.path'

local cmd = assert(..., "you forgot to specify a command")
local srcdir = path:cwd()

-- don't get stuck in recursion
local checkedSoFar = {}
local requests = {}
local nextreq = 1
xpcall(function()
	local function handleGitDir(reqdir)
		-- TODO how to resolve cwd wrt symlinks?
		path(reqdir):cd()
		local cwd = path:cwd()
		if checkedSoFar[cwd] then return end
		checkedSoFar[cwd] = true

		assert(not requests[nextreq])
		local r = {}
		requests[nextreq] = r
		nextreq = nextreq + 1
		r.dst = os.tmpname()

		if ffi.os == 'Linux' then
			-- horrible parallelism ...
			-- I should really find a package that does ipc / parallelism for me
			os.execute('luajit "'..os.getenv'LUA_PROJECT_PATH'..'/git/parallel_url.lua" "'..reqdir..'" "'..cmd..'" > "'..r.dst..'" 2&>1 &')
		else
			error("can't handle this OS yet ... running in sequence")
		end

		path(srcdir):cd()
	end

	path'.':rdir(function(f, isdir)
		local dir, name = path(f):getdir()
		if name == '.git' and isdir then
			handleGitDir(dir)
			return false	-- don't continue
		end
		return true
	end)
end, function(err)
	io.stderr:write(err,'\n',debug.traceback(),'\n')
end)

for _,r in pairs(requests) do
	if r.dst then
		os.remove(r.dst)
		r.dst = nil
	end
end
