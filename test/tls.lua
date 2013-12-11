local tls = require "luanode.tls"
local https = require "luanode.https"

---[[
local client = tls.connect(443, "encrypted.google.com", function(self)
	console.log("connected")
	local verified = self:verifyPeer()
	console.log(verified)

	console.log(self:remoteAddress())
	local peerDN = self:getPeerCertificate()

	console.log(peerDN.subject)
	console.log(peerDN.issuer)

	console.log(peerDN.valid_from)
	console.log(peerDN.valid_to)
	console.log(peerDN.fingerprint)

	self:destroy()
	--self:finish()
end)
--]]

--[[
https.get({ host = "encrypted.google.com", path = "/" }, function(self, response)
	console.log("pronto", self, response)
	console.log('STATUS: ' .. response.statusCode)
	console.log('HEADERS: ')
	for k,v in pairs(response.headers) do
		console.log(k, v)
	end
end)
--]]

process:loop()
