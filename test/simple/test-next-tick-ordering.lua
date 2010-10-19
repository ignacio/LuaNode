module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")

function test()
	local N = 30
	local done = {}

	function get_printer(timeout)
		return function ()
			console.log("Running from setTimeout " .. timeout)
			table.insert(done, timeout)
		end
	end

	process.nextTick(function ()
		console.log("Running from nextTick")
		done[0] = "nextTick"
	end)

	for i = 1, N do
		setTimeout(get_printer(i), i)
	end

	console.log("Running from main.")


	process:addListener('exit', function ()
		assert_equal('nextTick', done[0])
		for i = 1, N do
			assert_equal(i, done[i])
		end
	end)

	process:loop()
end