module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")
net = require("luanode.net")

function test()
	assert_equal(net.isIP("127.0.0.1"), true)
	assert_equal(net.isIP("x127.0.0.1"), false)
	assert_equal(net.isIP("example.com"), false)
	assert_equal(net.isIP("0000:0000:0000:0000:0000:0000:0000:0000"), true)
	assert_equal(net.isIP("0000:0000:0000:0000:0000:0000:0000:0000::0000"), false)
	assert_equal(net.isIP("1050:0:0:0:5:600:300c:326b"), true)
	assert_equal(net.isIP("2001:252:0:1::2008:6"), true)
	assert_equal(net.isIP("2001:dead:beef:1::2008:6"), true)
	assert_equal(net.isIP("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"), true)
	
	assert_equal(net.isIPv4("127.0.0.1"), true)
	assert_equal(net.isIPv4("example.com"), false)
	assert_equal(net.isIPv4("2001:252:0:1::2008:6"), false)
	
	assert_equal(net.isIPv6("127.0.0.1"), false)
	assert_equal(net.isIPv4("example.com"), false)
	assert_equal(net.isIPv6("2001:252:0:1::2008:6"), true)

	process:loop()
end