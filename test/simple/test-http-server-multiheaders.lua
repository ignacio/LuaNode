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
	assert_equal('foo, bar, baz', req.headers['www-authenticate'])
	assert_equal('foo, bar, baz', req.headers['proxy-authenticate'])
	assert_equal('bingo', req.headers['x-foo'])
	assert_equal('banjo, bango', req.headers['x-bar'])
	assert_equal('chat, share', req.headers['sec-websocket-protocol'])
	assert_equal('foo; 1, bar; 2, baz', req.headers['sec-websocket-extensions'])

	res:writeHead(200, {['Content-Type'] = 'text/plain'})
	res:finish('EOF')

	self:close()
end)

srv:listen(common.PORT, function ()
	http.get({
		host = "localhost",
		port = common.PORT,
		path = "/",
		headers = {
			{'accept', 'abc'},
			{'accept', 'def'},
			{'Accept', 'ghijklmnopqrst'},
			{'host', 'foo'},
			{'Host', 'bar'},
			{'hOst', 'baz'},
			{'www-authenticate', 'foo'},
			{'WWW-Authenticate', 'bar'},
			{'WWW-AUTHENTICATE', 'baz'},
			{'proxy-authenticate','foo'},
			{'Proxy-Authenticate','bar'},
			{'PROXY-AUTHENTICATE','baz'},
			{'x-foo', 'bingo'},
			{'x-bar', 'banjo'},
			{'x-bar', 'bango'},
			{'sec-websocket-protocol', 'chat'},
			{'sec-websocket-protocol', 'share'},
			{'sec-websocket-extensions', 'foo; 1'},
			{'sec-websocket-extensions', 'bar; 2'},
			{'sec-websocket-extensions', 'baz'}
		}
	})
end)

process:loop()
end