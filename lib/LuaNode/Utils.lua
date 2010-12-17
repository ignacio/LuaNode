local string = string
local table = table

module((...))

--
-- Dumps binary data in a "memory viewer" fashion. Ie:
-- Dumping 15 bytes
-- 00000000 00 48 65 6c 6c 6f 2c 20 77 6f 72 6c 64 21 ff ..  - .Hello, world!.
function DumpDataInHex(data)
	local dataLength = #data
	local bytesPerLine = 16

	--local result = { "00000000 00 01 02 03 04 05 06 07 08 09 10 0b 0c 0d 0e 0f" }
	local result = { ("Dumping %d bytes"):format(dataLength) }
	local hexDisplay = ""
	local display = ""

	local i = 1
	local line = 0

	while i <= dataLength do
		local c = data:sub(i, i)
		local c_code = string.byte(c)

		hexDisplay = hexDisplay .. ("%02x "):format(c_code)

		if c_code >= 32 and c_code <= 127 then
			display = display .. c
		else
			display = display .. "."
		end

		if i % bytesPerLine == 0 then
			result[#result + 1] = ("%08x %s - %s"):format(line * bytesPerLine, hexDisplay, display)
			hexDisplay = ""
			display = ""
			line = line + 1
		end
		i = i + 1
	end
	i = i - 1
	if i % bytesPerLine ~= 0 then
		for pad = i % bytesPerLine, bytesPerLine - 1 do
			hexDisplay = hexDisplay .. ".. "
		end
		result[#result + 1] = ("%08x %s - %s"):format(line * bytesPerLine, hexDisplay, display)
	end

	return table.concat(result, "\n")
end