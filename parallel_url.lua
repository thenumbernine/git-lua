#!/usr/bin/env luajit
local path = require 'ext.path'
local io = require 'ext.io'	-- io.readproc

local cmd = ...
assert(cmd, "expected cmd")

-- TODO here launch a process and somehow wait for it to finish ...
-- how to monitor other than busy wait or temp files?
-- start /b git cmd 2^>^&1 ... but that still waits to exit right?

io.stderr:write(path:cwd(), ' ... ')
print'... TODO'
do return end
local msg
msg, err = io.readproc('git '..cmd..' 2>&1')

if msg then
	-- if it is a known / simple message
	-- sometimes it's "Already up to date"
	-- sometimes it's "Already up-to-date"
	if msg:match'^Already up.to.date'
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
