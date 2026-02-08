--[[
get all .git files in all subfolders
converts to absolute path
returns only unique absolute paths
--]]
local table = require 'ext.table'
local path = require 'ext.path'

return function()
	local srcdir = path:cwd()

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
	local tocheckUnique = table()
	for _,reqdir in ipairs(tocheck) do
		path(reqdir):cd()
		local absreqdir = path:cwd().path
		srcdir:cd()
		tocheckUnique[absreqdir] = true
	end
	return tocheckUnique:keys():sort()
end
