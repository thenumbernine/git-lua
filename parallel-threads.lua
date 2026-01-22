#!/usr/bin/env luajit
local ffi = require 'ffi'
local template = require 'template'
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
		tocheckUnique[path:cwd().path] = true
	end
	srcdir:cd()
	tocheck = table.keys(tocheckUnique):sort()
end

-- don't collect
_G.tocheck = tocheck

local writeMutex = require 'thread.mutex'()
_G.writeMutex = writeMutex 

local Pool = require 'thread.pool'
local pool = Pool{
	userdata = ffi.cast('void*', writeMutex.id),
	initcode = function(pool, index)
		return template([[
local tocheck = <?=tocheck?>	-- just copying the whole thing
local cmd = <?=cmd?>
local writeMutex = require 'thread.mutex':wrap(userdata)
]],
			{
				tocheck = tolua(tocheck),
				cmd = tolua(cmd),
			})
	end,
	code = function(pool, index)
		return template([[
-- index == threadIndex
local i = tonumber(pool.taskIndex)+1
local reqdir = tocheck[i]

-- NOTICE the rest is the same as rundir.lua ...
-- ... except without any cd'ing
-- ... and with a mutex around the output

assert(path(reqdir)'.git':exists())

local msg, err = io.readproc('cd "'..reqdir..'"; git '..cmd..' 2>&1')

writeMutex:lock()
io.stderr:write(reqdir, ' ... ')
if msg then
	-- if it is a known / simple message
	-- sometimes it's "Already up to date"
	-- sometimes it's "Already up-to-date"
	if msg:match'^Already up.to.date'
	or msg:match'^Everything up.to.date'
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
print(i, reqdir, writeMutex.id)
writeMutex:unlock()
]])
	end,
}
pool:cycle(#tocheck)
pool:closed()

for i,worker in ipairs(pool) do
	local exitStatus = worker.thread.lua.global.exitStatus
	if not exitStatus then
		local errmsg = worker.thread.lua.global.errmsg
		io.stderr:write('worker '..i..' got error '..errmsg..'\n')
	end
end
