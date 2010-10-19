module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")
local url = require("luanode.url")

--
-- Slight variation on test-http-client-race to test for another race
-- condition involving the parsers FreeList used internally by http.Client.
--
function test()

local body1_s = "1111111111111111"
local body2_s = "22222"
local body3_s = "3333333333333333333"

local server = http.createServer(function (self, req, res)
	local pathname = url.parse(req.url).pathname

	local body
	if pathname == "/1" then
		body = body1_s
	elseif pathname == "/2" then
		body = body2_s
	else
		body = body3_s
	end

	res:writeHead(200, { ["Content-Type"] = "text/plain",
						["Content-Length"] = #body
						})
	res:finish(body)
end)

server:listen(common.PORT)

local body1 = ""
local body2 = ""
local body3 = ""

server:addListener("listening", function()
	local client = http.createClient(common.PORT)

	--
	-- Client #1 is assigned Parser #1
	--
	local req1 = client:request("/1")
	req1:finish()
	req1:addListener('response', function (self, res1)
		res1:setEncoding("utf8")

		res1:addListener("data", function (self, chunk)
			body1 = body1 .. chunk
		end)

		res1:addListener("end", function ()
			--
			-- Delay execution a little to allow the "close" event to be processed
			-- (required to trigger this bug!)
			--
			setTimeout(function ()
				--
				-- The bug would introduce itself here: Client #2 would be allocated the
				-- parser that previously belonged to Client #1. But we're not finished
				-- with Client #1 yet!
				--
				local client2 = http.createClient(common.PORT)

				--
				-- At this point, the bug would manifest itself and crash because the
				-- internal state of the parser was no longer valid for use by Client #1.
				--
				local req2 = client:request("/2")
				req2:finish()
				req2:addListener("response", function (self, res2)
					res2:setEncoding("utf8")
					res2:addListener("data", function (self, chunk)
						body2 = body2 .. chunk
					end)
					res2:addListener("end", function ()
						--
						-- Just to be really sure we've covered all our bases, execute a
						-- request using client2.
						--
						local req3 = client2:request("/3")
						req3:finish()
						req3:addListener("response", function (self, res3)
							res3:setEncoding("utf8")
							res3:addListener("data", function (self, chunk)
								body3 = body3 .. chunk
							end)
							res3:addListener("end", function()
								server:close()
							end)
						end)
					end)
				end)
			end, 500)
		end)
	end)
end)

process:addListener("exit", function ()
	assert_equal(body1_s, body1)
	assert_equal(body2_s, body2)
	assert_equal(body3_s, body3)
end)

process:loop()

end