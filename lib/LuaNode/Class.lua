--
-- The following code is taken from parts of LOOP - Lua Object-Oriented Programming
-- by Renato Maia <maia@inf.puc-rio.br>
-- Mostly, the base module, the simple inheritance module and the ObjectCache.
--

local pairs        = pairs
local unpack       = unpack
local rawget       = rawget
local rawset       = rawset
local setmetatable = setmetatable
local getmetatable = getmetatable

local base = {}

--------------------------------------------------------------------------------
function base.rawnew(class, object)
	return setmetatable(object or {}, class)
end
--------------------------------------------------------------------------------
function base.new(class, ...)
	if class.__init
		then return class:__init(...)
		else return base.rawnew(class, ...)
	end
end

function base.initclass(class)
	if class == nil then class = {} end
	if class.__index == nil then class.__index = class end
	return class
end

local MetaClass = { __call = base.new }
function base.class(class)
	return setmetatable(base.initclass(class), MetaClass)
end

base.classof = getmetatable

local simple = {}

-- Cache of Objects Created on Demand
local DerivedClass = {
	retrieve = function(self, super)
		return base.class { __index = super, __call = simple.new }
	end,
	__mode = "k",
	__index = function (self, key)
		if key ~= nil then
			local value = rawget(self, "retrieve")
			if value then
				value = value(self, key)
			else
				value = rawget(self, "default")
			end
			rawset(self, key, value)
			return value
		end
	end
}
setmetatable(DerivedClass, DerivedClass)

for k,v in pairs(base) do
	simple[k] = v
end

function simple.class(class, super)
	if super
		then return DerivedClass[super](simple.initclass({}))
		else return base.class({})
	end
end

--------------------------------------------------------------------------------
function simple.superclass(class)
	local metaclass = simple.classof(class)
	if metaclass then return metaclass.__index end
end

local Class = {}
local mt = {
	__call = function(self, class)
		return base.class(class)
	end
}
setmetatable(Class, mt)

Class.InheritsFrom = function(super, dummy)
	assert(not dummy)	-- avoid simple errors
	if super then 
		return DerivedClass[super](simple.initclass{})
	else
		return base.class{}
	end
end

Class.base = base
Class.simple = simple

-- shortcuts
Class.superclass = simple.superclass

Class.construct = function (class, ...)
	local obj = simple.superclass(class)(...)
	return simple.rawnew(class, obj)
end

return Class