
local STP = require("StackTracePlus")

local Page = {}

local function bla()
   error("oops")
end

local function foo()
   bla()
end

Page.render = foo

function main()
   local p = {}
   setmetatable(p, { __index = Page })
   local x = "render"
   p[x]()
end

xpcall(main, function() print(STP.stacktrace()) end)

