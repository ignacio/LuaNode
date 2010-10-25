local process = process

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
else
	fg_colors = {
		black = "\033[30m",
		red = "\033[31m",
		green = "\033[32m",
		brown = "\033[33m",
		blue = "\033[34m",
		magenta = "\033[35m",
		cyan = "\033[36m",
		gray = "\033[37m",
	
		lightred = "\033[1m\033[31m",
		lightgreen = "\033[1m\033[32m",
		lightbrown = "\033[1m\033[33m",
		lightblue = "\033[1m\033[34m",
		lightmagenta = "\033[1m\033[35m",
		lightcyan = "\033[1m\033[36m",
		white = "\033[1m\033[37m",
	}

	bg_colors = {
		black = "\033[40m",
		red = "\033[41m",
		green = "\033[42m",
		brown = "\033[43m",
		blue = "\033[44m",
		magenta = "\033[45m",
		cyan = "\033[46m",
		gray = "\033[47m",
	
		lightred = "\033[1m\033[41m",
		lightgreen = "\033[1m\033[42m",
		lightbrown = "\033[1m\033[43m",
		lightblue = "\033[1m\033[44m",
		lightmagenta = "\033[1m\033[45m",
		lightcyan = "\033[1m\033[46m",
		white = "\033[1m\033[47m",
	}
	
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

function reset_color()
	process.set_console_bg_color(bg_colors.black)
	process.set_console_fg_color(fg_colors.gray)
end