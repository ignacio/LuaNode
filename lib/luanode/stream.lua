local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"
--var util = require('util');

-- TODO: sacar el seeall
module(..., package.seeall)

-- Stream Class
Stream = Class.InheritsFrom(EventEmitter)

--
--
function Stream:pipe (dest, options)
	local source = self

	source:on("data", function (self, chunk)
		if dest.writable and not dest:write(chunk) then
			source:pause()
		end
	end)

	dest:on("drain", function ()
		if source.readable then
			source:resume()
		end
	end)

	--
	-- If the 'finish' option is not supplied, dest:finish() will be called when
	-- source gets the 'end' event.
	--

	if not options or options.finish ~= false then
		source:on("end", function ()
			dest:finish()
		end)
	end

	--
	-- Questionable:
	--

	if not source.pause then
		source.pause = function ()
			source:emit("pause")
		end
	end

	if not source.resume then
		source.resume = function ()
			source:emit("resume")
		end
	end

	dest:on("pause", function ()
		source:pause()
	end)

	dest:on("resume", function ()
		if source.readable then
			source:resume()
		end
	end)
end
