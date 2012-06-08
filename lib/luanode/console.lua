local process = process
local esc = string.char(27)

module((...), package.seeall)

local fg_colors = {
	black = esc.."[30m",
	red = esc.."[31m",
	green = esc.."[32m",
	brown = esc.."[33m",
	yellow = esc.."[33m",
	blue = esc.."[34m",
	magenta = esc.."[35m",
	cyan = esc.."[36m",
	gray = esc.."[90m",
	
	lightred = esc.."[1m"..esc.."[31m",
	lightgreen = esc.."[1m"..esc.."[32m",
	lightbrown = esc.."[1m"..esc.."[33m",
	lightyellow = esc.."[1m"..esc.."[33m",
	lightblue = esc.."[1m"..esc.."[34m",
	lightmagenta = esc.."[1m"..esc.."[35m",
	lightcyan = esc.."[1m"..esc.."[36m",
	white = esc.."[1m"..esc.."[37m",
}

local bg_colors = {
	black = esc.."[40m",
	red = esc.."[41m",
	green = esc.."[42m",
	brown = esc.."[43m",
	yellow = esc.."[43m",
	blue = esc.."[44m",
	magenta = esc.."[45m",
	cyan = esc.."[46m",
	gray = esc.."[100m",
	
	lightred = esc.."[1m"..esc.."[41m",
	lightgreen = esc.."[1m"..esc.."[42m",
	lightbrown = esc.."[1m"..esc.."[43m",
	lightblue = esc.."[1m"..esc.."[44m",
	lightmagenta = esc.."[1m"..esc.."[45m",
	lightcyan = esc.."[1m"..esc.."[46m",
	white = esc.."[1m"..esc.."[47m",
}

local reset = esc.."[0m"

reset_color = function (stream)
	stream = stream or process.stdout
	stream:write(reset)
end

--BLACK_BACK = "\033[40m"
--RED_BACK = "\033[41m"
--GREEN_BACK = "\033[42m"
--BROWN_BACK = "\033[43m"
--BLUE_BACK = "\033[44m"
--MAGENTA_BACK = "\033[45m"
--CYAN_BACK = "\033[46m"
--BG_WHITE = "\033[47m"

-- ANSI control chars
--RESET_COLORS = "\033[0m"
--BOLD_ON = "\033[1m"
--BLINK_ON = "\033[5m"
--REVERSE_ON = "\033[7m"
--BOLD_OFF = "\033[22m"
--BLINK_OFF = "\033[25m"
--REVERSE_OFF = "\033[27m"

function getColor(value)
	return fg_colors[value]
end

function getBgColor(value)
	return bg_colors[value]
end

function getResetColor()
	return reset
end

function color(value, stream)
	local v = fg_colors[value]
	if v then
		stream = stream or process.stdout
		stream:write(v)
	end
end

function bgcolor(value, stream)
	local v = bg_colors[value]
	if v then
		stream = stream or process.stdout
		stream:write(v)
	end
end
