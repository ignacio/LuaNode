local lunit = require "lunit"
local console = require "lunit-console"

package.path = "../src/?.lua;../src/?/init.lua;".. package.path

require "test"

lunit.setrunner({
	fail = function(...)
		print(...)
	end,
	err = function(...)
		print(...)
	end,
})

console.begin()
lunit.run()
console.done()
