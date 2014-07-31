local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"

local _M = {
	_NAME = "luanode.stream",
	_PACKAGE = "luanode."
}

-- Make LuaNode 'public' modules available as globals.
luanode.stream = _M

-- Stream Class
local Stream = Class.InheritsFrom(EventEmitter)
_M.Stream = Stream
Stream.__name = "luanode.stream.Stream"

--
--
function Stream:pipe (dest, options)
	local source = self

	-- forward references
	local ondata, ondrain, onend, onclose, onerror, cleanup

	ondata = function (source, chunk)
		if dest.writable then
			if dest:write(chunk) == false and source.pause then
				source:pause()
			end
		end
	end

	source:on("data", ondata)

	ondrain = function (source)
		if source.readable and source.resume then
			source:resume()
		end
	end

	dest:on("drain", ondrain)


	local did_onend = false
	onend = function (source)
		if did_onend then return end
		did_onend = true

		dest:finish()
	end

	onclose = function (source)
		if did_onend then return end
		did_onend = true

		if type(dest.destroy) == "function" then
			dest:destroy()
		end
	end

	-- don't leave dangling pipes when there are errors.
	onerror = function (source, err)
		cleanup()
		if #source:listeners("error") == 0 then
			error(err)	-- Unhandled stream error in pipe
		end
	end

	--
	-- If the 'finish' option is not supplied, dest:finish() will be called when
	-- source gets the 'end' or 'close' events.
	--
	if not dest._isStdio and (not options or options.finish ~= false) then
		source:on("end", onend)
		source:on("close", onclose)
	end

	source:on("error", onerror)
  	dest:on("error", onerror)

	-- remove all the event listeners that were added.
	cleanup = function ()
		source:removeListener("data", ondata)
		dest:removeListener("drain", ondrain)

		source:removeListener("end", onend)
		source:removeListener("close", onclose)

		source:removeListener("error", onerror)
		dest:removeListener("error", onerror)

		source:removeListener("end", cleanup)
		source:removeListener("close", cleanup)

		dest:removeListener("end", cleanup)
		dest:removeListener("close", cleanup)
	end

	source:on("end", cleanup)
	source:on("close", cleanup)

	dest:on("end", cleanup)
	dest:on("close", cleanup)

	dest:emit("pipe", source)

	-- Allow for unix-like usage: A:pipe(B):pipe(C)
	return dest
end

return _M
