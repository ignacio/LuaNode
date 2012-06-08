-- Converts the $(InputPath) macro of VS to a Unix-like path

local path = assert(select(1, ...))

path = path:match("(.+)\\build\\[^\\]+\\$")
path = path:gsub("\\", "/")

io.stdout:write("\""..path.."\"")
