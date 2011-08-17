local Resolver = process.Resolver

-- TODO: sacar el seeall
module(..., package.seeall)

local net = require "luanode.net"
local m_resolver = Resolver()

--
-- Easy DNS A/AAAA look up
-- lookup(domain, [family,] callback)
function lookup(domain, family, callback)
	if not callback then
		callback = family
		family = nil
	elseif (family and family ~= 4 and family ~= 6) then
		family = parseInt(family, 10)
		if family == dns.AF_INET then
			family = 4
		elseif family == dns.AF_INET6 then
			family = 6
		elseif family ~= 4 and family ~= 6 then
			error('invalid argument: "family" must be 4 or 6')
		end
	end
	
	if not domain then
		process.nextTick(function()
			callback(nil, nil, family == 6 and 6 or 4)
		end)
		return
	end
	
	local matchedFamily, f = net.isIP(domain)
	if matchedFamily then
		process.nextTick(function()
			callback(nil, { address = domain, family = f}, domain)
		end)
	else
		-- TODO: darle bola al family
		--local addresses, err = m_resolver:Lookup(domain, "", callback)
		m_resolver:Lookup(domain, "", callback, false)
		--if not addresses then
			--callback(err, {})
		--else
			--callback(nil, addresses[1])
		--end
			--[[
			channel.getHostByName(domain, dns.AF_INET, function (err, domains4) {
				if (domains4 && domains4.length) {
					callback(null, domains4[0], 4);
				} else {
					channel.getHostByName(domain, dns.AF_INET6,
									function (err, domains6) {
					if (domains6 && domains6.length) {
						callback(null, domains6[0], 6);
					} else {
						callback(err, []);
					}
				});
				}
			});
			--]]
	end
end

function lookupAll(domain, family, callback)
	if not callback then
		callback = family
		family = nil
	elseif (family and family ~= 4 and family ~= 6) then
		family = parseInt(family, 10)
		if family == dns.AF_INET then
			family = 4
		elseif family == dns.AF_INET6 then
			family = 6
		elseif family ~= 4 and family ~= 6 then
			error('invalid argument: "family" must be 4 or 6')
		end
	end
	
	if not domain then
		process.nextTick(function()
			callback(nil, nil, family == 6 and 6 or 4)
		end)
		return
	end
	
	local matchedFamily, f = net.isIP(domain)
	if matchedFamily then
		process.nextTick(function()
			callback(nil, { address = domain, family = f}, domain)
		end)
	else
		-- TODO: darle bola al family
		--local addresses, err = m_resolver:Lookup(domain, "", callback)
		m_resolver:Lookup(domain, "", callback, true)
		--if not addresses then
			--callback(err, {})
		--else
			--callback(nil, addresses[1])
		--end
			--[[
			channel.getHostByName(domain, dns.AF_INET, function (err, domains4) {
				if (domains4 && domains4.length) {
					callback(null, domains4[0], 4);
				} else {
					channel.getHostByName(domain, dns.AF_INET6,
									function (err, domains6) {
					if (domains6 && domains6.length) {
						callback(null, domains6[0], 6);
					} else {
						callback(err, []);
					}
				});
				}
			});
			--]]
	end
end