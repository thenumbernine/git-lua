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


local setlib = require 'ffi.req' 'c.stdlib'
setlib.setenv('GIT_TERMINAL_PROMPT', '0', 1)	-- don't wait for input


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
local string = require 'ext.string'
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
	'cd '..path(reqdir):escape(),
	'git '..gitcmd..' 2>&1',	-- stderr to stdout
}:concat(
	ffi.os == 'Windows'
	and ' & '
	or ' ; '
)

local msg, err = io.readproc(cmd)

if not msg then
	error('ERROR '..err)
end

local response
-- if it is a known / simple message


---------------- git pull responses: ----------------


-- sometimes it's "Already up to date"
-- sometimes it's "Already up-to-date"
if msg:match'^Already up.to.date'
or msg:match'^Everything up.to.date'
then
	--print first line only
	msg = msg:match'^([^\r\n]*)'
	response = '✅ '..reqdir..' ... '..tostring(msg)

elseif msg:match'^There is no tracking information for the current branch' then
	--print first line only
	msg = msg:match'^([^\r\n]*)'
	response = '💡 '..reqdir..' ... '..tostring(msg)

elseif msg:match'^From ' then
	
	-- format is:
	--From $(url)
	--   $(commit1)..$(commit2)    -> $(remote)/$(branch)
	--Updating $(commit1)..$(commit2)
	--Fast-forward
	-- $(list-of-files)
	-- $(howmany) file(s?) changed, $(m) insertions(+), $(n) deletions(-)
	-- $(create/delete messages)
	
	-- if something goes wrong (like there would be an overwrite), format is:
	--From $(url)
	--   $(commit1)..$(commit2)    -> $(remote)/$(branch)
	--error: $(errmsg)
	--...
	--Aborting

	local lines = string.split(string.trim(msg), '\n'):mapi(string.trim)
	
	local foundError = (lines[3] and lines[3]:match'^error:') or lines:last() == 'Aborting'
	
	if not foundError
	and (lines[3] and lines[3]:match'^Updating')
	and (lines[4] and lines[4]:match'^Fast%-forward')
	-- now comes the file list ...
	-- then a summary: " %d files changed, %d insertions(+), %d deletions(-)"
	-- then a list of create/delete files ...
	then
		-- try to get the summary line
		response = '⬇️ '..reqdir..' ... '..tostring(msg:match'%d+ files? change[^\r\n]*')
	else
		-- didn't parse, mabye it's an error
		response = '❌ '..reqdir..' ... '..tostring(msg)
	end


---------------- git status response ---------------- 


elseif msg:match"^On branch(.*)%s+Your branch is up.to.date with 'origin/(.*)'%.%s+nothing to commit, working tree clean" then
	-- only for this one, go ahead and merge the first \n

	-- first line: "On branch $(branch)"

	-- next line, if there's no extra changes to pull: 
	--"Your branch is up to date with '$(remote)/$(branch)'."
	--""
	-- TODO otherwise... what does it say

	-- next, if there's no other commits to push and no other files uncommitted:
	--"nothing to commit, working tree clean"

	-- if there are commits to push:
	--"Changes not staged for commit:"
	--  (use ...)"
	--  (use ...)"

	-- if there aren't commits to push but there are untracked files:
	--"Untracked files:"
	--"  (use ...)"
	--"  $(list-of-files)"
	--""
	--"nothing added to commit but untracked files present (use...)"

	msg = msg:gsub('[\r\n]', ' ')
	response = '✅ '..reqdir..' ... '..tostring(msg)

else

	-- print all output for things like pulls and conflicts and merges
	response = '❌ '..reqdir..' ... '..tostring(msg)
end

writeMutex:lock()
print(response)
writeMutex:unlock()
]],
}

pool:cycle(#tocheck)
pool:closed()
pool:showErrs()
