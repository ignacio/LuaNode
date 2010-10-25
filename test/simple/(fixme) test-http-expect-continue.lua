-- no anda, esta raro porque el server cierra el socket luego de responder al continue
module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local http = require("luanode.http")

function test()
local outstanding_reqs = 0
local test_req_body = "some stuff...\n"
local test_res_body = "other stuff!\n"
local sent_continue = false
local got_continue = false

function handler(self, req, res)
	assert_equal(sent_continue, true, "Full response sent before 100 Continue")
	common.debug("Server sending full response...")
	res:writeHead(200, {
		['Content-Type'] = 'text/plain',
		ABCD = "1"
	})
	res:finish(test_res_body)
end

local server = http.createServer(handler)
server:addListener("checkContinue", function(self, req, res)
	common.debug("Server got Expect: 100-continue...")
	res:writeContinue()
	sent_continue = true
	handler(self, req, res)
end)
server:listen(common.PORT)



server:addListener("listening", function()
	local client = http.createClient(common.PORT)
	req = client:request("POST", "/world", {
		Expect = "100-continue",
	})
	common.debug("Client sending request...")
	outstanding_reqs = outstanding_reqs + 1
	body = ""
	req:addListener('continue', function ()
		common.debug("Client got 100 Continue...")
		got_continue = true
		req:finish(test_req_body)
	end)
	req:addListener('response', function (self, res)
		assert_equal(got_continue, true, "Full response received before 100 Continue")
		assert_equal(200, res.statusCode, "Final status code was " .. res.statusCode .. ", not 200.")
		res:setEncoding("utf8")
		res:addListener('data', function (self, chunk) body = body .. chunk end)
		res:addListener('end', function ()
			common.debug("Got full response.")
			assert_equal(body, test_res_body, "Response body doesn't match.")
			assert_true(res.headers.abcd == "1", "Response headers missing.")
			outstanding_reqs = outstanding_reqs - 1
			if outstanding_reqs == 0 then
				server:close()
				process.exit()
			end
		end)
	end)
end)

process:loop()
end