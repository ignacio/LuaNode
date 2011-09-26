module(..., lunit.testcase, package.seeall)


local common = dofile("common.lua")
local http = require("luanode.http")
local net = require("luanode.net")
local url = require("luanode.url")
local qs = require("luanode.querystring")
local inspect = require("luanode.utils").inspect

local num_clients = 8
--local num_clients = 2
local batch_num = 1
local num_batches = 10

function test()
	local request_number = 0
	local client_got_eof = false

	local server = http.createServer(function (self, req, res)

		--[[
		console.log("got request")
		setTimeout(function ()
			console.log("will reply")
			res:writeHead(200, {
				["Content-Type"] = "text/plain",
				["Content-Length"] = "11"
			})
			res:write("Hello World")
			res:finish()
		end, 200)
		--]]
		---[[
		res.id = request_number
		req.id = request_number
		request_number = request_number + 1
		
		if request_number == num_clients * num_batches then
			self:close()
			console.info("server closed")
		end

		--setTimeout(function ()
			local id = qs.parse(url.parse(req.url).query).id
			--console.log("server reply: req id (%d), res id (%d), data (%s)", req.id, res.id, id)
			res:writeHead(200, {["Content-Type"] = "text/plain", ["Content-Length"] = #id})
			res:write(id)
			res:finish()
		--end, 200)
		--]]
	end)
	server:listen(common.PORT)

	---[[
	server:on("listening", function()
		console.info("server is listening")
		
		local clients = {}
		repeat 
			local client = http.createClient(common.PORT)
			table.insert(clients, client)
			client.id = #clients
		until #clients == num_clients
		
		local batch
		batch = function()
			batch_num = batch_num + 1
			table.foreach(clients, function(i, client)
				--local client = http.createClient(common.PORT)
				--client.id = #clients
				console.log("Issuing request with client %d", client.id)
				local req = client:request("/hello?id=".. client.id)
				req.id = client.id
				req:on("response", function(self, res)
					console.log("Got response for req (%d)", req.id)
					res.body = ""
					res.id = req.id
					res:on("data", function (self, chunk)
						console.log("req id (%d), res id (%d), data (%s)", req.id, res.id, chunk)
						res.body = res.body .. chunk
					end)
					res:on("end", function()
						client.parser.socket = {}
						assert_equal(res.body, tostring(res.id))
					end)
				end)
				req:finish()
			end)
			collectgarbage()
			if batch_num <= num_batches then
				setTimeout(batch, 500)
			end
		end
		
		batch()
	end)
	--]]

	process:loop()
end
