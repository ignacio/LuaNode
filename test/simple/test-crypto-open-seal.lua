require "lunit"

local crypto = require "luanode.crypto"
local fs = require "luanode.fs"

module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")

function test()

	local certPem = fs.readFileSync(common.fixturesDir .. '/keys/agent1-cert.pem', 'ascii')
	local keyPem = fs.readFileSync(common.fixturesDir .. '/keys/agent1-key.pem', 'ascii')

	assert(crypto.createOpener, "crypto.createOpener is unavaliable")
	assert(crypto.createSealer, "crypto.createSealer is unavaliable")

	local message = string.rep('This message will be signed', 122)

	local sealer = crypto.createSealer("aes128", certPem)

	local p1 = sealer:update(message)
	local p2, ek_2, iv_2 = sealer:final()

	local opener = crypto.createOpener("aes128", keyPem, ek_2, iv_2)
	local p3 = opener:update(p1)
	local p4 = opener:update(p2)
	local p5 = opener:final()
	assert_equal(message, p3..p4..p5)

end

process:loop()
