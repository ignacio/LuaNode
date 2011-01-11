local string = string
local table = table
local math = math

module((...))

--
-- Dumps binary data in a "memory viewer" fashion. Ie:
-- Dumping 12 bytes
-- 00000000  68 65 6C 6C 6F 2C 20 77  6F 72 6C 64 .. .. .. ..  hello, world
-- [first] begin dump at 16 byte-aligned offset containing 'first' byte
-- [last] end dump at 16 byte-aligned offset containing 'last' byte
-- Adapted from a snippet by Steve Donovan (http://snippets.luacode.org/?p=snippets/Hex_Dump_of_a_String_22)
function DumpDataInHex(buf, first, last)
	local res = {}
	if not first and not last then
		res[#res + 1] = ("Dumping %d bytes\n"):format((last or #buf) - (first or 1) + 1)
	else
		res[#res + 1] = ("Dumping from offset %d to %d\n\n"):format(first or 1, last or #buf)
		res[#res + 1] = "          00 01 02 03 04 05 06 07  08 09 10 0b 0c 0d 0e 0f\n"
		res[#res + 1] = "          ================================================\n"
	end
	local function align(n) return math.ceil(n/16) * 16 end
	for i = (align((first or 1) - 16) + 1), align(math.min(last or #buf, #buf)) do
		if (i - 1) % 16 == 0 then
			res[#res + 1] = string.format('%08X  ', i - 1)
		end
		res[#res + 1] =  i > #buf and '.. ' or string.format('%02X ', buf:byte(i))
		if i %  8 == 0 then
			res[#res + 1] = " "
		end
		if i % 16 == 0 then
			res[#res + 1] = buf:sub(i - 16 + 1, i):gsub('%c', '.')
			res[#res + 1] = '\n' 
		end
	end
	return table.concat(res)
end
