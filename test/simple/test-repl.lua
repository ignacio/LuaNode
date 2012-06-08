
-- function for REPL to run
invoke_me = function(arg)
	return "invoked " .. arg
end


module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")

local net = require "luanode.net"
local repl = require "luanode.repl"
local message = "Read, Eval, Print Loop"
local prompt_unix = "LuaNode via Unix socket> "
local prompt_tcp = "LuaNode via TCP socket> "
local prompt_multiline = ">> "
local server_tcp, server_unix, client_tcp, client_unix, timer


-- absolute path to test/fixtures/a.lua
local moduleFilename = require("luanode.path").join(common.fixturesDir, "a")

function send_expect (list)
	if #list > 0 then
		local cur = table.remove(list, 1)

		common.debug("sending '%s'", cur.send)

		cur.client.expect = cur.expect
		cur.client.list = list
		if #cur.send > 0 then
			cur.client:write(cur.send)
		end
	end
end

function clean_up()
	client_tcp:finish()
	--client_unix:finish()
	clearTimeout(timer)
end

---[=[
function error_repl()
	-- The other stuff is done so reuse unix socket
	local read_buffer = ""
	client_tcp:removeAllListeners("data")

	client_tcp:on("data", function(self, data)
		read_buffer = read_buffer .. data
		common.debug("TCP data: '%s', expecting '%s'.", read_buffer, client_tcp.expect)

		if read_buffer:find(prompt_tcp) then
			assert(read_buffer:match(client_tcp.expect))
			common.debug("match")
			read_buffer = ""
			if client_tcp.list and #client_tcp.list > 0 then
				send_expect(client_tcp.list)
			else
				common.debug("End of Error test.\n")
				--tcp_test()
				clean_up()
			end

		elseif read_buffer:find(prompt_multiline) then
			-- Check that you meant to send a multiline test
			assert_equal(prompt_multiline, client_tcp.expect)
			read_buffer = ""
			if client_tcp.list and #client_tcp.list > 0 then
				send_expect(client_tcp.list)
			else
				common.debug("End of Error test.\n")
				clean_up()
			end

		else
			common.debug("didn't see prompt yet, buffering.")
		end
	end)

	send_expect({
		-- Uncaught error throws and prints out
		{ client = client_tcp,
		  send = "error('test error');\n",
		  expect = [[%[string "REPL"%]:1: test error]]
		},
		-- Common syntax error is treated as multiline command
		--{ client = client_tcp, 
		  --send = "function test_func()\n",
		  --expect = prompt_multiline
		--},
		-- You can recover with the .break command
		--{ client = client_tcp,
		  --send = ".break\n",
		  --expect = prompt_tcp
		--},
		-- Can parse valid JSON
		--{ client = client_tcp, 
--		  send = [[JSON.parse('{"valid": "json"});]],
		  --expect = "{ valid: 'json' }"
		--},
		-- invalid input to JSON.parse error is special case of syntax error, should throw
		--{ client = client_tcp, 
--		  send = [[JSON.parse(\'{invalid: \\\'json\\\'}\');]],
		  --expect = /^SyntaxError: Unexpected token i/
		--},
		-- Named functions can be used:
		{ client = client_tcp, 
		  send = "function blah() return 1 end\n",
		  expect = prompt_tcp
		},
		{ client = client_tcp, 
		  send = "blah()\n",
		  expect = "1\n" .. prompt_tcp
		},
		-- Multiline object
		{ client = client_tcp, 
		  send = "{ a = \n",
		  expect = prompt_multiline
		},
		{ client = client_tcp, 
		  send = "1 }\n",
		  expect = [[{
  a => 1
}]]
		},
		-- Multiline anonymous function with comment
		{ client = client_tcp, 
		  send = "(function ()\n",
		  expect = prompt_multiline
		},
		{ client = client_tcp, 
		  send = "-- blah\n",
		  expect = prompt_multiline
		},
		{ client = client_tcp, 
		  send = "return 1\n",
		  expect = prompt_multiline
		},
		{ client = client_tcp, 
		  send = "end)()\n",
		  expect = "1"
		}
	})
end
--]=]

function tcp_repl()
	server_tcp = net.createServer(function(self, socket)
		assert_equal(server_tcp, socket.server)

		socket:on("end", function()
			socket:finish()
		end)

		repl.start(prompt_tcp, socket)
	end)

	server_tcp:listen(common.PORT, function()
		local read_buffer = ""

		client_tcp = net.createConnection(common.PORT)

		client_tcp:on("connect", function()
			assert_true(client_tcp.readable)
			assert_true(client_tcp.writable)

			send_expect({
				{ client = client_tcp,
				  send = "", 
				  expect = prompt_tcp
				},
				{ client = client_tcp,
				  send = "invoke_me(333)\n",
				  expect = [["invoked 333"]] .. "\n" .. prompt_tcp
				},
				{ client = client_tcp,
				  send = "a = 12345\n",
				  --expect = "12345\n" .. prompt_tcp },	-- luanode does not return the value when assigning (yet)
				  expect = prompt_tcp },
				{ client = client_tcp,
				  --send = "a = a + 1\n",
				  send = "a + 1\n",
				  expect = "12346" .. "\n" .. prompt_tcp
				},
				--{ client = client_tcp,
				  --send = "require(\"" .. tostring(moduleFilename) .. "\").number\n",
				  --expect = "42" .. "\n" .. prompt_tcp
				--}
			})
		end)

		client_tcp:on("data", function(self, data)
			read_buffer = read_buffer .. data
			common.debug("TCP data: '%s', expecting '%s'.", read_buffer, client_tcp.expect)
			if read_buffer:find(prompt_tcp) then
				assert_equal(client_tcp.expect, read_buffer)
				common.debug("match\n")
				read_buffer = ""
				if client_tcp.list and #client_tcp.list > 0 then
					send_expect(client_tcp.list)
				else
					common.debug("End of TCP test, running Error test.\n")
					process.nextTick(error_repl)
				end
			else
				common.debug("didn't see prompt yet, buffering\n")
			end
		end)

		client_tcp:on("error", function(self, e)
			console.error(e)
		end)

		client_tcp:on("close", function()
			server_tcp:close()
		end)
	end)

end

-- Disabled until we support pipes
--[=[
function unix_repl()
	server_unix = net.createServer(function(self, socket)
		assert_equal(server_unix, socket.server)

		socket:on("end", function()
			socket:finish()
		end)

		repl.start(prompt_unix, socket).context.message = message
	end)

	server_unix:on("listening", function()
		local read_buffer = ""

		client_unix = net.createConnection(common.PIPE)

		client_unix.on("connect", function()
			assert_true(client_unix.readable)
			assert_true(client_unix.writable)

			send_expect({
				{ client = client_unix, 
				  send = "",
				  expect = prompt_unix
				},
				{ client = client_unix, 
				  send = "message\n",
				  expect = "'" .. message .. "'\n" .. prompt_unix
				},
				{ client = client_unix, 
				  send = "invoke_me(987)\n",
				  expect = "'" .. "invoked 987" .. "'\n" .. prompt_unix
				},
				{ client = client_unix, 
				  send = "a = 12345\n",
				  --expect: ("12345" + "\n" + prompt_unix)
				  expect = prompt_unix
				},
				{ client = client_unix, 
				  send = "{a = 1}\n",
				  expect = [[{
  a => 1
}]] .. prompt_unix
				}
			})
		end)

		client_unix:on("data", function(self, data)
			read_buffer = read_buffer .. data
			common.debug("TCP data: '%s', expecting '%s'.", read_buffer, client_unix.expect)
			if read_buffer:find(prompt_unix) then
				assert_equal(client_unix.expect, read_buffer)
				common.debug("match")
				read_buffer = ""
				if client_unix.list and #client_unix.list > 0 then
					send_expect(client_unix.list)
				else
					common.error("End of Unix test, running Error test.\n")
					process.nextTick(error_test)
				end
			else
				common.debug("didn't see prompt yet, buffering.")
			end
		end)

		client_unix:on("error", function(self, e)
			error(e)
		end)

		client_unix:on("close", function()
			server_unix:close()
		end)
	end)

	server_unix:listen(common.PIPE)
end
--]=]

function test()

	tcp_repl()
	

	timer = setTimeout(function()
		assert_true(false, "Timeout")
	end, 5000)
	process:loop()

end