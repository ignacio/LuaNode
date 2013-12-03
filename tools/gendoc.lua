require "luarocks.require"
local discount = require "discount"
local f = io.open("README.md", "rb")
local code = f:read("*a")
f:close()

f = io.open("README.html", "wb")
f:write(discount(code))
f:close()