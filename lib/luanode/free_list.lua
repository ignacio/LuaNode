local setmetatable, table, next = setmetatable, table, next
local console_warn = console.warn

module((...))

-- This is a free list to avoid creating so many of the same object.
-- It is in fact a map, to avoid "freeing" multiple times the same 
-- element.

local FreeList = {}
FreeList.__index = FreeList
setmetatable(FreeList, FreeList)

function FreeList:alloc(...)
	-- print("alloc " .. self.name + " " + #self.list)
	if self.count > 0 then
		self.count = self.count - 1
		local element = next(self.map)
		self.map[element] = nil
		return element
	else
		return self.constructor(...)
	end
end

function FreeList:free(element)
	-- print("free " .. self.name .. " " .. self.#list)
	if self.count < self.max then
		if self.map[element] then
			console_warn("element %q has been already freed", self.map[element])
		else
			self.map[element] = element
			self.count = self.count + 1
		end
	end
end


--function FreeList(self, name, max, constructor)
	--self.name = name;
	--self.constructor = constructor;
	--self.max = max;
	--self.list = {};
--end



function new(name, max, constructor)
	local t = setmetatable({}, FreeList)
	t.name = name
	t.constructor = constructor
	t.max = max
	t.map = {}
	t.count = 0
	return t
end