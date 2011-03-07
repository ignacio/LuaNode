-- module path
-- This is modelled after Python's os.path library (11.1)
-- Steve Donovan,2007

-- imports and locals
local _G = _G
local sub = string.sub 
local getenv = os.getenv
local attributes
local currentdir
local _package = package
local io = io
local append = table.insert
local ipairs = ipairs

--pcall(require,'lfs')
if lfs then
	attributes = lfs.attributes
	currentdir = lfs.currentdir
end

local function at(s,i)
	return sub(s,i,i)
end

local function attrib(path,field)
	if not attributes then return nil end
	local attr = attributes(path)
	if not attr then return nil
	else
		return attr[field]
	end
end

module 'path'

is_windows = getenv('OS') and getenv('COMSPEC')

-- !constant @sep is the directory separator for this platform.
if is_windows then sep = '\\' else sep = '/' end

-- given a path @path, return the directory part and a file part.
-- if there's no directory part, the first value will be empty
function splitpath(path)
	local i = #path
	local ch = at(path,i)
	while i > 0 and ch ~= '/' and ch ~= '\\' do
		i = i - 1
		ch = at(path,i)
	end
	if i == 0 then
		return '',path
	else
		return sub(path,1,i-1), sub(path,i+1)
	end
end

-- return an absolute path to @path
function abspath(path)
	if not currendir then return path end
	if not isabs(path) then
		return join(currentdir(),path)
	else
		return path
	end
end

-- given a path @path, return the root part and the extension part
-- if there's no extension part, the second value will be empty
function splitext(path)
	local i = #path
	local ch = at(path,i)
	while i > 0 and ch ~= '.' do
		if ch == '/' or ch == '\\' then
			return path,''
		end
		i = i - 1		
		ch = at(path,i)
	end
    if i == 0 then
		return path,''
	else
		return sub(path,1,i-1),sub(path,i)
	end
end

-- return the directory part of @path
function dirname(path)
    local p1,p2 = splitpath(path)
    return p1
end

-- return the file part of @path
function basename(path)
    local p1,p2 = splitpath(path)
    return p2
end

function extension(path)
	p1,p2 = splitext(path)
	return p2
end

-- is this an absolute @path?
function isabs(path)
	return at(path,1) == '/' or at(path,1)=='\\' or at(path,2)==':'
end

-- return the path resulting from combining @p1 and @p2; path.sep is used.
-- if @p2 is already an absolute path, then it returns @p2
function join(p1,p2)
	if isabs(p2) then return p2 end
	local endc = at(p1,#p1)
	if endc ~= '/' and endc ~= '\\' then
		p1 = p1..sep
	end
	return p1..p2		
end

-- Normalize the case of a pathname @path. On Unix, this returns the path unchanged;
--  for Windows, it converts the path to lowercase, and it also converts forward slashes
-- to backward slashes. 
function normcase(path)
	if is_windows then
		return (path:lower():gsub('/','\\'))
	else
		return path
	end
end

-- is @path a directory?
function isdir(path)
	return attrib(path,'mode') == 'directory'
end

-- is @path a file?
function isfile(path)
	return attrib(path,'mode') == 'file'
end

-- return size of file @path
function getsize(path)
	return attrib(path,'size')
end

-- does @path exist?
function exists(path)
	if attributes then
		return attributes(path) ~= nil
	else
		local f = io.open(path,'r')
		if f then
			f:close()
			return true
		else
			return false
		end
	end
end

-- Replace a starting '~' in @path with the user's home directory.
function expanduser(path)
	if at(path,1) == '~' then
		local home = getenv('HOME')
		if not home then
			home = getenv('HOMEDRIVE')..getenv('HOMEPATH')
		end
		return home..sub(path,2)
	else
		return path
	end
end

-- Return the time of last access of @path as the number of seconds since the epoch.
function getatime(path) 
	return attrib(path,'access')
end

-- Return the time of last modification of @path
function getmtime(path) 
	return attrib(path,'modification')
end

--Return the system's ctime which, on some systems (like Unix) is the time of the last
-- change, and, on others (like Windows), is the creation time for @path
function getctime(path) 
	return attrib(path,'change')
end

function package(mod)
	for m in _package.path:gmatch('[^;]+') do
		local nm = m:gsub('?',mod)
		if exists(nm) then return dirname(m) end
	end
	return nil,'cannot find module on path'
end

function package_loadname(mod,extension)
	local ext
	local path,err = package(mod)
	if not path then return nil,err end
	if is_windows then ext = '.dll' else ext = '.so' end
	return path..sep..extension..ext
end

function loadlib(mod,extension)
	local filename,err = package_loadname(mod,extension)
	if not filename then return nil,err end
	local f,err = _package.loadlib(filename,"luaopen_"..extension)
	if not f then return nil,"cannot load extension: "..err end
	return f()
end

---- finis -----
