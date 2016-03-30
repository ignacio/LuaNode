local Class = require "luanode.class"
local EventEmitter = require "luanode.event_emitter"
local utils = require "luanode.utils"

-- TODO: sacar el seeall
module(..., package.seeall)

local endMethods = {'end', 'abort', 'destroy', 'destroySoon'}
local stack = {}

Domain = Class:InheritsFrom(EventEmitter)

local function pop (arr)
      local d = arr[table.getn(arr)]
      table.remove(arr)
      return d   
end

local function instanceof (obj1,obj2)
      obj2 = tostring (obj2)
      local mt = getmetatable (obj1)
 
      while true do
       	    if mt == nil then return false end
       	    if tostring (mt) == super then return true end
 	    mt = getmetatable (mt)
      end  
end

local function indexOf (arr, elem)
      local result
      if "table" == type(arr) then
      	 for i=1,#arr do
	     if elem = arr[i] then
	     	result = i
		break
             end
          end
      end
      return result
end

local function splice (arr, index, howmany)
      local new_arr = {}
      local table_size = table.getn(arr)

      if index < 1 then
      	 index = 1
      end

      if howmany < 0 then
      	 howmany = 0
      end

      if index > table_size then
      	 index = table_size + 1
	 howmany = 0
      end

      if index + howmany > table_size then
      	 howmany = table_size - index + 1
      end

      for i=1,index do
      	  table.insert(new_arr,arr[i])
      end

      for i=index + howmany - 1,table_size do
      	  table.insert(new_arr,arr[i])
      end

      return new_arr
end

local function extend (parent, obj1, obj2)
      if type(obj2) ~= "table" then
      	 return
      end

      for i,v in pairs(obj2) do
      	  table.insert(obj1,i,v)
      end

      if type(parent) ~= "table" then
      	 return obj1 or parent 
      end
      temp_obj = obj1 or {}
      temp_obj.__index = parent
      return setmetatable(parent, temp_obj)
end

local function apply (cb, self, obj)
      if type(cb) == "function" then
      	 cb = Object:extend()
      	 setmetatable(cb:new(),{__index = self})
	 cb(obj)
      end 
end

function Domain:enter () 
      if this._disposed then
      	 	return
      end
      table.insert(stack,this)
end

function Domain:exit ()
      if this._disposed then
      	 return
      end

      local d
      repeat
	d = pop(stack)
      until d ~= nil && d.__index ~= self

      process.domain = stack[table.getn(stack)]; 
end

function Domain:add (ee) 
      if this._disposed then 
      	 return
      end

      if ee.domain.__index == this then
      	 return
      end

      if ee.domain then
       	 ee.domain.remove(ee)
      end

      if this.domain && instanceof(ee,Domain) then
      	 for d = this.domain do 
      	     if ee.__index == d then
	     	return
    	     end
	  end
      end

      ee.domain = this;
      table.insert(this.members, ee);
end

function Domain:remove(ee)
      ee.domain = nil
      local index = indexOf(this.members, ee)
      if (index != -1) then
      	 splice(this.members, index, 1)
      end
end

function Domain:bind (cb, interceptError) 
  --if cb throws, catch it here.
     local self = this;
     local b = function () 

     	       		--disposing turns functions into no-ops
    			if self._disposed then 
       			   return
    			end

    			if instanceof(this,Domain) then 
       			   return cb.apply(this, arguments)
    			end

  			--only intercept first-arg errors if explicitly requested.
    			if interceptError && arguments[0] && instanceof(arguments[0],Error) then
       			   local er = arguments[0]
       			   extend(utils,er, {
        		   		    domainBound = cb,
        				    domainThrown = false,
        				    domain = self
      			   })
      			   self.emit('error', er)
      			   return
    			end

  			--remove first-arg if intercept as assumed to be the error-arg
    			if (interceptError) then
       			   local len = table.getn(arguments)
       			   local args
       			   switch (len) then
              		       case 0:
              		       case 1:
              	   	       	    --no args that we care about.
          	   		    args = {}
          	   		    break
              		       case 2:
              	   	       	    --optimization for most common case: cb(er, data)
          	   		    args = {arguments[1]}
          	   		    break
              		       default:
				    --slower for less common case: cb(er, foo, bar, baz, ...)
          	   		    args = {}
          	   		    for i = 1,len do
            	       		    	args[i] = arguments[i+1]
                   		    end
          	   		    break
       		           end
       		       	   self.enter()
       		       	   local ret = cb.apply(this, args)
       		       	   self.exit()
       		       	   return ret;
    	      	       end

    		       self.enter()
    		       var ret = cb.apply(this, arguments)
    		       self.exit()
    		       return ret
  		   end
  b.domain = this
  return b
end

Domain._disposed = true