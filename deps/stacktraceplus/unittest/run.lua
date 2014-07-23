local lunit = require "lunit"

package.path = "../src/?.lua;../src/?/init.lua;".. package.path

require "test"

local stats = lunit.main()
if stats.errors > 0 or stats.failed > 0 then
	os.exit(1)
end
