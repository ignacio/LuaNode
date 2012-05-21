#include "stdafx.h"

#ifdef _MSC_VER
#  pragma warning(disable:4180)	// warning C4180: qualifier applied to function type has no meaning; ignored
#  include "luanode.h"			// because the call to LuaNode::GetIoService().post(LuaNode::Tick) does not bind any arg
#  pragma warning(default:4180)
#else
#  include "luanode.h"
#endif

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
#include "luanode_stdio.h"
#include "luanode_constants.h"

#if defined (_WIN32)
	#include "luanode_file_win32.h"
#elif defined(__linux__)
	#include "luanode_file_linux.h"
#elif defined(__APPLE__)
	#include "luanode_file_linux.h"	// temporary hack
#elif defined(__FreeBSD__)
	#include "luanode_file_linux.h"	// temporary hack
#else
	#error "Unsupported platform"
#endif

#include "blogger.h"

#include "../lib/preloader.h"


#ifndef SIGPOLL
#if defined (__FreeBSD__)
#define SIGPOLL SIGIO
#endif
#endif

#if defined(__FreeBSD__)
extern char **environ;
#endif

/*#ifdef _WIN32
#include <io.h>
#include <stdio.h>
#define lua_stdin_is_tty()	_isatty(_fileno(stdin))
#else
#include <unistd.h>
#define lua_stdin_is_tty()	isatty(0)
#endif*/

#ifdef __APPLE__
  #include <crt_externs.h>
  #define environ (*_NSGetEnviron())
#endif


