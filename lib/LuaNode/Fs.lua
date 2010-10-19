local Stream = require "luanode.Stream"

local io = require "io"

-- TODO: sacar el seeall
module(..., package.seeall)

function openSync(path, flags, mode)
	mode = mode or 0666
	return io.open(path, flags)
end

function read(fd, length, position, callback)
	assert(type(length) == "number" or type(length) == "string", "length must be a number or a string")
	if type(position) == "function" then
		callback = position
		position = nil
	end

	process.nextTick(function()
		if type(position) == "number" then
			assert(fd:seek("set", position))
		end
		local data, err = fd:read(length)
		if type(callback) == "function" then
			callback(fd, err, data, #data)
		end
	end)
end


function readSync(fd, length, position)
	assert(type(length) == "number" or type(length) == "string", "length must be a number or a string")
	if type(position) == "number" then
		assert(fd:seek("set", position))
	else
		assert(not position)
	end

	return fd:read(length)
end

function readFileSync(path, encoding)
	local f = assert(io.open(path, "rb"))
	local content = f:read("*a")
	f:close()
	return content
end