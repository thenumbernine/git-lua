#!/usr/bin/env luajit
local ffi = require 'ffi'
local getgits = require 'git.getgits'

local gitcmd = assert(..., "you forgot to specify a command")

local tocheck = getgits()

-- one thread writes to stdout at a time
local writeMutex = require 'thread.mutex'()
_G.writeMutex = writeMutex

-- can I do this in the io.readproc command?
local setlib = require 'ffi.req' 'c.stdlib'
setlib.setenv('GIT_TERMINAL_PROMPT', '0', 1)	-- don't wait for input


local maxConcurrent = 8	-- = require 'thread'.numThreads()

local Pool = require 'thread.pool'
local pool = Pool{
	-- concurrency ... double it just because half of these are going to get stuck on something or another
	--size = 2 * require 'thread'.numThreads(),
	size = maxConcurrent,
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
local oneline = require 'git.oneline'
local writeMutex = require 'thread.mutex':wrap(userdata)
]],
	-- runs per cycle
	code = [[
local i = tonumber(pool.taskIndex)
local reqdir = tocheck[i]

local response = oneline(reqdir, gitcmd)

writeMutex:lock()
print(response)
writeMutex:unlock()
]],
}

pool:cycle(#tocheck)
pool:closed()
pool:showErrs()
