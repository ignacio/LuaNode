local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"
local utils = require "luanode.utils"

local endMethods = {'end', 'abort', 'destroy', 'destroySoon'}
local stack = {}

local function create (cb)
      return Domain(cb)
end

Domain = Class:InheritsFrom(EventEmitter)

local function Domain ()
      EventEmitter.call(self);
      self.members = [];
end

local function enter() 
      if self._disposed then
      	 	return
      end
      stack.push(this)
end

local function exit ()
      if self._disposed then
      	 return
      end
      local d

       process.domain = stack[stack.length - 1]; 
end

local function add (ee) 
      if self._disposed then 
      	 return
      end

      if ee.domain == self then
      	 return
      end

      if ee.domain then
       	 ee.domain.remove(ee)
      end

      if this.domain && ee instanceof Domain then
      	 for d = self.domain do 
      	     if ee === d then
	     	return
    	     end
	  end
      end

      ee.domain = self;
      self.members.push(ee);
end

local function remove(ee)
      ee.domain = null
      local index = self.members.indexOf(ee)
      if (index !== -1) then
      	 self.members.splice(index, 1)
      end
end

--push,pop,splice,instanceof,prototype