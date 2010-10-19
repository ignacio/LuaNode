.PHONY: clean All

All:
	@echo ----------Building project:[ LuaNode - Debug ]----------
	@"mingw32-make.exe"  -j 8 -f "LuaNode.mk"
clean:
	@echo ----------Cleaning project:[ LuaNode - Debug ]----------
	@"mingw32-make.exe"  -j 8 -f "LuaNode.mk" clean
