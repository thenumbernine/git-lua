local path = require 'ext.path'
local io = require 'ext.io'	-- io.readproc

-- does chdir
-- uses it to resolve symlinks and check for duplicates / loops
local function rundir(cmd, reqdir, checkedSoFar)
	-- use cd+cwd to resolve symlinks
	if reqdir then
		path(reqdir):cd()
	end
	assert(path'.git':isdir())

	local cwd = path:cwd().path

	-- TODO how to resolve cwd wrt symlinks?
	if checkedSoFar then
		if checkedSoFar[cwd] then return end
		checkedSoFar[cwd] = true
	end

	io.stderr:write(cwd, ' ... ')
	local msg, err = io.readproc('git '..cmd..' 2>&1')
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
end

return rundir
