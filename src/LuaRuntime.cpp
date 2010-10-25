#include "StdAfx.h"
#include "LuaRuntime.h"
#include "blogger.h"
#include "ToDo.h"
#include <assert.h>
#include <supportLib/bstring/bstrwrap.h>

//////////////////////////////////////////////////////////////////////////
/// Given a source file and a line number, tries to find the name of the function defined in that line.
static CBString GuessFunctionName(lua_State* L, lua_Debug& ar, const char* filename, int lineDefined) {
	static const size_t buff_size = 1024;
	char buffer[buff_size];
	const char* buffer_ptr = buffer;
	int line = 0;
	bool lineFound = false;

	if(filename && filename[0] == '@') {
		filename++;
		// read the file line by line until we find line #lineDefined
		FILE* handle = fopen(filename, "r");
		if(!handle) {
			////PLogError("GuessFunctionName - Could not open file '%s'\r\n%s", filename, (const char*)FormatLastErrorMessage());
			return "?";
		}
		for (;;) {
			if (fgets(buffer, buff_size, handle) == NULL) {  /* eof? */
				break;
			}
			size_t l = strlen(buffer);
			if(l != 0 && buffer[l - 1] == '\n') {
				line++;
				if(line == lineDefined) {
					buffer[l - 1] = 0;
					lineFound = true;
					// skip blanks and tabs (does not do a bounds check because Lua told us there's a function definition, so there will be something that resembles
					// a function definition
					for(;;) {
						if(buffer_ptr[0] == '\t' || buffer_ptr[0] == ' ') {
							buffer_ptr = buffer_ptr + 1;
						}
						else {
							break;
						}
					}
					break;
				}
			}
		}
		fclose(handle);
	}
	else {
		#pragma TODO("Unhandled case! Find function definitions in Lua code chunks (not files)")
		LogDebug("TODO: Unhandled case! Find function definitions in Lua code chunks (not files)");
		return "?";
	}

	if(!lineFound) {
		LogError("GuessFunctionName - Could not find line #%d in file '%s'", lineDefined, filename);
		return "?";
	}

	// once we found the line, do a naive parsing :D
	const size_t size_match_function = sizeof("function ") - 1;
	const size_t size_match_local = sizeof("local ") - 1;
	const size_t size_match_local_function = sizeof("local function ") - 1;
	const size_t size_match_return = sizeof("return function") - 1;

	if(strncmp(buffer_ptr, "function ", size_match_function) == 0) {	// ej: function blah(foo, bar, baz)
		CBString temp = buffer_ptr + size_match_function;
		long pos = temp.findchr(" (");	// matches either ' ' or '('
		if(pos != BSTR_ERR) {
			temp = temp.midstr(0, pos);
			temp.trim();
			if(temp.length() == 0) {
				temp = "(anonymous)";
			}
			return temp;
		}
	}
	else if(strncmp(buffer_ptr, "local function ", size_match_local_function) == 0) {	// ej: local function fill(render, web, template, env)
		CBString temp = buffer_ptr + size_match_local_function;
		long pos = temp.findchr(" (");
		if(pos != BSTR_ERR) {
			temp = temp.midstr(0, pos);
			temp.trim();
			return temp;
		}
	}
	else if(strncmp(buffer_ptr, "local ", size_match_local) == 0) {	// ej: local ruleHandler = function(bla, bla, bla)
		CBString temp = buffer_ptr + size_match_local;
		long pos = temp.find("=");
		if(pos != BSTR_ERR) {
			temp = temp.midstr(0, pos);
			temp.trim();
			if(temp.length() == 0) {
				temp = "(anonymous)";
			}
			return temp;
		}
	}
	else if(strncmp(buffer_ptr, "return function", size_match_return) == 0) {	// ej: return function(wsapi_env)
		return "(anonymous)";
	}
	LogError("GuessFunctionName - Unhandled function format definition in file '%s':\r\n%s", filename, buffer_ptr);
	return "?";
}

