-- validar creacion
assert(Test.ClaseHibrida:new())
assert(Test.ClaseHibrida())
assert(Test.ClaseHibrida{})

local instancia = Test.ClaseHibrida()
local instancia2 = Test.ClaseHibrida()
print(instancia:RetornaString())
local inst = instancia:RetornaNuevaInstanciaSinGC()
print(tostring(inst))

instancia.NewMethod = function(self, foo)
	print("called a new method with", tostring(foo))
end

instancia:NewMethod("blah")

-- instancia2 no tiene NewMethod, solo se lo puse a instancia
assert(false == pcall(instancia2.NewMethod, instancia2, "foo"))

local i1 = instancia:RetornaThisSinGC()
local i2 = instancia:RetornaThisSinGC()
assert(i1 == i2)

-- i1 e i2 son la misma instancia, si le agrego un método a una lo puedo llamar desde la otra
i1.NewMethod = function(self, foo)
	print("called a new method with", tostring(foo))
end

i2:NewMethod("foo")

local rawObject = Test.RawWithProps()
print(rawObject:TestMethod1())

local boton = Test.Boton()
assert(boton)
print(boton:GetLabel())
print(boton:GetRect())

local howp = Test.ClaseHibridaConProperties()
assert(howp)
print(type(howp))
print(howp:RetornaString())
print(howp.property)
howp.newProperty = true
print(howp.newProperty)
print(howp.RetornaString)
howp.RetornaString = true
print(howp.RetornaString)


--[=[
rawObject.NewMethod = function(self, foo)
	print("called a new method with", tostring(foo))
end

rawObject:NewMethod("blah")
--]=]