namespace LuaNode {

static const char* LUANODE_PROGNAME = "LuaNode";
static const char* LUANODE_VERSION = "0.0.1";
static const char* compileDateTime = "" __DATE__ """ - """ __TIME__ "";

static int option_end_index = 0;
static bool debug_mode = false;

static bool need_tick_cb = false;
static int tickCallback = LUA_NOREF;

static boost::asio::io_service io_service;
static CLuaVM* luaVm = NULL;
static int exit_code = 0;
static CLogger* logger = NULL;


//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ boost::asio::io_service& GetIoService() {
	return io_service;
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ CLuaVM& GetLuaVM() {
	return *luaVm;
}

//////////////////////////////////////////////////////////////////////////
/// 
/*static*/ CLogger& Logger() {
	return *logger;
}

//////////////////////////////////////////////////////////////////////////
/// -> nil, error message, error code
/*static*/ int BoostErrorCodeToLua(lua_State* L, const boost::system::error_code& ec) 
{
	if(ec) {
		lua_pushnil(L);
		lua_pushstring(L, ec.message().c_str());
		lua_pushinteger(L, ec.value());
		return 3;
	}
	lua_pushboolean(L, true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// ->error message, error code
/// To be used when preparing callback arguments: cb(err, stuff)
/*static*/ int BoostErrorToCallback (lua_State* L, const boost::system::error_code& ec)
{
	lua_pushstring(L, ec.message().c_str());
	lua_pushinteger(L, ec.value());
	return 2;
}

//////////////////////////////////////////////////////////////////////////
/// http://linux.die.net/man/7/signal
static const char* SignalNumberToString(int sig_no) {
	switch(sig_no) {
		case SIGABRT: return "SIGABRT"; break;  /* Abort signal from abort(3) */
		case SIGFPE:  return "SIGFPE";  break;  /* Floating point exception */
		case SIGILL:  return "SIGILL";  break;  /* Illegal Instruction */
		case SIGINT:  return "SIGINT";  break;  /* Interrupt from keyboard */
		case SIGSEGV: return "SIGSEGV"; break;  /* Invalid memory reference */
		case SIGTERM: return "SIGTERM"; break;  /* Termination signal */

#ifndef _WIN32
		case SIGALRM: return "SIGALRM"; break;  /* Timer signal from alarm(2) */
		case SIGHUP:  return "SIGHUP";  break;	/* Hangup detected on controlling terminal or death of controlling process */
		case SIGKILL: return "SIGKILL"; break;  /* Kill signal */
		case SIGPIPE: return "SIGPIPE"; break;  /* Broken pipe: write to pipe with no readers */
		case SIGQUIT: return "SIGQUIT"; break;  /* Quit from keyboard */
		case SIGUSR1: return "SIGUSR1"; break;  /* User-defined signal 1 */
		case SIGUSR2: return "SIGUSR2"; break;  /* User-defined signal 2 */
		case SIGCHLD: return "SIGCHLD"; break;  /* Child stopped or terminated */
		case SIGCONT: return "SIGCONT"; break;  /* Continue if stopped */
		case SIGSTOP: return "SIGSTOP"; break;  /* Stop process */
		case SIGTSTP: return "SIGTSTP"; break;  /* Stop typed at tty */
		case SIGTTIN: return "SIGTTIN"; break;  /* tty input for background process */
		case SIGTTOU: return "SIGTTOU"; break;  /* tty output for background process */

		case SIGBUS:  return "SIGBUS";  break;  /* Bus error (bad memory access) */
		case SIGPOLL: return "SIGPOLL"; break;  /* Pollable event (Sys V). Synonym of SIGIO */
		case SIGPROF: return "SIGPROF"; break;  /* Profiling timer expired */
		case SIGSYS:  return "SIGSYS";  break;  /* Bad argument to routine (SVr4) */
		case SIGTRAP: return "SIGTRAP"; break;  /* Trace/breakpoint trap */
		case SIGURG:  return "SIGURG";  break;  /* Urgent condition on socket (4.2BSD) */
		case SIGVTALRM: return "SIGVTALRM"; break;  /* Virtual alarm clock (4.2BSD) */
		case SIGXCPU: return "SIGXCPU"; break;  /* CPU time limit exceeded (4.2BSD) */
		case SIGXFSZ: return "SIGXFSZ"; break;  /* File size limit exceeded (4.2BSD) */

#endif

		default: return "unknown"; break;
	}
}

//////////////////////////////////////////////////////////////////////////
/// 
static void SignalExit(int signal) {
	fprintf(stderr, "\nSignalExit %s (%d)\n", SignalNumberToString(signal), signal);
	// Stop the io pool
	LuaNode::GetIoService().stop();
}

//////////////////////////////////////////////////////////////////////////
/// 
static int RegisterSignalHandler(int signal_no, void (*handler)(int)) {
	LogDebug("Registering signal handler for %s (%d)", SignalNumberToString(signal_no), signal_no);
#ifdef _WIN32
	signal(signal_no, handler);
	return 0;
#else
	struct sigaction sa;

	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = handler;
	sigfillset(&sa.sa_mask);
	return sigaction(signal_no, &sa, NULL);
#endif	
}

//////////////////////////////////////////////////////////////////////////
/// 
static void Tick() {
	need_tick_cb = false;
	CLuaVM& vm = LuaNode::GetLuaVM();
	
	int top = lua_gettop(vm);
	// I'd previously stored the callback in the registry
	lua_rawgeti(vm, LUA_REGISTRYINDEX, tickCallback);
	vm.call(0, LUA_MULTRET);
	int results = lua_gettop(vm) - top;
	if(results && lua_isstring(vm, -1)) {
		const char* message = lua_tostring(vm, -1);
		if(!FatalError(vm, message)) {
			ReportError(vm, message);
		}
	}

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
	fprintf(stderr, "Exit with code %d\n", code);

	// Will it be possible to have a clean ending?
#ifdef _WIN32
	//::ExitProcess(0);
	//::TerminateProcess(NULL, code);
	exit_code = code;
#else
	//exit(code);
	exit_code = code;
#endif
	return 0;
}

//////////////////////////////////////////////////////////////////////////
/// The main loop. Will return false + error message (or error code) in 
/// case of an error.
static int Loop(lua_State* L) {
	//lua_getfield(L, LUA_GLOBALSINDEX, "process");

	// store the callback in the registry to retrieve it faster
	lua_getfield(L, 1, "_tickcallback");	// process, function
	tickCallback = luaL_ref(L, LUA_REGISTRYINDEX);


	// TODO: Ver si esto no jode. Estoy sacando la tabla process del stack de C. Es seguro hacer esto porque en node.lua 
	// guardé una referencia en _G
	lua_settop(L, 0);
	// If Loop was called from a coroutine, also set the main thread's top to zero
	if(L != LuaNode::GetLuaVM())
	{
		lua_settop( LuaNode::GetLuaVM(), 0 );
	}

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
		lua_pushnil(L);
		lua_pushstring(L, ec.message().c_str());
		return 2;
	}
	LogDebug("LuaNode.exe: Loop - end");
	if(exit_code) {
		lua_pushnil(L);
		lua_pushnumber(L, exit_code);
		return 2;
	}
	lua_pushboolean(L, true);
	return 1;
}

//////////////////////////////////////////////////////////////////////////
/// 

static int uncaught_exception_counter = 0;

void ReportError(lua_State* L, const char* message) {
	lua_getfield(L, LUA_GLOBALSINDEX, "console");
	if(lua_istable(L, -1)) {
		lua_getfield(L, -1, "error");
		if(lua_type(L, -1) == LUA_TFUNCTION) {
			lua_pushstring(L, "%s");
			lua_pushstring(L, message);
			lua_call(L, 2, 0);
		}
		else {
			fprintf(stderr, "%s\n", message);
			lua_pop(L, 1);
		}
	}
	else {
		fprintf(stderr, "%s\n", message);
	}
	lua_pop(L, 1);
	LogError("%s", message);
}

//////////////////////////////////////////////////////////////////////////
/// Deals with unhandled Lua errors. Returns true if the error was handled
/// (that is, an 'unhandledError' handler was found).
bool FatalError(lua_State* L, const char* message)
{
	int top = lua_gettop(L);
	// Check if uncaught_exception_counter indicates a recursion
	if (uncaught_exception_counter > 0) {
		LuaNode::GetIoService().stop();
		return false;
	}

	lua_getfield(L, LUA_GLOBALSINDEX, "process");
	lua_getfield(L, -1, "_events");
	if(!lua_istable(L, -1)) {
		uncaught_exception_counter++;
		LuaNode::luaVm->dostring("process:exit(1)");
		uncaught_exception_counter--;
		return false;
	}
	lua_getfield(L, -1, "unhandledError");
	if(!lua_isnil(L, -1)) {
		uncaught_exception_counter++;
		lua_pushstring(L, message);
		LuaNode::luaVm->dostring("process:emit('unhandledError', ...)", 1);
		uncaught_exception_counter--;
		lua_settop(L, top);
		return true;
	}
	else {
		uncaught_exception_counter++;
		LuaNode::luaVm->dostring("process:exit(1)");
		uncaught_exception_counter--;
	}
	return false;
}

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
	lua_sethook(*LuaNode::luaVm, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
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
	lua_State* L = *LuaNode::luaVm;
	
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

	lua_pushboolean(L, true);
	lua_setfield(L, LUA_GLOBALSINDEX, "_LUANODE");

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

	// this also shouldn't be here
	lua_pushcfunction(L, LuaNode::Platform::SetProcessTitle);
	lua_setfield(L, process, "set_process_title");
	lua_pushcfunction(L, LuaNode::Platform::GetProcessTitle);
	lua_setfield(L, process, "get_process_title");

	// internal stuff
	lua_newtable(L);
	int internal = lua_gettop(L);
	lua_pushcfunction(L, LogDebug);
	lua_setfield(L, internal, "LogDebug");
	lua_pushcfunction(L, LogInfo);
	lua_setfield(L, internal, "LogInfo");
	lua_pushcfunction(L, LogProfile);
	lua_setfield(L, internal, "LogProfile");
	lua_pushcfunction(L, LogWarning);
	lua_setfield(L, internal, "LogWarning");
	lua_pushcfunction(L, LogError);
	lua_setfield(L, internal, "LogError");
	lua_pushcfunction(L, LogFatal);
	lua_setfield(L, internal, "LogFatal");
	lua_setfield(L, process, "__internal");

	// process.argv
	lua_newtable(L);
	int argArray = lua_gettop(L);
	lua_pushstring(L, argv[0]);
	lua_rawseti(L, argArray, -1);
	for(int j = 0, i = option_end_index; i < argc; j++, i++) {
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
#elif defined(__linux__) || defined(__FreeBSD__)
	lua_pushinteger(L, getpid());
#else
	#error "unsupported platform"
#endif
	lua_setfield(L, process, "pid");

	LuaNode::DefineConstants(L);
	lua_setfield(L, -2, "constants");

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

	Fs::File::Register(L, NULL, true);

	Stdio::RegisterFunctions(L);

	//DefineConstants(L);
	
	// Load modules that need to be loaded before LuaNode ones
	PreloadAdditionalModules(L);

	// load stacktraceplus and use it as our error handler
	lua_getfield(L, LUA_GLOBALSINDEX, "require");
	lua_pushliteral(L, "stacktraceplus");
	lua_call(L, 1, 1);
	lua_getfield(L, -1, "stacktrace");
	int ref = luaL_ref(L, LUA_REGISTRYINDEX);
	LuaNode::luaVm->setErrorHandler(ref);		// TODO: maybe add a flag to disable it?

	if(!debug_mode) {
		PreloadModules(L);
		static const unsigned char code[] = {
			#include "node.precomp"
		};
		if(luaL_loadbuffer(L,(const char*)code,sizeof(code),"luanode")) {
			return lua_error(L);
		}
	}
	else {
		lua_pushboolean(L, true);
		lua_setfield(L, LUA_GLOBALSINDEX, "DEBUG"); // esto es temporal (y horrendo)
#if defined _WIN32
		LuaNode::luaVm->loadfile("d:/trunk_git/sources/luanode/src/node.lua");
#else
		LuaNode::luaVm->loadfile("/home/ignacio/devel/sources/LuaNode/src/node.lua");
#endif
	}

	LuaNode::luaVm->call(0, 1);

	int function = lua_gettop(L);
	if(lua_type(L, function) != LUA_TFUNCTION) {
		LogError("Error in node.lua");
		lua_settop(L, 0);
		return EXIT_FAILURE;
	}
	lua_pushvalue(L, process);

	if(LuaNode::luaVm->call(1, LUA_MULTRET) != 0) {
		//LuaNode::luaVm->dostring("process:emit('unhandledError')");	// the error was already reported in CLuaVM::OnError
		LuaNode::luaVm->dostring("process:emit('exit')");
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
		} else if (strcmp(arg, "--logname") == 0 && i != *argc) {
			const char* app_name = argv[i+1];
			LuaNode::logger = new CLogger(app_name);
			argv[i] = const_cast<char*>("");
			argv[++i] = const_cast<char*>("");
		} else if (argv[i][0] != '-') {
			break;
		}
	}

	option_end_index = i;
}

//////////////////////////////////////////////////////////////////////////
/// 
static void AtExit() {
	LuaNode::Stdio::Flush();
	LuaNode::Stdio::OnExit();

#if defined(_WIN32)  &&  !defined(__CYGWIN__) 
	SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE);
#else
	printf("\033[0m");
#endif

	// in case it escaped
	if(luaVm) {
		delete luaVm;
		luaVm = NULL;
	}
	//LogFree();
	if(logger) {
		delete logger;
		logger = NULL;
	}
}

//////////////////////////////////////////////////////////////////////////
/// Para poder bajar el servicio, si tengo la consola habilitada
#if defined(_WIN32)

static void SafeLog(const char* message) {
	bool can_log = (logger != NULL);
	if(can_log) {
		LogInfo("%s", message);
	}
	else {
		fprintf(stderr, message);
		fprintf(stderr, "\n");
	}
}

BOOL WINAPI ConsoleControlHandler(DWORD ctrlType) {
	SafeLog("***** Console Event Detected *****");
	switch(ctrlType) {
		case CTRL_LOGOFF_EVENT:
			SafeLog("Event: CTRL-LOGOFF Event");
			return TRUE;
			break;
		case CTRL_C_EVENT:
		case CTRL_BREAK_EVENT:
			SafeLog("Event: CTRL-C or CTRL-BREAK Event");

			// Stop the io pool
			LuaNode::GetIoService().stop();
			SafeLog("After CTRL-C event");
			return TRUE;
			break;
		case CTRL_CLOSE_EVENT:
		case CTRL_SHUTDOWN_EVENT:
			SafeLog("Event: CTRL-CLOSE or CTRL-SHUTDOWN Event");

			// Stop the io pool
			LuaNode::GetIoService().stop();
			//AtExit();
			return TRUE;	// don't call the default handler
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
	// Parse a few arguments which are specific to Node.
	LuaNode::ParseArgs(&argc, argv);
	if(!LuaNode::logger) {
		LuaNode::logger = new CLogger("LuaNode");
	}

	LuaNode::luaVm = new CLuaVM;

	// TODO: wrappear el log en un objeto (o usar libblogger2cpp)
	LogInfo("**** Starting LuaNode - Built on %s ****", LuaNode::compileDateTime);
#ifndef _WIN32
	LuaNode::RegisterSignalHandler(SIGPIPE, SIG_IGN);
#endif
	LuaNode::RegisterSignalHandler(SIGINT, LuaNode::SignalExit);
	LuaNode::RegisterSignalHandler(SIGTERM, LuaNode::SignalExit);

	atexit(LuaNode::AtExit);

	int result = LuaNode::Load(argc, argv);

	delete LuaNode::luaVm; LuaNode::luaVm = NULL;
	delete LuaNode::logger; LuaNode::logger = NULL;

	if(LuaNode::exit_code != 0) {
		return LuaNode::exit_code;
	}
	return result;
}
