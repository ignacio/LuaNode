--package.cpath = [[d:\proyecto\bin\common\?.dll;]]..package.cpath
package.path = [[c:\luarocks\1.0\lua\?.lua;]]..package.path
require "luarocks.require"
require "lunit"

local console = require "lunit-console"

require "tests.test"

-- eventos posibles:
-- begin, done, fail, err, run, pass

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