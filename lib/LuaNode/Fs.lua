local Stream = require "luanode.stream"

local io = require "io"

-- TODO: sacar el seeall
module(..., package.seeall)

local function noop () end

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

function readFile(path, encoding, callback)
	callback = type(callback) == "function" and callback or (type(encoding) == "function" and encoding) or noop
	encoding = type(encoding) == "string" and encoding or nil
	
	if type(callback) == "function" then
		process.nextTick(function()
			local f, err = assert(io.open(path, "rb"))
			if not f then
				callback(err)
			else
				local content = f:read("*a")
				f:close()
				callback(nil, content)
			end
		end)
	end
end

function readFileSync(path, encoding)
	local f = assert(io.open(path, "rb"))
	local content = f:read("*a")
	f:close()
	return content
end






























