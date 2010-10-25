rem @echo off

@call luanode run.lua simple.test-event-emitter-add-listeners
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-event-emitter-modify-in-emit
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-event-emitter-once
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-event-emitter-remove-listeners
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-1_0
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-blank-header
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-cat
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-chunked
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-client-parse-error
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-client-race
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-client-race-2
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-client-upload
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-contentLength0
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-eof-on-connect
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-head-request
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-head-response-has-no-body
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-keep-alive
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-keep-alive-close-on-header
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-malformed-request
@rem @if not %errorlevel% == 0 exit %errorlevel%

@rem @call luanode run.lua simple.test-http-parser
@rem @if not %errorlevel% == 0 exit %errorlevel%

@rem @call luanode run.lua simple.test-http-proxy
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-server
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-server-multiheaders
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-set-cookies
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-set-timeout
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-set-trailers
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-tls
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-upgrade-client
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-upgrade-client2
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-upgrade-server
@rem @if not %errorlevel% == 0 exit %errorlevel%

@rem @call luanode run.lua test-http-upgrade-server2
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-wget
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-write-empty-string
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-binary
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-eaddrinuse
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-isip
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple\test-net-multiple-writes-close.lua
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-reconnect
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-pingpong
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-server-max-connections
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-tls
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple\test-next-tick
@rem @if not %errorlevel% == 0 exit %errorlevel%

@rem este test esta deshabilitado porque no llamo los event handlers con pcall (para facilitar el debug)
@rem @call luanode run.lua simple\test-next-tick-errors
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple\test-next-tick-ordering
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple\test-next-tick-ordering2
@rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-zerolengthbufferbug
@rem @if not %errorlevel% == 0 exit %errorlevel%