//////////////////////////////////////////////////////////////////////////
/// Given a stack frame, dump all local variables into string 'output'
static void DumpLocals(lua_State* L, lua_Debug ar, CBString& output) {
	static const char* prefix = "\t ";
	CBString variablesLine;
	int i = 1;
	const char* name = lua_getlocal(L, &ar, i++);
	if(name) {
		output += "\tLocal variables:\n";
	}
	do {
		int luaType = lua_type(L, -1);
		switch(luaType) {
			case LUA_TNUMBER: {
				variablesLine.format("%snumber '%s' = %d\n", prefix, name, lua_tonumber(L, -1));
			break;}

			case LUA_TSTRING:
				variablesLine.format("%sstring '%s' = '%s'\n", prefix, name, lua_tostring(L, -1));
			break;

			case LUA_TUSERDATA:
				variablesLine.format("%suserdata '%s' = 0x%08x\n", prefix, name, lua_touserdata(L, -1));
			break;

			case LUA_TNIL:
				variablesLine.format("%s'%s' (a nil value)\n", prefix, name);
			break;

			case LUA_TTABLE:
				variablesLine.format("%stable '%s' = 0x%08x\n", prefix, name, lua_topointer(L, -1));
			break;

			case LUA_TFUNCTION: {
				lua_Debug arFunction;
				memset(&arFunction, 0, sizeof(lua_Debug));
				lua_pushvalue(L, -1);	// hago una copia de la función
				lua_getinfo(L, ">Sn", &arFunction);
				if(strcmp(arFunction.what, "C") == 0) {
					variablesLine.format("%sC function '%s' = %s\n", prefix, name, arFunction.name ? arFunction.name : "no name");
				}
				else if(strcmp(arFunction.what, "Lua") == 0) {
					CBString source = arFunction.short_src;
					if(source.midstr(1, 6) == "string") {
						source = source.midstr(7, INT_MAX); // uno más, por el espacio que viene (string "Baragent.Main", por ejemplo)
					}
					variablesLine.format("%sLua function '%s' = %s (defined at line %d of chunk %s)\n",
						prefix, name, arFunction.name, arFunction.linedefined, (const char*)source);
				}
			break;}

			case LUA_TTHREAD:
				variablesLine.format("%sthread '%s' = 0x%08x\n", prefix, name, lua_topointer(L, -1));
			break;
		}
		lua_pop(L, 1);  /* remove variable value */
		output += variablesLine;
		name = lua_getlocal(L, &ar, i++);
	}
	while(name);
}

