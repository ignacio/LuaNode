local process = process
local esc = string.char(27)

module((...))

local FOREGROUND_BLUE           = 1
local FOREGROUND_GREEN          = 2
local FOREGROUND_RED            = 4
local FOREGROUND_INTENSITY      = 8
local BACKGROUND_BLUE           = 16
local BACKGROUND_GREEN          = 32
local BACKGROUND_RED            = 64
local BACKGROUND_INTENSITY      = 128

local fg_colors
local bg_colors
if process.platform == "windows" then
	fg_colors = {
		black        = 0,
		blue         = FOREGROUND_BLUE,
		lightblue    = FOREGROUND_BLUE + FOREGROUND_INTENSITY,
		red          = FOREGROUND_RED,
		lightred     = FOREGROUND_RED + FOREGROUND_INTENSITY,
		green        = FOREGROUND_GREEN,
		lightgreen   = FOREGROUND_GREEN + FOREGROUND_INTENSITY,
		magenta      = FOREGROUND_RED + FOREGROUND_BLUE,
		lightmagenta = FOREGROUND_RED + FOREGROUND_BLUE + FOREGROUND_INTENSITY,
		cyan         = FOREGROUND_GREEN + FOREGROUND_BLUE,
		lightcyan    = FOREGROUND_GREEN + FOREGROUND_BLUE + FOREGROUND_INTENSITY,
		brown        = FOREGROUND_RED + FOREGROUND_GREEN,
		yellow       = FOREGROUND_RED + FOREGROUND_GREEN + FOREGROUND_INTENSITY,
		gray         = FOREGROUND_RED + FOREGROUND_GREEN + FOREGROUND_BLUE,
		white        = FOREGROUND_RED + FOREGROUND_GREEN + FOREGROUND_BLUE + FOREGROUND_INTENSITY,
	}

	bg_colors = {
		black        = 0,
		blue         = BACKGROUND_BLUE,
		lightblue    = BACKGROUND_BLUE + BACKGROUND_INTENSITY,
		red          = BACKGROUND_RED,
		lightred     = BACKGROUND_RED + BACKGROUND_INTENSITY,
		green        = BACKGROUND_GREEN,
		lightgreen   = BACKGROUND_GREEN + BACKGROUND_INTENSITY,
		magenta      = BACKGROUND_RED + BACKGROUND_BLUE,
		lightmagenta = BACKGROUND_RED + BACKGROUND_BLUE + BACKGROUND_INTENSITY,
		cyan         = BACKGROUND_GREEN + BACKGROUND_BLUE,
		lightcyan    = BACKGROUND_GREEN + BACKGROUND_BLUE + BACKGROUND_INTENSITY,
		brown        = BACKGROUND_RED + BACKGROUND_GREEN,
		yellow       = BACKGROUND_RED + BACKGROUND_GREEN + BACKGROUND_INTENSITY,
		gray         = BACKGROUND_RED + BACKGROUND_GREEN + BACKGROUND_BLUE,
		white        = BACKGROUND_RED + BACKGROUND_GREEN + BACKGROUND_BLUE + BACKGROUND_INTENSITY,
	}
	
	reset_color = function()
		process.set_console_bg_color(bg_colors.black)
		process.set_console_fg_color(fg_colors.gray)
	end
	
else
	fg_colors = {
		black = esc.."[30m",
		red = esc.."[31m",
		green = esc.."[32m",
		brown = esc.."[33m",
		yellow = esc.."[33m",
		blue = esc.."[34m",
		magenta = esc.."[35m",
		cyan = esc.."[36m",
		gray = esc.."[37m",
	
		lightred = esc.."[1m"..esc.."[31m",
		lightgreen = esc.."[1m"..esc.."[32m",
		lightbrown = esc.."[1m"..esc.."[33m",
		lightblue = esc.."[1m"..esc.."[34m",
		lightmagenta = esc.."[1m"..esc.."[35m",
		lightcyan = esc.."[1m"..esc.."[36m",
		white = esc.."[1m"..esc.."[37m",
	}

	bg_colors = {
		black = esc.."[40m",
		red = esc.."[41m",
		green = esc.."[42m",
		brown = esc.."[43m",
		yellow = esc.."[43m",
		blue = esc.."[44m",
		magenta = esc.."[45m",
		cyan = esc.."[46m",
		gray = esc.."[47m",
	
		lightred = esc.."[1m"..esc.."[41m",
		lightgreen = esc.."[1m"..esc.."[42m",
		lightbrown = esc.."[1m"..esc.."[43m",
		lightblue = esc.."[1m"..esc.."[44m",
		lightmagenta = esc.."[1m"..esc.."[45m",
		lightcyan = esc.."[1m"..esc.."[46m",
		white = esc.."[1m"..esc.."[47m",
	}
	
	reset_color = function()
		process.set_console_fg_color(esc.."[0m")
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
end

function getColor(value)
	return fg_colors[value]
end

function getBgColor(value)
	return bg_colors[value]
end

function color(value)
	local v = fg_colors[value]
	if v then
		process.set_console_fg_color(v)
	end
end

function bgcolor(value)
	local v = bg_colors[value]
	if v then
		process.set_console_bg_color(v)
	end
end