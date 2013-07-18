local cmd = ...

require 'lfs'

local function recurse()
	for f in lfs.dir('.') do
		if f ~= '.' and f ~= '..' then
			if lfs.attributes(f).mode == 'directory' then
				if f == '.git' then
					print(lfs.currentdir())
					print('result',os.execute('git '..cmd))
				else
					lfs.chdir(f)
					recurse()
					lfs.chdir('..')
				end
			end
		end
	end
end

recurse()
