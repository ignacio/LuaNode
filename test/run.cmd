rem @echo off

@call luanode run.lua simple.test-event-emitter-add-listeners
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-event-emitter-modify-in-emit
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-event-emitter-remove-listeners
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-1_0
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-blank-header
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-cat
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-chunked
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-client-parse-error
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-client-race
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-client-race-2
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-client-upload
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-contentLength0
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-eof-on-connect
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-head-request
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-head-response-has-no-body
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-keep-alive
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-keep-alive-close-on-header
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-malformed-request
@if not %errorlevel% == 0 exit %errorlevel%

rem @call luanode run.lua simple.test-http-parser
rem @if not %errorlevel% == 0 exit %errorlevel%

rem @call luanode run.lua simple.test-http-proxy
rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-server
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-server-multiheaders
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-set-cookies
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-set-timeout
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-set-trailers
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-tls
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-upgrade-client
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-upgrade-client2
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-upgrade-server
@if not %errorlevel% == 0 exit %errorlevel%

rem @call luanode run.lua test-http-upgrade-server2
rem @if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-wget
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-http-write-empty-string
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-binary
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-isip
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-reconnect
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-pingpong
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-server-max-connections
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-net-tls
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple\test-next-tick
@if not %errorlevel% == 0 exit %errorlevel%

rem este test esta deshabilitado porque no llamo los event handlers con pcall (para facilitar el debug)
rem @call luanode run.lua simple\test-next-tick-errors
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple\test-next-tick-ordering
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple\test-next-tick-ordering2
@if not %errorlevel% == 0 exit %errorlevel%

@call luanode run.lua simple.test-zerolengthbufferbug
@if not %errorlevel% == 0 exit %errorlevel%

