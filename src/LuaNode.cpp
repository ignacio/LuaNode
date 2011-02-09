#include "stdafx.h"

#include "LuaNode.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h> /* PATH_MAX */
#include <assert.h>
//#include <unistd.h>
#include <errno.h>

#include <signal.h>

#include "platform.h"

#include "luanode_timer.h"
#include "luanode_net.h"
#include "luanode_net_acceptor.h"
#include "luanode_datagram_udp.h"
#include "luanode_http_parser.h"
#include "luanode_dns.h"
#include "luanode_crypto.h"
#include "luanode_child_process.h"
#include "luanode_module_api.h"
#include "luanode_os.h"

#if defined (_WIN32)
	#include "luanode_file_win32.h"
#elif defined(__linux__)
	#include "luanode_file_linux.h"
#else
	#error "Unsupported platform"
#endif

#include "blogger.h"

#include "../lib/preloader.h"


/*#ifdef _WIN32
#include <io.h>
#include <stdio.h>
#define lua_stdin_is_tty()	_isatty(_fileno(stdin))
#else
#include <unistd.h>
#define lua_stdin_is_tty()	isatty(0)
#endif*/


namespace LuaNode {

static const char* LUANODE_PROGNAME = "LuaNode";
static const char* LUANODE_VERSION = "0.0.1pre";
static const char* compileDateTime = "" __DATE__ """ - """ __TIME__ "";

static int option_end_index = 0;
static bool debug_mode = false;

static bool need_tick_cb = false;
static int tickCallback = LUA_NOREF;

static boost::asio::io_service io_service;
static CLuaVM luaVm;


//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ boost::asio::io_service& GetIoService() {
	return io_service;
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ CLuaVM& GetLuaVM() {
	return luaVm;
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ int BoostErrorCodeToLua(lua_State* L, const boost::system::error_code& ec) 
{
	if(ec) {
		lua_pushboolean(L, false);
		lua_pushinteger(L, ec.value());
		lua_pushstring(L, ec.message().c_str());
		return 3;
	}
	lua_pushboolean(L, true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
static void SignalExit(int signal) {
	// Stop the io pool
	LuaNode::GetIoService().stop();
	// Kindly leave the stage...
	exit(1);
}

//////////////////////////////////////////////////////////////////////////
/// 
static int RegisterSignalHandler(int sig_no, void (*handler)(int)) {
#ifdef _WIN32
	signal(sig_no, handler);
	return 0;
#else
	struct sigaction sa;

	memset(&sa, 0, sizeof(sa));

	sigfillset(&sa.sa_mask);
	return sigaction(sig_no, &sa, NULL);
#endif	
}

//////////////////////////////////////////////////////////////////////////
/// 
static void Tick() {
	need_tick_cb = false;
	CLuaVM& vm = LuaNode::GetLuaVM();
	//lua_getfield(vm, LUA_GLOBALSINDEX, "process");			// process
	//lua_getfield(vm, -1, "_tickcallback");					// process, function
	//int _tickCallback = luaL_ref(L, LUA_REGISTRYINDEX);
	//vm.call(0, LUA_MULTRET);

	// I'd previously stored the callback in the registry
	lua_rawgeti(vm, LUA_REGISTRYINDEX, tickCallback);
	vm.call(0, LUA_MULTRET);

	lua_settop(vm, 0);
}

//////////////////////////////////////////////////////////////////////////
/// 
static int NeedTickCallback(lua_State* L) {
	need_tick_cb = true;

	// TODO: esto no deberia ser un coso que se despacha con baja prioridad??
	// ver http://www.boost.org/doc/libs/1_44_0/doc/html/boost_asio/example/invocation/prioritised_handlers.cpp

	LuaNode::GetIoService().post( LuaNode::Tick );
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// Retrieves the current working directory
static int Cwd(lua_State* L) {
	return Platform::Cwd(L);
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
/// 
static int Exit(lua_State* L) {
	int code = luaL_optinteger(L, 1, EXIT_FAILURE);
	LuaNode::GetIoService().stop();
	//lua_close(LuaNode::GetLuaVM());

	// Will it be possible to have a clean ending?
#ifdef _WIN32
	TerminateProcess(NULL, code);
#else
	exit(code);
#endif
	return 0;
}

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

	LogDebug("LuaNode.exe: Loop - begin");
	boost::system::error_code ec;
	/*while(io_service.run_one(ec)) {
		if(LuaNode::need_tick_cb) {
			lua_rawgeti(L, LUA_REGISTRYINDEX, tickCallback);
			LuaNode::GetLuaVM().call(0, LUA_MULTRET);
		}
	}*/

	io_service.run(ec);
	luaL_unref(L, LUA_REGISTRYINDEX, tickCallback);

	if(ec) {
		LogError("LuaNode.exe: Loop - ended with error\r\n%s", ec.message().c_str());
		return ec.value();
	}
	LogDebug("LuaNode.exe: Loop - end");
	return 0;
}


//////////////////////////////////////////////////////////////////////////
/// 
/*static void OnFatalError(const char* location, const char* message) {
	if (location) {
		fprintf(stderr, "FATAL ERROR: %s %s\n", location, message);
	} else {
		fprintf(stderr, "FATAL ERROR: %s\n", message);
	}
	exit(1);
}*/

//////////////////////////////////////////////////////////////////////////
/// 
static void PrintVersion() {
	printf("LuaNode %s\n", LUANODE_VERSION);
}

//////////////////////////////////////////////////////////////////////////
/// taken from Lua interpreter

static void lstop (lua_State *L, lua_Debug *ar) {
	(void)ar;  /* unused arg. */
	lua_sethook(L, NULL, 0, 0);
	luaL_error(L, "interrupted!");
}

static void laction (int i) {
	signal(i, SIG_DFL); /* if another SIGINT happens before lstop,
							terminate process (default action) */
	lua_sethook(LuaNode::luaVm, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}


//////////////////////////////////////////////////////////////////////////
/// 
static void PrintUsage (void) {
	fprintf(stderr,
		"usage: %s [options] [script [args]].\n"
		"Available options are:\n"
		"  -e stat  execute string " LUA_QL("stat") "\n"
		"  -l name  require library " LUA_QL("name") "\n"
		"  -i       enter interactive mode after executing " LUA_QL("script") "\n"
		"  -v       show version information\n"
		"  --       stop handling options\n"
		"  -        execute stdin and stop handling options\n"
		,
		LUANODE_PROGNAME);
	fflush(stderr);
}

static void l_message (const char *pname, const char *msg) {
	if (pname) fprintf(stderr, "%s: ", pname);
	fprintf(stderr, "%s\n", msg);
	fflush(stderr);
}


static int report (lua_State *L, int status) {
	if (status && !lua_isnil(L, -1)) {
		const char *msg = lua_tostring(L, -1);
		if (msg == NULL) msg = "(error object is not a string)";
		l_message(LUANODE_PROGNAME, msg);
		lua_pop(L, 1);
	}
	return status;
}


//////////////////////////////////////////////////////////////////////////
/// 
static int traceback (lua_State *L) {
	if (!lua_isstring(L, 1))  /* 'message' not a string? */
		return 1;  /* keep it intact */
	lua_getfield(L, LUA_GLOBALSINDEX, "debug");
	if (!lua_istable(L, -1)) {
		lua_pop(L, 1);
		return 1;
	}
	lua_getfield(L, -1, "traceback");
	if (!lua_isfunction(L, -1)) {
		lua_pop(L, 2);
		return 1;
	}
	lua_pushvalue(L, 1);  /* pass error message */
	lua_pushinteger(L, 2);  /* skip this function and traceback */
	lua_call(L, 2, 1);  /* call debug.traceback */
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 
static int docall (lua_State *L, int narg, int clear) {
	int status;
	int base = lua_gettop(L) - narg;  /* function index */
	lua_pushcfunction(L, traceback);  /* push traceback function */
	lua_insert(L, base);  /* put it under chunk and args */
	signal(SIGINT, laction);
	status = lua_pcall(L, narg, (clear ? 0 : LUA_MULTRET), base);
	signal(SIGINT, SIG_DFL);
	lua_remove(L, base);  /* remove traceback function */
	/* force a complete garbage collection in case of errors */
	if (status != 0) lua_gc(L, LUA_GCCOLLECT, 0);
	return status;
}

//////////////////////////////////////////////////////////////////////////
/// 
static int dofile (lua_State *L, const char *name) {
	int status = luaL_loadfile(L, name) || docall(L, 0, 1);
	return report(L, status);
}

//////////////////////////////////////////////////////////////////////////
/// 
static int dostring (lua_State *L, const char *s, const char *name) {
	int status = luaL_loadbuffer(L, s, strlen(s), name) || docall(L, 0, 1);
	return report(L, status);
}

//////////////////////////////////////////////////////////////////////////
/// 
static int dolibrary (lua_State *L, const char *name) {
	lua_getglobal(L, "require");
	lua_pushstring(L, name);
	return report(L, docall(L, 1, 1));
}

/* check that argument has no extra characters at the end */
#define notail(x)	{if ((x)[2] != '\0') return -1;}


static int collectargs (char **argv, int *pi, int *pv, int *pe) {
	int i;
	for (i = 1; argv[i] != NULL; i++) {
		if (argv[i][0] != '-')  /* not an option? */
			return i;
		switch (argv[i][1]) {  /* option */
	  case '-':
		  notail(argv[i]);
		  return (argv[i+1] != NULL ? i+1 : 0);
	  case '\0':
		  return i;
	  case 'i':
		  notail(argv[i]);
		  *pi = 1;  /* go through */
	  case 'v':
		  notail(argv[i]);
		  *pv = 1;
		  break;
	  case 'e':
		  *pe = 1;  /* go through */
	  case 'l':
		  if (argv[i][2] == '\0') {
			  i++;
			  if (argv[i] == NULL) return -1;
		  }
		  break;
	  default: return -1;  /* invalid option */
		}
	}
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
static int runargs (lua_State *L, char **argv, int n) {
	int i;
	for (i = 1; i < n; i++) {
		if (argv[i] == NULL) continue;
		lua_assert(argv[i][0] == '-');
		switch (argv[i][1]) {  /* option */
	  case 'e': {
		  const char *chunk = argv[i] + 2;
		  if (*chunk == '\0') chunk = argv[++i];
		  lua_assert(chunk != NULL);
		  if (dostring(L, chunk, "=(command line)") != 0)
			  return 1;
		  break;
				}
	  case 'l': {
		  const char *filename = argv[i] + 2;
		  if (*filename == '\0') filename = argv[++i];
		  lua_assert(filename != NULL);
		  if (dolibrary(L, filename))
			  return 1;  /* stop if file fails */
		  break;
				}
	  default: break;
		}
	}
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// 
static int handle_luainit (lua_State *L) {
	const char *init = getenv(LUA_INIT);
	if (init == NULL) return 0;  /* status OK */
	else if (init[0] == '@')
		return dofile(L, init+1);
	else
		return dostring(L, init, "=" LUA_INIT);
}






//////////////////////////////////////////////////////////////////////////
/// 
static int Load(int argc, char *argv[]) {
	lua_State* L = LuaNode::luaVm;
	
	int status = handle_luainit(L);
	if(status != 0) return EXIT_FAILURE;

	int has_i, has_v, has_e;
	int script = collectargs(argv, &has_i, &has_v, &has_e);
	if (script < 0) {  /* invalid args? */
		PrintUsage();
		//s->status = 1;
		return 1;
	}

	status = runargs(L, argv, (script > 0) ? script : argc);
	//status = runargs(L, argv, argc);
	if(status != 0) return EXIT_FAILURE;

	if(!Platform::Initialize()) {
		LogError("Failed to perform platform specific initialization");
		return EXIT_FAILURE;
	}

	// tabla 'process'
	lua_newtable(L);
	int process = lua_gettop(L);
	lua_pushstring(L, LUANODE_VERSION);
	lua_setfield(L, process, "version");

	// process.platform
	lua_pushstring(L, LuaNode::Platform::GetPlatform());
	lua_setfield(L, process, "platform");

	// this shouldn't be here
	lua_pushcfunction(L, LuaNode::Platform::SetConsoleForegroundColor);
	lua_setfield(L, process, "set_console_fg_color");
	lua_pushcfunction(L, LuaNode::Platform::SetConsoleBackgroundColor);
	lua_setfield(L, process, "set_console_bg_color");

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
	lua_setfield(L, process, "argv");

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
	lua_setfield(L, process, "env");

#if defined(_WIN32)
	lua_pushinteger(L, _getpid());
#elif defined(__linux__)
	lua_pushinteger(L, getpid());
#else
	#error "unsupported platform"
#endif
	lua_setfield(L, process, "pid");

	// module api
	LuaNode::ModuleApi::Register(L, process);

	size_t size = 2048;
	std::vector<char> execPath(size);
	if (Platform::GetExecutablePath(&execPath[0], &size) != 0) {
		// as a last ditch effort, fallback on argv[0] ?
		lua_pushstring(L, argv[0]);
		lua_setfield(L, process, "execPath");
	}
	else {
		lua_pushstring(L, &execPath[0]);
		lua_setfield(L, process, "execPath");
	}
	
	// define various internal methods
	lua_pushvalue(L, process);
	luaL_Reg methods[] = {
		{ "loop", Loop },
		{ "cwd", Cwd },
		//{ "_kill", Kill },
		{ "_needTickCallback", NeedTickCallback },
		{ "_exit", Exit },
		{ 0, 0 }
	};
	luaL_register(L, NULL, methods);
	lua_pop(L, 1);
		
	// Initialize the C++ modules..................filename of module
	Net::RegisterFunctions(L);

	Net::Acceptor::Register(L, NULL, true);

	Net::Socket::Register(L, NULL, true);

	Dns::Resolver::Register(L, NULL, true);

	Datagram::Socket::Register(L, NULL, true);

	Crypto::Register(L);

	Http::RegisterFunctions(L);
	Http::Parser::EnableTracking(L);
	Http::Parser::Register(L, NULL, true);

	Timer::Register(L, NULL, true);

	ChildProcess::Register(L, NULL, true);
	
	OS::RegisterFunctions(L);
	Fs::RegisterFunctions(L);

	//DefineConstants(L);
	
	int extension_status = 1;

	// Load modules that need to be loaded before LuaNode ones
	PreloadAdditionalModules(L);

	// load stacktraceplus and use it as our error handler
	lua_getfield(L, LUA_GLOBALSINDEX, "require");
	lua_pushliteral(L, "stacktraceplus");
	lua_call(L, 1, 1);
	lua_getfield(L, -1, "stacktrace");
	int ref = luaL_ref(L, LUA_REGISTRYINDEX);
	LuaNode::luaVm.setErrorHandler(ref);		// TODO: maybe add a flag to disable it?

	if(!debug_mode) {
		PreloadModules(L);

		#include "../build/temp/node.precomp"
		if(extension_status) {
			return lua_error(L);
		}
	}
	else {
		lua_pushboolean(L, true);
		lua_setfield(L, LUA_GLOBALSINDEX, "DEBUG"); // esto es temporal (y horrendo)
#if defined _WIN32
		LuaNode::luaVm.loadfile("d:/trunk_git/sources/luanode/src/node.lua");
#else
		LuaNode::luaVm.loadfile("/home/ignacio/devel/sources/LuaNode/src/node.lua");
#endif
	}

	LuaNode::luaVm.call(0, 1);

	int function = lua_gettop(L);
	if(lua_type(L, function) != LUA_TFUNCTION) {
		LogError("Error in node.lua");
		lua_settop(L, 0);
		return EXIT_FAILURE;
	}
	lua_pushvalue(L, process);

	if(LuaNode::luaVm.call(1, LUA_MULTRET) != 0) {
		LuaNode::luaVm.dostring("process:emit('unhandledError')");	// TODO: pass the error's callstack
		LuaNode::luaVm.dostring("process:emit('exit')");
		return EXIT_FAILURE;
	}
	if(lua_type(L, -1) == LUA_TNUMBER) {
		return lua_tointeger(L, -1);
	}

	return EXIT_SUCCESS;
}


//////////////////////////////////////////////////////////////////////////
/// Parse LuaNode command line arguments.
static void ParseArgs(int *argc, char **argv) {
	int i;

	// TODO use parse opts
	for (i = 1; i < *argc; i++) {
		const char *arg = argv[i];
		if (strstr(arg, "--debug") == arg) {
			//ParseDebugOpt(arg);
			argv[i] = const_cast<char*>("");
			debug_mode = true;
		} else if (strcmp(arg, "--version") == 0 || strcmp(arg, "-v") == 0) {
			PrintVersion();
			exit(EXIT_SUCCESS);
		} else if (strcmp(arg, "--vars") == 0) {
			// TODO: Print the flags used when it was compiled
			exit(EXIT_SUCCESS);
		} else if (strcmp(arg, "--help") == 0 || strcmp(arg, "-h") == 0) {
			PrintUsage();
			exit(EXIT_SUCCESS);
		} else if (argv[i][0] != '-') {
			break;
		}
	}

	option_end_index = i;
}

//////////////////////////////////////////////////////////////////////////
/// 
static void AtExit() {
	//LuaNode::Stdio::Flush();
	//LuaNode::Stdio::DisableRawMode(STDIN_FILENO);
	LogFree();

#if defined(_WIN32)  &&  !defined(__CYGWIN__) 
	SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE);
#else
	printf("\033[0m");
#endif
}

//////////////////////////////////////////////////////////////////////////
/// Para poder bajar el servicio, si tengo la consola habilitada
#if defined(_WIN32)
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

			// Stop the io pool
			LuaNode::GetIoService().stop();
			LogInfo("After CTRL-C event");
			return TRUE;
			break;
		case CTRL_CLOSE_EVENT:
		case CTRL_SHUTDOWN_EVENT:
			LogInfo("Event: CTRL-CLOSE or CTRL-SHUTDOWN Event");

			// Stop the io pool
			LuaNode::GetIoService().stop();
			return FALSE;
			break;
	}
	return FALSE;
}
#endif

}  // namespace LuaNode


//////////////////////////////////////////////////////////////////////////
/// 
int main(int argc, char* argv[])
{
#if defined(_WIN32)
	if(!SetConsoleCtrlHandler((PHANDLER_ROUTINE)LuaNode::ConsoleControlHandler, TRUE)) {
		LogError("SetConsoleCtrlHandler failed");
		return -1;
	}
#endif
	// TODO: Parsear argumentos

	// TODO: wrappear el log en un objeto (o usar libblogger2cpp)
	LogInfo("**** Starting LuaNode - Built on %s ****", LuaNode::compileDateTime);

#ifndef _WIN32
	LuaNode::RegisterSignalHandler(SIGPIPE, SIG_IGN);
#endif
	LuaNode::RegisterSignalHandler(SIGINT, LuaNode::SignalExit);
	LuaNode::RegisterSignalHandler(SIGTERM, LuaNode::SignalExit);

	atexit(LuaNode::AtExit);

	// Parse a few arguments which are specific to Node.
	LuaNode::ParseArgs(&argc, argv);

	int result = LuaNode::Load(argc, argv);
	LogFree();
	return result;
}
