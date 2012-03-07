-- TODO: sacar el seeall
module(..., package.seeall)

-- TODO: Deberia usar penlight.path y dejarme de joder

local config_regexp = ("([^\n])\n"):rep(5):sub(1, -2)
local dir_sep, path_sep, path_mark, execdir, igmark = package.config:match(config_regexp)

-- funcion sacada de MetaLua (table2.lua)
local function transposeTable(t)
   local tt = { }
   for a, b in pairs(t) do tt[b] = a end
   return tt
end

----------------------------------------------------------------------
-- resc(k) returns "%"..k if it's a special regular expression char,
-- or just k if it's normal.
----------------------------------------------------------------------
local regexp_magic = transposeTable{"^", "$", "(", ")", "%", ".", "[", "]", "*", "+", "-", "?" }
local function resc(k)
   return regexp_magic[k] and '%'..k or k
end

_M.dir_sep = dir_sep


function join(...)
	local t = {...}
	return normalize( table.concat(t, dir_sep) )
end

--
--
function normalizeArray(parts, keepBlanks)
	local directories = {}
	local prev
	
	for i, directory in ipairs(parts) do
		--print(i, directory)
		-- if it's blank, but it's not the first thing, and not the last thing, skip it.
		if (directory == "" and i ~= 1 and i ~= #parts and not keepBlanks) then
			--continue; -- fuck, no continue in Lua
			
		-- if it's a dot, and there was some previous dir already, then skip it.
		elseif directory == "." and prev then
			-- continue; -- requetefuck, still no continue
			
		-- if it starts with "", and is a . or .., then skip it.
		elseif #directories == 1 and directories[1] == "" and (
			directory == "." or directory == "..")
		then
			-- continue;	-- yeah...
		
		elseif directory == ".." and
			#directories > 0 and
			prev ~= ".." and
			prev ~= "." and
			prev and
			(prev ~= "" or keepBlanks)
		then
			table.remove(directories)
			prev = directories[#directories]
		else
			if prev == "." then table.remove(directories) end
			directories[#directories + 1] = directory
			prev = directory
		end
	end
	
	return directories
end

--
--
function normalize(path, keepBlanks)
	local paths = {}
	--print("normalize", path)
	path = path:gsub("[\\/]", dir_sep)
	local pattern = ("([^%s]+)"):format( resc(dir_sep) )
	for p in path:gmatch(pattern) do
		--print("p", p)
		paths[#paths + 1] = p
	end
	paths = normalizeArray(paths, keepBlanks)
	if process.platform ~= "windows" then
		return dir_sep .. table.concat(paths, dir_sep)
	else
		return table.concat(paths, dir_sep)
	end
end

local function splitpath(path)
	local path, file = string.match(path, "^(.*)[/\\]([^/\\]*)$")
	if path == "" then
		return dir_sep, file
	elseif not path then
		return "."
	end
	return path, file
end

--
--
function dirname(path)
	local path = splitpath(path)
	return path
end

--
--
function basename(path, ext)
	local path, file = splitpath(path)
	if file and ext then
		local file2 = file:match("(.*)"..ext.."$")
		if not file2 then
			return file
		end
		return file
	end
	return file
end

--
--
function extname(path)
	-- TODO: implementar
	error("not yet implemented")
end

function exists(path, callback)
	-- TODO: implementar
	error("not yet implemented")
	--process.binding('fs').stat(path, function (err, stats) {
--		if (callback) callback(err ? false : true);
--	});
end

function existsSync(path)
	-- TODO: implementar
	error("not yet implemented")
	--process.binding('fs').stat(path)
end




