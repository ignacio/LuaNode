// LuaNode.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"

#include "LuaNode.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h> /* PATH_MAX */
#include <assert.h>
//#include <unistd.h>
#include <errno.h>
#include <direct.h>	//< contigo seguro que voy a tener problemas

#include "platform.h"

#include "luanode_timer.h"
#include "luanode_net.h"
#include "luanode_http_parser.h"
#include "luanode_dns.h"
#include "luanode_crypto.h"
#include "luanode_child_process.h"

#include "blogger.h"

#include "SocketServer.h"

namespace LuaNode {

static const char* LUANODE_VERSION = "0.0.1";

static int option_end_index = 0;
static bool use_debug_agent = false;
static bool debug_wait_connect = false;
static int debug_port=5858;

static bool need_tick_cb = false;
static int tickCallback = LUA_NOREF;

static boost::asio::io_service io_service;

/*static*/ boost::asio::io_service& GetIoService() {
	return io_service;
}

static CEvaluadorLua eval;

/*static*/ CEvaluadorLua& GetLuaEval() {
	return eval;
}

static const char* compileDateTime = "" __DATE__ """ - """ __TIME__ "";

#if defined(_WIN32)


//////////////////////////////////////////////////////////////////////////
/// Para poder bajar el servicio, si tengo la consola habilitada
BOOL WINAPI ConsoleControlHandler(DWORD ctrlType) {
	LogInfo("***** Console Event Detected *****");
	switch(ctrlType) {
		case CTRL_LOGOFF_EVENT:
			LogInfo("Event: CTRL-LOGOFF Event");
			return TRUE;
		break;
		case CTRL_C_EVENT:
		case CTRL_BREAK_EVENT:
			LogInfo("Event: CTRL-C or CTRL-BREAK Event");
			//_Module.SetServiceStatus(SERVICE_STOP_PENDING);
			//PostThreadMessage(_Module.m_dwThreadID, WM_QUIT, 0, 0);
			
			// Stop the io pool
			LuaNode::GetIoService().stop();
			return TRUE;
		break;
		case CTRL_CLOSE_EVENT:
		case CTRL_SHUTDOWN_EVENT:
			LogInfo("Event: CTRL-CLOSE or CTRL-SHUTDOWN Event");
			//_Module.SetServiceStatus(SERVICE_STOP_PENDING);
			//PostThreadMessage(_Module.m_dwThreadID, WM_QUIT, 0, 0);
			
			// Stop the io pool
			LuaNode::GetIoService().stop();
			return FALSE;
		break;
	}
	return FALSE;
}
#endif



//////////////////////////////////////////////////////////////////////////
/// 
static void Tick() {
	need_tick_cb = false;
	CEvaluadorLua& eval = LuaNode::GetLuaEval();
	//lua_getfield(eval, LUA_GLOBALSINDEX, "process");			// process
	//lua_getfield(eval, -1, "_tickcallback");					// process, function
	//int _tickCallback = luaL_ref(L, LUA_REGISTRYINDEX);
	//eval.call(0, LUA_MULTRET);

	// I'd previously stored the callback in the registry
	lua_rawgeti(eval, LUA_REGISTRYINDEX, tickCallback);
	eval.call(0, LUA_MULTRET);

	lua_settop(eval, 0);
}

//////////////////////////////////////////////////////////////////////////
/// 
static int NeedTickCallback(lua_State* L) {
	/*HandleScope scope;
	need_tick_cb = true;
	ev_idle_start(EV_DEFAULT_UC_ &tick_spinner);
	return Undefined();*/

	need_tick_cb = true;

	// TODO: esto no deberia ser un coso que se despacha con baja prioridad??
	// ver http://www.boost.org/doc/libs/1_44_0/doc/html/boost_asio/example/invocation/prioritised_handlers.cpp

	LuaNode::GetIoService().post( LuaNode::Tick );
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// Retrieves the current working directory
static int Cwd(lua_State* L) {
	char getbuf[2048];
	char *r = _getcwd(getbuf, sizeof(getbuf) - 1);
	if (r == NULL) {
		luaL_error(L, strerror(errno));
	}

	getbuf[sizeof(getbuf) - 1] = '\0';
	lua_pushstring(L, getbuf);
	return 1;
}

/*Handle<Value> Kill(const Arguments& args) {
	HandleScope scope;

	if (args.Length() != 2 || !args[0]->IsNumber() || !args[1]->IsNumber()) {
		return ThrowException(Exception::Error(String::New("Bad argument.")));
	}

	pid_t pid = args[0]->IntegerValue();
	int sig = args[1]->Int32Value();
	int r = kill(pid, sig);

	if (r != 0) return ThrowException(ErrnoException(errno, "kill"));

	return Undefined();
}*/

//////////////////////////////////////////////////////////////////////////
/// The main loop
static int Loop(lua_State* L) {
	//lua_getfield(L, LUA_GLOBALSINDEX, "process");

	// store the callback in the registry to retrieve it faster
	lua_getfield(L, 1, "_tickcallback");	// process, function
	tickCallback = luaL_ref(L, LUA_REGISTRYINDEX);


	// TODO: Ver si esto no jode. Estoy sacando la tabla process del stack de C. Es seguro hacer esto porque en node.lua 
	// guardé una referencia en _G
	lua_settop(L, 0);
	/*int t = lua_gettop(L);
	int j = luaL_ref(L, LUA_REGISTRYINDEX);
	t = lua_gettop(L);*/

	LogDebug("LuaNode.exe: Loop - begin");
	boost::system::error_code ec;
	/*while(io_service.run_one(ec)) {
		if(LuaNode::need_tick_cb) {
			lua_rawgeti(L, LUA_REGISTRYINDEX, tickCallback);
			LuaNode::GetLuaEval().call(0, LUA_MULTRET);
		}
	}
	// TODO: hacer algo con el error code :D
	*/

	// TODO: hacer algo con el error code :D
	io_service.run(ec);
	luaL_unref(L, LUA_REGISTRYINDEX, tickCallback);

	LogDebug("LuaNode.exe: Loop - end");
	return 0;
}


//////////////////////////////////////////////////////////////////////////
/// 
static void OnFatalError(const char* location, const char* message) {
	if (location) {
		fprintf(stderr, "FATAL ERROR: %s %s\n", location, message);
	} else {
		fprintf(stderr, "FATAL ERROR: %s\n", message);
	}
	exit(1);
}

//////////////////////////////////////////////////////////////////////////
/// 
static void Load(int argc, char *argv[]) {
	lua_State* L = LuaNode::eval;
	
	// tabla 'process'
	lua_newtable(L);
	int table = lua_gettop(L);
	lua_pushstring(L, LUANODE_VERSION);	// TODO: sacarlo de un lugar sensato
	lua_setfield(L, table, "version");

	// process.platform
	// TODO: que dependa del platform compilado
	lua_pushstring(L, "windows");
	lua_setfield(L, table, "platform");

	// process.argv
	lua_newtable(L);
	int argArray = lua_gettop(L);
	lua_pushstring(L, argv[0]);
	lua_rawseti(L, argArray, 1);
	for(int j = 2, i = option_end_index; i < argc; j++, i++) {
		lua_pushstring(L, argv[i]);
		lua_rawseti(L, argArray, j);
	}
	// assign it
	lua_pushvalue(L, argArray);
	lua_setfield(L, table, "ARGV");
	lua_setfield(L, table, "argv");

	// create process.env
	lua_newtable(L);
	int envTable = lua_gettop(L);
	for(int i = 0; environ[i]; i++) {
		// skip entries without a '=' character
		int j;
		for(j = 0; environ[i][j] && environ[i][j] != '='; j++) { ; }
		lua_pushlstring(L, environ[i], j);
		if (environ[i][j] == '=') {
			lua_pushstring(L, environ[i] + j + 1);
		}
		else {
			lua_pushstring(L, "");
		}
		lua_settable(L, envTable);
	}
	// assign process.ENV
	lua_pushvalue(L, envTable);
	lua_setfield(L, table, "ENV");
	lua_setfield(L, table, "env");

	lua_pushinteger(L, _getpid());
	lua_setfield(L, table, "pid");

	// TODO:
	size_t size = 2 * MAX_PATH;
	std::vector<char> execPath(size);
	if (OS::GetExecutablePath(&execPath[0], &size) != 0) {
		// as a last ditch effort, fallback on argv[0] ?
		lua_pushstring(L, argv[0]);
		lua_setfield(L, table, "execPath");
	}
	else {
		lua_pushstring(L, &execPath[0]);
		lua_setfield(L, table, "execPath");
	}
	
	// define various internal methods
	lua_pushvalue(L, table);
	luaL_Reg methods[] = {
		{ "loop", Loop },
		{ "cwd", Cwd },
		//{ "_kill", Kill },
		{ "_needTickCallback", NeedTickCallback },
		{ 0, 0 }
	};
	luaL_register(L, NULL, methods);
	lua_pop(L, 1);
	//lua_pushcfunction(L, Loop);
	//lua_setfield(L, table, "loop");
	
	// Initialize the C++ modules..................filename of module
	Net::RegisterFunctions(L);
	//Net::EnableTracking(L);
	//Net::Register(L, NULL, true);

	//Net::Acceptor::EnableTracking(L);
	Net::Acceptor::Register(L, NULL, true);

	//Net::Socket::EnableTracking(L);
	Net::Socket::Register(L, NULL, true);
	//IOWatcher::Initialize(process);              // io_watcher.cc

	//Dns::Resolver::EnableTracking(L);
	Dns::Resolver::Register(L, NULL, true);

	//Crypto::Socket::EnableTracking(L);
	//Crypto::Socket::Register(L, "Socket", true);
	Crypto::Socket::Register(L, NULL, true);
	Crypto::SecureContext::Register(L, NULL, true);

	Http::RegisterFunctions(L);
	Http::Parser::EnableTracking(L);
	Http::Parser::Register(L, NULL, true);

	//Timer::Initialize(process);                  // timer.cc
	//Timer::EnableTracking(L);
	//Timer::s_trackingEnabled = true;
	Timer::Register(L, NULL, true);					// luanode_timer.cc

	ChildProcess::Register(L, NULL, true);

	//DefineConstants(process);                    // constants.cc
	// Compile, execute the src/node.js file. (Which was included as static C
	// string in node_natives.h. 'natve_node' is the string containing that
	// source code.)

	// The node.js file returns a function 'f'

	LuaNode::eval.dofile("d:/trunk_git/sources/LuaNode/src/node.lua");
	int function = lua_gettop(L);
	if(lua_type(L, function) != LUA_TFUNCTION) {
		// TODO: fix me
		LogError("Error in node.lua");
		lua_settop(L, 0);
		return;
	}
	lua_pushvalue(L, table);

	eval.call(1, LUA_MULTRET);
}


// Parse LuaNode command line arguments.
static void ParseArgs(int *argc, char **argv) {
	int i;

	// TODO use parse opts
	for (i = 1; i < *argc; i++) {
		const char *arg = argv[i];
		if (strstr(arg, "--debug") == arg) {
			//ParseDebugOpt(arg);
			argv[i] = const_cast<char*>("");
		} else if (strcmp(arg, "--version") == 0 || strcmp(arg, "-v") == 0) {
			printf("%s\n", LUANODE_VERSION);
			exit(0);
		} else if (strcmp(arg, "--vars") == 0) {
			//printf("NODE_PREFIX: %s\n", NODE_PREFIX);
			//printf("NODE_CFLAGS: %s\n", NODE_CFLAGS);
			exit(0);
		} else if (strcmp(arg, "--help") == 0 || strcmp(arg, "-h") == 0) {
			//PrintHelp();
			exit(0);
		/*} else if (strcmp(arg, "--v8-options") == 0) {
			argv[i] = const_cast<char*>("--help");*/
		} else if (argv[i][0] != '-') {
			break;
		}
	}

	option_end_index = i;
}


static void AtExit() {
	//LuaNode::Stdio::Flush();
	//LuaNode::Stdio::DisableRawMode(STDIN_FILENO);
	LogFree();
}


}  // namespace LuaNode

int main(int argc, char* argv[])
{
	// TODO: Parsear argumentos
	if(!SetConsoleCtrlHandler((PHANDLER_ROUTINE)LuaNode::ConsoleControlHandler, TRUE)) {
		LogError("SetConsoleCtrlHandler failed");
	}

	// TODO: wrappear el log en un objeto (o usar libblogger2cpp)
	LogInfo("**** Starting LuaNode - Built on %s ****", LuaNode::compileDateTime);

	long nListenPort, keepAliveTime, keepAliveInterval;

	nListenPort = 6060;
	keepAliveTime = 10000;
	keepAliveInterval = 5000;

	//inConcert::Network::CSocketAllocator allocator(2);
	//CSocketServer server(static_cast<unsigned short>(nListenPort), allocator, keepAliveTime, keepAliveInterval, allocator);

	atexit(LuaNode::AtExit);

	// Parse a few arguments which are specific to Node.
	LuaNode::ParseArgs(&argc, argv);

	LuaNode::Load(argc, argv);
	//LuaNode::eval.dostring("print('\\nHello world from LuaNode');");
	

	//server.Start();
	//LuaNode::hEvtStop = CreateEvent(NULL, FALSE, FALSE, NULL);
	//WaitForSingleObject(LuaNode::hEvtStop, INFINITE);

	LogFree();
	return 0;
}
