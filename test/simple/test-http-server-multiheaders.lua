module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

-- Verify that the HTTP server implementation handles multiple instances
-- of the same header as per RFC2616: joining the handful of fields by ', '
-- that support it, and dropping duplicates for other fields.
function test()

local srv = http.createServer(function(self, req, res)
	assert_equal('abc, def, ghijklmnopqrst', req.headers.accept)
	assert_equal('foo', req.headers.host)
	assert_equal('bingo', req.headers['x-foo'])
	assert_equal('banjo, bango', req.headers['x-bar'])

	res:writeHead(200, {['Content-Type'] = 'text/plain'})
	res:finish('EOF')

	self:close()
end)

srv:listen(common.PORT, function ()
	local hc = http.createClient(common.PORT, 'localhost')
	local hr = hc:request('/', {
		{'accept', 'abc'},
		{'accept', 'def'},
		{'Accept', 'ghijklmnopqrst'},
		{'host', 'foo'},
		{'Host', 'bar'},
		{'hOst', 'baz'},
		{'x-foo', 'bingo'},
		{'x-bar', 'banjo'},
		{'x-bar', 'bango'}
	})
	hr:finish()
end)

process:loop()
end