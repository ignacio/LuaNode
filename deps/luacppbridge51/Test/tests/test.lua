module(..., lunit.testcase, package.seeall)

local function isInstanceOf(instance, class)
	return getmetatable(instance) == class
end

function test_tostring()
	local obj = Test.ClaseHibridaConProperties()
	assert_equal("overridden tostring (ClaseHibridaConProps)", tostring(obj))
end

---[=====[
function tes_tCreacion()
	assert(Test.ClaseHibrida:new())
	assert(Test.ClaseHibrida())
	assert(Test.ClaseHibrida{})
end

function testHierarchy()
end

function testConstructWithTable()
	-- builtin_property is, of course, builtin
	local t = { foo = 12, bar = "baz", [12] = 90, builtin_property = "a random string" }
	local obj = Test.ClaseHibridaConProperties(t)
	
	assert_true( isInstanceOf(obj, Test.ClaseHibridaConProperties) )
	
	assert_equal(t.foo, obj.foo)
	assert_equal(t.bar, obj.bar)
	assert_equal(t[12], obj[12])
	assert_equal(t.builtin_property, obj.builtin_property)
	obj.builtin_property = 90
	
	assert_equal("this property is readonly", obj.readonly_property)
	assert_error("password must be readonly", function() obj.readonly_property = 100 end)
	
	-- write only properties always return nil
	assert_nil(obj.writeonly_property)
	
	obj.pirulo = "noventa"
	assert_equal("noventa", obj.pirulo)
	-- make sure we didn't write to _G by accident
	assert_not_equal(pirulo, obj.pirulo)
end

--[=[
function testTest()
	local obj = Test.ClaseHibridaConProperties()
	assert_true(obj:Test_Test(obj))
	
	assert_false(obj:Test_Test(newproxy()))
	
	print(obj)
	
	do
		local newObj = obj:Test_PushNewCollectable()
		
		newObj.foo = 90
		assert(foo ~= newObj.foo)
	end
	collectgarbage()
end
--]=]

function tes_tCheck()
end

function te_stHybrid()
	local obj = Test.ClaseHibridaConProperties()
	obj:RetornaString(1,2,3,4)
	assert_userdata(obj)
	assert_equal("this is a hybrid object", obj:RetornaString())
	assert_equal("this is a property of a hybrid object", obj.property)
	
	-- can add new properties
	obj.newBoolProperty = true
	assert_equal(true, obj.newBoolProperty)
	
	obj.newTableProperty = {}
	assert_table(obj.newTableProperty)
	
	-- Can't override builtin functions
	assert_function(obj.RetornaString)
	obj.RetornaString = true
	assert_function(obj.RetornaString)
end
--]=====]

function testBoton()
	local boton = Test.Boton()
	print(boton:GetLabel())
	print(boton:GetRect())
end