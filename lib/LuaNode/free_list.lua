local setmetatable, table = setmetatable, table

module((...))

-- This is a free list to avoid creating so many of the same object.

local FreeList = {}
FreeList.__index = FreeList
setmetatable(FreeList, FreeList)

function FreeList:alloc(...)
	-- print("alloc " .. self.name + " " + #self.list)
	if #self.list > 0 then
		--this.list.shift()
		return table.remove(self.list, 1)
	else
		return self.constructor(...)
	end
	--return this.list.length ? this.list.shift()
							--: this.constructor.apply(this, arguments);
end

function FreeList:free(obj)
	-- print("free " .. self.name .. " " .. self.#list)
	if #self.list < self.max then
		self.list[#self.list + 1] = obj
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
	t.list = {}
	return t
end