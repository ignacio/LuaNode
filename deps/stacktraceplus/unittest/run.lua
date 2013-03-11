require "luarocks.require"
require "lunit"

local console = require "lunit-console"

package.path = [[d:\trunk_git\sources\StackTracePlus\src\?.lua;.\?.lua]] --.. package.path

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