module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
nresponses = 0

local server = http.createServer(function(self, req, res)
	if req.url == "/one" then
		res:writeHead(200, { {"set-cookie", "A"},
							{"content-type", "text/plain"} });
		res:finish("one\n")
	else
		res:writeHead(200, { {"set-cookie", "A"},
							{"set-cookie", "B"},
							{"content-type", "text/plain"} });
		res:finish("two\n")
	end
end)
server:listen(common.PORT)

server:on("listening", function()
	--
	-- one set-cookie header
	--
	http.get({ port = common.PORT, path = "/one" }, function(_, res)
		-- set-cookie headers are always return in an array.
		-- even if there is only one.
		assert_equal("A", res.headers["set-cookie"][1])
		assert_equal("text/plain", res.headers["content-type"])
	
		res:on("data", function(self, chunk)
			console.log(chunk)
		end)

		res:on("end", function()
			nresponses = nresponses + 1
			if nresponses == 2 then
				server:close()
			end
		end)
	end)

	-- two set-cookie headers

	http.get({ port = common.PORT, path = "/two" }, function(_, res)
		for k,v in ipairs({"A", "B"}) do
			assert_equal(v, res.headers["set-cookie"][k])
		end
		assert_equal("text/plain", res.headers["content-type"])

		res:on("data", function(self, chunk)
			console.log(chunk)
		end)

		res:on("end", function()
			nresponses = nresponses + 1
			if nresponses == 2 then
				server:close()
			end
		end)
	end)

end)

process:on("exit", function ()
	assert_equal(2, nresponses)
end)

process:loop()
end