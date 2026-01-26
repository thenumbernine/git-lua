#!/usr/bin/env luajit
local ffi = require 'ffi'
local table = require 'ext.table'
local path = require 'ext.path'


local srcdir = path:cwd()

local gitcmd = assert(..., "you forgot to specify a command")


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

-- filter out unique dirs
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

-- one thread writes to stdout at a time
local writeMutex = require 'thread.mutex'()
_G.writeMutex = writeMutex

local Pool = require 'thread.pool'
local pool = Pool{
	-- concurrency ... double it just because half of these are going to get stuck on something or another
	--size = 2 * require 'thread'.numThreads(),
	-- init the threads' LUa state:
	threadInit = function(thread)
		-- write our Lua args
		local WG = thread.lua.global
		WG.tocheck = tocheck
		WG.gitcmd = gitcmd
	end,
	-- what to pass to the threads' pool-init code:
	userdata = ffi.cast('void*', writeMutex.id),
	-- runs once upon init
	initcode = [[
local ffi = require 'ffi'
local io = require 'ext.io'
local path = require 'ext.path'
local table = require 'ext.table'
local writeMutex = require 'thread.mutex':wrap(userdata)
]],
	-- runs per cycle
	code = [[
local i = tonumber(pool.taskIndex)
local reqdir = tocheck[i]

-- NOTICE the rest is the same as rundir.lua ...
-- ... except without any cd'ing
-- ... and with a mutex around the output

-- hmm none of the entries are . but somehow it is looking for one entry of .git at ./.git ....
local gitpath = path(reqdir)'.git'
if not gitpath:exists() then
	error("expected to find "..gitpath.." from reqdir "..tostring(reqdir).." = tocheck["..tostring(i)..']')
end

local cmd = table{
	'cd "'..reqdir..'"',
	ffi.os == 'Windows' and '&' or ';',
	'git',
	gitcmd,
	ffi.os == 'Windows' and '<NUL' or '</dev/null',	-- don't wait for input
	'2>&1',	-- stderr to stdout
}:concat' '
local msg, err = io.readproc(cmd)

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

pool:cycle(#tocheck)
pool:closed()
pool:showErrs()