//////////////////////////////////////////////////////////////////////////
/// Collects a stack trace. Prints all relevant information for each stack frame, such as
/// function names, where are they defined, its local variables, etc.
int CollectTraceback(lua_State* L) {
	int startLevel = 1;	// me salteo este handler
	bool traverseInDepth = true;

	CBString stackTrace;
	char msgline[4096];
	lua_Debug ar;

	memset(&ar, 0, sizeof(lua_Debug));

	int stack_top = lua_gettop(L);
	// The 'error' function can raise anything. At least treat tables as a special case.
	if(lua_istable(L, stack_top)) {
		CBString err_message = "an error object => {\r\n";
		bool first = true;
		lua_pushnil(L);
		while(lua_next(L, stack_top)) {
			if(first) {
				err_message += "  ";
				first = false;
			}
			else {
				err_message += ",\r\n  ";
			}
			switch(lua_type(L, -2)) {
				case LUA_TNUMBER:
					err_message += CBString(lua_tonumber(L, -2));
				break;
				case LUA_TSTRING:
					err_message += "'";
					err_message += lua_tostring(L, -2);
					err_message += "'";
				break;
				default:
					err_message += luaL_typename(L, -2);
				break;
			}
			err_message += ": ";
			switch(lua_type(L, -1)) {
				case LUA_TNUMBER:
					err_message += CBString(lua_tonumber(L, -1));
				break;
				case LUA_TSTRING:
					err_message += lua_tostring(L, -1);
				break;
				default:
					err_message += luaL_typename(L, -1);
				break;
			}
			lua_pop(L, 1);
		}
		// we remove the table from the stack and instead we push our printable version
		lua_remove(L, -1);
		err_message += "\r\n}";
		lua_pushstring(L, err_message);
	}

	lua_pushliteral(L, "\n\r");
	lua_pushliteral(L, "Stack Traceback\n===============\n\r");

	int res = lua_getstack(L, startLevel, &ar);
	while(res == 1) {
		bool dumpLocals = false;
		lua_getinfo(L, "nSl", &ar);	// name, namewhat, source information, currentline

		if(strcmp(ar.what, "main") == 0) {
			if(ar.source && strlen(ar.source) > 0) {
				if(ar.source[0] == '@') {
					sprintf(msgline, "(%d) main chunk of file '%s' at line %d\n", startLevel, &ar.source[1], ar.currentline);
				}
				else {
					sprintf(msgline, "(%d) main chunk of %s at line %d\n", startLevel, ar.source, ar.currentline);
				}
				stackTrace += msgline;
			}
			else {
				CBString source = ar.short_src;
				if(source.midstr(1, 6) == "string") {
					source = source.midstr(7, INT_MAX); // uno más, por el espacio que viene (string "Baragent.Main", por ejemplo)
				}
				sprintf(msgline, "(%d) main chunk of %s at line %d\n", startLevel, (const char*)source, ar.currentline);
				stackTrace += msgline;
			}
		}
		else if(strcmp(ar.what, "C") == 0) {
			sprintf(msgline, "(%d) %s C function '%s'\n", startLevel, ar.namewhat, ar.name);
			stackTrace += msgline;
		}
		else if(strcmp(ar.what, "tail") == 0) {
			sprintf(msgline, "(%d) tail call\n", startLevel);
			stackTrace += msgline;
			dumpLocals = true;
		}
		else if(strcmp(ar.what, "Lua") == 0) {
			CBString messageLine;
			CBString source = ar.short_src;
			if(source.midstr(1, 6) == "string") {
				source = source.midstr(7, INT_MAX); // uno más, por el espacio que viene (string "Baragent.Main", por ejemplo)
			}
			CBString function_name;
			bool wasGuessed = false;
			if(!ar.name) {	// fuck! open the file in which the function is defined and try to guess its name
				function_name = GuessFunctionName(L, ar, ar.source, ar.linedefined);
				wasGuessed = true;
			}
			else {
				function_name = ar.name;
			}
			// test if we have a file name
			if(ar.source && ar.source[0] == '@') {
				const char* function_type = (strcmp(ar.namewhat, "") == 0) ? "function" : ar.namewhat;
				messageLine.format("(%d) Lua %s '%s' at file '%s:%d'%s\n", startLevel, function_type, (const char*)function_name, &ar.source[1], ar.currentline, (wasGuessed) ? " (best guess)" : "");
			}
			else if(ar.source && ar.source[0] == '#') {
				const char* function_type = (strcmp(ar.namewhat, "") == 0) ? "function" : ar.namewhat;
				messageLine.format("(%d) Lua %s '%s' at template '%s'%s\n", startLevel, function_type, (const char*)function_name, &ar.source[1], (wasGuessed) ? " (best guess)" : "");
			}
			else {
				const char* function_type = (strcmp(ar.namewhat, "") == 0) ? "function" : ar.namewhat;
				messageLine.format("(%d) Lua %s '%s' at line %d of chunk '%s'\n", startLevel, function_type, (const char*)function_name, ar.currentline, (const char*)source);
			}
			stackTrace += messageLine;
			dumpLocals = true;
		}
		else {
			sprintf(msgline, "(%d) unknown frame %s\n", startLevel, ar.what);
			stackTrace += msgline;
		}

		if(dumpLocals) {
			DumpLocals(L, ar, stackTrace);
		}
		if(traverseInDepth == false) {
			break;
		}

		memset(&ar, 0, sizeof(ar));
		startLevel++;
		res = lua_getstack(L, startLevel, &ar);
	}
	lua_pushstring(L, stackTrace);
	lua_concat(L, lua_gettop(L));
	return 1;
}

