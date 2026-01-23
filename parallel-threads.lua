#!/usr/bin/env luajit
local ffi = require 'ffi'
local table = require 'ext.table'
local range = require 'ext.range'
local tolua = require 'ext.tolua'
local path = require 'ext.path'


local srcdir = path:cwd()

-- chdir to source dir
--local luagitdir = path(package.searchpath('git.parallel', package.path):gsub('\\', '/')):getdir()
path(arg[0]):getdir():cd()
local luagitdir = path:cwd()
srcdir:cd()


local cmd = assert(..., "you forgot to specify a command")


local maxConcurrent = 4	-- = require 'thread'.numThreads()
local tocheck = table()	-- mitigate these, only allow 4 checking at a time
for f in path'.':rdir(function(f, isdir)
	local dir, name = path(f):getdir()
	if name.path == '.git' and isdir then
		tocheck:insert(dir:fixpathsep())
		return false	-- don't continue
	end
	return true
end) do end

-- filter out unique
do
	local tocheckUnique = table()
	for _,reqdir in ipairs(tocheck) do
		path(reqdir):cd()
		local absreqdir = path:cwd().path
		srcdir:cd()
		tocheckUnique[absreqdir] = true
	end
	tocheck = table.keys(tocheckUnique):sort()
end

-- don't collect
local writeMutex = require 'thread.mutex'()
_G.writeMutex = writeMutex 

local Pool = require 'thread.pool'
local pool = Pool{
	-- concurrency ... double it just because half of these are going to get stuck on something or another
	size = 2 * require 'thread'.numThreads(),
	userdata = ffi.cast('void*', writeMutex.id),
	-- runs once upon init
	initcode = [[
local io = require 'ext.io'
local path = require 'ext.path'
local writeMutex = require 'thread.mutex':wrap(userdata)
]],
	-- runs per cycle
	code = [[
local i = tonumber(pool.taskIndex)+1
local reqdir = tocheck[i]

-- NOTICE the rest is the same as rundir.lua ...
-- ... except without any cd'ing
-- ... and with a mutex around the output

-- hmm none of the entries are . but somehow it is looking for one entry of .git at ./.git ....
local gitpath = path(reqdir)'.git'
if not gitpath:exists() then
	error("expected to find "..gitpath)
end

local msg, err = io.readproc('cd "'..reqdir..'"; git '..cmd..' 2>&1')

if msg then
	-- if it is a known / simple message
	-- sometimes it's "Already up to date"
	-- sometimes it's "Already up-to-date"
	if msg:match'^Already up.to.date'
	or msg:match'^Everything up.to.date'
	or msg:match'^There is no tracking information for the current branch'
	then
		--print first line only
		msg = msg:match'^([^\r\n]*)'
	elseif msg:match"^On branch(.*)%s+Your branch is up.to.date with 'origin/(.*)'%.%s+nothing to commit, working tree clean" then
		-- only for this one, go ahead and merge the first \n
		msg = msg:gsub('[\r\n]', ' ')
	else
		-- print all output for things like pulls and conflicts and merges
	end
else
	error('ERROR '..err)
end

writeMutex:lock()
print(reqdir..' ... '..tostring(msg))
writeMutex:unlock()
]],
}
-- write our Lua args
for _,worker in ipairs(pool) do
	local WG = worker.thread.lua.global
	WG.tocheck = tocheck
	WG.cmd = cmd
end

pool:cycle(#tocheck)
pool:closed()

for i,worker in ipairs(pool) do
	local exitStatus = worker.thread.lua.global.exitStatus
	if not exitStatus then
		local errmsg = worker.thread.lua.global.errmsg
		io.stderr:write('worker '..i..' got error '..errmsg..'\n')
	end
end
