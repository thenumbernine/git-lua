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

local lines = string.split(string.trim(msg), '\n')

local response
-- if it is a known response, parse it and emojify it 


-- while we're here, remove the "Untracked files:" section
for k=1,#lines do
	if lines[k] == 'Untracked files:' then
		local j=k+1
		while j <= #lines do
			if lines[j] == '' then break end
			j=j+1
		end
		-- now either lines[j] is empty or j is past the end
		lines = lines:sub(1,k-1):append(lines:sub(j+1))
		msg = lines:concat'\n'
		break
	end
end


---------------- git pull responses: ----------------


-- sometimes it's "Already up to date"
-- sometimes it's "Already up-to-date"
if lines[1]:match'^Already up.to.date'
or lines[1]:match'^Everything up.to.date'
then
	response = '✅ '..reqdir..' ... '..tostring(lines[1])

elseif lines[1]
and lines[1]:match'^There is no tracking information for the current branch'
then
	response = '💡 '..reqdir..' ... '..tostring(lines[1])

elseif lines[1]:match'^From ' then
	
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


elseif lines[1]:match'^On branch' then

	-- only for this one, go ahead and merge the first \n

	-- first line: "On branch $(branch)"

	-- next line, if there's no extra changes to pull: 
	--"Your branch is up to date with '$(remote)/$(branch)'."
	--""
	-- TODO otherwise... what does it say
	--
	-- otehrwise if you didi commit but haven't pusehd:
	--"Your branch is ahead of '$(remote)/$(branch)' by (%d) commits?."
	--"  (use ...)"

	-- next, if there's no other commits to push and no other files uncommitted:
	--"nothing to commit, working tree clean"

	-- if there are changes that haven't been committed:
	--"Changes not staged for commit:"
	--  (use ...)"
	--  (use ...)"
	--""
	--"no changes added to commit (use...)"

	-- if there aren't commits to push but there are untracked files:
	--"Untracked files:"
	--"  (use ...)"
	--"  $(list-of-files)"
	--""
	--"nothing added to commit but untracked files present (use...)"

	-- git status, commits to push
	if lines[2]:match'^Your branch is ahead' then
		local summary = lines[2]
		if lines[5] and lines[5]:match'^Changes not staged' then
			summary = summary .. ' ' .. lines[5]
		end
		response = '⬆️ '..reqdir..' ... '..summary

	-- git status, all is well
	elseif lines[2] and lines[2]:match'Your branch is up.to.date'
	and lines[3] and lines[3] == ''
	and lines[4] and lines[4]:match'nothing to commit, working tree clean'
	then
		response = '✅ '..reqdir..' ... '..tostring(lines[4])

	else

		response = '❌ '..reqdir..' ... '..tostring(msg)
	end

-- all else:
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
