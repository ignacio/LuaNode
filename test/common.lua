local path = require "luanode.path"

__filename = [[d:\trunk_git\sources\LuaNode\test\]]


local t = {}
-- TODO: FIXME
t.testDir = path.dirname(__filename)
t.fixturesDir = path.join(t.testDir, "fixtures")
t.libDir = path.join(t.testDir, "../lib")
t.tmpDir = path.join(t.testDir, "tmp")
t.PORT = 12346

--exports.assert = require('assert');

--var sys = require("sys");
--for (var i in sys) exports[i] = sys[i];
--//for (var i in exports) global[i] = exports[i];

--[[
function protoCtrChain (o) {
  var result = [];
  for (; o; o = o.__proto__) { result.push(o.constructor); }
  return result.join();
}
]]

--[[
exports.indirectInstanceOf = function (obj, cls) {
  if (obj instanceof cls) { return true; }
  var clsChain = protoCtrChain(cls.prototype);
  var objChain = protoCtrChain(obj);
  return objChain.slice(-clsChain.length) === clsChain;
};
]]

--}
local assert = assert

t.assert = {
	equal = function(v1, v2, text)
		assert(v1 == v2, text)
	end,
		
	ok = function(value, message)
		assert(value == true, message)
	end
}

t.debug = LogDebug
t.error = LogError

t.p = print

return t