//////////////////////////////////////////////////////////////////////////
///
CBString InternalStackTrace(lua_State* L, int startLevel, bool traverseInDepth) {
	CBString stackTrace;
	char msgline[4096];
	lua_Debug ar;

	memset(&ar, 0, sizeof(lua_Debug));

	int res = lua_getstack(L, startLevel, &ar);
	while(res == 1) {
		lua_getinfo(L, "nSlu", &ar);

		if(strcmp(ar.what, "main") == 0) {
			CBString source = ar.short_src;
			if(source.midstr(1, 6) == "string") {
				source = source.midstr(7, INT_MAX); // uno más, por el espacio que viene (string "Baragent.Main", por ejemplo)
			}
			sprintf(msgline, "main chunk of %s at line %d\n", (const char*)source, ar.currentline);
			stackTrace += msgline;
		}
		else if(strcmp(ar.what, "C") == 0) {
			sprintf(msgline, "C function %s\n", ar.name);
			stackTrace += msgline;
		}
		else {
			CBString messageLine;
			CBString source = ar.short_src;
			if(source.midstr(1, 6) == "string") {
				source = source.midstr(7, INT_MAX); // uno más, por el espacio que viene (string "Baragent.Main", por ejemplo)
			}
			messageLine.format("Lua function '%s' at line %d of chunk %s\n", ar.name, ar.currentline, (const char*)source);

			CBString variablesLine;
			const char* name;
			int i = 1;
			while ((name = lua_getlocal(L, &ar, i++)) != NULL) {
				int luaType = lua_type(L, -1);
				switch(luaType) {
				case LUA_TNUMBER: {
					variablesLine.format("\t* local number '%s' = %g\n", name, lua_tonumber(L, -1));
					break;}

				case LUA_TSTRING:
					variablesLine.format("\t* local string '%s' = %s\n", name, lua_tostring(L, -1));
					break;

				case LUA_TUSERDATA:
					variablesLine.format("\t* local userdata '%s' = 0x%08x\n", name, lua_touserdata(L, -1));
					break;

				case LUA_TNIL:
					variablesLine.format("\t* local '%s' (a nil value)\n", name);
					break;

				case LUA_TTABLE:
					variablesLine.format("\t* local table '%s' = 0x%08x\n", name, lua_topointer(L, -1));
					break;

				case LUA_TFUNCTION: {
					lua_Debug arFunction;
					memset(&arFunction, 0, sizeof(lua_Debug));
					lua_pushvalue(L, -1);	// hago una copia de la función
					lua_getinfo(L, ">Sn", &arFunction);
					if(strcmp(arFunction.what, "C") == 0) {
						variablesLine.format("\t* local '%s' (a C function) = %s\n", name, arFunction.name);
					}
					else if(strcmp(arFunction.what, "Lua") == 0) {
						CBString functionSource = arFunction.short_src;
						if(functionSource.midstr(1, 6) == "string") {
							functionSource = functionSource.midstr(7, INT_MAX); // uno más, por el espacio que viene (string "Baragent.Main", por ejemplo)
						}
						variablesLine.format("\t* local '%s' (a Lua function) = %s (defined at line %d of chunk %s)\n",
							name, arFunction.name, arFunction.linedefined, (const char*)functionSource);
					}
					break;}
				}
				lua_pop(L, 1);  /* remove variable value */
				messageLine += variablesLine;
			}
			stackTrace += messageLine;
		}
		if(traverseInDepth == false) {
			break;
		}

		memset(&ar, 0, sizeof(ar));
		startLevel++;
		res = lua_getstack(L, startLevel, &ar);
	}
	return stackTrace;
}

//////////////////////////////////////////////////////////////////////////
///
CBString redirected_print_formatter(lua_State* L) {
	CBString text;
	int count = lua_gettop(L);
	for(int i = 1; i <= count; i++) {
		if(lua_isstring(L, i)) {
			text += lua_tostring(L, i);
			text += "\t";
		}
		else {
			lua_getfield(L, LUA_GLOBALSINDEX, "tostring");
			lua_pushvalue(L, i);
			lua_call(L, 1, 1);
			assert(lua_isstring(L, -1));
			text += lua_tostring(L, -1);
			text += "\t";
			lua_pop(L, 1);
		}
	}
	return text;
}

//////////////////////////////////////////////////////////////////////////
/// Función para reemplazar el 'print' de Lua. Redirige la salida a
/// LogInfo
int redirected_print(lua_State* L) {
	printf("%s\r\n", (const char*)redirected_print_formatter(L));
	return 0;
}
