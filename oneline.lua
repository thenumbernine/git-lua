--[[
accepts a path and some git cmd
returns a one-line summary, or the original output
--]]
local ffi = require 'ffi'
local io = require 'ext.io'
local path = require 'ext.path'
local table = require 'ext.table'
local string = require 'ext.string'

return function(reqdir, gitcmd)
	-- hmm none of the entries are . but somehow it is looking for one entry of .git at ./.git ....
	if not (path(reqdir)/'.git'):exists() then
		error("expected to find "..reqdir.."/.git")
	end

	local cmd = table{
		'cd '..path(reqdir):escape(),
		'git '..gitcmd..' 2>&1',	-- stderr to stdout
	}:concat(
		ffi.os == 'Windows'
		and ' & '
		or ' ; '
	)

	local msg = assert(io.readproc(cmd))

	local lines = string.split(string.trim(msg), '\n')
	while lines:last() and lines:last():match'^%s*$' do
		lines:remove()
	end

	assert(#lines > 0, "somehow all the response was empty.")

	-- while we're here, remove the "Untracked files:" section
	for k=1,#lines do
		if lines[k] == 'Untracked files:' then
			local j=k+1
			if lines[j]:match'^%s*%(use' then j=j+1 end	-- skip tips
			if lines[j]:match'^%s*$' then j=j+1 end	-- sometimes there's a space next
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

	-- if it is a known response, parse it and emojify it

	---------------- git pull ----------------


	-- sometimes it's "Already up to date"
	-- sometimes it's "Already up-to-date"
	if (lines[1]:match'^Already up.to.date'
		or lines[1]:match'^Everything up.to.date'
	) and #lines == 1
	then
		return '✅ '..reqdir
	end

	if lines[1]
	and lines[1]:match'^There is no tracking information for the current branch'
	then
		return '💡 '..reqdir..' ... '..tostring(lines[1])
	end

	if lines[1]:match'^From ' then

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
			return '⬇️  '..reqdir..' ... '..tostring(msg:match'%d+ files? change[^\r\n]*')
		end
	end


	---------------- git status ----------------


	if lines[1]:match'^On branch' then
		lines:remove(1)
	
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


-- TODO sometimes it doesn't say "your branch is ahead" or "your branch is behind"
-- but just "changes not staged"

		-- git status, commits to push
		if lines[1]:match'^Your branch is ahead' then
			if lines[4] and lines[4]:match'^Changes not staged' then
				return '❌⬆️ '..reqdir..' ... '..lines[1]..' '..lines[4]
			else
				return '⬆️ '..reqdir..' ... '..lines[1]
			end

		elseif lines[1]:match'^Your branch is behind' then
			local summary = lines[1]
			if lines[4] and lines[4]:match'^Changes not staged' then
				summary = summary .. ' ' .. lines[4]
			end
			return '❌⬇️ '..reqdir..' ... '..summary

		-- git status, all is well
		elseif lines[1] and lines[1]:match'^Your branch is up.to.date' then
			local line1 = lines:remove(1)
			if lines[1] == '' then lines:remove(1) end
	
			if lines[1] and (
				lines[1]:match'^nothing to commit, working tree clean'
				or lines[1]:match'^nothing added to commit but untracked files present'
			)
			and #lines == 1
			then
				return '✅ '..reqdir

			elseif lines[1] and lines[1]:match'^Changes not staged for commit' then
				return '❌⬆️ '..reqdir..' ... '..line1..' '..lines[1]
			end
		end
	end

	-- all else:
	-- print all output for things like pulls and conflicts and merges
	return '❌ '..reqdir..' ... '..tostring(msg)
end
