module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")
net = require("luanode.net")

function test()
	assert_equal(true, net.isIP("127.0.0.1"))
	assert_not_equal(true, net.isIP("x127.0.0.1"))
	assert_not_equal(true, net.isIP("example.com"))
	assert_equal(true, net.isIP("0000:0000:0000:0000:0000:0000:0000:0000"))
	assert_not_equal(true, net.isIP("0000:0000:0000:0000:0000:0000:0000:0000::0000"))
	assert_equal(true, net.isIP("1050:0:0:0:5:600:300c:326b"))
	assert_equal(true, net.isIP("2001:252:0:1::2008:6"))
	assert_equal(true, net.isIP("2001:dead:beef:1::2008:6"))
	assert_equal(true, net.isIP("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"))
	
	assert_equal(true, net.isIPv4("127.0.0.1"))
	assert_equal(true, net.isIPv6("::1"))
	assert_not_equal(true, net.isIPv4("example.com"))
	assert_not_equal(true, net.isIPv4("2001:252:0:1::2008:6"))
	
	assert_not_equal(true, net.isIPv6("127.0.0.1"))
	assert_not_equal(true, net.isIPv4("example.com"))
	assert_equal(true, net.isIPv6("2001:252:0:1::2008:6"))

	process:loop()
end