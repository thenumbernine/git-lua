#!/usr/bin/env luajit
local path = require 'ext.path'
local oneline = require 'git.oneline'
local getgits = require 'git.getgits'

local gitcmd = assert(..., "you forgot to specify a command")

local tocheck = getgits()
for _,reqdir in ipairs(tocheck) do
	xpcall(function()
		print(oneline(reqdir, gitcmd))
	end, function(err)
		io.stderr:write(dir..'\n'..err..'\n'..debug.traceback())
	end)
end
