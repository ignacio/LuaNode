module(..., lunit.testcase, package.seeall)

local inspect = require "luanode.utils".inspect

require "luanode.class"
require "luanode.console"
require "luanode.crypto"
require "luanode.datagram"
require "luanode.dns"
require "luanode.event_emitter"
require "luanode.free_list"
require "luanode.fs"
require "luanode.http"
require "luanode.net"
require "luanode.path"
require "luanode.querystring"
require "luanode.readline"
require "luanode.repl"
require "luanode.script"
require "luanode.stream"
require "luanode.timers"
require "luanode.tty"
require "luanode.url"
require "luanode.utils"

---
-- Makes sure that introspect.dump_vm can iterate the VM with
-- our built-in module loaded
-- (luanode.free_list had a loop and this function entered a loop)
--
function test()
	local introspect = require "luanode.introspect"

	local dump = introspect.dump_vm()
	console.log(inspect(dump))

	local counters = introspect.counters

	local stats = {
		timers = introspect.counters.timers(),
		net = {
			acceptors = counters.net.acceptors(),
			sockets = counters.net.sockets()
		},
		crypto = {
			verifiers = counters.crypto.verifiers(),
			hmacs = counters.crypto.hmacs(),
			deciphers = counters.crypto.deciphers(),
			ciphers = counters.crypto.ciphers(),
			sealers = counters.crypto.sealers(),
			signers = counters.crypto.signers(),
			openers = counters.crypto.openers(),
			sockets = counters.crypto.sockets(),
			contexts = counters.crypto.contexts(),
			hashes = counters.crypto.hashes()
		},
		resolvers = counters.resolvers(),
		http_parsers = counters.http_parsers()
	}

	assert_number(stats.timers)
	assert_number(stats.net.sockets)
	assert_number(stats.net.acceptors)
	assert_number(stats.crypto.verifiers)
	assert_number(stats.crypto.hmacs)
	assert_number(stats.crypto.deciphers)
	assert_number(stats.crypto.ciphers)
	assert_number(stats.crypto.sealers)
	assert_number(stats.crypto.signers)
	assert_number(stats.crypto.openers)
	assert_number(stats.crypto.sockets)
	assert_number(stats.crypto.contexts)
	assert_number(stats.crypto.hashes)
	assert_number(stats.resolvers)
	assert_number(stats.http_parsers)

	process:loop()
end
