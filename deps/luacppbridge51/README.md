**LuaCppBridge51** is a library to expose C++ classes to Lua. You pick a class from the library to derive from, add the desired methods, properties, etc and register it into Lua. It is a very simple wrapper that does not aim to expose already existing C++ classes. There are lots of libraries for that ([Simple Lua Binder] [1], [LuaBind] [2], [OOLua] [3], etc).

**LuaCppBridge51** builds on ideas from binding classes using [Lunar] [4] and [Lua Technical Note 5] [5]. It builds on Lunar, adding the following:

 - allows you to define *properties*, by means of getter/setter methods in C++.
 - retrieve Lua instances from C++ callbacks

The following were already present in Lunar:

 - add new class methods from Lua
 - simple inheritance (make a C++ class inherit from a "class" in Lua, or viceversa)

More detailed documentation is available [on the wiki] [6]



[1]: http://code.google.com/p/slb/
[2]: http://www.rasterbar.com/products/luabind.html
[3]: http://code.google.com/p/oolua/
[4]: http://lua-users.org/wiki/CppBindingWithLunar
[5]: http://www.lua.org/notes/ltn005.html
[6]: https://github.com/ignacio/LuaCppBridge51/wiki